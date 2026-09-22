-- Character class ability audit fixes (PLAN_11 follow-up)
--
-- 1) claim_alchemist_detox was completely broken:
--    - referenced non-existent items.item_id column (items PK is text "id")
--    - looked up wrong item ids ('potion_antidote') instead of 'detox_minor'
--    - called non-existent add_item_to_inventory()
--    - stored cooldown in non-existent users.custom_fields column
--    Rewritten from scratch using dungeon_add_item + a dedicated timestamp column.
--
-- 2) pvp_attack: warrior hospital_duration_reduction (-20%) was applied in
--    enter_dungeon but not in arena PvP hospitalizations. Patched both branches.
--
-- 3) respond_pvp_invite: duel sim gave shadow +15% power but ignored warrior
--    entirely (+20% pvp damage and Bloodlust). Warrior multipliers added.

-- ─── 1) claim_alchemist_detox rewrite ───────────────────────────────────────

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS alchemist_detox_claimed_at timestamptz;

CREATE OR REPLACE FUNCTION public.claim_alchemist_detox()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_user record;
  v_now timestamptz := now();
  v_next timestamptz;
  v_remaining interval;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Oturum bulunamadı.');
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Oyuncu bulunamadı.');
  END IF;

  IF COALESCE(v_user.character_class, '') <> 'alchemist' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Sadece Simyacılar günlük detox alabilir.'
    );
  END IF;

  IF v_user.alchemist_detox_claimed_at IS NOT NULL
     AND v_user.alchemist_detox_claimed_at + interval '24 hours' > v_now THEN
    v_next := v_user.alchemist_detox_claimed_at + interval '24 hours';
    v_remaining := v_next - v_now;
    RETURN json_build_object(
      'success', false,
      'message', format(
        'Günlük detox zaten alındı. Kalan: %s sa %s dk',
        floor(extract(epoch from v_remaining) / 3600)::int,
        floor(mod(extract(epoch from v_remaining)::numeric, 3600) / 60)::int
      ),
      'next_claim_at', v_next
    );
  END IF;

  IF NOT public.dungeon_add_item(v_user_id, 'detox_minor', 1) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Envanterde boş yer yok. Yer açıp tekrar dene.'
    );
  END IF;

  UPDATE public.users
  SET alchemist_detox_claimed_at = v_now,
      updated_at = v_now
  WHERE auth_id = v_user_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Minor Detox envanterine eklendi!',
    'next_claim_at', v_now + interval '24 hours'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_alchemist_detox() TO authenticated;

-- ─── 2) pvp_attack: warrior -20% hospital duration ──────────────────────────

DO $do$
DECLARE
  v_def TEXT;
  v_old_ko TEXT := E'    v_hospital_minutes := GREATEST(30, floor(45 + random() * 45)::INT);';
  v_new_ko TEXT := E'    v_hospital_minutes := GREATEST(30, floor(45 + random() * 45)::INT);\n    IF COALESCE((CASE WHEN v_winner_id = p_attacker_id THEN v_defender.character_class ELSE v_attacker.character_class END), '''') = ''warrior'' THEN\n      v_hospital_minutes := GREATEST(15, floor(v_hospital_minutes * 0.80)::INT);\n    END IF;';
  v_old_rand TEXT := E'    v_hospital_minutes := floor(30 + random() * 120)::INT;';
  v_new_rand TEXT := E'    v_hospital_minutes := floor(30 + random() * 120)::INT;\n    IF COALESCE((CASE WHEN v_winner_id = p_attacker_id THEN v_defender.character_class ELSE v_attacker.character_class END), '''') = ''warrior'' THEN\n      v_hospital_minutes := GREATEST(15, floor(v_hospital_minutes * 0.80)::INT);\n    END IF;';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'pvp_attack'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE NOTICE 'pvp_attack not found, skipping';
    RETURN;
  END IF;

  IF position('v_hospital_minutes * 0.80' in v_def) > 0 THEN
    RAISE NOTICE 'pvp_attack already patched, skipping';
    RETURN;
  END IF;

  IF position(v_old_ko in v_def) = 0 OR position(v_old_rand in v_def) = 0 THEN
    RAISE EXCEPTION 'pvp_attack hospital snippets not found — manual review needed';
  END IF;

  v_def := replace(v_def, v_old_ko, v_new_ko);
  v_def := replace(v_def, v_old_rand, v_new_rand);
  EXECUTE v_def;
END $do$;

-- ─── 3) respond_pvp_invite: warrior +20% power & Bloodlust ──────────────────

DO $do$
DECLARE
  v_def TEXT;
  v_old TEXT := E'  IF COALESCE(v_challenger.character_class, '''') = ''shadow'' THEN v_att_power := v_att_power * 1.15; END IF;\n  IF COALESCE(v_target.character_class, '''') = ''shadow'' THEN v_def_power := v_def_power * 1.15; END IF;';
  v_new TEXT := E'  IF COALESCE(v_challenger.character_class, '''') = ''shadow'' THEN v_att_power := v_att_power * 1.15; END IF;\n  IF COALESCE(v_target.character_class, '''') = ''shadow'' THEN v_def_power := v_def_power * 1.15; END IF;\n  IF COALESCE(v_challenger.character_class, '''') = ''warrior'' THEN\n    v_att_power := v_att_power * 1.20;\n    IF v_challenger.warrior_bloodlust_until IS NOT NULL AND v_challenger.warrior_bloodlust_until > now() THEN\n      v_att_power := v_att_power * CASE WHEN COALESCE(v_challenger.warrior_bloodlust_streak, 0) >= 3 THEN 1.20 ELSE 1.10 END;\n    END IF;\n  END IF;\n  IF COALESCE(v_target.character_class, '''') = ''warrior'' THEN\n    v_def_power := v_def_power * 1.20;\n    IF v_target.warrior_bloodlust_until IS NOT NULL AND v_target.warrior_bloodlust_until > now() THEN\n      v_def_power := v_def_power * CASE WHEN COALESCE(v_target.warrior_bloodlust_streak, 0) >= 3 THEN 1.20 ELSE 1.10 END;\n    END IF;\n  END IF;';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'respond_pvp_invite'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE NOTICE 'respond_pvp_invite not found, skipping';
    RETURN;
  END IF;

  IF position('= ''warrior''' in v_def) > 0 THEN
    RAISE NOTICE 'respond_pvp_invite already patched, skipping';
    RETURN;
  END IF;

  IF position(v_old in v_def) = 0 THEN
    RAISE EXCEPTION 'respond_pvp_invite class snippet not found — manual review needed';
  END IF;

  v_def := replace(v_def, v_old, v_new);
  EXECUTE v_def;
END $do$;
