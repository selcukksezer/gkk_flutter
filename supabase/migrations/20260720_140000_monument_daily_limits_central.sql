-- Single source for monument daily donation limits (dashboard + donate RPC).

CREATE OR REPLACE FUNCTION public._monument_daily_limits()
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'structural', 500,
    'mystical', 200,
    'critical', 50,
    'gold', 10000000
  );
$$;

CREATE OR REPLACE FUNCTION public.get_monument_dashboard(p_guild_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
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
      'monument_gold_pool', v_guild.monument_gold_pool
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
$$;

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

  UPDATE public.guilds SET
    monument_structural = monument_structural + p_structural,
    monument_mystical = monument_mystical + p_mystical,
    monument_critical = monument_critical + p_critical,
    monument_gold_pool = monument_gold_pool + p_gold
  WHERE id = v_guild_id;

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

  RETURN jsonb_build_object('success', true, 'score_added', v_contribution_score);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_monument_dashboard(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.donate_to_monument(INT, INT, INT, BIGINT) TO authenticated;
