-- System 2 C: Guild Clinic & Bureau
-- clinic_level + steeper cost table; donate/upgrade vault pattern
-- Cut bands 5%→18% by level; min 5 max 45 min; never instant
-- Soft: monument_level>=60 → cut ×0.9
-- Daily: 1 shared doctor|lawyer per member per Istanbul day; self-use only
-- Lawyer sets prison_lawyer_used_this_stay for D +5%

BEGIN;

ALTER TABLE public.guilds
  ADD COLUMN IF NOT EXISTS clinic_level integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS clinic_structural bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS clinic_mystical bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS clinic_critical bigint NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.clinic_level_costs (
  level int PRIMARY KEY CHECK (level BETWEEN 1 AND 100),
  structural bigint NOT NULL DEFAULT 0,
  mystical bigint NOT NULL DEFAULT 0,
  critical bigint NOT NULL DEFAULT 0,
  gold bigint NOT NULL DEFAULT 0
);

-- Steeper than monument: ~1.75× monument costs (no blueprint gate)
INSERT INTO public.clinic_level_costs (level, structural, mystical, critical, gold)
SELECT
  m.level,
  CEIL(m.structural * 1.75)::bigint,
  CEIL(m.mystical * 1.75)::bigint,
  CEIL(m.critical * 1.75)::bigint,
  CEIL(m.gold * 1.75)::bigint
FROM public.monument_level_costs m
ON CONFLICT (level) DO UPDATE SET
  structural = EXCLUDED.structural,
  mystical = EXCLUDED.mystical,
  critical = EXCLUDED.critical,
  gold = EXCLUDED.gold;

CREATE TABLE IF NOT EXISTS public.guild_clinic_daily_uses (
  user_id uuid NOT NULL,
  used_on date NOT NULL,
  use_kind text NOT NULL CHECK (use_kind IN ('doctor', 'lawyer')),
  PRIMARY KEY (user_id, used_on)
);

ALTER TABLE public.guild_clinic_daily_uses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS guild_clinic_daily_uses_select_own ON public.guild_clinic_daily_uses;
CREATE POLICY guild_clinic_daily_uses_select_own ON public.guild_clinic_daily_uses
  FOR SELECT USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public._clinic_cut_pct(p_level integer)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_level IS NULL OR p_level < 1 THEN 0::numeric
    WHEN p_level >= 100 THEN 0.18::numeric
    ELSE (0.05 + ((p_level - 1)::numeric / 99.0) * 0.13)
  END;
$$;

CREATE OR REPLACE FUNCTION public._clinic_apply_cut(
  p_until timestamptz,
  p_level integer,
  p_monument_level integer
)
RETURNS timestamptz
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_pct numeric;
  v_remaining_mins numeric;
  v_cut integer;
  v_new timestamptz;
BEGIN
  IF p_until IS NULL OR p_until <= now() OR p_level < 1 THEN
    RETURN p_until;
  END IF;

  v_pct := public._clinic_cut_pct(p_level);
  IF COALESCE(p_monument_level, 0) >= 60 THEN
    v_pct := v_pct * 0.9;
  END IF;

  v_remaining_mins := EXTRACT(EPOCH FROM (p_until - now())) / 60.0;
  v_cut := GREATEST(5, LEAST(45, CEIL(v_remaining_mins * v_pct)::integer));

  v_new := p_until - make_interval(mins => v_cut);

  -- Never instant: leave at least 1 minute
  IF v_new <= now() + interval '1 minute' THEN
    v_new := now() + interval '1 minute';
  END IF;

  RETURN v_new;
END;
$$;

-- Donate resources/gold into clinic pools (gold → vault_gold like monument)
CREATE OR REPLACE FUNCTION public.donate_to_clinic(
  p_structural integer DEFAULT 0,
  p_mystical integer DEFAULT 0,
  p_critical integer DEFAULT 0,
  p_gold bigint DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_user record;
  v_guild record;
  v_s int := GREATEST(0, COALESCE(p_structural, 0));
  v_m int := GREATEST(0, COALESCE(p_mystical, 0));
  v_c int := GREATEST(0, COALESCE(p_critical, 0));
  v_g bigint := GREATEST(0, COALESCE(p_gold, 0));
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF v_s = 0 AND v_m = 0 AND v_c = 0 AND v_g = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bos bagis');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_auth FOR UPDATE;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca yok');
  END IF;

  IF v_g > 0 AND COALESCE(v_user.gold, 0) < v_g THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altin');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_user.guild_id FOR UPDATE;

  IF v_s > 0 AND NOT public._consume_inventory_item(v_auth, 'resource_structural', v_s) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz structural');
  END IF;
  IF v_m > 0 AND NOT public._consume_inventory_item(v_auth, 'resource_mystical', v_m) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz mystical');
  END IF;
  IF v_c > 0 AND NOT public._consume_inventory_item(v_auth, 'resource_critical', v_c) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz critical');
  END IF;

  IF v_g > 0 THEN
    UPDATE public.users
    SET gold = gold - v_g, updated_at = now()
    WHERE auth_id = v_auth AND gold >= v_g;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altin');
    END IF;
  END IF;

  UPDATE public.guilds
  SET clinic_structural = clinic_structural + v_s,
      clinic_mystical = clinic_mystical + v_m,
      clinic_critical = clinic_critical + v_c,
      vault_gold = vault_gold + v_g
  WHERE id = v_guild.id;

  IF v_g > 0 THEN
    INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
    VALUES (
      v_guild.id, v_auth, 'clinic_donate_gold',
      jsonb_build_object('amount', v_g)
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'donated', jsonb_build_object(
      'structural', v_s, 'mystical', v_m, 'critical', v_c, 'gold', v_g
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.donate_to_clinic(integer, integer, integer, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.upgrade_clinic()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_user record;
  v_guild record;
  v_next int;
  v_cost record;
  v_members int;
  v_mult numeric;
  v_req_s bigint;
  v_req_m bigint;
  v_req_c bigint;
  v_req_g bigint;
  v_vault_before bigint;
  v_vault_after bigint;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_auth FOR UPDATE;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca yok');
  END IF;
  IF COALESCE(v_user.guild_role, '') NOT IN ('leader', 'officer', 'commander') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkiniz yok (Lider veya Subay gerekli)');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_user.guild_id FOR UPDATE;
  v_next := COALESCE(v_guild.clinic_level, 0) + 1;
  IF v_next > 100 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Klinik maksimum seviyede');
  END IF;

  SELECT * INTO v_cost FROM public.clinic_level_costs WHERE level = v_next;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seviye maliyeti tanimli degil');
  END IF;

  SELECT COUNT(*)::int INTO v_members FROM public.users WHERE guild_id = v_guild.id;
  v_mult := public.guild_size_multiplier(v_members);
  v_req_s := CEIL(v_cost.structural * v_mult)::bigint;
  v_req_m := CEIL(v_cost.mystical * v_mult)::bigint;
  v_req_c := CEIL(v_cost.critical * v_mult)::bigint;
  v_req_g := CEIL(COALESCE(v_cost.gold, 0) * v_mult)::bigint;
  v_vault_before := COALESCE(v_guild.vault_gold, 0);

  IF v_guild.clinic_structural < v_req_s
     OR v_guild.clinic_mystical < v_req_m
     OR v_guild.clinic_critical < v_req_c
     OR v_vault_before < v_req_g THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Yeterli kaynak yok',
      'need_structural', v_req_s,
      'need_mystical', v_req_m,
      'need_critical', v_req_c,
      'need_gold', v_req_g,
      'vault_gold', v_vault_before
    );
  END IF;

  UPDATE public.guilds
  SET clinic_level = v_next,
      clinic_structural = clinic_structural - v_req_s,
      clinic_mystical = clinic_mystical - v_req_m,
      clinic_critical = clinic_critical - v_req_c,
      vault_gold = vault_gold - v_req_g
  WHERE id = v_guild.id
    AND COALESCE(vault_gold, 0) >= v_req_g
  RETURNING vault_gold INTO v_vault_after;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli kaynak yok');
  END IF;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_guild.id, v_auth, 'clinic_upgrade_spend',
    jsonb_build_object(
      'amount', v_req_g,
      'level', v_next,
      'vault_before', v_vault_before,
      'vault_gold', v_vault_after
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'clinic_level', v_next,
    'vault_gold', v_vault_after
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.upgrade_clinic() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_clinic_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_user record;
  v_guild record;
  v_today date := public._istanbul_today();
  v_used text;
  v_next_cost record;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_auth;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca yok');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_user.guild_id;

  SELECT use_kind INTO v_used
  FROM public.guild_clinic_daily_uses
  WHERE user_id = v_auth AND used_on = v_today;

  SELECT * INTO v_next_cost
  FROM public.clinic_level_costs
  WHERE level = COALESCE(v_guild.clinic_level, 0) + 1;

  RETURN jsonb_build_object(
    'success', true,
    'clinic_level', COALESCE(v_guild.clinic_level, 0),
    'clinic_structural', COALESCE(v_guild.clinic_structural, 0),
    'clinic_mystical', COALESCE(v_guild.clinic_mystical, 0),
    'clinic_critical', COALESCE(v_guild.clinic_critical, 0),
    'vault_gold', COALESCE(v_guild.vault_gold, 0),
    'monument_level', COALESCE(v_guild.monument_level, 0),
    'cut_pct', public._clinic_cut_pct(COALESCE(v_guild.clinic_level, 0)),
    'daily_use_kind', v_used,
    'daily_available', v_used IS NULL,
    'next_cost', CASE WHEN v_next_cost.level IS NULL THEN NULL ELSE jsonb_build_object(
      'level', v_next_cost.level,
      'structural', v_next_cost.structural,
      'mystical', v_next_cost.mystical,
      'critical', v_next_cost.critical,
      'gold', v_next_cost.gold
    ) END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_clinic_dashboard() TO authenticated;

CREATE OR REPLACE FUNCTION public.use_guild_doctor()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_user record;
  v_guild record;
  v_today date := public._istanbul_today();
  v_new_until timestamptz;
  v_old_until timestamptz;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_auth FOR UPDATE;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca yok');
  END IF;

  IF v_user.hospital_until IS NULL OR v_user.hospital_until <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastanede degilsin');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_user.guild_id;
  IF COALESCE(v_guild.clinic_level, 0) < 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca klinigi yok');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.guild_clinic_daily_uses
    WHERE user_id = v_auth AND used_on = v_today
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'daily_limit', 'message', 'Bugunku klinik hakkin kullanildi');
  END IF;

  v_old_until := v_user.hospital_until;
  v_new_until := public._clinic_apply_cut(
    v_old_until,
    v_guild.clinic_level,
    v_guild.monument_level
  );

  INSERT INTO public.guild_clinic_daily_uses (user_id, used_on, use_kind)
  VALUES (v_auth, v_today, 'doctor');

  UPDATE public.users
  SET hospital_until = v_new_until,
      updated_at = now()
  WHERE auth_id = v_auth;

  RETURN jsonb_build_object(
    'success', true,
    'kind', 'doctor',
    'old_until', v_old_until,
    'new_until', v_new_until,
    'cut_pct', public._clinic_cut_pct(v_guild.clinic_level)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.use_guild_doctor() TO authenticated;

CREATE OR REPLACE FUNCTION public.use_guild_lawyer()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_user record;
  v_guild record;
  v_today date := public._istanbul_today();
  v_new_until timestamptz;
  v_old_until timestamptz;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_auth FOR UPDATE;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca yok');
  END IF;

  IF v_user.prison_until IS NULL OR v_user.prison_until <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cezaevinde degilsin');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_user.guild_id;
  IF COALESCE(v_guild.clinic_level, 0) < 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca klinigi yok');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.guild_clinic_daily_uses
    WHERE user_id = v_auth AND used_on = v_today
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'daily_limit', 'message', 'Bugunku klinik hakkin kullanildi');
  END IF;

  v_old_until := v_user.prison_until;
  v_new_until := public._clinic_apply_cut(
    v_old_until,
    v_guild.clinic_level,
    v_guild.monument_level
  );

  INSERT INTO public.guild_clinic_daily_uses (user_id, used_on, use_kind)
  VALUES (v_auth, v_today, 'lawyer');

  UPDATE public.users
  SET prison_until = v_new_until,
      prison_lawyer_used_this_stay = true,
      updated_at = now()
  WHERE auth_id = v_auth;

  RETURN jsonb_build_object(
    'success', true,
    'kind', 'lawyer',
    'old_until', v_old_until,
    'new_until', v_new_until,
    'lawyer_bonus_ready', true,
    'cut_pct', public._clinic_cut_pct(v_guild.clinic_level)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.use_guild_lawyer() TO authenticated;

COMMIT;
