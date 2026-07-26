-- Kral pazar indirimi: kim/ne kadar bilgisi (UI + king_powers).

BEGIN;

CREATE OR REPLACE FUNCTION public.get_kingdom_market_blessing_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row record;
BEGIN
  SELECT
    b.gold_discount_pct,
    b.gem_discount_pct,
    b.started_at,
    b.expires_at,
    u.username AS activated_by_username,
    g.name AS activated_by_guild_name
  INTO v_row
  FROM public.kingdom_market_blessings b
  LEFT JOIN public.users u ON u.auth_id = b.activated_by
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE b.expires_at > now()
  ORDER BY b.started_at DESC
  LIMIT 1;

  IF v_row IS NULL OR v_row.expires_at IS NULL THEN
    RETURN jsonb_build_object('active', false);
  END IF;

  RETURN jsonb_build_object(
    'active', true,
    'gold_discount_pct', COALESCE(v_row.gold_discount_pct, 0),
    'gem_discount_pct', COALESCE(v_row.gem_discount_pct, 0),
    'started_at', v_row.started_at,
    'expires_at', v_row.expires_at,
    'activated_by_username', COALESCE(v_row.activated_by_username, 'Kral'),
    'activated_by_guild_name', v_row.activated_by_guild_name
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._kingdom_king_powers_context()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_is_king boolean := false;
  v_active record;
  v_used_today boolean := false;
  v_day date := public._kingdom_blessing_day();
BEGIN
  IF v_user IS NOT NULL THEN
    v_is_king := public.is_current_king(v_user);
  END IF;

  SELECT
    b.gold_discount_pct,
    b.gem_discount_pct,
    b.started_at,
    b.expires_at,
    u.username AS activated_by_username,
    g.name AS activated_by_guild_name
  INTO v_active
  FROM public.kingdom_market_blessings b
  LEFT JOIN public.users u ON u.auth_id = b.activated_by
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE b.expires_at > now()
  ORDER BY b.started_at DESC
  LIMIT 1;

  SELECT EXISTS (
    SELECT 1 FROM public.kingdom_market_blessings b WHERE b.blessing_day = v_day
  ) INTO v_used_today;

  RETURN jsonb_build_object(
    'is_king', v_is_king,
    'blessing_active', v_active.expires_at IS NOT NULL,
    'blessing_expires_at', v_active.expires_at,
    'blessing_started_at', v_active.started_at,
    'active_gold_pct', COALESCE(v_active.gold_discount_pct, 0),
    'active_gem_pct', COALESCE(v_active.gem_discount_pct, 0),
    'blessing_used_today', v_used_today,
    'blessing_activated_by_username', v_active.activated_by_username,
    'blessing_activated_by_guild_name', v_active.activated_by_guild_name,
    'max_gold_pct', 20,
    'max_gem_pct', 10,
    'duration_minutes', 30
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_kingdom_market_blessing_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_kingdom_market_blessing_status() TO anon;

COMMIT;
