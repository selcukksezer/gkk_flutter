-- Fix policy RPC ambiguity, staff action notifications, lift restrictions, enforcement history.

BEGIN;

-- ── Policy: remove duplicate zero-arg overloads ─────────────────────────────
DROP FUNCTION IF EXISTS public.get_my_policy_status();
DROP FUNCTION IF EXISTS public.get_active_legal_documents();
DROP FUNCTION IF EXISTS public.accept_legal_document(text);
DROP FUNCTION IF EXISTS public.accept_all_legal_documents();

CREATE OR REPLACE FUNCTION public.policy_require_acceptance(p_user_id UUID DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status JSONB;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT public.get_my_policy_status(NULL) INTO v_status;
  IF COALESCE((v_status->>'all_accepted')::boolean, false) = false THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Devam etmek için Kullanım Koşulları, Gizlilik ve Topluluk Kurallarını kabul edin.',
      'missing', v_status->'missing'
    );
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_legal_document(p_doc_type TEXT, p_locale TEXT DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_locale TEXT := lower(COALESCE(NULLIF(btrim(p_locale), ''), 'tr'));
  v_version INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF p_doc_type NOT IN ('terms', 'privacy', 'community') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz belge türü.');
  END IF;

  SELECT version INTO v_version
  FROM public.legal_documents
  WHERE doc_type = p_doc_type AND is_active = true AND locale = v_locale
  LIMIT 1;

  IF v_version IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Belge bulunamadı.');
  END IF;

  INSERT INTO public.policy_acceptances (user_id, doc_type, version)
  VALUES (v_user, p_doc_type, v_version)
  ON CONFLICT (user_id, doc_type, version) DO NOTHING;

  RETURN jsonb_build_object('success', true, 'status', public.get_my_policy_status(v_locale));
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_all_legal_documents(p_locale TEXT DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_locale TEXT := lower(COALESCE(NULLIF(btrim(p_locale), ''), 'tr'));
  v_doc RECORD;
BEGIN
  FOR v_doc IN
    SELECT doc_type FROM public.legal_documents WHERE is_active = true AND locale = v_locale
  LOOP
    PERFORM public.accept_legal_document(v_doc.doc_type, v_locale);
  END LOOP;
  RETURN jsonb_build_object('success', true, 'status', public.get_my_policy_status(v_locale));
END;
$$;

-- ── Staff → player inbox notifications ────────────────────────────────────
CREATE OR REPLACE FUNCTION public._notify_player_staff_action(
  p_user_id UUID,
  p_kind TEXT,
  p_title TEXT,
  p_body TEXT,
  p_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;
  PERFORM public._notify_player_inbox(
    p_user_id,
    COALESCE(NULLIF(btrim(p_kind), ''), 'staff_action'),
    left(COALESCE(p_title, 'Moderasyon'), 200),
    left(COALESCE(p_body, ''), 1000),
    COALESCE(p_payload, '{}'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._format_until_tr(p_until TIMESTAMPTZ)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_until IS NULL THEN 'Kalıcı'
    ELSE to_char(p_until AT TIME ZONE 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI')
  END;
$$;

CREATE OR REPLACE FUNCTION public.staff_unban_player(p_target_user_id UUID, p_note TEXT DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.unban');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  UPDATE public.users
  SET is_banned = false, ban_reason = NULL, banned_until = NULL
  WHERE auth_id = p_target_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  PERFORM public._notify_player_staff_action(
    p_target_user_id,
    'account_unban',
    'Hesap banı kaldırıldı',
    format('Not: %s', COALESCE(NULLIF(btrim(p_note), ''), 'Banınız kaldırıldı.')),
    jsonb_build_object('note', p_note)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'player.unban', 'unban_player', 'user', p_target_user_id::text,
    jsonb_build_object('note', p_note),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Ban kaldırıldı.');
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

  PERFORM public._notify_player_staff_action(
    p_target_user_id,
    'staff_rename',
    'Görünen isminiz değiştirildi',
    format('Yeni isim: %s\nSebep: %s', left(v_name, 40), left(p_reason, 300)),
    jsonb_build_object('display_name', v_name, 'reason', p_reason)
  );

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
  v_guard JSONB;
  v_perm TEXT;
  v_amt BIGINT := GREATEST(COALESCE(p_amount, 0), 0);
BEGIN
  v_perm := CASE lower(COALESCE(p_currency, ''))
    WHEN 'gold' THEN 'player.grant_gold'
    WHEN 'gems' THEN 'player.grant_gems'
    ELSE NULL
  END;

  IF v_perm IS NULL OR v_amt <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz para birimi veya miktar.');
  END IF;

  v_guard := public.staff_require_permission(v_actor, v_perm);
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  IF lower(p_currency) = 'gold' THEN
    UPDATE public.users SET gold = COALESCE(gold, 0) + v_amt WHERE auth_id = p_target_user_id;
  ELSE
    UPDATE public.users SET gems = COALESCE(gems, 0) + v_amt WHERE auth_id = p_target_user_id;
  END IF;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  PERFORM public._notify_player_staff_action(
    p_target_user_id,
    'staff_grant',
    CASE WHEN lower(p_currency) = 'gems' THEN 'Elmas eklendi' ELSE 'Altın eklendi' END,
    format('Miktar: %s\nSebep: %s', v_amt, left(p_reason, 300)),
    jsonb_build_object('currency', p_currency, 'amount', v_amt, 'reason', p_reason)
  );

  PERFORM public.staff_write_audit(
    v_actor, v_perm, 'grant_currency', 'user', p_target_user_id::text,
    jsonb_build_object('currency', p_currency, 'amount', v_amt, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_adjust_inventory(
  p_target_user_id UUID,
  p_item_id TEXT,
  p_quantity_delta INT,
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
  v_delta INT := COALESCE(p_quantity_delta, 0);
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.adjust_inventory');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  IF v_delta > 0 THEN
    IF NOT public.market_give_items(p_target_user_id, p_item_id, v_delta, 0) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu.');
    END IF;
  ELSIF v_delta < 0 THEN
    UPDATE public.inventory
    SET quantity = quantity + v_delta
    WHERE user_id = p_target_user_id
      AND item_id = p_item_id
      AND quantity >= ABS(v_delta);
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yeterli item yok.');
    END IF;
    DELETE FROM public.inventory WHERE user_id = p_target_user_id AND item_id = p_item_id AND quantity <= 0;
  END IF;

  PERFORM public._notify_player_staff_action(
    p_target_user_id,
    'staff_inventory',
    'Envanteriniz düzenlendi',
    format('Item: %s\nDeğişim: %s\nSebep: %s', p_item_id, v_delta, left(p_reason, 300)),
    jsonb_build_object('item_id', p_item_id, 'delta', v_delta, 'reason', p_reason)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'player.adjust_inventory', 'adjust_inventory', 'user', p_target_user_id::text,
    jsonb_build_object('item_id', p_item_id, 'delta', v_delta, 'reason', p_reason),
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
  v_target_user UUID;
  v_actor_user UUID;
  v_label TEXT;
  v_body TEXT;
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

  IF p_until IS NULL OR p_until <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçerli bitiş zamanı gerekli.');
  END IF;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  IF public.staff_is_admin(p_target_user_id)
     OR public.staff_active_assignment(p_target_user_id) IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkili oyuncuya kısıt uygulanamaz.');
  END IF;

  v_label := CASE p_restriction
    WHEN 'chat' THEN 'Chat susturma'
    WHEN 'hospital' THEN 'Hastane'
    WHEN 'prison' THEN 'Hapishane'
    WHEN 'trade' THEN 'Ticaret yasağı'
    ELSE p_restriction
  END;

  IF p_restriction = 'chat' THEN
    SELECT u.id INTO v_target_user FROM public.users u WHERE u.auth_id = p_target_user_id;
    SELECT u.id INTO v_actor_user FROM public.users u WHERE u.auth_id = v_actor;
    IF v_target_user IS NULL OR v_actor_user IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
    END IF;

    UPDATE public.chat_bans
    SET revoked_at = now(), revoked_by_user_id = v_actor_user
    WHERE user_id = v_target_user
      AND revoked_at IS NULL
      AND expires_at > now()
      AND scope = 'global';

    INSERT INTO public.chat_bans (user_id, scope, channel, guild_id, reason, expires_at, created_by_user_id)
    VALUES (
      v_target_user,
      'global',
      NULL,
      NULL,
      left(COALESCE(p_reason, 'Staff mute'), 200),
      p_until,
      v_actor_user
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

  IF NOT FOUND AND p_restriction <> 'chat' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  v_body := format(
    '%s uygulandı.\nSebep: %s\nSüre: %s',
    v_label,
    left(p_reason, 300),
    public._format_until_tr(p_until)
  );

  PERFORM public._notify_player_staff_action(
    p_target_user_id,
    'staff_restriction',
    v_label,
    v_body,
    jsonb_build_object('restriction', p_restriction, 'until', p_until, 'reason', p_reason)
  );

  PERFORM public.staff_write_audit(
    v_actor, v_perm, 'set_restriction', 'user', p_target_user_id::text,
    jsonb_build_object('restriction', p_restriction, 'until', p_until, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Kısıt uygulandı.');
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_clear_restriction(
  p_target_user_id UUID,
  p_restriction TEXT,
  p_note TEXT DEFAULT NULL
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
  v_target_user UUID;
  v_actor_user UUID;
  v_label TEXT;
  v_count INT := 0;
BEGIN
  v_perm := CASE p_restriction
    WHEN 'hospital' THEN 'player.restrict_hospital'
    WHEN 'prison' THEN 'player.restrict_prison'
    WHEN 'trade' THEN 'player.restrict_trade'
    WHEN 'chat' THEN 'player.chat_mute'
    WHEN 'account_ban' THEN 'player.unban'
    ELSE NULL
  END;

  IF v_perm IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz kısıt.');
  END IF;

  v_guard := public.staff_require_permission(v_actor, v_perm);
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  v_label := CASE p_restriction
    WHEN 'chat' THEN 'Chat susturma'
    WHEN 'hospital' THEN 'Hastane'
    WHEN 'prison' THEN 'Hapishane'
    WHEN 'trade' THEN 'Ticaret yasağı'
    WHEN 'account_ban' THEN 'Hesap banı'
    ELSE p_restriction
  END;

  IF p_restriction = 'account_ban' THEN
    RETURN public.staff_unban_player(p_target_user_id, COALESCE(p_note, 'Ban kaldırıldı'));
  ELSIF p_restriction = 'chat' THEN
    SELECT u.id INTO v_target_user FROM public.users u WHERE u.auth_id = p_target_user_id;
    SELECT u.id INTO v_actor_user FROM public.users u WHERE u.auth_id = v_actor;
    UPDATE public.chat_bans
    SET revoked_at = now(), revoked_by_user_id = v_actor_user
    WHERE user_id = v_target_user
      AND revoked_at IS NULL
      AND expires_at > now();
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSIF p_restriction = 'hospital' THEN
    UPDATE public.users SET hospital_until = NULL, hospital_reason = NULL WHERE auth_id = p_target_user_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSIF p_restriction = 'prison' THEN
    UPDATE public.users SET prison_until = NULL, prison_reason = NULL WHERE auth_id = p_target_user_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSIF p_restriction = 'trade' THEN
    UPDATE public.users SET trade_banned_until = NULL WHERE auth_id = p_target_user_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  END IF;

  PERFORM public._notify_player_staff_action(
    p_target_user_id,
    'staff_restriction_lift',
    format('%s kaldırıldı', v_label),
    format('Not: %s', COALESCE(NULLIF(btrim(p_note), ''), 'Kısıtınız kaldırıldı.')),
    jsonb_build_object('restriction', p_restriction, 'note', p_note)
  );

  PERFORM public.staff_write_audit(
    v_actor, v_perm, 'clear_restriction', 'user', p_target_user_id::text,
    jsonb_build_object('restriction', p_restriction, 'note', p_note, 'affected', v_count),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Kısıt kaldırıldı.');
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_get_player_enforcement(p_target_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_u RECORD;
  v_target_internal UUID;
  v_active JSONB := '[]'::jsonb;
  v_history JSONB := '[]'::jsonb;
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'player.view_detail') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  SELECT u.*, g.name AS guild_name
  INTO v_u
  FROM public.users u
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE u.auth_id = p_target_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  v_target_internal := v_u.id;

  IF COALESCE(v_u.is_banned, false) = true
     AND (v_u.banned_until IS NULL OR v_u.banned_until > now()) THEN
    v_active := v_active || jsonb_build_array(jsonb_build_object(
      'key', 'account_ban',
      'label', 'Hesap banı',
      'until', v_u.banned_until,
      'reason', v_u.ban_reason
    ));
  END IF;

  IF v_u.hospital_until IS NOT NULL AND v_u.hospital_until > now() THEN
    v_active := v_active || jsonb_build_array(jsonb_build_object(
      'key', 'hospital',
      'label', 'Hastane',
      'until', v_u.hospital_until,
      'reason', v_u.hospital_reason
    ));
  END IF;

  IF v_u.prison_until IS NOT NULL AND v_u.prison_until > now() THEN
    v_active := v_active || jsonb_build_array(jsonb_build_object(
      'key', 'prison',
      'label', 'Hapishane',
      'until', v_u.prison_until,
      'reason', v_u.prison_reason
    ));
  END IF;

  IF v_u.trade_banned_until IS NOT NULL AND v_u.trade_banned_until > now() THEN
    v_active := v_active || jsonb_build_array(jsonb_build_object(
      'key', 'trade',
      'label', 'Ticaret yasağı',
      'until', v_u.trade_banned_until,
      'reason', NULL
    ));
  END IF;

  v_active := v_active || COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'key', 'chat',
      'label', 'Chat susturma',
      'until', cb.expires_at,
      'reason', cb.reason,
      'ban_id', cb.id
    ) ORDER BY cb.expires_at DESC)
    FROM public.chat_bans cb
    WHERE cb.user_id = v_target_internal
      AND cb.revoked_at IS NULL
      AND cb.expires_at > now()
  ), '[]'::jsonb);

  SELECT COALESCE(jsonb_agg(row ORDER BY row->>'created_at' DESC), '[]'::jsonb)
  INTO v_history
  FROM (
    SELECT jsonb_build_object(
      'id', a.id,
      'action', a.action,
      'permission_key', a.permission_key,
      'payload', a.payload,
      'created_at', a.created_at,
      'actor_username', au.username
    ) AS row
    FROM public.staff_audit_log a
    LEFT JOIN public.users au ON au.auth_id = a.actor_user_id
    WHERE a.target_type = 'user'
      AND a.target_id = p_target_user_id::text
    ORDER BY a.created_at DESC
    LIMIT 30
  ) sub;

  RETURN jsonb_build_object(
    'success', true,
    'active', v_active,
    'history', v_history
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_clear_restriction(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_get_player_enforcement(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_legal_document(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_all_legal_documents(text) TO authenticated;

COMMIT;
