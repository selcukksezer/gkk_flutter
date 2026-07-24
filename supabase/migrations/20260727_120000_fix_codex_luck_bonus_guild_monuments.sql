-- Fix get_codex_luck_bonus: monument data lives on public.guilds (monument_level),
-- not a non-existent public.guild_monuments table introduced in codex_nemesis_night_market.

CREATE OR REPLACE FUNCTION public.get_codex_luck_bonus(p_player_id UUID DEFAULT auth.uid())
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_bonus INT := 0;
  v_monument INT := 0;
BEGIN
  IF p_player_id IS NULL THEN RETURN 0; END IF;
  v_bonus := public._codex_luck_bonus_raw(p_player_id);
  SELECT COALESCE(g.monument_level, 0) INTO v_monument
  FROM public.guilds g
  JOIN public.users u ON u.guild_id = g.id
  WHERE u.auth_id = p_player_id
  LIMIT 1;
  IF v_monument >= 30 THEN
    v_bonus := LEAST(v_bonus + 10, 11);
  END IF;
  RETURN LEAST(v_bonus, 11);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_codex_luck_bonus(UUID) TO authenticated;
