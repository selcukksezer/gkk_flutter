-- Önerilen loncalar: yer açık, anıt/seviye/güce göre sıralı liste
CREATE OR REPLACE FUNCTION public.get_recommended_guilds(p_limit INT DEFAULT 15)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_results JSONB;
  v_limit INT;
BEGIN
  v_limit := GREATEST(1, LEAST(COALESCE(p_limit, 15), 30));

  SELECT jsonb_agg(row_data ORDER BY sort_key DESC)
  INTO v_results
  FROM (
    SELECT
      jsonb_build_object(
        'id', g.id,
        'guild_id', g.id,
        'name', g.name,
        'level', g.level,
        'description', g.description,
        'member_count', mc.cnt,
        'max_members', COALESCE(g.max_members, 50),
        'total_power', COALESCE(mc.total_pwr, 0),
        'monument_level', COALESCE(g.monument_level, 0)
      ) AS row_data,
      (
        COALESCE(g.monument_level, 0) * 1000000
        + COALESCE(g.level, 1) * 1000
        + COALESCE(mc.total_pwr, 0)
      )::bigint AS sort_key
    FROM public.guilds g
    JOIN LATERAL (
      SELECT
        COUNT(*)::INT AS cnt,
        COALESCE(SUM(u.power), 0)::BIGINT AS total_pwr
      FROM public.users u
      WHERE u.guild_id = g.id
    ) mc ON true
    WHERE mc.cnt < COALESCE(g.max_members, 50)
    ORDER BY sort_key DESC
    LIMIT v_limit
  ) ranked;

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.get_recommended_guilds(INT) TO authenticated;
