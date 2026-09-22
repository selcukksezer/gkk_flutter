-- Monument gold: no separate pool. Donate → vault only. Upgrade spend → vault only.
-- Progress UI uses vault_gold. Zero legacy monument_gold_pool (already mirrored into vault).

BEGIN;

-- Legacy mirror pool already counted into vault_gold on donate; do not fold again.
UPDATE public.guilds
SET monument_gold_pool = 0
WHERE COALESCE(monument_gold_pool, 0) <> 0;

CREATE OR REPLACE FUNCTION public.donate_to_monument(
  p_structural INT DEFAULT 0,
  p_mystical INT DEFAULT 0,
  p_critical INT DEFAULT 0,
  p_gold BIGINT DEFAULT 0
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_user RECORD;
  v_guild_id UUID;
  v_daily RECORD;
  v_contribution_score BIGINT;
  v_limits JSONB := public._monument_daily_limits();
  v_max_structural INT := COALESCE((v_limits->>'structural')::INT, 500);
  v_max_mystical INT := COALESCE((v_limits->>'mystical')::INT, 200);
  v_max_critical INT := COALESCE((v_limits->>'critical')::INT, 50);
  v_max_gold BIGINT := COALESCE((v_limits->>'gold')::BIGINT, 10000000);
  v_vault_after BIGINT := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz');
  END IF;
  v_guild_id := v_user.guild_id;

  SELECT * INTO v_daily
  FROM public.guild_daily_donations
  WHERE guild_id = v_guild_id AND user_id = v_user_id AND donation_date = CURRENT_DATE
  FOR UPDATE;

  IF FOUND THEN
    IF v_daily.structural_today + p_structural > v_max_structural OR
       v_daily.mystical_today + p_mystical > v_max_mystical OR
       v_daily.critical_today + p_critical > v_max_critical OR
       v_daily.gold_today + p_gold > v_max_gold THEN
      RETURN jsonb_build_object('success', false, 'error', 'Günlük bağış sınırını aştınız');
    END IF;
  ELSE
    IF p_structural > v_max_structural OR p_mystical > v_max_mystical OR p_critical > v_max_critical OR p_gold > v_max_gold THEN
      RETURN jsonb_build_object('success', false, 'error', 'Günlük bağış sınırını aştınız');
    END IF;
  END IF;

  IF p_gold > 0 AND v_user.gold < p_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli altınınız yok');
  END IF;

  IF p_structural > 0 AND NOT public._consume_inventory_item(v_user_id, 'resource_structural', p_structural) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli yapısal kaynağınız yok');
  END IF;

  IF p_mystical > 0 AND NOT public._consume_inventory_item(v_user_id, 'resource_mystical', p_mystical) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli mistik kaynağınız yok');
  END IF;

  IF p_critical > 0 AND NOT public._consume_inventory_item(v_user_id, 'resource_critical', p_critical) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli kritik kaynağınız yok');
  END IF;

  IF p_gold > 0 THEN
    UPDATE public.users SET gold = gold - p_gold WHERE auth_id = v_user_id AND gold >= p_gold;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yeterli altınınız yok');
    END IF;
  END IF;

  v_contribution_score := p_structural * 10 + p_mystical * 25 + p_critical * 100 + p_gold / 1000;

  -- Resources → monument stock. Gold → shared guild vault only (no separate pool).
  UPDATE public.guilds SET
    monument_structural = monument_structural + p_structural,
    monument_mystical = monument_mystical + p_mystical,
    monument_critical = monument_critical + p_critical,
    vault_gold = vault_gold + GREATEST(p_gold, 0),
    monument_gold_pool = 0
  WHERE id = v_guild_id
  RETURNING vault_gold INTO v_vault_after;

  IF p_gold > 0 THEN
    INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
    VALUES (
      v_guild_id, v_user_id, 'monument_gold_to_vault',
      jsonb_build_object('amount', p_gold, 'vault_gold', v_vault_after)
    );
  END IF;

  INSERT INTO public.guild_contributions (
    guild_id, user_id, structural_donated, mystical_donated, critical_donated,
    gold_donated, contribution_score, last_donated_at
  )
  VALUES (v_guild_id, v_user_id, p_structural, p_mystical, p_critical, p_gold, v_contribution_score, now())
  ON CONFLICT (guild_id, user_id) DO UPDATE SET
    structural_donated = public.guild_contributions.structural_donated + EXCLUDED.structural_donated,
    mystical_donated = public.guild_contributions.mystical_donated + EXCLUDED.mystical_donated,
    critical_donated = public.guild_contributions.critical_donated + EXCLUDED.critical_donated,
    gold_donated = public.guild_contributions.gold_donated + EXCLUDED.gold_donated,
    contribution_score = public.guild_contributions.contribution_score + EXCLUDED.contribution_score,
    last_donated_at = now();

  INSERT INTO public.guild_daily_donations (
    guild_id, user_id, donation_date, structural_today, mystical_today, critical_today, gold_today
  )
  VALUES (v_guild_id, v_user_id, CURRENT_DATE, p_structural, p_mystical, p_critical, p_gold)
  ON CONFLICT (guild_id, user_id, donation_date) DO UPDATE SET
    structural_today = public.guild_daily_donations.structural_today + EXCLUDED.structural_today,
    mystical_today = public.guild_daily_donations.mystical_today + EXCLUDED.mystical_today,
    critical_today = public.guild_daily_donations.critical_today + EXCLUDED.critical_today,
    gold_today = public.guild_daily_donations.gold_today + EXCLUDED.gold_today;

  RETURN jsonb_build_object(
    'success', true,
    'score_added', v_contribution_score,
    'vault_credited', GREATEST(p_gold, 0),
    'vault_gold', v_vault_after
  );
END;
$$;

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
  v_req_gold := CEIL(v_cost.gold * v_mult)::BIGINT;
  IF v_cost.blueprint_type IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.guild_blueprints
      WHERE guild_id = v_guild.id AND blueprint_type = v_cost.blueprint_type AND is_complete = true
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', v_cost.blueprint_type || ' blueprint tamamlanmali');
    END IF;
  END IF;

  v_available_gold := COALESCE(v_guild.vault_gold, 0);

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
    monument_100_first = CASE WHEN v_next_level = 100 AND NOT EXISTS (SELECT 1 FROM public.guilds WHERE monument_level >= 100 AND id != v_guild.id) THEN true ELSE monument_100_first END,
    monument_100_at = CASE WHEN v_next_level = 100 THEN now() ELSE monument_100_at END
  WHERE id = v_guild.id;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_guild.id, p_user_id, 'monument_upgrade_spend',
    jsonb_build_object(
      'amount', v_req_gold,
      'level', v_next_level
    )
  );

  INSERT INTO public.monument_upgrades (guild_id, from_level, to_level, structural_spent, mystical_spent, critical_spent, gold_spent, upgraded_by)
  VALUES (v_guild.id, v_guild.monument_level, v_next_level, v_req_structural, v_req_mystical, v_req_critical, v_req_gold, p_user_id);
  PERFORM public.sync_guild_member_monument_stats(v_guild.id);
  RETURN jsonb_build_object(
    'success', true,
    'new_level', v_next_level,
    'gold_from_vault', v_req_gold
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_monument_dashboard(p_guild_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_caller UUID := auth.uid();
  v_guild RECORD;
  v_member_count INT;
  v_contributors JSONB;
  v_blueprints JSONB;
  v_preview JSONB;
  v_user RECORD;
  v_structural_owned BIGINT := 0;
  v_mystical_owned BIGINT := 0;
  v_critical_owned BIGINT := 0;
  v_daily_limits JSONB := public._monument_daily_limits();
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum gerekli');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.users WHERE auth_id = v_caller AND guild_id = p_guild_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyeliği gerekli');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = p_guild_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca bulunamadı');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_caller;

  SELECT COALESCE(SUM(quantity), 0)::BIGINT INTO v_structural_owned
  FROM public.inventory
  WHERE user_id = v_caller AND item_id = 'resource_structural';

  SELECT COALESCE(SUM(quantity), 0)::BIGINT INTO v_mystical_owned
  FROM public.inventory
  WHERE user_id = v_caller AND item_id = 'resource_mystical';

  SELECT COALESCE(SUM(quantity), 0)::BIGINT INTO v_critical_owned
  FROM public.inventory
  WHERE user_id = v_caller AND item_id = 'resource_critical';

  SELECT COUNT(*)::INT INTO v_member_count FROM public.users WHERE guild_id = p_guild_id;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'user_id', ranked.user_id,
        'username', ranked.username,
        'contribution_score', ranked.contribution_score,
        'gold_donated', ranked.gold_donated
      )
      ORDER BY ranked.contribution_score DESC
    ),
    '[]'::jsonb
  )
  INTO v_contributors
  FROM (
    SELECT
      gc.user_id,
      COALESCE(u.username, 'Oyuncu') AS username,
      gc.contribution_score,
      gc.gold_donated
    FROM public.guild_contributions gc
    LEFT JOIN public.users u ON u.auth_id = gc.user_id
    WHERE gc.guild_id = p_guild_id
    ORDER BY gc.contribution_score DESC
    LIMIT 5
  ) ranked;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'blueprint_type', gb.blueprint_type,
        'fragments', gb.fragments,
        'fragments_required', gb.fragments_required,
        'is_complete', gb.is_complete
      )
      ORDER BY gb.blueprint_type
    ),
    '[]'::jsonb
  )
  INTO v_blueprints
  FROM public.guild_blueprints gb
  WHERE gb.guild_id = p_guild_id;

  v_preview := public.get_monument_upgrade_preview(p_guild_id);

  RETURN jsonb_build_object(
    'success', true,
    'guild', jsonb_build_object(
      'id', v_guild.id,
      'name', v_guild.name,
      'monument_level', v_guild.monument_level,
      'monument_structural', v_guild.monument_structural,
      'monument_mystical', v_guild.monument_mystical,
      'monument_critical', v_guild.monument_critical,
      'vault_gold', COALESCE(v_guild.vault_gold, 0),
      -- deprecated mirror; always 0 after vault-only gold
      'monument_gold_pool', 0
    ),
    'member_count', v_member_count,
    'contributors', v_contributors,
    'blueprints', v_blueprints,
    'next_cost', v_preview,
    'daily_limits', v_daily_limits,
    'my_totals', jsonb_build_object(
      'structural', COALESCE((SELECT structural_donated FROM public.guild_contributions WHERE guild_id = p_guild_id AND user_id = v_caller), 0),
      'mystical', COALESCE((SELECT mystical_donated FROM public.guild_contributions WHERE guild_id = p_guild_id AND user_id = v_caller), 0),
      'critical', COALESCE((SELECT critical_donated FROM public.guild_contributions WHERE guild_id = p_guild_id AND user_id = v_caller), 0),
      'gold', COALESCE((SELECT gold_donated FROM public.guild_contributions WHERE guild_id = p_guild_id AND user_id = v_caller), 0),
      'contribution_score', COALESCE((SELECT contribution_score FROM public.guild_contributions WHERE guild_id = p_guild_id AND user_id = v_caller), 0)
    ),
    'my_today', jsonb_build_object(
      'structural', COALESCE((SELECT structural_today FROM public.guild_daily_donations WHERE guild_id = p_guild_id AND user_id = v_caller AND donation_date = CURRENT_DATE), 0),
      'mystical', COALESCE((SELECT mystical_today FROM public.guild_daily_donations WHERE guild_id = p_guild_id AND user_id = v_caller AND donation_date = CURRENT_DATE), 0),
      'critical', COALESCE((SELECT critical_today FROM public.guild_daily_donations WHERE guild_id = p_guild_id AND user_id = v_caller AND donation_date = CURRENT_DATE), 0),
      'gold', COALESCE((SELECT gold_today FROM public.guild_daily_donations WHERE guild_id = p_guild_id AND user_id = v_caller AND donation_date = CURRENT_DATE), 0)
    ),
    'my_wallet', jsonb_build_object(
      'structural', v_structural_owned,
      'mystical', v_mystical_owned,
      'critical', v_critical_owned,
      'gold', COALESCE(v_user.gold, 0)
    )
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.donate_to_monument(INT, INT, INT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upgrade_monument(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_monument_dashboard(uuid) TO authenticated;

COMMIT;
