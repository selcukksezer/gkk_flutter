-- Wounded (< 50% max health) fighters hit 15% weaker in arena attacks and duels.

BEGIN;

-- ── pvp_attack: wounded damage multiplier ────────────────────────────────────

DO $patch$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_functiondef('public.pvp_attack(uuid,uuid,uuid)'::regprocedure) INTO v_def;
  IF v_def IS NULL OR position('wounded_mult' IN v_def) > 0 THEN
    RETURN;
  END IF;

  v_def := replace(
    v_def,
    '  v_defender_bloodlust_mult NUMERIC := 1.0;',
    '  v_defender_bloodlust_mult NUMERIC := 1.0;
  v_attacker_wounded_mult NUMERIC := 1.0;
  v_defender_wounded_mult NUMERIC := 1.0;'
  );

  v_def := replace(
    v_def,
    '  v_attacker_hp := COALESCE(v_attacker.health, 100);',
    '  IF COALESCE(v_attacker.health, 100) < public.player_wounded_health(COALESCE(v_attacker.max_health, 100)) THEN
    v_attacker_wounded_mult := 0.85;
  END IF;
  IF COALESCE(v_defender.health, 100) < public.player_wounded_health(COALESCE(v_defender.max_health, 100)) THEN
    v_defender_wounded_mult := 0.85;
  END IF;

  v_attacker_hp := COALESCE(v_attacker.health, 100);'
  );

  v_def := replace(
    v_def,
    '                     * v_attacker_bloodlust_mult',
    '                     * v_attacker_bloodlust_mult
                     * v_attacker_wounded_mult'
  );

  v_def := replace(
    v_def,
    '                     * v_defender_bloodlust_mult',
    '                     * v_defender_bloodlust_mult
                     * v_defender_wounded_mult'
  );

  IF position('wounded_mult' IN v_def) > 0 THEN
    EXECUTE v_def;
  END IF;
END;
$patch$;

-- ── respond_pvp_invite: wounded power multiplier ─────────────────────────────

DO $patch$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_functiondef('public.respond_pvp_invite(uuid, boolean)'::regprocedure) INTO v_def;
  IF v_def IS NULL OR position('player_wounded_health' IN v_def) > 0 THEN
    RETURN;
  END IF;

  v_def := replace(
    v_def,
    '  v_win_chance := v_att_power / NULLIF(v_att_power + v_def_power, 0);',
    '  IF COALESCE(v_challenger.health, 100) < public.player_wounded_health(COALESCE(v_challenger.max_health, 100)) THEN
    v_att_power := v_att_power * 0.85;
  END IF;
  IF COALESCE(v_target.health, 100) < public.player_wounded_health(COALESCE(v_target.max_health, 100)) THEN
    v_def_power := v_def_power * 0.85;
  END IF;

  v_win_chance := v_att_power / NULLIF(v_att_power + v_def_power, 0);'
  );

  IF position('player_wounded_health' IN v_def) > 0 THEN
    EXECUTE v_def;
  END IF;
END;
$patch$;

COMMIT;
