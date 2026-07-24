-- Guild war season auto-rotation + siege/guild-war zone alignment fixes

BEGIN;

-- ── Lonca savaşı: zones 5–7 (kuşatma ile hizalı) ─────────────
INSERT INTO public.guild_war_territories (
  id, name, owner_guild_id, defense_power, reward, base_defense_power, trade_income, defense_line_level, zone_number
) VALUES
  ('00000000-0000-0000-0000-000000030005', 'Cehennem Kapısı', NULL, 3200, '8,000 Altın/gün', 3000, 9000, 3, 5),
  ('00000000-0000-0000-0000-000000030006', 'Gökyüzü Burcu', NULL, 4000, '12,000 Altın/gün', 3800, 12000, 4, 6),
  ('00000000-0000-0000-0000-000000030007', 'Efsanevi Sınır', NULL, 5000, 'Efsanevi Eşya + 15,000 Altın/gün', 4800, 15000, 4, 7)
ON CONFLICT (id) DO UPDATE SET
  zone_number = EXCLUDED.zone_number,
  name = EXCLUDED.name,
  reward = EXCLUDED.reward,
  trade_income = EXCLUDED.trade_income;

-- ── Kuşatma: bölge sahibi — sadece eşleşen zone (LEAST kaldır) ─
CREATE OR REPLACE FUNCTION public.dungeon_siege_territory_owner_for_zone(p_zone_number integer)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_owner uuid;
BEGIN
  IF p_zone_number IS NULL OR p_zone_number <= 0 THEN
    RETURN NULL;
  END IF;

  SELECT t.owner_guild_id INTO v_owner
  FROM public.guild_war_territories t
  WHERE t.zone_number = p_zone_number
  ORDER BY t.created_at NULLS LAST
  LIMIT 1;

  RETURN v_owner;
END;
$$;

-- ── Status: owner name = owner id lookup (tutarlı) ───────────
CREATE OR REPLACE FUNCTION public.get_dungeon_siege_status(p_dungeon_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_cfg public.dungeon_siege_config;
  v_sessions jsonb := '[]'::jsonb;
  v_my_slot jsonb := NULL;
  v_my_guild_id uuid;
BEGIN
  PERFORM public.dungeon_siege_cleanup();
  v_cfg := public.dungeon_siege_get_config();

  IF v_me IS NOT NULL THEN
    SELECT guild_id INTO v_my_guild_id FROM public.users WHERE auth_id = v_me;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'session_id', sess.id,
    'dungeon_id', sess.dungeon_id,
    'zone_number', sess.zone_number,
    'ends_at', sess.ends_at,
    'territory_owner_guild_id', public.dungeon_siege_territory_owner_for_zone(sess.zone_number),
    'territory_owner_guild_name', (
      SELECT COALESCE(g.name, 'Sahipsiz')
      FROM public.guilds g
      WHERE g.id = public.dungeon_siege_territory_owner_for_zone(sess.zone_number)
    ),
    'guild_slots', CASE
      WHEN v_my_guild_id IS NULL THEN 0
      ELSE public.dungeon_siege_count_guild_slots(sess.id, v_my_guild_id)
    END,
    'hold', public.dungeon_siege_hold_json(sess.id),
    'slots', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'slot_id', s.id,
        'slot_number', s.slot_number,
        'holder_id', s.holder_id,
        'holder_name', COALESCE(u.display_name, u.username, '—'),
        'holder_power', COALESCE(u.power, 0),
        'guild_id', s.guild_id,
        'guild_name', g.name,
        'expires_at', s.expires_at,
        'last_active_at', s.last_active_at,
        'is_mine', s.holder_id = v_me,
        'is_territory_reserved', s.slot_number <= v_cfg.territory_reserve_slot_count
          AND public.dungeon_siege_territory_owner_for_zone(sess.zone_number) IS NOT NULL
      ) ORDER BY s.slot_number), '[]'::jsonb)
      FROM public.dungeon_siege_slots s
      LEFT JOIN public.users u ON u.auth_id = s.holder_id
      LEFT JOIN public.guilds g ON g.id = s.guild_id
      WHERE s.session_id = sess.id
    )
  ) ORDER BY sess.zone_number), '[]'::jsonb)
  INTO v_sessions
  FROM public.dungeon_siege_sessions sess
  WHERE sess.is_active = true
    AND sess.ends_at > now()
    AND (p_dungeon_id IS NULL OR sess.dungeon_id = p_dungeon_id);

  IF v_me IS NOT NULL THEN
    SELECT jsonb_build_object(
      'slot_id', s.id,
      'slot_number', s.slot_number,
      'dungeon_id', sess.dungeon_id,
      'expires_at', s.expires_at
    )
    INTO v_my_slot
    FROM public.dungeon_siege_slots s
    JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
    WHERE s.holder_id = v_me
      AND sess.is_active = true
      AND sess.ends_at > now()
      AND (p_dungeon_id IS NULL OR sess.dungeon_id = p_dungeon_id)
    ORDER BY s.claimed_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'enabled', v_cfg.is_enabled,
    'in_prime_window', public.dungeon_siege_in_prime_window(),
    'siege_active', v_cfg.is_enabled AND public.dungeon_siege_in_prime_window(),
    'sessions', v_sessions,
    'my_slot', v_my_slot,
    'is_banned', CASE
      WHEN v_me IS NULL OR p_dungeon_id IS NULL THEN false
      ELSE public.dungeon_siege_is_banned(v_me, p_dungeon_id)
    END,
    'config', public.get_dungeon_siege_config()
  );
END;
$$;

-- ── Lonca savaşı sezon döngüsü ───────────────────────────────
CREATE OR REPLACE FUNCTION public.rotate_guild_war_season()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old record;
  v_new_id uuid;
BEGIN
  SELECT id, season_number, end_at
  INTO v_old
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF v_old IS NULL THEN
    INSERT INTO public.guild_war_seasons (season_number, week_number, start_at, end_at, is_active)
    VALUES (1, 1, now(), now() + interval '7 days', true)
    RETURNING id INTO v_new_id;
    RETURN v_new_id;
  END IF;

  IF v_old.end_at > now() THEN
    RETURN v_old.id;
  END IF;

  UPDATE public.guild_war_seasons
  SET is_active = false
  WHERE id = v_old.id;

  INSERT INTO public.guild_war_seasons (season_number, week_number, start_at, end_at, is_active)
  VALUES (v_old.season_number + 1, 1, now(), now() + interval '7 days', true)
  RETURNING id INTO v_new_id;

  INSERT INTO public.guild_war_rankings (season_id, guild_id, points, wins, losses)
  SELECT v_new_id, g.id, 0, 0, 0
  FROM public.guilds g
  ON CONFLICT (season_id, guild_id) DO UPDATE SET updated_at = now();

  INSERT INTO public.guild_war_tournaments (season_id, name, status, guild_count, prize_pool, start_at, end_at)
  VALUES
    (v_new_id, 'Haftalık Arena', 'active', 0, '50,000 Altın', now(), now() + interval '7 days'),
    (v_new_id, 'Sezon Finali', 'upcoming', 0, '250,000 Altın + Efsanevi Eşya', now() + interval '7 days', now() + interval '14 days');

  RETURN v_new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_guild_war_season()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_season record;
BEGIN
  PERFORM public.rotate_guild_war_season();

  SELECT season_number, week_number, end_at
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1
  INTO v_season;

  IF v_season IS NULL THEN
    RETURN json_build_object('season', 1, 'week', 1, 'end_at', null);
  END IF;

  RETURN json_build_object(
    'season', v_season.season_number,
    'week', v_season.week_number,
    'end_at', v_season.end_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rotate_guild_war_season() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_guild_war_season() TO authenticated;

-- Kuşatma itibar: rep_bonus_pct × 20 taban → ~5 itibar/koşu (daha hissedilir)
UPDATE public.dungeon_siege_config
SET rep_bonus_pct = 0.25,
    updated_at = now()
WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

COMMIT;
