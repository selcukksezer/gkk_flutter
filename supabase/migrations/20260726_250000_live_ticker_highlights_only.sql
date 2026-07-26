-- Live ticker: HIGHLIGHTS only + slower client already handles pace.
-- Keep: +8 enhance, legendary+ loot, first dungeon clear, guild conquest,
--        siege win/live, night market. Drop routine arena/horse/market/craft.

CREATE OR REPLACE FUNCTION public.get_live_ticker_feed(p_limit integer DEFAULT 10)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_limit INT := GREATEST(3, LEAST(COALESCE(p_limit, 10), 12));
  v_items JSONB := '[]'::JSONB;
  v_night RECORD;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  WITH raw_events AS (
    -- First dungeon clears only
    SELECT
      'dungeon_clear'::text AS event_type,
      r.id::text AS event_id,
      r.player_id AS actor_id,
      r.created_at AS occurred_at,
      ('⚔️ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' ilk kez '
        || public._ticker_clip_label(COALESCE(d.name_tr, d.name, r.dungeon_id), 'zindan')
        || ' temizledi!') AS message,
      30 AS weight
    FROM public.dungeon_runs r
    JOIN public.users u ON u.auth_id = r.player_id
    LEFT JOIN public.dungeons d ON d.id = r.dungeon_id
    WHERE r.success = true
      AND r.is_first_clear = true
      AND r.created_at > now() - interval '48 hours'
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = r.player_id
      )

    UNION ALL

    -- Enhance +8+
    SELECT
      'enhance_success',
      e.id::text,
      e.player_id,
      e.created_at,
      ('✨ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' +' || e.attempted_level::text || ' '
        || public._ticker_clip_label(COALESCE(i.name, e.item_id), 'eşya')
        || ' güçlendirdi!'),
      40 + LEAST(e.attempted_level, 15)
    FROM public.enhancement_history e
    JOIN public.users u ON u.auth_id = e.player_id
    LEFT JOIN public.items i ON i.id = e.item_id
    WHERE e.success = true
      AND e.attempted_level >= 8
      AND e.created_at > now() - interval '7 days'
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = e.player_id
      )

    UNION ALL

    -- Loot legendary / mythic only
    SELECT
      'loot_rare',
      l.id::text,
      l.user_id,
      l.created_at,
      ('🎁 ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' ' || upper(COALESCE(i.rarity, 'nadir')) || ' '
        || public._ticker_clip_label(COALESCE(i.name, l.reward_item_id), 'ödül')
        || ' kazandı!'),
      CASE lower(COALESCE(i.rarity, ''))
        WHEN 'mythic' THEN 50
        ELSE 42
      END
    FROM public.player_loot_box_logs l
    JOIN public.users u ON u.auth_id = l.user_id
    LEFT JOIN public.items i ON i.id = l.reward_item_id
    WHERE l.created_at > now() - interval '7 days'
      AND lower(COALESCE(i.rarity, '')) IN ('legendary', 'mythic')
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = l.user_id
      )

    UNION ALL

    -- Guild war successful conquest only
    SELECT
      'guild_war',
      a.id::text,
      a.attacker_guild_id,
      a.created_at,
      ('🏰 Lonca ' || public._ticker_clip_name(COALESCE(ag.name, ag.tag, '???'))
        || ' toprak fethetti!'),
      28
    FROM public.guild_war_attack_logs a
    LEFT JOIN public.guilds ag ON ag.id = a.attacker_guild_id
    WHERE a.success = true
      AND a.created_at > now() - interval '7 days'

    UNION ALL

    -- Siege resolved winner
    SELECT
      'siege_win',
      c.id::text,
      c.winner_id,
      COALESCE(c.resolved_at, c.created_at),
      ('🛡️ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' kuşatmada '
        || public._ticker_clip_label(COALESCE(d.name_tr, d.name, c.dungeon_id), 'zindan')
        || ' kazandı!'),
      32
    FROM public.dungeon_siege_challenges c
    JOIN public.users u ON u.auth_id = c.winner_id
    LEFT JOIN public.dungeons d ON d.id = c.dungeon_id
    WHERE c.status = 'resolved'
      AND c.winner_id IS NOT NULL
      AND COALESCE(c.resolved_at, c.created_at) > now() - interval '7 days'
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = c.winner_id
      )

    UNION ALL

    -- Active siege world event
    SELECT
      'siege_live',
      s.id::text,
      NULL::uuid,
      s.started_at,
      ('🔥 Kuşatma canlı: '
        || public._ticker_clip_label(COALESCE(d.name_tr, d.name, s.dungeon_id), 'zindan')
        || '!'),
      26
    FROM public.dungeon_siege_sessions s
    LEFT JOIN public.dungeons d ON d.id = s.dungeon_id
    WHERE s.is_active = true
      AND s.ends_at > now()
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
      WHEN 'guild_war' THEN 3
      WHEN 'siege_win' THEN 3
      WHEN 'siege_live' THEN 2
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
        'id', event_type || ':' || event_id,
        'type', event_type,
        'text', message,
        'created_at', occurred_at
      )
      ORDER BY weight DESC, occurred_at DESC
    ),
    '[]'::JSONB
  )
  INTO v_items
  FROM ranked
  WHERE rn <= v_limit;

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

REVOKE ALL ON FUNCTION public.get_live_ticker_feed(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_live_ticker_feed(integer) TO authenticated;
