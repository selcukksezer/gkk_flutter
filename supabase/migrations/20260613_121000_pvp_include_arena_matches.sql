-- Include arena (mekan_pvp_bet) matches in PvP dashboard/history feeds.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_pvp_dashboard(p_match_limit INT DEFAULT 8)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_arenas JSONB;
  v_matches JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', m.id,
    'name', m.name,
    'mekan_type', m.mekan_type
  ) ORDER BY m.name), '[]'::jsonb)
  INTO v_arenas
  FROM public.mekans m
  WHERE m.mekan_type IN ('dovus_kulubu', 'luks_lounge', 'yeralti')
    AND m.is_open = true;

  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('arenas', v_arenas, 'recent_matches', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
  INTO v_matches
  FROM (
    SELECT *
    FROM (
      SELECT
        pm.id::text AS id,
        'pvp'::text AS match_source,
        pm.attacker_id,
        pm.defender_id,
        pm.winner_id,
        pm.gold_stolen,
        pm.rep_change_winner,
        pm.rep_change_loser,
        COALESCE(pm.is_critical_success, false) AS is_critical_success,
        pm.attacker_hp_remaining,
        pm.created_at,
        ua.username AS attacker_username,
        ud.username AS defender_username
      FROM public.pvp_matches pm
      LEFT JOIN public.users ua ON ua.auth_id = pm.attacker_id
      LEFT JOIN public.users ud ON ud.auth_id = pm.defender_id
      WHERE pm.attacker_id = v_uid OR pm.defender_id = v_uid

      UNION ALL

      SELECT
        mpm.id::text,
        'arena'::text,
        mpm.attacker_id,
        mpm.defender_id,
        mpm.winner_id,
        CASE
          WHEN mpm.winner_id = v_uid THEN GREATEST(mpm.gold_won - mpm.gold_wagered, 0)
          ELSE mpm.gold_wagered
        END AS gold_stolen,
        CASE
          WHEN v_uid = mpm.attacker_id THEN GREATEST(mpm.attacker_rating_change, 0)
          ELSE GREATEST(mpm.defender_rating_change, 0)
        END AS rep_change_winner,
        CASE
          WHEN v_uid = mpm.attacker_id THEN ABS(LEAST(mpm.attacker_rating_change, 0))
          ELSE ABS(LEAST(mpm.defender_rating_change, 0))
        END AS rep_change_loser,
        false AS is_critical_success,
        0 AS attacker_hp_remaining,
        mpm.created_at,
        ua.username AS attacker_username,
        ud.username AS defender_username
      FROM public.mekan_pvp_matches mpm
      LEFT JOIN public.users ua ON ua.auth_id = mpm.attacker_id
      LEFT JOIN public.users ud ON ud.auth_id = mpm.defender_id
      WHERE mpm.attacker_id = v_uid OR mpm.defender_id = v_uid
    ) combined
    ORDER BY created_at DESC
    LIMIT GREATEST(p_match_limit, 1)
  ) t;

  RETURN jsonb_build_object(
    'arenas', v_arenas,
    'recent_matches', v_matches
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_pvp_history(p_limit INT DEFAULT 50)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rows JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.', 'matches', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT *
    FROM (
      SELECT
        pm.id::text AS id,
        'pvp'::text AS match_source,
        pm.attacker_id,
        pm.defender_id,
        pm.winner_id,
        pm.gold_stolen,
        pm.rep_change_winner,
        pm.rep_change_loser,
        COALESCE(pm.is_critical_success, false) AS is_critical_success,
        pm.created_at,
        ua.username AS attacker_username,
        ud.username AS defender_username
      FROM public.pvp_matches pm
      LEFT JOIN public.users ua ON ua.auth_id = pm.attacker_id
      LEFT JOIN public.users ud ON ud.auth_id = pm.defender_id
      WHERE pm.attacker_id = v_uid OR pm.defender_id = v_uid

      UNION ALL

      SELECT
        mpm.id::text,
        'arena'::text,
        mpm.attacker_id,
        mpm.defender_id,
        mpm.winner_id,
        CASE
          WHEN mpm.winner_id = v_uid THEN GREATEST(mpm.gold_won - mpm.gold_wagered, 0)
          ELSE mpm.gold_wagered
        END AS gold_stolen,
        CASE
          WHEN v_uid = mpm.attacker_id THEN GREATEST(mpm.attacker_rating_change, 0)
          ELSE GREATEST(mpm.defender_rating_change, 0)
        END AS rep_change_winner,
        CASE
          WHEN v_uid = mpm.attacker_id THEN ABS(LEAST(mpm.attacker_rating_change, 0))
          ELSE ABS(LEAST(mpm.defender_rating_change, 0))
        END AS rep_change_loser,
        false AS is_critical_success,
        mpm.created_at,
        ua.username AS attacker_username,
        ud.username AS defender_username
      FROM public.mekan_pvp_matches mpm
      LEFT JOIN public.users ua ON ua.auth_id = mpm.attacker_id
      LEFT JOIN public.users ud ON ud.auth_id = mpm.defender_id
      WHERE mpm.attacker_id = v_uid OR mpm.defender_id = v_uid
    ) combined
    ORDER BY created_at DESC
    LIMIT GREATEST(p_limit, 1)
  ) t;

  RETURN jsonb_build_object('success', true, 'matches', v_rows);
END;
$$;

COMMIT;
