-- Smoke-test fixes: blueprint auto-complete, search empty guard, guild war season refresh

CREATE OR REPLACE FUNCTION public.sync_guild_blueprint_completion()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $fn$
BEGIN
  IF COALESCE(NEW.fragments, 0) >= COALESCE(NEW.fragments_required, 100) THEN
    NEW.is_complete := true;
    IF NEW.completed_at IS NULL THEN
      NEW.completed_at := now();
    END IF;
  ELSE
    NEW.is_complete := false;
    NEW.completed_at := NULL;
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_guild_blueprint_completion ON public.guild_blueprints;
CREATE TRIGGER trg_guild_blueprint_completion
  BEFORE INSERT OR UPDATE OF fragments, fragments_required
  ON public.guild_blueprints
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_guild_blueprint_completion();

UPDATE public.guild_blueprints
SET
  is_complete = true,
  completed_at = COALESCE(completed_at, now())
WHERE COALESCE(fragments, 0) >= COALESCE(fragments_required, 100)
  AND is_complete IS DISTINCT FROM true;

CREATE OR REPLACE FUNCTION public.search_guilds(p_query TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_results JSONB;
  v_query TEXT;
BEGIN
  v_query := trim(COALESCE(p_query, ''));
  IF v_query = '' THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id',             g.id,
      'guild_id',       g.id,
      'name',           g.name,
      'level',          g.level,
      'description',    g.description,
      'member_count',   (SELECT COUNT(*) FROM public.users WHERE guild_id = g.id),
      'max_members',    g.max_members,
      'total_power',    COALESCE((SELECT SUM(power) FROM public.users WHERE guild_id = g.id), 0),
      'monument_level', COALESCE(g.monument_level, 0),
      'min_join_power', COALESCE(g.min_join_power, 0)
    )
  )
  INTO v_results
  FROM public.guilds g
  WHERE g.name ILIKE '%' || v_query || '%'
  LIMIT 20;

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$fn$;

UPDATE public.guild_war_seasons
SET
  start_at = CASE WHEN end_at < now() THEN now() ELSE start_at END,
  end_at = GREATEST(end_at, now()) + interval '7 days',
  is_active = true
WHERE is_active = true;
