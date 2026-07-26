-- Fix production Postgres errors from Supabase logs:
-- 42703 column d.dungeon_id does not exist (dungeons PK is id)
-- 3A000 UPDATE is not allowed in a non-volatile function (get_my_ban_status)

BEGIN;

-- Expired temp bans must write; PostgREST read-only tx rejects STABLE+UPDATE.
CREATE OR REPLACE FUNCTION public.get_my_ban_status()
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_u RECORD;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  UPDATE public.users
  SET is_banned = false,
      ban_reason = NULL,
      banned_until = NULL
  WHERE auth_id = v_user
    AND COALESCE(is_banned, false) = true
    AND banned_until IS NOT NULL
    AND banned_until <= now();

  SELECT is_banned, ban_reason, banned_until
  INTO v_u
  FROM public.users
  WHERE auth_id = v_user;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı.');
  END IF;

  IF COALESCE(v_u.is_banned, false) = true
     AND (v_u.banned_until IS NULL OR v_u.banned_until > now()) THEN
    RETURN jsonb_build_object(
      'success', true,
      'is_banned', true,
      'ban_reason', COALESCE(v_u.ban_reason, 'Hesabınız askıya alındı.'),
      'banned_until', v_u.banned_until
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'is_banned', false);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_live_ticker_feed_core(p_limit integer DEFAULT 10)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_limit INT := GREATEST(3, LEAST(COALESCE(p_limit, 10), 20));
  v_items JSONB := '[]'::JSONB;
  v_night RECORD;
  v_staff JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT jsonb_build_object(
    'id', 'staff_broadcast:' || b.id::text,
    'type', 'staff_broadcast',
    'text', '📣 ' || left(btrim(b.message), 280),
    'created_at', b.created_at,
    'max_passes', b.max_passes,
    'passes_remaining', GREATEST(b.max_passes - b.passes_completed, 0)
  )
  INTO v_staff
  FROM public.staff_broadcasts b
  WHERE b.is_active = true
    AND b.passes_completed < b.max_passes
    AND (b.expires_at IS NULL OR b.expires_at > now())
  ORDER BY b.created_at DESC
  LIMIT 1;

  WITH raw_events AS (
    SELECT
      'dungeon_clear'::text AS event_type,
      r.id::text AS event_id,
      r.player_id AS actor_id,
      r.created_at AS occurred_at,
      ('⚔️ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' boss '
        || public._ticker_clip_label(COALESCE(d.name_tr, d.name, r.dungeon_id), 'zindan')
        || ' yendi!') AS message,
      32 AS weight,
      NULL::int AS max_passes,
      NULL::int AS passes_remaining
    FROM public.dungeon_runs r
    JOIN public.users u ON u.auth_id = r.player_id
    JOIN public.dungeons d ON d.id = r.dungeon_id
    WHERE r.success = true
      AND COALESCE(d.is_boss, false) = true
      AND r.created_at > now() - interval '48 hours'
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles qb WHERE qb.bot_auth_id = r.player_id
      )

    UNION ALL

    SELECT
      'enhance_success', e.id::text, e.player_id, e.created_at,
      ('✨ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' +' || e.attempted_level::text || ' '
        || public._ticker_clip_label(COALESCE(i.name, e.item_id), 'eşya')
        || ' güçlendirdi!'),
      40 + LEAST(e.attempted_level, 15), NULL, NULL
    FROM public.enhancement_history e
    JOIN public.users u ON u.auth_id = e.player_id
    LEFT JOIN public.items i ON i.id = e.item_id
    WHERE e.success = true AND e.attempted_level >= 8
      AND e.created_at > now() - interval '7 days'
      AND NOT EXISTS (SELECT 1 FROM public.qa_bot_profiles qb WHERE qb.bot_auth_id = e.player_id)

    UNION ALL

    SELECT
      'loot_rare', l.id::text, l.user_id, l.created_at,
      ('🎁 ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' ' || upper(COALESCE(i.rarity, 'nadir')) || ' '
        || public._ticker_clip_label(COALESCE(i.name, l.reward_item_id), 'ödül')
        || ' kazandı!'),
      CASE lower(COALESCE(i.rarity, '')) WHEN 'mythic' THEN 50 ELSE 42 END,
      NULL, NULL
    FROM public.player_loot_box_logs l
    JOIN public.users u ON u.auth_id = l.user_id
    LEFT JOIN public.items i ON i.id = l.reward_item_id
    WHERE l.created_at > now() - interval '7 days'
      AND lower(COALESCE(i.rarity, '')) IN ('legendary', 'mythic')
      AND NOT EXISTS (SELECT 1 FROM public.qa_bot_profiles qb WHERE qb.bot_auth_id = l.user_id)

    UNION ALL

    SELECT
      'guild_war', a.id::text, a.attacker_guild_id, a.created_at,
      ('🏰 Lonca ' || public._ticker_clip_name(COALESCE(ag.name, ag.tag, '???'))
        || ' → '
        || public._ticker_clip_label(COALESCE(dg.name, dg.tag, ter.name, 'hedef'), 'lonca')
        || CASE WHEN a.success THEN ' fethetti!' ELSE ' saldırdı!' END),
      CASE WHEN a.success THEN 30 ELSE 22 END, NULL, NULL
    FROM public.guild_war_attack_logs a
    LEFT JOIN public.guilds ag ON ag.id = a.attacker_guild_id
    LEFT JOIN public.guilds dg ON dg.id = a.defender_guild_id
    LEFT JOIN public.guild_war_territories ter ON ter.id = a.territory_id
    WHERE a.created_at > now() - interval '7 days'

    UNION ALL

    SELECT
      'siege_win', c.id::text, c.winner_id, COALESCE(c.resolved_at, c.created_at),
      ('🛡️ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' kuşatmada '
        || public._ticker_clip_label(COALESCE(d.name_tr, d.name, c.dungeon_id), 'zindan')
        || ' kazandı!'),
      32, NULL, NULL
    FROM public.dungeon_siege_challenges c
    JOIN public.users u ON u.auth_id = c.winner_id
    LEFT JOIN public.dungeons d ON d.id = c.dungeon_id
    WHERE c.status = 'resolved' AND c.winner_id IS NOT NULL
      AND COALESCE(c.resolved_at, c.created_at) > now() - interval '7 days'
      AND NOT EXISTS (SELECT 1 FROM public.qa_bot_profiles qb WHERE qb.bot_auth_id = c.winner_id)

    UNION ALL

    SELECT
      'siege_live', s.id::text, NULL::uuid, s.started_at,
      ('🔥 Kuşatma canlı: '
        || public._ticker_clip_label(COALESCE(d.name_tr, d.name, s.dungeon_id), 'zindan')
        || '!'),
      26, NULL, NULL
    FROM public.dungeon_siege_sessions s
    LEFT JOIN public.dungeons d ON d.id = s.dungeon_id
    WHERE s.is_active = true AND s.ends_at > now()

    UNION ALL

    SELECT
      'king_blessing', b.id::text, b.activated_by, b.started_at,
      ('👑 '
        || public._ticker_clip_name(COALESCE(g.name, 'Krallık'))
        || ' · '
        || public._ticker_clip_name(COALESCE(u.display_name, u.username, 'Kral'))
        || ' indirim: '
        || public._ticker_king_discount_summary(b.gold_discount_pct, b.gem_discount_pct)
        || ' — mağaza & pazar'
        || CASE
             WHEN b.expires_at > now() THEN ' · aktif (' || GREATEST(1, ceil(extract(epoch FROM (b.expires_at - now())) / 60))::int || ' dk)'
             ELSE ' · bitti'
           END),
      CASE WHEN b.expires_at > now() THEN 52 ELSE 30 END, NULL, NULL
    FROM public.kingdom_market_blessings b
    LEFT JOIN public.users u ON u.auth_id = b.activated_by
    LEFT JOIN public.guilds g ON g.id = u.guild_id
    WHERE b.started_at > now() - interval '48 hours'

    UNION ALL

    SELECT
      'player_ban', a.id::text, NULLIF(a.target_id, '')::uuid, a.created_at,
      ('🚫 '
        || public._ticker_clip_name(COALESCE(tu.display_name, tu.username, 'Oyuncu'))
        || ' banlandı — Sebep: '
        || public._ticker_clip_label(
             COALESCE(a.payload->>'reason', tu.ban_reason, 'Kural ihlali'),
             'sebep belirtilmedi'
           )),
      44, NULL, NULL
    FROM public.staff_audit_log a
    LEFT JOIN public.users tu ON tu.auth_id::text = a.target_id
    WHERE a.action = 'ban_player'
      AND a.target_type = 'user'
      AND COALESCE(a.result->>'success', 'true')::boolean IS NOT DISTINCT FROM true
      AND a.created_at > now() - interval '14 days'
      AND NOT EXISTS (SELECT 1 FROM public.qa_bot_profiles qb WHERE qb.bot_auth_id::text = a.target_id)
  ),
  deduped AS (
    SELECT *
    FROM (
      SELECT
        raw_events.*,
        row_number() OVER (
          PARTITION BY event_type, COALESCE(actor_id::text, event_id),
            date_trunc('hour', occurred_at)
              + (EXTRACT(minute FROM occurred_at)::int / 30) * interval '30 minutes'
          ORDER BY occurred_at DESC, weight DESC
        ) AS dedupe_rn
      FROM raw_events
    ) d
    WHERE dedupe_rn = 1
  ),
  typed AS (
    SELECT *
    FROM (
      SELECT
        deduped.*,
        row_number() OVER (
          PARTITION BY event_type
          ORDER BY occurred_at DESC, weight DESC
        ) AS type_rn
      FROM deduped
    ) t
    WHERE type_rn <= CASE event_type
      WHEN 'dungeon_clear' THEN 3
      WHEN 'enhance_success' THEN 5
      WHEN 'loot_rare' THEN 4
      WHEN 'guild_war' THEN 4
      WHEN 'siege_win' THEN 3
      WHEN 'siege_live' THEN 2
      WHEN 'king_blessing' THEN 3
      WHEN 'player_ban' THEN 4
      ELSE 2
    END
  ),
  ranked AS (
    SELECT
      event_type,
      event_id,
      message,
      occurred_at,
      weight,
      max_passes,
      passes_remaining,
      row_number() OVER (ORDER BY weight DESC, occurred_at DESC) AS rn
    FROM typed
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', event_type || ':' || event_id,
        'type', event_type,
        'text', message,
        'created_at', occurred_at,
        'max_passes', max_passes,
        'passes_remaining', passes_remaining
      )
      ORDER BY weight DESC, occurred_at DESC
    ),
    '[]'::JSONB
  )
  INTO v_items
  FROM ranked
  WHERE rn <= v_limit;

  IF v_staff IS NOT NULL THEN
    v_items := jsonb_build_array(v_staff) || COALESCE(v_items, '[]'::JSONB);
    IF jsonb_array_length(v_items) > v_limit THEN
      SELECT COALESCE(jsonb_agg(elem), '[]'::JSONB)
      INTO v_items
      FROM (
        SELECT elem
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_limit
      ) x;
    END IF;
  END IF;

  BEGIN
    SELECT * INTO v_night FROM public._night_market_window();
    IF COALESCE(v_night.active, false) THEN
      v_items := jsonb_build_array(
        jsonb_build_object(
          'id', 'night_market:open',
          'type', 'night_market',
          'text', '🌙 Gece Pazarı açık! Nadir fırsatlar seni bekliyor.',
          'created_at', now()
        )
      ) || COALESCE(v_items, '[]'::JSONB);
      IF jsonb_array_length(v_items) > v_limit THEN
        SELECT COALESCE(jsonb_agg(elem), '[]'::JSONB)
        INTO v_items
        FROM (
          SELECT elem
          FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
          WHERE ord <= v_limit
        ) x;
      END IF;
    END IF;
  EXCEPTION WHEN undefined_function THEN
    NULL;
  END;

  IF v_items IS NULL OR jsonb_array_length(v_items) = 0 THEN
    v_items := jsonb_build_array(
      jsonb_build_object(
        'id', 'fallback:quiet',
        'type', 'ambient',
        'text', '🌌 Kamp sessiz… yeni efsaneler yazılıyor.',
        'created_at', now()
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', v_items,
    'count', jsonb_array_length(v_items)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_ban_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_live_ticker_feed_core(integer) TO authenticated;

COMMIT;

