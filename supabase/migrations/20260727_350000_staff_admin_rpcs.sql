-- Staff admin RPCs: player actions, tickets, bugs, GM management, audit.

BEGIN;

CREATE OR REPLACE FUNCTION public.staff_search_players(p_query TEXT, p_limit INT DEFAULT 20)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_q TEXT := lower(btrim(COALESCE(p_query, '')));
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'player.view_detail') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  IF char_length(v_q) < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'En az 2 karakter girin.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'auth_id', u.auth_id,
        'username', u.username,
        'display_name', u.display_name,
        'level', u.level,
        'is_banned', COALESCE(u.is_banned, false),
        'staff_badge', public.get_public_staff_badge(u.auth_id)
      ) ORDER BY u.username)
      FROM public.users u
      WHERE lower(u.username) LIKE v_q || '%'
         OR lower(COALESCE(u.display_name, '')) LIKE '%' || v_q || '%'
      LIMIT v_limit
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_get_player_detail(p_target_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_u RECORD;
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'player.view_detail') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  SELECT u.auth_id, u.username, u.display_name, u.level, u.gold, u.gems, u.energy,
         u.guild_id, u.is_banned, u.ban_reason, u.banned_until,
         u.hospital_until, u.prison_until, u.trade_banned_until,
         g.name AS guild_name
  INTO v_u
  FROM public.users u
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE u.auth_id = p_target_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'player', jsonb_build_object(
      'auth_id', v_u.auth_id,
      'username', v_u.username,
      'display_name', v_u.display_name,
      'level', v_u.level,
      'gold', v_u.gold,
      'gems', v_u.gems,
      'energy', v_u.energy,
      'guild_id', v_u.guild_id,
      'guild_name', v_u.guild_name,
      'is_banned', COALESCE(v_u.is_banned, false),
      'ban_reason', v_u.ban_reason,
      'banned_until', v_u.banned_until,
      'hospital_until', v_u.hospital_until,
      'prison_until', v_u.prison_until,
      'trade_banned_until', v_u.trade_banned_until,
      'staff_badge', public.get_public_staff_badge(v_u.auth_id)
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_rename_player(
  p_target_user_id UUID,
  p_display_name TEXT,
  p_reason TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_name TEXT := btrim(COALESCE(p_display_name, ''));
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.rename');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF char_length(v_name) < 3 OR char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'İsim ve sebep gerekli.');
  END IF;

  UPDATE public.users SET display_name = left(v_name, 40) WHERE auth_id = p_target_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'player.rename', 'rename_player', 'user', p_target_user_id::text,
    jsonb_build_object('display_name', v_name, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_grant_currency(
  p_target_user_id UUID,
  p_currency TEXT,
  p_amount BIGINT,
  p_reason TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_perm TEXT;
  v_amt BIGINT := GREATEST(COALESCE(p_amount, 0), 0);
  v_guard JSONB;
BEGIN
  IF p_currency = 'gems' THEN
    v_perm := 'player.grant_gems';
    IF v_amt > 5000 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Max 5000 elmas.');
    END IF;
  ELSIF p_currency = 'gold' THEN
    v_perm := 'player.grant_gold';
    IF v_amt > 1000000 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Max 1M altın.');
    END IF;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz para birimi.');
  END IF;

  v_guard := public.staff_require_permission(v_actor, v_perm);
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  IF p_currency = 'gems' THEN
    UPDATE public.users SET gems = COALESCE(gems, 0) + v_amt WHERE auth_id = p_target_user_id;
  ELSE
    UPDATE public.users SET gold = COALESCE(gold, 0) + v_amt WHERE auth_id = p_target_user_id;
  END IF;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, v_perm, 'grant_currency', 'user', p_target_user_id::text,
    jsonb_build_object('currency', p_currency, 'amount', v_amt, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_set_restriction(
  p_target_user_id UUID,
  p_restriction TEXT,
  p_until TIMESTAMPTZ,
  p_reason TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_perm TEXT;
  v_guard JSONB;
BEGIN
  v_perm := CASE p_restriction
    WHEN 'hospital' THEN 'player.restrict_hospital'
    WHEN 'prison' THEN 'player.restrict_prison'
    WHEN 'trade' THEN 'player.restrict_trade'
    WHEN 'chat' THEN 'player.chat_mute'
    ELSE NULL
  END;

  IF v_perm IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz kısıt.');
  END IF;

  v_guard := public.staff_require_permission(v_actor, v_perm);
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_restriction = 'chat' THEN
    PERFORM public.ban_chat_user(
      (SELECT u.id FROM public.users u WHERE u.auth_id = p_target_user_id),
      'global',
      GREATEST(1, (EXTRACT(EPOCH FROM (p_until - now())) / 60)::int),
      left(COALESCE(p_reason, 'Staff mute'), 200)
    );
  ELSIF p_restriction = 'hospital' THEN
    UPDATE public.users SET hospital_until = p_until, hospital_reason = left(p_reason, 200)
    WHERE auth_id = p_target_user_id;
  ELSIF p_restriction = 'prison' THEN
    UPDATE public.users SET prison_until = p_until, prison_reason = left(p_reason, 200)
    WHERE auth_id = p_target_user_id;
  ELSIF p_restriction = 'trade' THEN
    UPDATE public.users SET trade_banned_until = p_until WHERE auth_id = p_target_user_id;
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, v_perm, 'set_restriction', 'user', p_target_user_id::text,
    jsonb_build_object('restriction', p_restriction, 'until', p_until, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_tickets(p_status TEXT DEFAULT NULL, p_limit INT DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'ticket.view_all') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', t.id,
        'player_id', t.player_id,
        'username', u.username,
        'category', t.category,
        'subject', t.subject,
        'status', t.status,
        'created_at', t.created_at,
        'updated_at', t.updated_at
      ) ORDER BY t.updated_at DESC)
      FROM public.support_tickets t
      JOIN public.users u ON u.auth_id = t.player_id
      WHERE p_status IS NULL OR t.status = p_status
      LIMIT LEAST(GREATEST(p_limit, 1), 100)
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_reply_ticket(p_ticket_id UUID, p_body TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'ticket.reply');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.support_tickets WHERE id = p_ticket_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticket yok.');
  END IF;

  INSERT INTO public.support_ticket_messages (ticket_id, sender_id, is_staff, body)
  VALUES (p_ticket_id, v_actor, true, left(btrim(p_body), 4000));

  UPDATE public.support_tickets
  SET status = 'staff_reply', assigned_staff_id = v_actor, updated_at = now()
  WHERE id = p_ticket_id;

  PERFORM public.staff_write_audit(v_actor, 'ticket.reply', 'reply_ticket', 'ticket', p_ticket_id::text, '{}'::jsonb, '{"success":true}'::jsonb);

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_update_ticket_status(
  p_ticket_id UUID,
  p_status TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'ticket.close');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_status NOT IN ('open', 'staff_reply', 'waiting_player', 'resolved', 'closed', 'spam') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz durum.');
  END IF;

  UPDATE public.support_tickets
  SET status = p_status,
      updated_at = now(),
      closed_at = CASE WHEN p_status IN ('closed', 'spam', 'resolved') THEN now() ELSE closed_at END
  WHERE id = p_ticket_id;

  PERFORM public.staff_write_audit(
    v_actor, 'ticket.close', 'update_ticket_status', 'ticket', p_ticket_id::text,
    jsonb_build_object('status', p_status, 'note', p_note),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_bug_reports(p_status TEXT DEFAULT NULL, p_limit INT DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'bug.view') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', b.id,
        'player_id', b.player_id,
        'username', u.username,
        'category', b.category,
        'title', b.title,
        'status', b.status,
        'reward_gems_approved', b.reward_gems_approved,
        'created_at', b.created_at
      ) ORDER BY b.created_at DESC)
      FROM public.bug_reports b
      JOIN public.users u ON u.auth_id = b.player_id
      WHERE p_status IS NULL OR b.status = p_status
      LIMIT LEAST(GREATEST(p_limit, 1), 100)
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_update_bug_report(
  p_report_id UUID,
  p_status TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'bug.triage');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_status NOT IN ('submitted', 'triaged', 'needs_info', 'rejected', 'duplicate') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz durum (onay ayrı RPC).');
  END IF;

  UPDATE public.bug_reports
  SET status = p_status,
      review_note = COALESCE(NULLIF(left(btrim(COALESCE(p_note, '')), 500), ''), review_note),
      reviewed_by = v_actor,
      reviewed_at = now()
  WHERE id = p_report_id;

  PERFORM public.staff_write_audit(
    v_actor, 'bug.triage', 'update_bug', 'bug_report', p_report_id::text,
    jsonb_build_object('status', p_status),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_assign_gm(
  p_target_user_id UUID,
  p_permissions TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_sa_id UUID;
  v_perm TEXT;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'staff.manage_gm');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_target_user_id = v_actor THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinize GM atayamazsınız.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE auth_id = p_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  UPDATE public.staff_assignments
  SET revoked_at = now(), revoke_reason = 'replaced'
  WHERE user_id = p_target_user_id AND revoked_at IS NULL;

  INSERT INTO public.staff_assignments (user_id, role, display_badge, granted_by)
  VALUES (p_target_user_id, 'gm', 'gm', v_actor)
  RETURNING id INTO v_sa_id;

  DELETE FROM public.staff_permissions WHERE staff_assignment_id = v_sa_id;

  FOREACH v_perm IN ARRAY COALESCE(p_permissions, ARRAY[]::TEXT[])
  LOOP
    IF EXISTS (SELECT 1 FROM public.staff_permission_catalog WHERE key = v_perm AND min_role = 'gm') THEN
      INSERT INTO public.staff_permissions (staff_assignment_id, permission_key)
      VALUES (v_sa_id, v_perm)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  INSERT INTO public.staff_permissions (staff_assignment_id, permission_key)
  VALUES (v_sa_id, 'staff.view_hub')
  ON CONFLICT DO NOTHING;

  PERFORM public.staff_write_audit(
    v_actor, 'staff.manage_gm', 'assign_gm', 'user', p_target_user_id::text,
    jsonb_build_object('permissions', p_permissions),
    jsonb_build_object('assignment_id', v_sa_id)
  );

  RETURN jsonb_build_object('success', true, 'assignment_id', v_sa_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_revoke_gm(p_target_user_id UUID, p_reason TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'staff.manage_gm');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF public.staff_is_admin(p_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin rolü kaldırılamaz.');
  END IF;

  UPDATE public.staff_assignments
  SET revoked_at = now(), revoke_reason = left(COALESCE(p_reason, 'revoked'), 200)
  WHERE user_id = p_target_user_id AND revoked_at IS NULL;

  PERFORM public.staff_write_audit(
    v_actor, 'staff.manage_gm', 'revoke_gm', 'user', p_target_user_id::text,
    jsonb_build_object('reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_set_gm_permissions(
  p_target_user_id UUID,
  p_permissions TEXT[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_sa_id UUID;
  v_perm TEXT;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'staff.manage_gm');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF public.staff_is_admin(p_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin izinleri değiştirilemez.');
  END IF;

  SELECT id INTO v_sa_id
  FROM public.staff_assignments
  WHERE user_id = p_target_user_id AND revoked_at IS NULL AND role = 'gm'
  LIMIT 1;

  IF v_sa_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aktif GM ataması yok.');
  END IF;

  DELETE FROM public.staff_permissions WHERE staff_assignment_id = v_sa_id;

  FOREACH v_perm IN ARRAY COALESCE(p_permissions, ARRAY[]::TEXT[])
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.staff_permission_catalog
      WHERE key = v_perm AND min_role = 'gm'
    ) THEN
      INSERT INTO public.staff_permissions (staff_assignment_id, permission_key)
      VALUES (v_sa_id, v_perm)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  INSERT INTO public.staff_permissions (staff_assignment_id, permission_key)
  VALUES (v_sa_id, 'staff.view_hub')
  ON CONFLICT DO NOTHING;

  PERFORM public.staff_write_audit(
    v_actor, 'staff.manage_gm', 'set_permissions', 'user', p_target_user_id::text,
    jsonb_build_object('permissions', p_permissions),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_audit(p_limit INT DEFAULT 50, p_offset INT DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'staff.view_audit') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', a.id,
          'actor_user_id', a.actor_user_id,
          'actor_username', u.username,
          'permission_key', a.permission_key,
          'action', a.action,
          'target_type', a.target_type,
          'target_id', a.target_id,
          'payload', a.payload,
          'result', a.result,
          'created_at', a.created_at
        ) AS row
        FROM public.staff_audit_log a
        LEFT JOIN public.users u ON u.auth_id = a.actor_user_id
        ORDER BY a.created_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
        OFFSET GREATEST(p_offset, 0)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_get_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'staff.view_hub') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'open_tickets', (SELECT COUNT(*) FROM public.support_tickets WHERE status IN ('open', 'waiting_player')),
    'pending_bugs', (SELECT COUNT(*) FROM public.bug_reports WHERE status IN ('submitted', 'triaged', 'needs_info')),
    'recent_audit', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'action', a.action, 'created_at', a.created_at, 'target_type', a.target_type
      ) ORDER BY a.created_at DESC)
      FROM (SELECT * FROM public.staff_audit_log ORDER BY created_at DESC LIMIT 5) a
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_get_permission_catalog()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'success', true,
    'items', COALESCE(jsonb_agg(jsonb_build_object(
      'key', key,
      'category', category,
      'label_tr', label_tr,
      'description_tr', description_tr,
      'min_role', min_role::text,
      'is_dangerous', is_dangerous
    ) ORDER BY category, key), '[]'::jsonb)
  )
  FROM public.staff_permission_catalog
  WHERE public.staff_has_permission(auth.uid(), 'staff.manage_gm')
     OR public.staff_is_admin(auth.uid());
$$;

GRANT EXECUTE ON FUNCTION public.staff_search_players(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_get_player_detail(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_rename_player(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_grant_currency(uuid, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_set_restriction(uuid, text, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_list_tickets(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_reply_ticket(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_update_ticket_status(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_list_bug_reports(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_update_bug_report(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_assign_gm(uuid, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_revoke_gm(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_set_gm_permissions(uuid, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_list_audit(int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_get_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_get_permission_catalog() TO authenticated;

COMMIT;
