-- Live ticker: return retired ids for client queue sync; staff broadcast default 3 passes.

BEGIN;

CREATE OR REPLACE FUNCTION public.staff_liveops_create_broadcast(
  p_message TEXT,
  p_max_passes INT DEFAULT 3
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_id UUID;
  v_passes INT := GREATEST(1, LEAST(COALESCE(p_max_passes, 3), 500));
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.broadcast');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF btrim(COALESCE(p_message, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duyuru metni gerekli.');
  END IF;

  UPDATE public.staff_broadcasts SET is_active = false WHERE is_active = true;

  INSERT INTO public.staff_broadcasts (
    message, created_by, is_active, expires_at, max_passes, passes_completed
  )
  VALUES (
    left(btrim(p_message), 280),
    v_actor,
    true,
    now() + interval '7 days',
    v_passes,
    0
  )
  RETURNING id INTO v_id;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.broadcast', 'create_broadcast', 'staff_broadcast', v_id::text,
    jsonb_build_object('message', p_message, 'max_passes', v_passes),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object(
    'success', true,
    'broadcast_id', v_id,
    'max_passes', v_passes
  );
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
  v_retired JSONB := '[]'::JSONB;
  v_night RECORD;
  v_staff JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT COALESCE(jsonb_agg(q.ticker_id ORDER BY q.retired_at DESC), '[]'::jsonb)
  INTO v_retired
  FROM (
    SELECT ticker_id, retired_at
    FROM public.live_ticker_queue_state
    WHERE retired_at IS NOT NULL
      AND retired_at > now() - interval '14 days'
    ORDER BY retired_at DESC
    LIMIT 500
  ) q;

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
      32 AS weight
    FROM public.dungeon_runs r
    JOIN public.users u ON u.auth_id = r.player_id
    JOIN public.dungeons d ON d.id = r.dungeon_id
    WHERE r.success = true
      AND COALESCE(d.is_boss, false) = true
      AND r.created_at > now() - interval '24 hours'
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
      40 + LEAST(e.attempted_level, 15)
    FROM public.enhancement_history e
    JOIN public.users u ON u.auth_id = e.player_id
    LEFT JOIN public.items i ON i.id = e.item_id
    WHERE e.success = true AND e.attempted_level >= 8
      AND e.created_at > now() - interval '48 hours'
      AND NOT EXISTS (SELECT 1 FROM public.qa_bot_profiles qb WHERE qb.bot_auth_id = e.player_id)

    UNION ALL

    SELECT
      'loot_rare', l.id::text, l.user_id, l.created_at,
      ('🎁 ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' ' || upper(COALESCE(i.rarity, 'nadir')) || ' '
        || public._ticker_clip_label(COALESCE(i.name, l.reward_item_id), 'ödül')
        || ' kazandı!'),
      CASE lower(COALESCE(i.rarity, '')) WHEN 'mythic' THEN 50 ELSE 42 END
    FROM public.player_loot_box_logs l
    JOIN public.users u ON u.auth_id = l.user_id
    LEFT JOIN public.items i ON i.id = l.reward_item_id
    WHERE l.created_at > now() - interval '48 hours'
      AND lower(COALESCE(i.rarity, '')) IN ('legendary', 'mythic')
      AND NOT EXISTS (SELECT 1 FROM public.qa_bot_profiles qb WHERE qb.bot_auth_id = l.user_id)

    UNION ALL

    SELECT
      'guild_war', a.id::text, a.attacker_guild_id, a.created_at,
      ('🏰 Lonca ' || public._ticker_clip_name(COALESCE(ag.name, ag.tag, '???'))
        || ' → '
        || public._ticker_clip_label(COALESCE(dg.name, dg.tag, ter.name, 'hedef'), 'lonca')
        || CASE WHEN a.success THEN ' fethetti!' ELSE ' saldırdı!' END),
      CASE WHEN a.success THEN 30 ELSE 22 END
    FROM public.guild_war_attack_logs a
    LEFT JOIN public.guilds ag ON ag.id = a.attacker_guild_id
    LEFT JOIN public.guilds dg ON dg.id = a.defender_guild_id
    LEFT JOIN public.guild_war_territories ter ON ter.id = a.territory_id
    WHERE a.created_at > now() - interval '48 hours'

    UNION ALL

    SELECT
      'siege_win', c.id::text, c.winner_id, COALESCE(c.resolved_at, c.created_at),
      ('🛡️ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' kuşatmada '
        || public._ticker_clip_label(COALESCE(d.name_tr, d.name, c.dungeon_id), 'zindan')
        || ' kazandı!'),
      32
    FROM public.dungeon_siege_challenges c
    JOIN public.users u ON u.auth_id = c.winner_id
    LEFT JOIN public.dungeons d ON d.id = c.dungeon_id
    WHERE c.status = 'resolved' AND c.winner_id IS NOT NULL
      AND COALESCE(c.resolved_at, c.created_at) > now() - interval '48 hours'
      AND NOT EXISTS (SELECT 1 FROM public.qa_bot_profiles qb WHERE qb.bot_auth_id = c.winner_id)

    UNION ALL

    SELECT
      'siege_live', s.id::text, NULL::uuid, s.started_at,
      ('🔥 Kuşatma canlı: '
        || public._ticker_clip_label(COALESCE(d.name_tr, d.name, s.dungeon_id), 'zindan')
        || '!'),
      26
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
      CASE WHEN b.expires_at > now() THEN 52 ELSE 30 END
    FROM public.kingdom_market_blessings b
    LEFT JOIN public.users u ON u.auth_id = b.activated_by
    LEFT JOIN public.guilds g ON g.id = u.guild_id
    WHERE b.started_at > now() - interval '24 hours'
      AND b.expires_at > now()

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
      44
    FROM public.staff_audit_log a
    LEFT JOIN public.users tu ON tu.auth_id::text = a.target_id
    WHERE a.action = 'ban_player'
      AND a.target_type = 'user'
      AND COALESCE(a.result->>'success', 'true')::boolean IS NOT DISTINCT FROM true
      AND a.created_at > now() - interval '48 hours'
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
      WHEN 'dungeon_clear' THEN 2
      WHEN 'enhance_success' THEN 3
      WHEN 'loot_rare' THEN 2
      WHEN 'guild_war' THEN 2
      WHEN 'siege_win' THEN 2
      WHEN 'siege_live' THEN 1
      WHEN 'king_blessing' THEN 1
      WHEN 'player_ban' THEN 2
      ELSE 1
    END
  ),
  ranked AS (
    SELECT
      event_type,
      event_id,
      message,
      occurred_at,
      weight,
      row_number() OVER (ORDER BY weight DESC, occurred_at DESC) AS rn
    FROM typed
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', r.event_type || ':' || r.event_id,
        'type', r.event_type,
        'text', r.message,
        'created_at', r.occurred_at,
        'max_passes', COALESCE(q.max_passes, 3),
        'passes_remaining', GREATEST(COALESCE(q.max_passes, 3) - COALESCE(q.passes_completed, 0), 0)
      )
      ORDER BY r.occurred_at ASC, r.weight DESC
    ),
    '[]'::JSONB
  )
  INTO v_items
  FROM ranked r
  LEFT JOIN public.live_ticker_queue_state q
    ON q.ticker_id = r.event_type || ':' || r.event_id
  WHERE r.rn <= v_limit
    AND q.retired_at IS NULL
    AND COALESCE(q.passes_completed, 0) < COALESCE(q.max_passes, 3);

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
          'created_at', now(),
          'max_passes', NULL,
          'passes_remaining', NULL
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
    'count', jsonb_array_length(v_items),
    'retired_ticker_ids', v_retired
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_live_ticker_feed(p_limit integer DEFAULT 10)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_base JSONB;
  v_manual JSONB;
  v_items JSONB;
  v_limit INT := GREATEST(3, LEAST(COALESCE(p_limit, 10), 20));
BEGIN
  v_base := public.get_live_ticker_feed_core(p_limit);
  IF COALESCE((v_base->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_base;
  END IF;

  v_items := COALESCE(v_base->'items', '[]'::jsonb);

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', e.event_type || ':' || e.id::text,
        'type', e.event_type,
        'text', e.message,
        'created_at', e.created_at,
        'max_passes', COALESCE(q.max_passes, 3),
        'passes_remaining', GREATEST(COALESCE(q.max_passes, 3) - COALESCE(q.passes_completed, 0), 0)
      )
      ORDER BY e.created_at ASC
    ),
    '[]'::jsonb
  )
  INTO v_manual
  FROM (
    SELECT e.*
    FROM public.live_ticker_manual_events e
    WHERE e.expires_at > now()
    ORDER BY e.created_at ASC
    LIMIT 5
  ) e
  LEFT JOIN public.live_ticker_queue_state q
    ON q.ticker_id = e.event_type || ':' || e.id::text
  WHERE q.retired_at IS NULL
    AND COALESCE(q.passes_completed, 0) < COALESCE(q.max_passes, 3);

  IF jsonb_array_length(v_manual) > 0 THEN
    v_items := v_manual || v_items;
    IF jsonb_array_length(v_items) > v_limit THEN
      SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT elem
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_limit
      ) x;
    END IF;
  END IF;

  RETURN jsonb_set(v_base, '{items}', v_items, true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_liveops_create_broadcast(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_live_ticker_feed(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_live_ticker_feed_core(integer) TO authenticated;

COMMIT;
