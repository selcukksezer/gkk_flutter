-- ============================================================
-- Live ticker feed — aggregate public-ish recent game events
-- for the top-of-screen announcement strip (SELECT only).
-- Anti-spam: max age, per-type caps, actor+type dedupe window.
-- Privacy: clip display names; no email/gold dumps.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public._ticker_clip_name(p_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_name IS NULL OR btrim(p_name) = '' THEN 'Bir savaşçı'
    WHEN char_length(btrim(p_name)) > 12 THEN left(btrim(p_name), 10) || '…'
    ELSE btrim(p_name)
  END;
$$;

CREATE OR REPLACE FUNCTION public._ticker_clip_label(p_label text, p_fallback text DEFAULT '???')
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_label IS NULL OR btrim(p_label) = '' THEN COALESCE(p_fallback, '???')
    WHEN char_length(btrim(p_label)) > 22 THEN left(btrim(p_label), 20) || '…'
    ELSE btrim(p_label)
  END;
$$;

CREATE OR REPLACE FUNCTION public.get_live_ticker_feed(p_limit integer DEFAULT 24)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_limit INT := GREATEST(6, LEAST(COALESCE(p_limit, 24), 40));
  v_items JSONB := '[]'::JSONB;
  v_night RECORD;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  WITH raw_events AS (
    -- 1) Dungeon clears (48h, prefer first-clear / boss-ish via is_first_clear)
    SELECT
      'dungeon_clear'::text AS event_type,
      r.id::text AS event_id,
      r.player_id AS actor_id,
      r.created_at AS occurred_at,
      ('⚔️ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || CASE WHEN r.is_first_clear THEN ' ilk kez ' ELSE ' ' END
        || public._ticker_clip_label(COALESCE(d.name_tr, d.name, r.dungeon_id), 'zindan')
        || ' temizledi!') AS message,
      CASE WHEN r.is_first_clear THEN 30 ELSE 10 END AS weight
    FROM public.dungeon_runs r
    JOIN public.users u ON u.auth_id = r.player_id
    LEFT JOIN public.dungeons d ON d.id = r.dungeon_id
    WHERE r.success = true
      AND r.created_at > now() - interval '48 hours'
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = r.player_id
      )

    UNION ALL

    -- 2) High enhancement success (+3 or better)
    SELECT
      'enhance_success',
      e.id::text,
      e.player_id,
      e.created_at,
      ('✨ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' +' || e.attempted_level::text || ' '
        || public._ticker_clip_label(COALESCE(i.name, e.item_id), 'eşya')
        || ' güçlendirdi!'),
      20 + LEAST(e.attempted_level, 15)
    FROM public.enhancement_history e
    JOIN public.users u ON u.auth_id = e.player_id
    LEFT JOIN public.items i ON i.id = e.item_id
    WHERE e.success = true
      AND e.attempted_level >= 3
      AND e.created_at > now() - interval '7 days'
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = e.player_id
      )

    UNION ALL

    -- 3) Rare+ loot box rewards
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
        WHEN 'mythic' THEN 40
        WHEN 'legendary' THEN 35
        WHEN 'epic' THEN 28
        ELSE 22
      END
    FROM public.player_loot_box_logs l
    JOIN public.users u ON u.auth_id = l.user_id
    LEFT JOIN public.items i ON i.id = l.reward_item_id
    WHERE l.created_at > now() - interval '7 days'
      AND lower(COALESCE(i.rarity, '')) IN ('rare', 'epic', 'legendary', 'mythic')
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = l.user_id
      )

    UNION ALL

    -- 4) Arena / mekan PvP wins
    SELECT
      'arena_win',
      m.id::text,
      m.winner_id,
      m.created_at,
      ('🏟️ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' arenada galip!'),
      18
    FROM public.mekan_pvp_matches m
    JOIN public.users u ON u.auth_id = m.winner_id
    WHERE m.winner_id IS NOT NULL
      AND m.created_at > now() - interval '48 hours'
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = m.winner_id
      )

    UNION ALL

    -- 5) PvP arena notification wins (viewer-agnostic public blurb)
    SELECT
      'arena_streak',
      n.id::text,
      n.user_id,
      n.created_at,
      ('💀 ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' ' || public._ticker_clip_name(n.opponent_name)
        || ' karşısında zafer!'),
      16
    FROM public.pvp_arena_notifications n
    JOIN public.users u ON u.auth_id = n.user_id
    WHERE n.won = true
      AND n.created_at > now() - interval '48 hours'
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = n.user_id
      )

    UNION ALL

    -- 6) Guild war attacks (success preferred)
    SELECT
      'guild_war',
      a.id::text,
      a.attacker_guild_id,
      a.created_at,
      ('🏰 Lonca ' || public._ticker_clip_name(COALESCE(ag.name, ag.tag, '???'))
        || CASE WHEN a.success THEN ' toprak fethetti!' ELSE ' saldırı düzenledi!' END),
      CASE WHEN a.success THEN 25 ELSE 12 END
    FROM public.guild_war_attack_logs a
    LEFT JOIN public.guilds ag ON ag.id = a.attacker_guild_id
    WHERE a.created_at > now() - interval '7 days'

    UNION ALL

    -- 7) Horse race round results
    SELECT
      'horse_race',
      r.id::text,
      NULL::uuid,
      COALESCE(r.finished_ends_at, r.created_at),
      ('🏇 At yarışı: ' || public._ticker_clip_label(COALESCE(h.name, r.winner_horse_id), 'şampiyon')
        || ' birinci!'),
      14
    FROM public.horse_race_rounds r
    LEFT JOIN public.horse_race_horses h ON h.id = r.winner_horse_id
    WHERE r.status = 'finished'
      AND r.winner_horse_id IS NOT NULL
      AND COALESCE(r.finished_ends_at, r.created_at) > now() - interval '24 hours'

    UNION ALL

    -- 8) Horse bet big wins (payout >= 100, skip tiny QA bets)
    SELECT
      'horse_bet_win',
      l.id::text,
      l.user_id,
      l.created_at,
      ('🍀 ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' at yarışında kazandı!'),
      15
    FROM public.player_horse_race_logs l
    JOIN public.users u ON u.auth_id = l.user_id
    WHERE l.won = true
      AND COALESCE(l.payout_amount, 0) >= 100
      AND l.created_at > now() - interval '7 days'
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = l.user_id
      )

    UNION ALL

    -- 9) Dungeon siege challenge resolved
    SELECT
      'siege_win',
      c.id::text,
      c.winner_id,
      COALESCE(c.resolved_at, c.created_at),
      ('🛡️ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' kuşatmada '
        || public._ticker_clip_label(COALESCE(d.name_tr, d.name, c.dungeon_id), 'zindan')
        || ' kazandı!'),
      26
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

    -- 10) Active siege session start (world event)
    SELECT
      'siege_live',
      s.id::text,
      NULL::uuid,
      s.started_at,
      ('🔥 Kuşatma canlı: '
        || public._ticker_clip_label(COALESCE(d.name_tr, d.name, s.dungeon_id), 'zindan')
        || '!'),
      24
    FROM public.dungeon_siege_sessions s
    LEFT JOIN public.dungeons d ON d.id = s.dungeon_id
    WHERE s.is_active = true
      AND s.ends_at > now()

    UNION ALL

    -- 11) Market sales (history) — quiet until economy moves
    SELECT
      'market_sale',
      h.id::text,
      h.seller_id,
      COALESCE(h.sold_at, h.created_at),
      ('📈 Pazarda '
        || public._ticker_clip_label(COALESCE(h.item_name, h.item_id), 'eşya')
        || ' satıldı!'),
      12
    FROM public.market_history h
    WHERE COALESCE(h.sold_at, h.created_at) > now() - interval '7 days'

    UNION ALL

    -- 12) Fresh open market listings (rare+)
    SELECT
      'market_list',
      o.id::text,
      o.seller_id,
      o.created_at,
      ('🛒 ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' '
        || public._ticker_clip_label(COALESCE(o.item_name, o.item_id), 'eşya')
        || ' satışa çıkardı!'),
      11
    FROM public.market_orders o
    JOIN public.users u ON u.auth_id = o.seller_id
    WHERE o.created_at > now() - interval '7 days'
      AND lower(COALESCE(o.rarity, '')) IN ('rare', 'epic', 'legendary', 'mythic')
      AND (o.status IS NULL OR lower(o.status) IN ('open', 'active', 'listed'))
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = o.seller_id
      )

    UNION ALL

    -- 13) Crafted rare+ items
    SELECT
      'craft_rare',
      c.id::text,
      c.user_id,
      c.created_at,
      ('🛠️ ' || public._ticker_clip_name(COALESCE(u.display_name, u.username))
        || ' '
        || public._ticker_clip_label(COALESCE(i.name, c.item_id), 'eşya')
        || ' üretti!'),
      21
    FROM public.crafted_items_log c
    JOIN public.users u ON u.auth_id = c.user_id
    LEFT JOIN public.items i ON i.id = c.item_id
    WHERE c.created_at > now() - interval '7 days'
      AND lower(COALESCE(c.rarity, i.rarity, '')) IN ('rare', 'epic', 'legendary', 'mythic')
      AND NOT EXISTS (
        SELECT 1 FROM public.qa_bot_profiles b WHERE b.bot_auth_id = c.user_id
      )
  ),
  -- Dedupe same actor+type within 20 minutes (keep newest)
  deduped AS (
    SELECT *
    FROM (
      SELECT
        raw_events.*,
        row_number() OVER (
          PARTITION BY event_type, COALESCE(actor_id::text, event_id),
            date_trunc('hour', occurred_at)
              + (EXTRACT(minute FROM occurred_at)::int / 20) * interval '20 minutes'
          ORDER BY occurred_at DESC, weight DESC
        ) AS dedupe_rn
      FROM raw_events
    ) d
    WHERE dedupe_rn = 1
  ),
  -- Per-type cap
  typed AS (
    SELECT *
    FROM (
      SELECT
        deduped.*,
        row_number() OVER (
          PARTITION BY event_type
          ORDER BY weight DESC, occurred_at DESC
        ) AS type_rn
      FROM deduped
    ) t
    WHERE type_rn <= CASE event_type
      WHEN 'dungeon_clear' THEN 6
      WHEN 'enhance_success' THEN 4
      WHEN 'loot_rare' THEN 5
      WHEN 'arena_win' THEN 5
      WHEN 'arena_streak' THEN 4
      WHEN 'guild_war' THEN 4
      WHEN 'horse_race' THEN 4
      WHEN 'horse_bet_win' THEN 3
      WHEN 'siege_win' THEN 3
      WHEN 'siege_live' THEN 2
      WHEN 'market_sale' THEN 4
      WHEN 'market_list' THEN 3
      WHEN 'craft_rare' THEN 3
      ELSE 3
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

  -- Synthetic night-market open blurb when window active
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

REVOKE ALL ON FUNCTION public._ticker_clip_name(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._ticker_clip_label(text, text) FROM PUBLIC;

COMMIT;
