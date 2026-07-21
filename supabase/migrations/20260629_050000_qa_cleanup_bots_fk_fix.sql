-- qa_cleanup_bots: delete mekan PvP + related FK rows before auth.users

CREATE OR REPLACE FUNCTION public.qa_cleanup_bots()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp', 'auth'
AS $$
DECLARE
  v_deleted_users integer;
  v_bot_ids uuid[];
BEGIN
  PERFORM public.qa_assert_qa_mode();

  SELECT array_agg(auth_id) INTO v_bot_ids
  FROM public.users
  WHERE username LIKE 'qa_bot_%';

  IF v_bot_ids IS NULL OR array_length(v_bot_ids, 1) IS NULL THEN
    DELETE FROM public.guild_contributions WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %');
    DELETE FROM public.guild_activities WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %');
    DELETE FROM public.guild_blueprints WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %');
    DELETE FROM public.guild_daily_donations WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %');
    DELETE FROM public.guilds WHERE name LIKE 'QA Lonca %';
    DELETE FROM public.qa_bot_profiles;
    RETURN json_build_object('success', true, 'deleted_auth_users', 0);
  END IF;

  DELETE FROM public.market_orders WHERE seller_id = ANY(v_bot_ids);
  DELETE FROM public.pvp_matches
  WHERE attacker_id = ANY(v_bot_ids) OR defender_id = ANY(v_bot_ids);
  DELETE FROM public.mekan_pvp_matches
  WHERE attacker_id = ANY(v_bot_ids)
     OR defender_id = ANY(v_bot_ids);
  DELETE FROM public.dungeon_runs WHERE player_id = ANY(v_bot_ids);
  DELETE FROM public.inventory WHERE user_id = ANY(v_bot_ids);
  DELETE FROM public.facilities WHERE user_id = ANY(v_bot_ids);
  DELETE FROM public.mekans WHERE owner_id = ANY(v_bot_ids) OR name LIKE 'QA Mekan %';

  UPDATE public.users SET guild_id = NULL, guild_role = NULL
  WHERE auth_id = ANY(v_bot_ids);

  DELETE FROM public.guild_contributions
  WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %' OR leader_id = ANY(v_bot_ids));
  DELETE FROM public.guild_activities
  WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %' OR leader_id = ANY(v_bot_ids));
  DELETE FROM public.guild_blueprints
  WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %' OR leader_id = ANY(v_bot_ids));
  DELETE FROM public.guild_daily_donations
  WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %' OR leader_id = ANY(v_bot_ids));

  DELETE FROM public.guilds
  WHERE name LIKE 'QA Lonca %' OR leader_id = ANY(v_bot_ids);

  DELETE FROM auth.users au
  USING public.users u
  WHERE au.id = u.auth_id
    AND u.username LIKE 'qa_bot_%';

  GET DIAGNOSTICS v_deleted_users = ROW_COUNT;

  DELETE FROM public.users WHERE username LIKE 'qa_bot_%';
  DELETE FROM public.qa_bot_profiles;

  RETURN json_build_object('success', true, 'deleted_auth_users', v_deleted_users);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.qa_cleanup_bots() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_cleanup_bots() TO service_role;
