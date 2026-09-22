-- Monument upgrade: vault debit must equal required gold (no silent no-op).
-- Returns vault_before / vault_gold so clients can refresh UI immediately.

CREATE OR REPLACE FUNCTION public.upgrade_monument(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user RECORD;
  v_guild RECORD;
  v_next_level INT;
  v_cost RECORD;
  v_members INT;
  v_mult NUMERIC;
  v_req_structural BIGINT;
  v_req_mystical BIGINT;
  v_req_critical BIGINT;
  v_req_gold BIGINT;
  v_available_gold BIGINT;
  v_vault_before BIGINT;
  v_vault_after BIGINT;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz islem');
  END IF;
  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bir loncaya uye degilsiniz');
  END IF;
  IF COALESCE(v_user.guild_role, '') NOT IN ('leader', 'officer', 'commander') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkiniz yok (Lider veya Subay gerekli)');
  END IF;
  SELECT * INTO v_guild FROM public.guilds WHERE id = v_user.guild_id FOR UPDATE;
  v_next_level := v_guild.monument_level + 1;
  IF v_next_level > 100 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Anit zaten maksimum seviyede');
  END IF;
  SELECT * INTO v_cost FROM public.monument_level_costs WHERE level = v_next_level;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seviye maliyeti tanimli degil');
  END IF;
  SELECT COUNT(*)::INT INTO v_members FROM public.users WHERE guild_id = v_guild.id;
  v_mult := public.guild_size_multiplier(v_members);
  v_req_structural := CEIL(v_cost.structural * v_mult)::BIGINT;
  v_req_mystical := CEIL(v_cost.mystical * v_mult)::BIGINT;
  v_req_critical := CEIL(v_cost.critical * v_mult)::BIGINT;
  v_req_gold := CEIL(COALESCE(v_cost.gold, 0) * v_mult)::BIGINT;
  IF v_cost.blueprint_type IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.guild_blueprints
      WHERE guild_id = v_guild.id AND blueprint_type = v_cost.blueprint_type AND is_complete = true
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', v_cost.blueprint_type || ' blueprint tamamlanmali');
    END IF;
  END IF;

  v_available_gold := COALESCE(v_guild.vault_gold, 0);
  v_vault_before := v_available_gold;

  IF v_guild.monument_structural < v_req_structural OR
     v_guild.monument_mystical < v_req_mystical OR
     v_guild.monument_critical < v_req_critical OR
     v_available_gold < v_req_gold THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Yeterli kaynak yok (altın: lonca kasası)',
      'vault_gold', v_available_gold,
      'required_gold', v_req_gold,
      'have_structural', v_guild.monument_structural,
      'have_mystical', v_guild.monument_mystical,
      'have_critical', v_guild.monument_critical,
      'need_structural', v_req_structural,
      'need_mystical', v_req_mystical,
      'need_critical', v_req_critical
    );
  END IF;

  UPDATE public.guilds SET
    monument_level = v_next_level,
    monument_structural = monument_structural - v_req_structural,
    monument_mystical = monument_mystical - v_req_mystical,
    monument_critical = monument_critical - v_req_critical,
    monument_gold_pool = 0,
    vault_gold = vault_gold - v_req_gold,
    monument_100_first = CASE
      WHEN v_next_level = 100 AND NOT EXISTS (
        SELECT 1 FROM public.guilds WHERE monument_level >= 100 AND id != v_guild.id
      ) THEN true
      ELSE monument_100_first
    END,
    monument_100_at = CASE WHEN v_next_level = 100 THEN now() ELSE monument_100_at END
  WHERE id = v_guild.id
    AND COALESCE(vault_gold, 0) >= v_req_gold
  RETURNING vault_gold INTO v_vault_after;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Yeterli kaynak yok (altın: lonca kasası)',
      'vault_gold', v_vault_before,
      'required_gold', v_req_gold
    );
  END IF;

  IF v_vault_after <> (v_vault_before - v_req_gold) THEN
    RAISE EXCEPTION 'monument upgrade vault debit mismatch: before=% required=% after=%',
      v_vault_before, v_req_gold, v_vault_after;
  END IF;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_guild.id, p_user_id, 'monument_upgrade_spend',
    jsonb_build_object(
      'amount', v_req_gold,
      'level', v_next_level,
      'vault_before', v_vault_before,
      'vault_gold', v_vault_after
    )
  );

  INSERT INTO public.monument_upgrades (
    guild_id, from_level, to_level,
    structural_spent, mystical_spent, critical_spent, gold_spent, upgraded_by
  )
  VALUES (
    v_guild.id, v_guild.monument_level, v_next_level,
    v_req_structural, v_req_mystical, v_req_critical, v_req_gold, p_user_id
  );

  PERFORM public.sync_guild_member_monument_stats(v_guild.id);

  RETURN jsonb_build_object(
    'success', true,
    'new_level', v_next_level,
    'gold_from_vault', v_req_gold,
    'required_gold', v_req_gold,
    'vault_before', v_vault_before,
    'vault_gold', v_vault_after
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.upgrade_monument(uuid) TO authenticated;
