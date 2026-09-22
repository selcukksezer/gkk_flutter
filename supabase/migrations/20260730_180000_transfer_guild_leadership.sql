-- Transfer guild leadership to another member (leader only).

BEGIN;

CREATE OR REPLACE FUNCTION public.transfer_guild_leadership(p_member_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth_id UUID := auth.uid();
  v_caller RECORD;
  v_member RECORD;
  v_guild_id UUID;
BEGIN
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik doğrulama gerekli');
  END IF;

  SELECT id, auth_id, guild_id, guild_role, username
  INTO v_caller
  FROM public.users
  WHERE auth_id = v_auth_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;

  IF v_caller.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bir loncada değilsiniz');
  END IF;

  IF COALESCE(v_caller.guild_role, '') <> 'leader' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lider liderliği devredebilir');
  END IF;

  v_guild_id := v_caller.guild_id;

  -- Lock guild row
  PERFORM 1 FROM public.guilds WHERE id = v_guild_id FOR UPDATE;

  IF NOT EXISTS (
    SELECT 1 FROM public.guilds g
    WHERE g.id = v_guild_id AND g.leader_id = v_auth_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca lider kaydı uyuşmuyor');
  END IF;

  SELECT id, auth_id, guild_id, guild_role, username
  INTO v_member
  FROM public.users
  WHERE id = p_member_id
  FOR UPDATE;

  IF NOT FOUND OR v_member.guild_id IS DISTINCT FROM v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef üye loncada değil');
  END IF;

  IF v_member.auth_id = v_auth_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinize liderlik devredemezsiniz');
  END IF;

  -- New leader
  UPDATE public.users
  SET guild_role = 'leader', updated_at = now()
  WHERE id = v_member.id;

  -- Old leader → officer (keeps some authority, can leave later)
  UPDATE public.users
  SET guild_role = 'officer', updated_at = now()
  WHERE id = v_caller.id;

  UPDATE public.guilds
  SET leader_id = v_member.auth_id
  WHERE id = v_guild_id;

  RETURN jsonb_build_object(
    'success', true,
    'new_leader_id', v_member.id,
    'new_leader_auth_id', v_member.auth_id,
    'new_leader_username', v_member.username,
    'previous_leader_role', 'officer'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.transfer_guild_leadership(UUID) TO authenticated;

COMMIT;
