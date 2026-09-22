-- Gem defense: anytime addable; NO prime wipe; only clears on territory loss (conquest).

BEGIN;

-- No-op: callers (get_guild_war_territories / detail / siege) keep working.
CREATE OR REPLACE FUNCTION public.guild_war_reset_gem_defense_outside_prime()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Eski mantık: prime dışı tüm gem_defense_boost = 0. KALDIRILDI.
  -- Gem savunma yalnızca bölge kaybedilince (attack success) sıfırlanır.
  RETURN 0;
END;
$function$;

CREATE OR REPLACE FUNCTION public.add_territory_defense(
  p_territory_id uuid,
  p_gems integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_guild_id uuid;
  v_territory record;
  v_player_gems integer;
  v_defense_increase integer;
  v_siege_bonus_pct numeric;
  v_effective_defense integer;
BEGIN
  IF p_gems IS NULL OR p_gems <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'Geçersiz elmas miktarı.');
  END IF;

  -- Prime zorunluluğu KALDIRILDI — her an eklenebilir.

  SELECT guild_id INTO v_guild_id
  FROM public.users
  WHERE auth_id = v_player_id;

  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  SELECT * INTO v_territory
  FROM public.guild_war_territories
  WHERE id = p_territory_id
  FOR UPDATE;

  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id != v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Sadece kendi bölgenize savunma ekleyebilirsiniz.');
  END IF;

  SELECT gems INTO v_player_gems
  FROM public.users
  WHERE auth_id = v_player_id;

  IF v_player_gems < p_gems THEN
    RETURN json_build_object('success', false, 'error', 'Yeterli elmasınız yok.');
  END IF;

  v_defense_increase := p_gems * 10;

  UPDATE public.users
  SET gems = gems - p_gems
  WHERE auth_id = v_player_id;

  UPDATE public.guild_war_territories
  SET gem_defense_boost = gem_defense_boost + v_defense_increase,
      defense_added_at = now(),
      updated_at = now()
  WHERE id = p_territory_id
  RETURNING * INTO v_territory;

  v_effective_defense := public.guild_war_territory_effective_defense(
    v_territory.defense_power,
    v_territory.gem_defense_boost
  );
  v_siege_bonus_pct := public.dungeon_siege_territory_defense_multiplier(v_territory.zone_number);

  RETURN json_build_object(
    'success', true,
    'message', format(
      'Elmas savunması +%s (toplam etkili %s). Bölge kaybedilirse sıfırlanır.',
      v_defense_increase,
      v_effective_defense
    ),
    'gem_defense_boost', v_territory.gem_defense_boost,
    'effective_defense', v_effective_defense,
    'siege_bonus_pct', v_siege_bonus_pct
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.guild_war_reset_gem_defense_outside_prime() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_territory_defense(uuid, integer) TO authenticated;

COMMIT;
