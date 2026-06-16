-- ============================================================
-- Migration: Arena bracket matchmaking
-- ============================================================
-- QA audit bulgusu: client fetchArenaOpponents() doğrudan
-- users tablosundan pvp_rating DESC LIMIT 15 çekiyordu →
-- her newbie en güçlü 15 oyuncuyla eşleşiyor (newbie crush).
-- Bu RPC seviye/rating bandı uygular + newbie shield ekler.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.get_arena_opponents(p_limit integer DEFAULT 15)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID;
  v_level INTEGER;
  v_rating INTEGER;
  v_lvl_band INTEGER := 5;       -- ±5 seviye
  v_rating_band INTEGER := 250;  -- ±250 rating
  v_newbie_cap INTEGER;
  v_rows jsonb;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT level, COALESCE(pvp_rating, 1000)
  INTO v_level, v_rating
  FROM public.users WHERE auth_id = v_uid;

  IF v_level IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profil bulunamadı.');
  END IF;

  -- Newbie shield: seviye < 5 ise sadece yakın/zayıf rakipler gösterilir.
  v_newbie_cap := CASE WHEN v_level < 5 THEN v_level + 2 ELSE 2147483647 END;

  WITH candidates AS (
    SELECT
      u.auth_id, u.username, u.level, COALESCE(u.pvp_rating, 1000) AS pvp_rating,
      u.attack, u.defense,
      abs(u.level - v_level) AS lvl_gap,
      abs(COALESCE(u.pvp_rating, 1000) - v_rating) AS rating_gap
    FROM public.users u
    WHERE u.auth_id <> v_uid
      AND u.level >= 1
      AND u.level <= v_newbie_cap
      AND u.hospital_until IS NULL
      AND u.prison_until IS NULL
  ),
  banded AS (
    SELECT *,
      CASE
        WHEN lvl_gap <= v_lvl_band OR rating_gap <= v_rating_band THEN 0
        WHEN lvl_gap <= v_lvl_band * 2 OR rating_gap <= v_rating_band * 2 THEN 1
        ELSE 2
      END AS band_tier
    FROM candidates
  ),
  ranked AS (
    SELECT * FROM banded
    ORDER BY band_tier ASC, (lvl_gap + rating_gap / 50) ASC, random()
    LIMIT GREATEST(p_limit, 1)
  )
  SELECT jsonb_agg(jsonb_build_object(
    'auth_id', auth_id,
    'username', username,
    'level', level,
    'pvp_rating', pvp_rating,
    'attack', attack,
    'defense', defense,
    'level_gap', lvl_gap
  )) INTO v_rows FROM ranked;

  RETURN jsonb_build_object(
    'success', true,
    'opponents', COALESCE(v_rows, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_arena_opponents(integer) TO authenticated;

COMMIT;
