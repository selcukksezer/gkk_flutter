-- Fast garrison join: skip clash lock path, early already_here, lock_timeout.

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
  -- Fail fast on lock contention instead of client SocketException timeout.
  PERFORM set_config('lock_timeout', '2s', true);
  PERFORM set_config('statement_timeout', '8s', true);

  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok.');
  END IF;

  SELECT guild_id, COALESCE(power, 0)
  INTO v_guild_id, v_power
  FROM public.users WHERE auth_id = v_user;

  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  SELECT id, name, owner_guild_id, COALESCE(defense_power, 0) AS defense_power
  INTO v_terr
  FROM public.guild_war_territories
  WHERE id = p_territory_id;

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

  v_def_before := v_terr.defense_power;

  -- Already posted here: refresh defense (power may have changed), skip clash.
  IF v_already THEN
    v_def_after := public._guild_war_recompute_defense(p_territory_id);
    SELECT COUNT(*) INTO v_count
    FROM public.guild_war_garrison WHERE territory_id = p_territory_id;
    RETURN jsonb_build_object(
      'success', true,
      'already_here', true,
      'moved', false,
      'territory_id', p_territory_id,
      'territory_name', v_terr.name,
      'my_power', v_power,
      'defense_before', v_def_before,
      'defense_after', v_def_after,
      'defense_delta', v_def_after - v_def_before,
      'garrison_count', v_count,
      'message', 'Zaten bu bölgede nöbettesin. Gücün savunmaya sayılıyor: +' || v_power
    );
  END IF;

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

  IF v_moved AND v_old IS NOT NULL THEN
    PERFORM public._guild_war_recompute_defense(v_old);
  END IF;

  v_def_after := public._guild_war_recompute_defense(p_territory_id);

  SELECT COUNT(*) INTO v_count
  FROM public.guild_war_garrison WHERE territory_id = p_territory_id;

  -- Clash scoring is best-effort and must never block nöbet.
  -- Intentionally omitted here (live Clash hooks stay on attack/rally paths).

  RETURN jsonb_build_object(
    'success', true,
    'already_here', false,
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
      WHEN v_moved THEN 'Nöbet taşındı: ' || COALESCE(v_old_name, 'eski bölge') || ' → ' || v_terr.name
                        || '. Senin gücün +' || v_power || ' savunmaya eklendi.'
      ELSE 'Nöbete yazıldın. Senin gücün (+' || v_power || ') bu bölgenin savunmasına eklendi.'
    END
  );
EXCEPTION
  WHEN lock_not_available OR query_canceled THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Nöbet şu an meşgul (sunucu kilit). Birkaç saniye sonra tekrar dene.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.guild_war_garrison_join(uuid) TO authenticated;

COMMIT;
