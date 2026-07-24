-- Geri Dönüş Özeti (Comeback Summary) — retention modal verisi
-- Offline >= 8 saat VEYA >= 2 bekleyen aksiyon → show_summary

CREATE OR REPLACE FUNCTION public._comeback_facility_label(p_type text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_type
    WHEN 'farming' THEN 'Çiftlik'
    WHEN 'mine' THEN 'Maden'
    WHEN 'lumber' THEN 'Kereste'
    WHEN 'fishing' THEN 'Balıkçılık'
    ELSE COALESCE(NULLIF(p_type, ''), 'Tesis')
  END;
$$;

CREATE OR REPLACE FUNCTION public.get_comeback_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_player record;
  v_items jsonb := '[]'::jsonb;
  v_offline_hours numeric := 0;
  v_last_seen timestamptz;
  v_pending_count integer := 0;
  v_show_summary boolean := false;
  -- Prod: 8h. QA/dev: düşürmek için burayı değiştir.
  v_offline_threshold_hours numeric := 8;
  v_min_pending_for_summary integer := 2;

  v_daily record;
  v_facility record;
  v_counts jsonb;
  v_box record;
  v_quest record;
  v_bp_quest record;
  v_incoming integer := 0;
  v_claimable_gems integer := 0;
  v_guild_war_count integer := 0;
  v_siege_active boolean := false;
  v_hospital_secs integer;
  v_prison_secs integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Oturum bulunamadı.',
      'show_summary', false,
      'offline_hours', 0,
      'pending_count', 0,
      'items', '[]'::jsonb
    );
  END IF;

  SELECT
    u.auth_id,
    u.level,
    u.energy,
    u.max_energy,
    u.hospital_until,
    u.prison_until,
    u.hospital_reason,
    u.prison_reason,
    u.guild_id,
    COALESCE(u.last_active_at, u.last_login_at, u.updated_at, u.created_at) AS last_seen
  INTO v_player
  FROM public.users u
  WHERE u.auth_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Profil bulunamadı.',
      'show_summary', false,
      'offline_hours', 0,
      'pending_count', 0,
      'items', '[]'::jsonb
    );
  END IF;

  v_last_seen := v_player.last_seen;
  v_offline_hours := ROUND(
    EXTRACT(EPOCH FROM (now() - v_last_seen)) / 3600.0,
    1
  );

  -- ── Tesis toplama ───────────────────────────────────────────────────────
  FOR v_facility IN
    SELECT f.id, f.type, COALESCE(f.level, 1) AS level, f.production_started_at
    FROM public.facilities f
    WHERE f.user_id = v_user_id
      AND COALESCE(f.is_active, true) = true
      AND f.production_started_at IS NOT NULL
  LOOP
    v_counts := public._facility_production_counts(
      v_facility.production_started_at,
      v_facility.level,
      v_facility.type
    );
    IF COALESCE((v_counts->>'is_ready')::boolean, false) THEN
      v_items := v_items || jsonb_build_array(
        jsonb_build_object(
          'id', 'facility:' || v_facility.id::text,
          'kind', 'facility_ready',
          'title', 'Tesis üretimi hazır',
          'subtitle', public._comeback_facility_label(v_facility.type) || ' — kaynakları topla.',
          'route', '/facilities/' || v_facility.type,
          'priority', 62,
          'cta_label', 'Topla'
        )
      );
    END IF;
  END LOOP;

  -- ── Kasa açılmaya hazır ─────────────────────────────────────────────────
  FOR v_box IN
    SELECT
      bo.id AS opening_id,
      COALESCE(cfg.name, bo.box_id) AS box_name
    FROM public.box_openings bo
    LEFT JOIN public.loot_box_configs cfg ON cfg.id = bo.box_id
    WHERE bo.user_id = v_user_id
      AND bo.status = 'opening'
      AND now() >= bo.opens_at
  LOOP
    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'id', 'box:' || v_box.opening_id::text,
        'kind', 'box_ready',
        'title', 'Kasa açılmaya hazır',
        'subtitle', v_box.box_name || ' kasasını açabilirsin.',
        'route', '/inventory',
        'priority', 65,
        'cta_label', 'Aç'
      )
    );
  END LOOP;

  -- ── Hastane / hapishane ───────────────────────────────────────────────────
  IF v_player.hospital_until IS NOT NULL AND v_player.hospital_until > now() THEN
    v_hospital_secs := GREATEST(
      0,
      EXTRACT(EPOCH FROM (v_player.hospital_until - now()))::integer
    );
    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'id', 'hospital:active',
        'kind', 'hospital',
        'title', 'Hastanedesin',
        'subtitle', COALESCE(
          NULLIF(v_player.hospital_reason, ''),
          'İyileşene kadar bazı aktiviteler kısıtlı.'
        ) || ' · ' || (v_hospital_secs / 60)::text || ' dk kaldı',
        'route', '/hospital',
        'priority', 60,
        'cta_label', 'Git'
      )
    );
  ELSIF v_player.hospital_until IS NOT NULL
        AND v_player.hospital_until <= now()
        AND v_player.hospital_until >= v_last_seen THEN
    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'id', 'hospital:released',
        'kind', 'hospital',
        'title', 'Hastaneden çıktın',
        'subtitle', 'Yokluğunda iyileşme tamamlandı.',
        'route', '/hospital',
        'priority', 58,
        'cta_label', 'Detay'
      )
    );
  END IF;

  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    v_prison_secs := GREATEST(
      0,
      EXTRACT(EPOCH FROM (v_player.prison_until - now()))::integer
    );
    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'id', 'prison:active',
        'kind', 'prison',
        'title', 'Hapistesin',
        'subtitle', COALESCE(
          NULLIF(v_player.prison_reason, ''),
          'Serbest kalana kadar hareketlerin kısıtlı.'
        ) || ' · ' || (v_prison_secs / 60)::text || ' dk kaldı',
        'route', '/prison',
        'priority', 60,
        'cta_label', 'Git'
      )
    );
  ELSIF v_player.prison_until IS NOT NULL
        AND v_player.prison_until <= now()
        AND v_player.prison_until >= v_last_seen THEN
    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'id', 'prison:released',
        'kind', 'prison',
        'title', 'Hapishaneden çıktın',
        'subtitle', 'Yokluğunda ceza süresi bitti.',
        'route', '/prison',
        'priority', 58,
        'cta_label', 'Detay'
      )
    );
  END IF;

  -- ── Lonca savaşı / kuşatma ──────────────────────────────────────────────
  IF v_player.guild_id IS NOT NULL THEN
    SELECT COUNT(*)::integer
    INTO v_guild_war_count
    FROM public.guild_war_tournaments t
    WHERE t.status IN ('active', 'registration', 'live', 'upcoming')
      AND (t.end_at IS NULL OR t.end_at > now());

    IF v_guild_war_count > 0 THEN
      v_items := v_items || jsonb_build_array(
        jsonb_build_object(
          'id', 'guild_war:alerts',
          'kind', 'guild_war',
          'title', 'Lonca savaşı uyarısı',
          'subtitle', v_guild_war_count::text || ' aktif turnuva veya kayıt dönemi.',
          'route', '/guild-war',
          'priority', 82,
          'cta_label', 'Git'
        )
      );
    END IF;

    BEGIN
      v_siege_active := public.dungeon_siege_is_enabled()
        AND public.dungeon_siege_in_prime_window();
    EXCEPTION WHEN OTHERS THEN
      v_siege_active := false;
    END;

    IF v_siege_active THEN
      v_items := v_items || jsonb_build_array(
        jsonb_build_object(
          'id', 'siege:active',
          'kind', 'guild_siege',
          'title', 'Zindan kuşatması aktif',
          'subtitle', 'Prime saatlerinde slot al veya meydan oku.',
          'route', '/dungeon/siege',
          'priority', 81,
          'cta_label', 'Git'
        )
      );
    END IF;
  END IF;

  -- ── Arkadaşlık istekleri ──────────────────────────────────────────────────
  SELECT COUNT(*)::integer
  INTO v_incoming
  FROM public.friendships f
  WHERE f.status = 'pending'
    AND f.addressee_id = v_user_id;

  IF v_incoming > 0 THEN
    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'id', 'friends:incoming',
        'kind', 'friend_request',
        'title', 'Arkadaşlık isteği',
        'subtitle', v_incoming::text || ' bekleyen istek var.',
        'route', '/friends',
        'priority', 80,
        'cta_label', 'Gör'
      )
    );
  END IF;

  -- ── Referans ödülü ──────────────────────────────────────────────────────
  SELECT COALESCE(SUM(sub.gems), 0)::integer
  INTO v_claimable_gems
  FROM (
    SELECT rr.referrer_gems AS gems
    FROM public.referral_rewards rr
    WHERE rr.referrer_id = v_user_id AND rr.referrer_claimed_at IS NULL
    UNION ALL
    SELECT 50
    FROM public.users u
    WHERE u.referred_by = v_user_id AND u.level >= 5
      AND NOT EXISTS (
        SELECT 1 FROM public.referral_rewards r2 WHERE r2.referred_id = u.auth_id
      )
    UNION ALL
    SELECT rr.referred_gems
    FROM public.referral_rewards rr
    WHERE rr.referred_id = v_user_id AND rr.referred_claimed_at IS NULL
    UNION ALL
    SELECT 25
    FROM public.users me
    WHERE me.auth_id = v_user_id
      AND me.referred_by IS NOT NULL
      AND me.level >= 5
      AND NOT EXISTS (
        SELECT 1 FROM public.referral_rewards r3 WHERE r3.referred_id = v_user_id
      )
  ) sub;

  IF v_claimable_gems > 0 THEN
    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'id', 'referral:claim',
        'kind', 'referral_reward',
        'title', 'Referans ödülü',
        'subtitle', v_claimable_gems::text || ' gem tahsil edilebilir.',
        'route', '/friends',
        'priority', 75,
        'cta_label', 'Al'
      )
    );
  END IF;

  -- ── Günlük ödül ───────────────────────────────────────────────────────────
  SELECT * INTO v_daily
  FROM public.daily_reward_resolve_state(
    v_user_id,
    (now() AT TIME ZONE 'UTC')::date
  );

  IF COALESCE(v_daily.can_claim, false) THEN
    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'id', 'daily:claim',
        'kind', 'daily_reward',
        'title', 'Günlük ödül hazır',
        'subtitle', 'Bugünkü ödülünü almayı unutma.',
        'route', '/home',
        'priority', 70,
        'cta_label', 'Al'
      )
    );
  END IF;

  -- ── Görev ödülleri ────────────────────────────────────────────────────────
  FOR v_quest IN
    SELECT q.name, q.quest_id
    FROM public.player_quests pq
    JOIN public.quests q ON q.quest_id = pq.quest_id
    WHERE pq.user_id = v_user_id
      AND pq.status = 'completed'
    ORDER BY pq.updated_at DESC NULLS LAST
    LIMIT 5
  LOOP
    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'id', 'quest:' || v_quest.quest_id,
        'kind', 'quest_reward',
        'title', 'Görev ödülü hazır',
        'subtitle', v_quest.name || ' — ödülü al.',
        'route', '/quests',
        'priority', 68,
        'cta_label', 'Al'
      )
    );
  END LOOP;

  -- ── Haftalık sözleşme (BP weekly) — varsa ─────────────────────────────────
  FOR v_bp_quest IN
    SELECT
      q.id,
      t.description,
      t.quest_type,
      q.current_progress,
      t.target_count,
      q.is_completed,
      q.reward_claimed
    FROM public.bp_player_quests q
    JOIN public.bp_quest_templates t ON t.id = q.template_id
    JOIN public.bp_seasons s ON s.id = q.season_id AND s.is_active = true
    WHERE q.player_id = v_user_id
      AND t.quest_type = 'weekly'
      AND (
        (q.is_completed AND NOT q.reward_claimed)
        OR (NOT q.is_completed AND q.current_progress > 0)
      )
    ORDER BY q.is_completed DESC, q.updated_at DESC NULLS LAST
    LIMIT 3
  LOOP
    IF v_bp_quest.is_completed AND NOT v_bp_quest.reward_claimed THEN
      v_items := v_items || jsonb_build_array(
        jsonb_build_object(
          'id', 'bp_weekly:' || v_bp_quest.id::text,
          'kind', 'weekly_contract',
          'title', 'Haftalık sözleşme tamamlandı',
          'subtitle', COALESCE(v_bp_quest.description, 'Sezon görev ödülünü al.'),
          'route', '/season',
          'priority', 66,
          'cta_label', 'Al'
        )
      );
    ELSE
      v_items := v_items || jsonb_build_array(
        jsonb_build_object(
          'id', 'bp_weekly_progress:' || v_bp_quest.id::text,
          'kind', 'weekly_contract',
          'title', 'Haftalık sözleşme ilerlemesi',
          'subtitle', COALESCE(v_bp_quest.description, 'Sezon görevi')
            || ' · '
            || v_bp_quest.current_progress::text
            || '/'
            || GREATEST(v_bp_quest.target_count, 1)::text,
          'route', '/season',
          'priority', 64,
          'cta_label', 'Git'
        )
      );
    END IF;
  END LOOP;

  -- ── Enerji durumu (her zaman) ─────────────────────────────────────────────
  v_items := v_items || jsonb_build_array(
    jsonb_build_object(
      'id', 'energy:status',
      'kind', 'energy',
      'title', 'Enerji durumu',
      'subtitle', COALESCE(v_player.energy, 0)::text
        || '/'
        || GREATEST(COALESCE(v_player.max_energy, 100), 1)::text
        || ' — '
        || CASE
          WHEN COALESCE(v_player.energy, 0) >= COALESCE(v_player.max_energy, 100)
            THEN 'Dolu'
          WHEN COALESCE(v_player.energy, 0) < 20
            THEN 'Kritik seviye'
          ELSE 'Yenileniyor'
        END,
      'route', '/character',
      'priority', 50,
      'cta_label', 'Gör'
    )
  );

  v_pending_count := (
    SELECT COUNT(*)::integer
    FROM jsonb_array_elements(v_items) AS elem
    WHERE elem->>'kind' <> 'energy'
  );

  v_show_summary := v_offline_hours >= v_offline_threshold_hours
    OR v_pending_count >= v_min_pending_for_summary;

  RETURN jsonb_build_object(
    'success', true,
    'show_summary', v_show_summary,
    'offline_hours', v_offline_hours,
    'pending_count', v_pending_count,
    'items', (
      SELECT COALESCE(jsonb_agg(elem ORDER BY (elem->>'priority')::integer DESC), '[]'::jsonb)
      FROM jsonb_array_elements(v_items) AS elem
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_comeback_summary_seen()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  UPDATE public.users
  SET last_active_at = now(),
      updated_at = now()
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_comeback_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_comeback_summary_seen() TO authenticated;
