-- Single round-trip dashboard for Lonca Anıtı screen.

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
    'next_cost', v_preview
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_monument_dashboard(UUID) TO authenticated;
