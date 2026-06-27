ALTER TABLE public.guilds
  ADD COLUMN IF NOT EXISTS min_join_power INT NOT NULL DEFAULT 0;

ALTER TABLE public.guilds
  DROP CONSTRAINT IF EXISTS guilds_min_join_power_nonneg;
ALTER TABLE public.guilds
  ADD CONSTRAINT guilds_min_join_power_nonneg CHECK (min_join_power >= 0);

CREATE OR REPLACE FUNCTION public.set_guild_min_join_power(p_min_power INT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_auth_id UUID;
  v_user    RECORD;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  IF p_min_power IS NULL OR p_min_power < 0 OR p_min_power > 100000000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz guc limiti (0-100.000.000)');
  END IF;

  SELECT guild_id, guild_role FROM public.users WHERE auth_id = v_auth_id INTO v_user;
  IF NOT FOUND OR v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bir loncaya uye degilsiniz');
  END IF;

  IF COALESCE(v_user.guild_role, '') <> 'leader' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lonca lideri guc limiti belirleyebilir');
  END IF;

  UPDATE public.guilds
  SET min_join_power = p_min_power
  WHERE id = v_user.guild_id;

  RETURN jsonb_build_object('success', true, 'min_join_power', p_min_power);
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.set_guild_min_join_power(INT) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_guild_info()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_auth_id  UUID;
  v_user     RECORD;
  v_guild    RECORD;
  v_members  JSONB;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT guild_id FROM public.users WHERE auth_id = v_auth_id INTO v_user;
  IF NOT FOUND OR v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Herhangi bir loncada degilsiniz');
  END IF;

  SELECT * FROM public.guilds WHERE id = v_user.guild_id INTO v_guild;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca bulunamadi');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'player_id', u.id,
      'user_id',   u.auth_id,
      'username',  u.username,
      'level',     u.level,
      'role',      u.guild_role,
      'power',     COALESCE(u.power, 0),
      'is_online', COALESCE(u.is_online, false)
    ) ORDER BY u.guild_role, u.level DESC
  )
  INTO v_members
  FROM public.users u
  WHERE u.guild_id = v_guild.id;

  RETURN jsonb_build_object(
    'success',             true,
    'guild_id',            v_guild.id,
    'name',                v_guild.name,
    'description',         v_guild.description,
    'level',               v_guild.level,
    'leader_id',           v_guild.leader_id,
    'monument_level',      v_guild.monument_level,
    'monument_structural', v_guild.monument_structural,
    'monument_mystical',   v_guild.monument_mystical,
    'monument_critical',   v_guild.monument_critical,
    'monument_gold_pool',  v_guild.monument_gold_pool,
    'min_join_power',      COALESCE(v_guild.min_join_power, 0),
    'members',             COALESCE(v_members, '[]'::jsonb),
    'member_count',        (SELECT COUNT(*) FROM public.users WHERE guild_id = v_guild.id),
    'max_members',         v_guild.max_members,
    'total_power',         (SELECT COALESCE(SUM(power), 0) FROM public.users WHERE guild_id = v_guild.id)
  );
END;
$fn$;

CREATE OR REPLACE FUNCTION public.join_guild(p_guild_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_auth_id UUID;
  v_user    RECORD;
  v_guild   RECORD;
  v_members BIGINT;
  v_power   INT;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT id, guild_id, power FROM public.users WHERE auth_id = v_auth_id INTO v_user;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanici bulunamadi');
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bir lonca uyesisiniz. Oncelikle loncayi terk edin');
  END IF;

  SELECT * FROM public.guilds WHERE id = p_guild_id INTO v_guild;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca bulunamadi');
  END IF;

  v_power := COALESCE(v_user.power, 0);
  IF COALESCE(v_guild.min_join_power, 0) > 0 AND v_power < v_guild.min_join_power THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Bu lonca en az %s guc gerektiriyor (sizin gucunuz: %s)', v_guild.min_join_power, v_power)
    );
  END IF;

  SELECT COUNT(*) INTO v_members FROM public.users WHERE guild_id = p_guild_id;
  IF v_members >= COALESCE(v_guild.max_members, 50) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca dolu (maks. 50 uye)');
  END IF;

  UPDATE public.users
  SET guild_id = p_guild_id,
      guild_role = 'member'
  WHERE auth_id = v_auth_id;

  INSERT INTO public.guild_contributions (guild_id, user_id)
  VALUES (p_guild_id, v_auth_id)
  ON CONFLICT (guild_id, user_id) DO NOTHING;

  PERFORM public.sync_guild_member_monument_stats(p_guild_id);

  RETURN jsonb_build_object(
    'success', true,
    'guild_id', p_guild_id,
    'name', v_guild.name,
    'role', 'member'
  );
END;
$fn$;

CREATE OR REPLACE FUNCTION public.search_guilds(p_query TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_results JSONB;
BEGIN
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
  WHERE g.name ILIKE '%' || p_query || '%'
  LIMIT 20;

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$fn$;

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
        'id',             g.id,
        'guild_id',       g.id,
        'name',           g.name,
        'level',          g.level,
        'description',    g.description,
        'member_count',   mc.cnt,
        'max_members',    COALESCE(g.max_members, 50),
        'total_power',    COALESCE(mc.total_pwr, 0),
        'monument_level', COALESCE(g.monument_level, 0),
        'min_join_power', COALESCE(g.min_join_power, 0)
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
