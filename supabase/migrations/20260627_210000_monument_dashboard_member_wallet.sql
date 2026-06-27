-- Extend monument dashboard with member wallet, totals, daily usage.

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
    'daily_limits', jsonb_build_object(
      'structural', 500,
      'mystical', 200,
      'critical', 50,
      'gold', 10000000
    ),
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

GRANT EXECUTE ON FUNCTION public.get_monument_dashboard(UUID) TO authenticated;
