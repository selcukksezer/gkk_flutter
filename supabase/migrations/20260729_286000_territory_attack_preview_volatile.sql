-- Fix PostgREST 25006: get_territory_attack_preview was STABLE but accrues guild vault
-- (SELECT FOR UPDATE inside _accrue_guild_vault). Read-only RPC tx → crash.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_territory_attack_preview(p_territory_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_territory RECORD;
  v_guild RECORD;
  v_defender RECORD;
  v_attack_power INTEGER;
  v_effective_defense INTEGER;
  v_cost INTEGER;
  v_win_pct NUMERIC;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  PERFORM public._accrue_guild_vault(v_guild_id);

  SELECT g.id, g.name, g.tag, g.vault_gold, g.vault_gold_pending, g.leader_id
  INTO v_guild
  FROM public.guilds g WHERE g.id = v_guild_id;

  IF v_territory.owner_guild_id IS NOT NULL THEN
    SELECT g.id, g.name, g.tag INTO v_defender
    FROM public.guilds g WHERE g.id = v_territory.owner_guild_id;
  END IF;

  SELECT COALESCE(level * 50, 100) INTO v_attack_power FROM public.users WHERE auth_id = v_user;
  v_effective_defense := public.guild_war_territory_effective_defense(
    v_territory.defense_power, v_territory.gem_defense_boost
  );
  v_cost := COALESCE(
    v_territory.attack_gold_cost,
    GREATEST(1000, (COALESCE(v_territory.trade_income, 0) * 0.55)::INTEGER)
  );
  v_win_pct := ROUND(
    (v_attack_power::NUMERIC / GREATEST(v_attack_power + v_effective_defense, 1)) * 100,
    1
  );

  RETURN jsonb_build_object(
    'success', true,
    'territory_id', v_territory.id,
    'territory_name', v_territory.name,
    'trade_income', COALESCE(v_territory.trade_income, 0),
    'attack_gold_cost', v_cost,
    'roi_days', CASE
      WHEN COALESCE(v_territory.trade_income, 0) > 0
      THEN ROUND(v_cost::NUMERIC / v_territory.trade_income, 1)
      ELSE NULL
    END,
    'attack_power', v_attack_power,
    'defense_power', v_effective_defense,
    'win_chance_pct', v_win_pct,
    'vault_gold', COALESCE(v_guild.vault_gold, 0),
    'vault_gold_pending', COALESCE(v_guild.vault_gold_pending, 0),
    'can_afford', COALESCE(v_guild.vault_gold, 0) >= v_cost,
    'attacker_guild', jsonb_build_object(
      'id', v_guild.id,
      'name', v_guild.name,
      'tag', v_guild.tag
    ),
    'defender_guild', CASE
      WHEN v_defender.id IS NULL THEN NULL
      ELSE jsonb_build_object('id', v_defender.id, 'name', v_defender.name, 'tag', v_defender.tag)
    END
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_territory_attack_preview(uuid) TO authenticated;

COMMIT;
