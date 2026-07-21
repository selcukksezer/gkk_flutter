-- Tek kaynak: güçlendirme maliyet / şans / yıkım tabloları (+ oyuncu anıt indirimi).
CREATE OR REPLACE FUNCTION public.get_enhancement_config()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_player RECORD;
  v_monument_level INT := 0;
  v_gold_discount_pct INT := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('error', 'unauthorized');
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = auth.uid();

  IF v_player.guild_id IS NOT NULL THEN
    SELECT monument_level
    INTO v_monument_level
    FROM public.guilds
    WHERE id = v_player.guild_id;
  END IF;

  IF COALESCE(v_monument_level, 0) >= 90 THEN
    v_gold_discount_pct := 5;
  END IF;

  RETURN jsonb_build_object(
    'base_costs', jsonb_build_array(
      100000, 200000, 300000, 500000, 1500000, 3500000,
      7500000, 15000000, 50000000, 200000000, 1000000000
    ),
    'success_rates', jsonb_build_array(100, 100, 100, 100, 70, 60, 50, 35, 20, 10, 3),
    'destroy_rates', jsonb_build_array(0, 0, 0, 0, 0, 0, 100, 100, 100, 100, 100),
    'rarity_multipliers', jsonb_build_object(
      'common', 1.0,
      'uncommon', 1.5,
      'rare', 2.5,
      'epic', 4.0,
      'legendary', 7.0,
      'mythic', 12.0
    ),
    'gold_discount_pct', v_gold_discount_pct,
    'monument_level', COALESCE(v_monument_level, 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_enhancement_config() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_enhancement_config() TO authenticated;
