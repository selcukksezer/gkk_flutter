-- Garrison UX + logic: move recompute old terr, rich status payload.

BEGIN;

CREATE OR REPLACE FUNCTION public.guild_war_garrison_join(p_territory_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_terr RECORD;
  v_old UUID;
  v_old_name TEXT;
  v_power INTEGER := 0;
  v_def_before INTEGER := 0;
  v_def_after INTEGER := 0;
  v_moved BOOLEAN := false;
  v_already BOOLEAN := false;
  v_count INTEGER := 0;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok.');
  END IF;

  SELECT guild_id, COALESCE(power, 0)
  INTO v_guild_id, v_power
  FROM public.users WHERE auth_id = v_user;

  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  SELECT * INTO v_terr FROM public.guild_war_territories WHERE id = p_territory_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;
  IF v_terr.owner_guild_id IS DISTINCT FROM v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece kendi bölgenize nöbet yazılabilir.');
  END IF;

  SELECT territory_id INTO v_old FROM public.guild_war_garrison WHERE user_id = v_user;
  IF v_old IS NOT NULL AND v_old = p_territory_id THEN
    v_already := true;
  ELSIF v_old IS NOT NULL AND v_old IS DISTINCT FROM p_territory_id THEN
    v_moved := true;
    SELECT name INTO v_old_name FROM public.guild_war_territories WHERE id = v_old;
  END IF;

  SELECT COALESCE(defense_power, 0) INTO v_def_before
  FROM public.guild_war_territories WHERE id = p_territory_id;

  INSERT INTO public.guild_war_garrison (user_id, guild_id, territory_id)
  VALUES (v_user, v_guild_id, p_territory_id)
  ON CONFLICT (user_id) DO UPDATE
    SET territory_id = EXCLUDED.territory_id,
        guild_id = EXCLUDED.guild_id,
        joined_at = CASE
          WHEN public.guild_war_garrison.territory_id IS DISTINCT FROM EXCLUDED.territory_id
            THEN now()
          ELSE public.guild_war_garrison.joined_at
        END;

  -- Recompute previous post when moving
  IF v_moved AND v_old IS NOT NULL THEN
    PERFORM public._guild_war_recompute_defense(v_old);
  END IF;

  v_def_after := public._guild_war_recompute_defense(p_territory_id);

  SELECT COUNT(*) INTO v_count
  FROM public.guild_war_garrison WHERE territory_id = p_territory_id;

  -- Live Clash contribution if any
  BEGIN
    PERFORM public._tournament_clash_add(m_id, v_guild_id, 'garrison', 3, v_user)
    FROM unnest(public._live_clash_match_ids_for_guild(v_guild_id)) AS m_id;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'already_here', v_already,
    'moved', v_moved,
    'from_territory_id', v_old,
    'from_territory_name', v_old_name,
    'territory_id', p_territory_id,
    'territory_name', v_terr.name,
    'my_power', v_power,
    'defense_before', v_def_before,
    'defense_after', v_def_after,
    'defense_delta', v_def_after - v_def_before,
    'garrison_count', v_count,
    'message', CASE
      WHEN v_already THEN 'Zaten bu bölgede nöbettesin. Gücün savunmaya sayılıyor: +' || v_power
      WHEN v_moved THEN 'Nöbet taşındı: ' || COALESCE(v_old_name, 'eski bölge') || ' → ' || v_terr.name
                        || '. Senin gücün +' || v_power || ' savunmaya eklendi.'
      ELSE 'Nöbete yazıldın. Senin gücün (+' || v_power || ') bu bölgenin savunmasına eklendi.'
    END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.guild_war_garrison_leave()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_terr UUID;
  v_name TEXT;
  v_power INTEGER := 0;
  v_def_before INTEGER := 0;
  v_def_after INTEGER := 0;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok.');
  END IF;

  SELECT g.territory_id, COALESCE(u.power, 0)
  INTO v_terr, v_power
  FROM public.guild_war_garrison g
  JOIN public.users u ON u.auth_id = g.user_id
  WHERE g.user_id = v_user;

  IF v_terr IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Nöbette değilsin.');
  END IF;

  SELECT name, COALESCE(defense_power, 0)
  INTO v_name, v_def_before
  FROM public.guild_war_territories WHERE id = v_terr;

  DELETE FROM public.guild_war_garrison WHERE user_id = v_user;
  v_def_after := public._guild_war_recompute_defense(v_terr);

  RETURN jsonb_build_object(
    'success', true,
    'territory_id', v_terr,
    'territory_name', v_name,
    'my_power', v_power,
    'defense_before', v_def_before,
    'defense_after', v_def_after,
    'defense_delta', v_def_after - v_def_before,
    'message', 'Nöbetten ayrıldın (' || COALESCE(v_name, 'bölge') || '). Savunmadan −' || v_power || ' düştü.'
  );
END;
$$;

DROP FUNCTION IF EXISTS public.get_territory_garrison(uuid);
CREATE OR REPLACE FUNCTION public.get_territory_garrison(p_territory_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_members jsonb;
  v_sum INTEGER := 0;
  v_count INTEGER := 0;
  v_i_here BOOLEAN := false;
  v_my_tid UUID;
  v_my_name TEXT;
  v_my_joined TIMESTAMPTZ;
  v_base INTEGER := 0;
  v_gem INTEGER := 0;
  v_line INTEGER := 0;
  v_effective INTEGER := 0;
BEGIN
  SELECT COALESCE(base_defense_power, 0), COALESCE(gem_defense_boost, 0),
         COALESCE(defense_line_level, 0)
  INTO v_base, v_gem, v_line
  FROM public.guild_war_territories WHERE id = p_territory_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'user_id', g.user_id,
    'username', u.username,
    'power', COALESCE(u.power, 0),
    'joined_at', g.joined_at,
    'is_me', g.user_id = v_uid
  ) ORDER BY COALESCE(u.power, 0) DESC), '[]'::jsonb)
  INTO v_members
  FROM public.guild_war_garrison g
  JOIN public.users u ON u.auth_id = g.user_id
  WHERE g.territory_id = p_territory_id;

  SELECT COALESCE(SUM(COALESCE(u.power, 0)), 0)::INTEGER, COUNT(*)::INTEGER
  INTO v_sum, v_count
  FROM public.guild_war_garrison g
  JOIN public.users u ON u.auth_id = g.user_id
  WHERE g.territory_id = p_territory_id;

  v_i_here := EXISTS (
    SELECT 1 FROM public.guild_war_garrison WHERE territory_id = p_territory_id AND user_id = v_uid
  );

  SELECT g.territory_id, t.name, g.joined_at
  INTO v_my_tid, v_my_name, v_my_joined
  FROM public.guild_war_garrison g
  JOIN public.guild_war_territories t ON t.id = g.territory_id
  WHERE g.user_id = v_uid
  LIMIT 1;

  v_effective := public.guild_war_territory_effective_defense(
    CASE WHEN v_count > 0 THEN v_sum ELSE v_base END,
    v_gem,
    v_line
  );

  RETURN jsonb_build_object(
    'success', true,
    'territory_id', p_territory_id,
    'members', v_members,
    'garrison_power', v_sum,
    'garrison_count', v_count,
    'base_defense_power', v_base,
    'gem_defense_boost', v_gem,
    'defense_line_level', v_line,
    'effective_defense', v_effective,
    'i_am_here', v_i_here,
    'my_post', CASE WHEN v_my_tid IS NULL THEN NULL ELSE jsonb_build_object(
      'territory_id', v_my_tid,
      'territory_name', v_my_name,
      'joined_at', v_my_joined
    ) END,
    'rules', jsonb_build_object(
      'one_post', true,
      'formula', 'effective = garrison_Σ_power + gem + line×200 (garnizon boşsa base)',
      'on_conquest', 'garnizon dağılır, gem sıfır, base kalır'
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_garrison_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_row RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'on_duty', false);
  END IF;

  SELECT g.territory_id, t.name AS territory_name, g.joined_at, COALESCE(u.power, 0) AS power
  INTO v_row
  FROM public.guild_war_garrison g
  JOIN public.guild_war_territories t ON t.id = g.territory_id
  JOIN public.users u ON u.auth_id = g.user_id
  WHERE g.user_id = v_uid
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', true, 'on_duty', false);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'on_duty', true,
    'territory_id', v_row.territory_id,
    'territory_name', v_row.territory_name,
    'joined_at', v_row.joined_at,
    'my_power', v_row.power
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.guild_war_garrison_join(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guild_war_garrison_leave() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_territory_garrison(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_garrison_status() TO authenticated;

COMMIT;
