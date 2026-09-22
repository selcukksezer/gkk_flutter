-- Clinic + monument: shared daily donate limits (guild_daily_donations)
-- and shared guild vault (vault_gold — already used by clinic; keep).
-- Clinic resource pools remain upgrade meters (like monument_* pools).
-- Doctor/lawyer daily use (guild_clinic_daily_uses) unchanged.

BEGIN;

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
  v_daily record;
  v_s int := GREATEST(0, COALESCE(p_structural, 0));
  v_m int := GREATEST(0, COALESCE(p_mystical, 0));
  v_c int := GREATEST(0, COALESCE(p_critical, 0));
  v_g bigint := GREATEST(0, COALESCE(p_gold, 0));
  v_limits jsonb := public._monument_daily_limits();
  v_max_structural int := COALESCE((v_limits->>'structural')::int, 500);
  v_max_mystical int := COALESCE((v_limits->>'mystical')::int, 200);
  v_max_critical int := COALESCE((v_limits->>'critical')::int, 50);
  v_max_gold bigint := COALESCE((v_limits->>'gold')::bigint, 10000000);
  v_contribution_score bigint;
  v_vault_after bigint := 0;
  v_today_s int := 0;
  v_today_m int := 0;
  v_today_c int := 0;
  v_today_g bigint := 0;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF v_s = 0 AND v_m = 0 AND v_c = 0 AND v_g = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bos bagis');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_auth FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca yok');
  END IF;

  -- Shared daily pool with monument (guild_daily_donations / CURRENT_DATE).
  SELECT * INTO v_daily
  FROM public.guild_daily_donations
  WHERE guild_id = v_user.guild_id
    AND user_id = v_auth
    AND donation_date = CURRENT_DATE
  FOR UPDATE;

  IF FOUND THEN
    v_today_s := COALESCE(v_daily.structural_today, 0);
    v_today_m := COALESCE(v_daily.mystical_today, 0);
    v_today_c := COALESCE(v_daily.critical_today, 0);
    v_today_g := COALESCE(v_daily.gold_today, 0);
    IF v_today_s + v_s > v_max_structural OR
       v_today_m + v_m > v_max_mystical OR
       v_today_c + v_c > v_max_critical OR
       v_today_g + v_g > v_max_gold THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Günlük bağış sınırını aştınız',
        'daily_limits', v_limits,
        'my_today', jsonb_build_object(
          'structural', v_today_s,
          'mystical', v_today_m,
          'critical', v_today_c,
          'gold', v_today_g
        )
      );
    END IF;
  ELSE
    IF v_s > v_max_structural OR v_m > v_max_mystical OR
       v_c > v_max_critical OR v_g > v_max_gold THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Günlük bağış sınırını aştınız',
        'daily_limits', v_limits
      );
    END IF;
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

  v_contribution_score := v_s * 10 + v_m * 25 + v_c * 100 + v_g / 1000;

  -- Resources → clinic upgrade pools. Gold → shared guild vault.
  UPDATE public.guilds
  SET clinic_structural = clinic_structural + v_s,
      clinic_mystical = clinic_mystical + v_m,
      clinic_critical = clinic_critical + v_c,
      vault_gold = vault_gold + v_g
  WHERE id = v_guild.id
  RETURNING vault_gold INTO v_vault_after;

  IF v_g > 0 THEN
    INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
    VALUES (
      v_guild.id, v_auth, 'clinic_donate_gold',
      jsonb_build_object('amount', v_g, 'vault_gold', v_vault_after)
    );
  END IF;

  INSERT INTO public.guild_contributions (
    guild_id, user_id, structural_donated, mystical_donated, critical_donated,
    gold_donated, contribution_score, last_donated_at
  )
  VALUES (
    v_guild.id, v_auth, v_s, v_m, v_c, v_g, v_contribution_score, now()
  )
  ON CONFLICT (guild_id, user_id) DO UPDATE SET
    structural_donated = public.guild_contributions.structural_donated + EXCLUDED.structural_donated,
    mystical_donated = public.guild_contributions.mystical_donated + EXCLUDED.mystical_donated,
    critical_donated = public.guild_contributions.critical_donated + EXCLUDED.critical_donated,
    gold_donated = public.guild_contributions.gold_donated + EXCLUDED.gold_donated,
    contribution_score = public.guild_contributions.contribution_score + EXCLUDED.contribution_score,
    last_donated_at = now();

  INSERT INTO public.guild_daily_donations (
    guild_id, user_id, donation_date,
    structural_today, mystical_today, critical_today, gold_today
  )
  VALUES (v_guild.id, v_auth, CURRENT_DATE, v_s, v_m, v_c, v_g)
  ON CONFLICT (guild_id, user_id, donation_date) DO UPDATE SET
    structural_today = public.guild_daily_donations.structural_today + EXCLUDED.structural_today,
    mystical_today = public.guild_daily_donations.mystical_today + EXCLUDED.mystical_today,
    critical_today = public.guild_daily_donations.critical_today + EXCLUDED.critical_today,
    gold_today = public.guild_daily_donations.gold_today + EXCLUDED.gold_today;

  RETURN jsonb_build_object(
    'success', true,
    'donated', jsonb_build_object(
      'structural', v_s, 'mystical', v_m, 'critical', v_c, 'gold', v_g
    ),
    'score_added', v_contribution_score,
    'vault_credited', v_g,
    'vault_gold', v_vault_after,
    'daily_limits', v_limits,
    'my_today', jsonb_build_object(
      'structural', v_today_s + v_s,
      'mystical', v_today_m + v_m,
      'critical', v_today_c + v_c,
      'gold', v_today_g + v_g
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.donate_to_clinic(integer, integer, integer, bigint) TO authenticated;

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
  v_structural_owned bigint := 0;
  v_mystical_owned bigint := 0;
  v_critical_owned bigint := 0;
  v_daily_limits jsonb := public._monument_daily_limits();
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

  SELECT COALESCE(SUM(quantity), 0)::bigint INTO v_structural_owned
  FROM public.inventory
  WHERE user_id = v_auth AND item_id = 'resource_structural';

  SELECT COALESCE(SUM(quantity), 0)::bigint INTO v_mystical_owned
  FROM public.inventory
  WHERE user_id = v_auth AND item_id = 'resource_mystical';

  SELECT COALESCE(SUM(quantity), 0)::bigint INTO v_critical_owned
  FROM public.inventory
  WHERE user_id = v_auth AND item_id = 'resource_critical';

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
    'daily_limits', v_daily_limits,
    'my_today', jsonb_build_object(
      'structural', COALESCE((
        SELECT structural_today FROM public.guild_daily_donations
        WHERE guild_id = v_user.guild_id AND user_id = v_auth
          AND donation_date = CURRENT_DATE
      ), 0),
      'mystical', COALESCE((
        SELECT mystical_today FROM public.guild_daily_donations
        WHERE guild_id = v_user.guild_id AND user_id = v_auth
          AND donation_date = CURRENT_DATE
      ), 0),
      'critical', COALESCE((
        SELECT critical_today FROM public.guild_daily_donations
        WHERE guild_id = v_user.guild_id AND user_id = v_auth
          AND donation_date = CURRENT_DATE
      ), 0),
      'gold', COALESCE((
        SELECT gold_today FROM public.guild_daily_donations
        WHERE guild_id = v_user.guild_id AND user_id = v_auth
          AND donation_date = CURRENT_DATE
      ), 0)
    ),
    'my_wallet', jsonb_build_object(
      'structural', v_structural_owned,
      'mystical', v_mystical_owned,
      'critical', v_critical_owned,
      'gold', COALESCE(v_user.gold, 0)
    ),
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

COMMIT;
