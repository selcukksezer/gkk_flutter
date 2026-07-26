-- Live ticker: global pass counter — 3 marquee passes then retired for everyone.

BEGIN;

CREATE TABLE IF NOT EXISTS public.live_ticker_queue_state (
  ticker_id TEXT PRIMARY KEY,
  passes_completed INT NOT NULL DEFAULT 0 CHECK (passes_completed >= 0),
  max_passes INT NOT NULL DEFAULT 3 CHECK (max_passes >= 1 AND max_passes <= 100),
  retired_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_pass_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS live_ticker_queue_state_retired_idx
  ON public.live_ticker_queue_state (retired_at)
  WHERE retired_at IS NOT NULL;

ALTER TABLE public.live_ticker_queue_state ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public._live_ticker_is_retired(p_ticker_id TEXT)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.live_ticker_queue_state q
    WHERE q.ticker_id = p_ticker_id
      AND (
        q.retired_at IS NOT NULL
        OR q.passes_completed >= q.max_passes
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.record_live_ticker_pass(p_ticker_id TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id TEXT := nullif(btrim(p_ticker_id), '');
  v_row public.live_ticker_queue_state%ROWTYPE;
BEGIN
  IF v_id IS NULL OR v_id LIKE 'fallback:%' THEN
    RETURN jsonb_build_object('success', false, 'skipped', true);
  END IF;

  IF v_id LIKE 'staff_broadcast:%' THEN
    RETURN jsonb_build_object(
      'success', false,
      'skipped', true,
      'error', 'staff_broadcast uses record_staff_broadcast_pass'
    );
  END IF;

  IF public._live_ticker_is_retired(v_id) THEN
    RETURN jsonb_build_object('success', false, 'inactive', true, 'retired', true);
  END IF;

  INSERT INTO public.live_ticker_queue_state (ticker_id, passes_completed, max_passes, last_pass_at)
  VALUES (v_id, 1, 3, now())
  ON CONFLICT (ticker_id) DO UPDATE
  SET
    passes_completed = live_ticker_queue_state.passes_completed + 1,
    last_pass_at = now(),
    retired_at = CASE
      WHEN live_ticker_queue_state.passes_completed + 1 >= live_ticker_queue_state.max_passes
      THEN now()
      ELSE live_ticker_queue_state.retired_at
    END
  WHERE live_ticker_queue_state.retired_at IS NULL
    AND live_ticker_queue_state.passes_completed < live_ticker_queue_state.max_passes
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'inactive', true, 'retired', true);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'passes_completed', v_row.passes_completed,
    'max_passes', v_row.max_passes,
    'passes_remaining', GREATEST(v_row.max_passes - v_row.passes_completed, 0),
    'retired', v_row.retired_at IS NOT NULL
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
      32 AS weight
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
      40 + LEAST(e.attempted_level, 15)
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
      CASE lower(COALESCE(i.rarity, '')) WHEN 'mythic' THEN 50 ELSE 42 END
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
      CASE WHEN a.success THEN 30 ELSE 22 END
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
      32
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
      44
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
      ORDER BY r.weight DESC, r.occurred_at DESC
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
    'count', jsonb_array_length(v_items)
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
      ORDER BY e.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_manual
  FROM (
    SELECT e.*
    FROM public.live_ticker_manual_events e
    WHERE e.expires_at > now()
    ORDER BY e.created_at DESC
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

GRANT EXECUTE ON FUNCTION public._live_ticker_is_retired(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_live_ticker_pass(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_live_ticker_feed(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_live_ticker_feed_core(integer) TO authenticated;

COMMIT;
