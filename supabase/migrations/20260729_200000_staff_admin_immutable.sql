-- Admin accounts are immutable: no staff/GM action (ban, rename, mute, inventory, etc.).
-- Fixes is_chat_mute_protected when callers pass users.id instead of auth_id.

BEGIN;

CREATE OR REPLACE FUNCTION public.staff_resolve_auth_id(p_user_ref UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT u.auth_id
  FROM public.users u
  WHERE u.auth_id = p_user_ref OR u.id = p_user_ref
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.staff_is_protected_admin(p_user_ref UUID)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.staff_is_admin(public.staff_resolve_auth_id(p_user_ref));
$$;

CREATE OR REPLACE FUNCTION public.staff_require_mutable_player(p_user_ref UUID)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth UUID;
BEGIN
  v_auth := public.staff_resolve_auth_id(p_user_ref);
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  IF public.staff_is_admin(v_auth) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Admin hesabına staff işlemi uygulanamaz.');
  END IF;

  RETURN jsonb_build_object('ok', true, 'auth_id', v_auth);
END;
$$;

CREATE OR REPLACE FUNCTION public.is_chat_mute_protected(p_user_id UUID)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.staff_is_protected_admin(p_user_id)
      OR public.staff_active_assignment(public.staff_resolve_auth_id(p_user_id)) IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION public.staff_ban_player(
  p_target_user_id UUID,
  p_reason TEXT,
  p_until TIMESTAMPTZ DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_mutable JSONB;
  v_auth UUID;
  v_body TEXT;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.ban');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_target_user_id IS NULL OR btrim(COALESCE(p_reason, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef ve sebep gerekli.');
  END IF;

  v_mutable := public.staff_require_mutable_player(p_target_user_id);
  IF (v_mutable->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_mutable->>'error');
  END IF;
  v_auth := (v_mutable->>'auth_id')::uuid;

  UPDATE public.users
  SET is_banned = true,
      ban_reason = left(p_reason, 500),
      banned_until = p_until
  WHERE auth_id = v_auth;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  v_body := format('Sebep: %s', left(p_reason, 400));
  IF p_until IS NULL THEN
    v_body := v_body || E'\nSüre: Kalıcı';
  ELSE
    v_body := v_body || format(E'\nSüre: %s', to_char(p_until AT TIME ZONE 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'));
  END IF;

  PERFORM public._notify_player_inbox(
    v_auth,
    'account_ban',
    'Hesabınız askıya alındı',
    v_body,
    jsonb_build_object('reason', p_reason, 'banned_until', p_until)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'player.ban', 'ban_player', 'user', v_auth::text,
    jsonb_build_object('reason', p_reason, 'until', p_until),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Oyuncu banlandı.');
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
  v_mutable JSONB;
  v_auth UUID;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.unban');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  v_mutable := public.staff_require_mutable_player(p_target_user_id);
  IF (v_mutable->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_mutable->>'error');
  END IF;
  v_auth := (v_mutable->>'auth_id')::uuid;

  UPDATE public.users
  SET is_banned = false, ban_reason = NULL, banned_until = NULL
  WHERE auth_id = v_auth;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  PERFORM public._notify_player_staff_action(
    v_auth,
    'account_unban',
    'Hesap banı kaldırıldı',
    format('Not: %s', COALESCE(NULLIF(btrim(p_note), ''), 'Banınız kaldırıldı.')),
    jsonb_build_object('note', p_note)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'player.unban', 'unban_player', 'user', v_auth::text,
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
  v_mutable JSONB;
  v_auth UUID;
  v_name TEXT := btrim(COALESCE(p_display_name, ''));
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.rename');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  v_mutable := public.staff_require_mutable_player(p_target_user_id);
  IF (v_mutable->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_mutable->>'error');
  END IF;
  v_auth := (v_mutable->>'auth_id')::uuid;

  IF char_length(v_name) < 3 OR char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'İsim ve sebep gerekli.');
  END IF;

  UPDATE public.users SET display_name = left(v_name, 40) WHERE auth_id = v_auth;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  PERFORM public._notify_player_staff_action(
    v_auth,
    'staff_rename',
    'Görünen isminiz değiştirildi',
    format('Yeni isim: %s\nSebep: %s', left(v_name, 40), left(p_reason, 300)),
    jsonb_build_object('display_name', v_name, 'reason', p_reason)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'player.rename', 'rename_player', 'user', v_auth::text,
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
  v_mutable JSONB;
  v_auth UUID;
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

  v_mutable := public.staff_require_mutable_player(p_target_user_id);
  IF (v_mutable->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_mutable->>'error');
  END IF;
  v_auth := (v_mutable->>'auth_id')::uuid;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  IF lower(p_currency) = 'gold' THEN
    UPDATE public.users SET gold = COALESCE(gold, 0) + v_amt WHERE auth_id = v_auth;
  ELSE
    UPDATE public.users SET gems = COALESCE(gems, 0) + v_amt WHERE auth_id = v_auth;
  END IF;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  PERFORM public._notify_player_staff_action(
    v_auth,
    'staff_grant',
    CASE WHEN lower(p_currency) = 'gems' THEN 'Elmas eklendi' ELSE 'Altın eklendi' END,
    format('Miktar: %s\nSebep: %s', v_amt, left(p_reason, 300)),
    jsonb_build_object('currency', p_currency, 'amount', v_amt, 'reason', p_reason)
  );

  PERFORM public.staff_write_audit(
    v_actor, v_perm, 'grant_currency', 'user', v_auth::text,
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
  v_mutable JSONB;
  v_auth UUID;
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

  v_mutable := public.staff_require_mutable_player(p_target_user_id);
  IF (v_mutable->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_mutable->>'error');
  END IF;
  v_auth := (v_mutable->>'auth_id')::uuid;

  v_label := CASE p_restriction
    WHEN 'chat' THEN 'Chat susturma'
    WHEN 'hospital' THEN 'Hastane'
    WHEN 'prison' THEN 'Hapishane'
    WHEN 'trade' THEN 'Ticaret yasağı'
    ELSE p_restriction
  END;

  IF p_restriction = 'chat' THEN
    SELECT u.id INTO v_target_user FROM public.users u WHERE u.auth_id = v_auth;
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
    WHERE auth_id = v_auth;
  ELSIF p_restriction = 'prison' THEN
    UPDATE public.users SET prison_until = p_until, prison_reason = left(p_reason, 200)
    WHERE auth_id = v_auth;
  ELSIF p_restriction = 'trade' THEN
    UPDATE public.users SET trade_banned_until = p_until WHERE auth_id = v_auth;
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
    v_auth,
    'staff_restriction',
    v_label,
    v_body,
    jsonb_build_object('restriction', p_restriction, 'until', p_until, 'reason', p_reason)
  );

  PERFORM public.staff_write_audit(
    v_actor, v_perm, 'set_restriction', 'user', v_auth::text,
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
  v_mutable JSONB;
  v_auth UUID;
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

  v_mutable := public.staff_require_mutable_player(p_target_user_id);
  IF (v_mutable->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_mutable->>'error');
  END IF;
  v_auth := (v_mutable->>'auth_id')::uuid;

  v_label := CASE p_restriction
    WHEN 'chat' THEN 'Chat susturma'
    WHEN 'hospital' THEN 'Hastane'
    WHEN 'prison' THEN 'Hapishane'
    WHEN 'trade' THEN 'Ticaret yasağı'
    WHEN 'account_ban' THEN 'Hesap banı'
    ELSE p_restriction
  END;

  IF p_restriction = 'account_ban' THEN
    RETURN public.staff_unban_player(v_auth, COALESCE(p_note, 'Ban kaldırıldı'));
  ELSIF p_restriction = 'chat' THEN
    SELECT u.id INTO v_target_user FROM public.users u WHERE u.auth_id = v_auth;
    SELECT u.id INTO v_actor_user FROM public.users u WHERE u.auth_id = v_actor;
    UPDATE public.chat_bans
    SET revoked_at = now(), revoked_by_user_id = v_actor_user
    WHERE user_id = v_target_user
      AND revoked_at IS NULL
      AND expires_at > now();
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSIF p_restriction = 'hospital' THEN
    UPDATE public.users SET hospital_until = NULL, hospital_reason = NULL WHERE auth_id = v_auth;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSIF p_restriction = 'prison' THEN
    UPDATE public.users SET prison_until = NULL, prison_reason = NULL WHERE auth_id = v_auth;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSIF p_restriction = 'trade' THEN
    UPDATE public.users SET trade_banned_until = NULL WHERE auth_id = v_auth;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  END IF;

  PERFORM public._notify_player_staff_action(
    v_auth,
    'staff_restriction_lift',
    format('%s kaldırıldı', v_label),
    format('Not: %s', COALESCE(NULLIF(btrim(p_note), ''), 'Kısıtınız kaldırıldı.')),
    jsonb_build_object('restriction', p_restriction, 'note', p_note)
  );

  PERFORM public.staff_write_audit(
    v_actor, v_perm, 'clear_restriction', 'user', v_auth::text,
    jsonb_build_object('restriction', p_restriction, 'note', p_note, 'affected', v_count),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Kısıt kaldırıldı.');
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
  v_mutable JSONB;
  v_auth UUID;
  v_delta INT := COALESCE(p_quantity_delta, 0);
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.adjust_inventory');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  v_mutable := public.staff_require_mutable_player(p_target_user_id);
  IF (v_mutable->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_mutable->>'error');
  END IF;
  v_auth := (v_mutable->>'auth_id')::uuid;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  IF v_delta > 0 THEN
    IF NOT public.market_give_items(v_auth, p_item_id, v_delta, 0) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu.');
    END IF;
  ELSIF v_delta < 0 THEN
    UPDATE public.inventory
    SET quantity = quantity + v_delta
    WHERE user_id = v_auth
      AND item_id = p_item_id
      AND quantity + v_delta >= 0;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz miktar veya eşya yok.');
    END IF;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Miktar 0 olamaz.');
  END IF;

  PERFORM public._notify_player_staff_action(
    v_auth,
    'staff_inventory',
    'Envanteriniz düzenlendi',
    format('Eşya: %s\nDeğişim: %s\nSebep: %s', p_item_id, v_delta, left(p_reason, 300)),
    jsonb_build_object('item_id', p_item_id, 'delta', v_delta, 'reason', p_reason)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'player.adjust_inventory', 'adjust_inventory', 'user', v_auth::text,
    jsonb_build_object('item_id', p_item_id, 'delta', v_delta, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_remove_inventory_row(
  p_target_user_id UUID,
  p_row_id UUID,
  p_reason TEXT,
  p_force_equipped BOOLEAN DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_mutable JSONB;
  v_auth UUID;
  v_row RECORD;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.adjust_inventory');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  v_mutable := public.staff_require_mutable_player(p_target_user_id);
  IF (v_mutable->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_mutable->>'error');
  END IF;
  v_auth := (v_mutable->>'auth_id')::uuid;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  SELECT inv.row_id, inv.item_id, inv.quantity, inv.is_equipped, it.name
  INTO v_row
  FROM public.inventory inv
  LEFT JOIN public.items it ON it.id = inv.item_id
  WHERE inv.row_id = p_row_id
    AND inv.user_id = v_auth;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Envanter satırı bulunamadı.');
  END IF;

  IF COALESCE(v_row.is_equipped, false) AND NOT COALESCE(p_force_equipped, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşanılmış eşya — zorla silme onayı gerekli.');
  END IF;

  DELETE FROM public.inventory WHERE row_id = p_row_id AND user_id = v_auth;

  PERFORM public._notify_player_staff_action(
    v_auth,
    'staff_inventory',
    'Envanteriniz düzenlendi',
    format('Silindi: %s x%s\nSebep: %s', COALESCE(v_row.name, v_row.item_id), v_row.quantity, left(p_reason, 300)),
    jsonb_build_object('row_id', p_row_id, 'item_id', v_row.item_id, 'reason', p_reason)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'player.adjust_inventory', 'adjust_inventory', 'user', v_auth::text,
    jsonb_build_object('row_id', p_row_id, 'item_id', v_row.item_id, 'delta', -v_row.quantity, 'reason', p_reason, 'action', 'remove_row'),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_set_inventory_quantity(
  p_target_user_id UUID,
  p_item_id TEXT,
  p_quantity INT,
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
  v_mutable JSONB;
  v_auth UUID;
  v_target INT := GREATEST(COALESCE(p_quantity, 0), 0);
  v_current INT := 0;
  v_delta INT;
  v_stackable BOOLEAN;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.adjust_inventory');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  v_mutable := public.staff_require_mutable_player(p_target_user_id);
  IF (v_mutable->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_mutable->>'error');
  END IF;
  v_auth := (v_mutable->>'auth_id')::uuid;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.items WHERE id = p_item_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşya.');
  END IF;

  SELECT COALESCE(is_stackable, false) INTO v_stackable FROM public.items WHERE id = p_item_id;
  IF NOT v_stackable THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu eşya stack değil — satır sil/ekle kullanın.');
  END IF;

  SELECT COALESCE(SUM(quantity), 0)::int INTO v_current
  FROM public.inventory
  WHERE user_id = v_auth AND item_id = p_item_id AND COALESCE(is_equipped, false) = false;

  v_delta := v_target - v_current;
  IF v_delta = 0 THEN
    RETURN jsonb_build_object('success', true, 'message', 'Değişiklik yok.');
  END IF;

  RETURN public.staff_adjust_inventory(v_auth, p_item_id, v_delta, p_reason);
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_chat_message(
  p_message_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor public.users%ROWTYPE;
  v_message RECORD;
  v_notice TEXT;
BEGIN
  v_actor := public.get_current_chat_user();

  SELECT id, channel, guild_id, sender_user_id, deleted_at
  INTO v_message
  FROM public.chat_messages
  WHERE id = p_message_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj bulunamadi');
  END IF;

  IF v_message.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj zaten silinmis');
  END IF;

  IF public.staff_is_protected_admin(v_message.sender_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin mesajina mudahale edilemez.');
  END IF;

  IF NOT public.has_chat_permission(v_actor.id, 'delete', v_message.channel, v_message.guild_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu mesaji silme yetkiniz yok');
  END IF;

  v_notice := public.format_chat_deleted_notice(v_actor.id);

  UPDATE public.chat_messages
  SET deleted_at = now(),
      deleted_by_user_id = v_actor.id,
      deleted_reason = left(public.normalize_chat_content(COALESCE(p_reason, v_notice)), 200),
      content = left(public.normalize_chat_content(v_notice), 200),
      is_system = true
  WHERE id = p_message_id;

  PERFORM public.write_chat_audit(v_actor.id, 'message_deleted', v_message.sender_user_id, p_message_id, jsonb_build_object('reason', p_reason));

  RETURN jsonb_build_object('success', true, 'notice', v_notice);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_moderate_chat_message(
  p_message_id UUID,
  p_mute_minutes INTEGER DEFAULT NULL,
  p_reason TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_message RECORD;
  v_sender_auth UUID;
  v_sender_user UUID;
  v_actor_user UUID;
  v_delete JSONB;
  v_notice TEXT;
  v_reason TEXT := COALESCE(NULLIF(btrim(p_reason), ''), 'moderator_delete');
  v_until TIMESTAMPTZ;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum gerekli.');
  END IF;

  v_guard := public.staff_require_permission(v_actor, 'chat.delete_message');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  SELECT cm.id, cm.channel, cm.guild_id, cm.sender_user_id, cm.deleted_at, u.auth_id
  INTO v_message
  FROM public.chat_messages cm
  JOIN public.users u ON u.id = cm.sender_user_id
  WHERE cm.id = p_message_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj bulunamadi');
  END IF;

  IF v_message.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj zaten silinmis');
  END IF;

  IF public.staff_is_protected_admin(v_message.sender_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin mesajina mudahale edilemez.');
  END IF;

  v_delete := public.delete_chat_message(p_message_id, v_reason);
  IF (v_delete->>'success')::boolean IS NOT TRUE THEN
    RETURN v_delete;
  END IF;

  v_notice := v_delete->>'notice';

  IF p_mute_minutes IS NOT NULL AND p_mute_minutes > 0 THEN
    v_guard := public.staff_require_permission(v_actor, 'player.chat_mute');
    IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'success', true,
        'notice', v_notice,
        'message_id', p_message_id,
        'warning', 'Mesaj silindi ancak susturma yetkisi yok.'
      );
    END IF;

    v_sender_auth := v_message.auth_id;
    IF v_sender_auth IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Gonderici bulunamadi.');
    END IF;

    IF public.staff_is_protected_admin(v_sender_auth) THEN
      RETURN jsonb_build_object(
        'success', true,
        'notice', v_notice,
        'message_id', p_message_id,
        'warning', 'Yetkili oyuncu susturulamaz.'
      );
    END IF;

    v_until := now() + make_interval(mins => LEAST(p_mute_minutes, 525600));

    SELECT u.id INTO v_sender_user FROM public.users u WHERE u.auth_id = v_sender_auth;
    SELECT u.id INTO v_actor_user FROM public.users u WHERE u.auth_id = v_actor;

    IF v_sender_user IS NULL OR v_actor_user IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadi.');
    END IF;

    UPDATE public.chat_bans
    SET revoked_at = now(), revoked_by_user_id = v_actor_user
    WHERE user_id = v_sender_user
      AND revoked_at IS NULL
      AND expires_at > now()
      AND scope = 'global';

    INSERT INTO public.chat_bans (user_id, scope, channel, guild_id, reason, expires_at, created_by_user_id)
    VALUES (
      v_sender_user,
      'global',
      NULL,
      NULL,
      left(v_reason, 200),
      v_until,
      v_actor_user
    );

    PERFORM public.staff_write_audit(
      v_actor,
      'player.chat_mute',
      'chat_mute_with_delete',
      'user',
      v_sender_auth::text,
      jsonb_build_object('message_id', p_message_id, 'minutes', p_mute_minutes, 'reason', v_reason),
      jsonb_build_object('success', true)
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'notice', v_notice,
    'message_id', p_message_id,
    'muted_minutes', p_mute_minutes
  );
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
  v_auth UUID;
  v_active JSONB := '[]'::jsonb;
  v_history JSONB := '[]'::jsonb;
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'player.view_detail') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  v_auth := public.staff_resolve_auth_id(p_target_user_id);
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  SELECT u.*, g.name AS guild_name
  INTO v_u
  FROM public.users u
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE u.auth_id = v_auth;

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
      AND a.target_id = v_auth::text
    ORDER BY a.created_at DESC
    LIMIT 30
  ) sub;

  RETURN jsonb_build_object(
    'success', true,
    'is_protected_admin', public.staff_is_admin(v_auth),
    'active', v_active,
    'history', v_history
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_resolve_auth_id(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_is_protected_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_require_mutable_player(uuid) TO authenticated;

COMMIT;
