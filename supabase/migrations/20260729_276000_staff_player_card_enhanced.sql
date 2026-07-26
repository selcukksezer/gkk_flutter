-- Staff player card: full snapshot + stat adjust RPCs.

BEGIN;

INSERT INTO public.staff_permission_catalog (key, category, label_tr, description_tr, min_role, is_dangerous)
VALUES
  ('player.adjust_energy', 'player', 'Enerji düzenle', 'Enerji ver/eksilt', 'gm', true),
  ('player.adjust_xp', 'player', 'XP düzenle', 'XP ver/eksilt', 'gm', true),
  ('player.adjust_reputation', 'player', 'İtibar düzenle', 'İtibar ver/eksilt', 'gm', true),
  ('player.adjust_health', 'player', 'Can düzenle', 'Can ver/eksilt', 'gm', true)
ON CONFLICT (key) DO UPDATE SET
  label_tr = EXCLUDED.label_tr,
  description_tr = EXCLUDED.description_tr,
  min_role = EXCLUDED.min_role,
  is_dangerous = EXCLUDED.is_dangerous;

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
  v_chat_until TIMESTAMPTZ;
  v_inv_slots INT;
  v_inv_items INT;
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

  SELECT MAX(cb.expires_at) INTO v_chat_until
  FROM public.chat_bans cb
  WHERE cb.user_id = v_u.id
    AND cb.revoked_at IS NULL
    AND cb.expires_at > now();

  SELECT
    COUNT(*) FILTER (WHERE inv.is_equipped = false AND inv.quantity > 0),
    COUNT(*) FILTER (WHERE inv.quantity > 0)
  INTO v_inv_slots, v_inv_items
  FROM public.inventory inv
  WHERE inv.user_id = p_target_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'player', jsonb_build_object(
      'auth_id', v_u.auth_id,
      'username', v_u.username,
      'display_name', v_u.display_name,
      'email', v_u.email,
      'character_class', v_u.character_class,
      'level', v_u.level,
      'xp', COALESCE(v_u.xp, v_u.experience, 0),
      'gold', COALESCE(v_u.gold, 0),
      'gems', COALESCE(v_u.gems, 0),
      'energy', COALESCE(v_u.energy, 0),
      'max_energy', COALESCE(v_u.max_energy, 100),
      'health', COALESCE(v_u.health, 0),
      'max_health', COALESCE(v_u.max_health, 100),
      'attack', COALESCE(v_u.attack, 0),
      'defense', COALESCE(v_u.defense, 0),
      'power', COALESCE(v_u.power, 0),
      'luck', COALESCE(v_u.luck, 0),
      'stat_points', COALESCE(v_u.stat_points, 0),
      'reputation', COALESCE(v_u.reputation, 0),
      'pvp_rating', COALESCE(v_u.pvp_rating, 1000),
      'pvp_wins', COALESCE(v_u.pvp_wins, 0),
      'pvp_losses', COALESCE(v_u.pvp_losses, 0),
      'addiction_level', COALESCE(v_u.addiction_level, 0),
      'tolerance', COALESCE(v_u.tolerance, 0),
      'guild_id', v_u.guild_id,
      'guild_name', v_u.guild_name,
      'guild_role', v_u.guild_role,
      'is_online', COALESCE(v_u.is_online, false),
      'is_banned', COALESCE(v_u.is_banned, false),
      'ban_reason', v_u.ban_reason,
      'banned_until', v_u.banned_until,
      'in_hospital', COALESCE(v_u.in_hospital, false)
        OR (v_u.hospital_until IS NOT NULL AND v_u.hospital_until > now()),
      'hospital_until', v_u.hospital_until,
      'hospital_reason', v_u.hospital_reason,
      'in_prison', COALESCE(v_u.in_prison, false)
        OR (v_u.prison_until IS NOT NULL AND v_u.prison_until > now()),
      'prison_until', v_u.prison_until,
      'prison_reason', v_u.prison_reason,
      'trade_banned_until', v_u.trade_banned_until,
      'chat_muted_until', v_chat_until,
      'inventory_slots_used', COALESCE(v_inv_slots, 0),
      'inventory_item_rows', COALESCE(v_inv_items, 0),
      'inventory_capacity', 20,
      'last_login_at', v_u.last_login_at,
      'last_active_at', v_u.last_active_at,
      'created_at', v_u.created_at,
      'total_playtime_seconds', COALESCE(v_u.total_playtime_seconds, 0),
      'staff_badge', public.get_public_staff_badge(v_u.auth_id),
      'king_badge', public.get_public_king_badge(v_u.auth_id),
      'is_protected_admin', public.staff_is_admin(v_u.auth_id)
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_adjust_player_stat(
  p_target_user_id UUID,
  p_stat TEXT,
  p_delta INT,
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
  v_delta INT := COALESCE(p_delta, 0);
  v_before INT;
  v_after INT;
  v_max INT;
BEGIN
  IF v_delta = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Delta sıfır olamaz.');
  END IF;

  v_perm := CASE lower(btrim(COALESCE(p_stat, '')))
    WHEN 'energy' THEN 'player.adjust_energy'
    WHEN 'xp' THEN 'player.adjust_xp'
    WHEN 'reputation' THEN 'player.adjust_reputation'
    WHEN 'health' THEN 'player.adjust_health'
    ELSE NULL
  END;

  IF v_perm IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz stat.');
  END IF;

  IF (lower(p_stat) = 'energy' AND abs(v_delta) > 500)
     OR (lower(p_stat) = 'xp' AND abs(v_delta) > 100000)
     OR (lower(p_stat) = 'reputation' AND abs(v_delta) > 5000)
     OR (lower(p_stat) = 'health' AND abs(v_delta) > 50000) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Delta limiti aşıldı.');
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

  SELECT
    CASE lower(p_stat)
      WHEN 'energy' THEN COALESCE(energy, 0)
      WHEN 'xp' THEN COALESCE(xp, experience, 0)
      WHEN 'reputation' THEN COALESCE(reputation, 0)
      WHEN 'health' THEN COALESCE(health, 0)
    END,
    CASE lower(p_stat)
      WHEN 'energy' THEN COALESCE(max_energy, 100)
      WHEN 'health' THEN COALESCE(max_health, 100)
      ELSE NULL
    END
  INTO v_before, v_max
  FROM public.users
  WHERE auth_id = v_auth
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  v_after := v_before + v_delta;

  IF lower(p_stat) IN ('energy', 'health') THEN
    v_after := GREATEST(0, LEAST(v_after, COALESCE(v_max, v_before + abs(v_delta))));
  ELSE
    v_after := GREATEST(0, v_after);
  END IF;

  IF lower(p_stat) = 'energy' THEN
    UPDATE public.users SET energy = v_after WHERE auth_id = v_auth;
  ELSIF lower(p_stat) = 'xp' THEN
    UPDATE public.users SET xp = v_after, experience = v_after WHERE auth_id = v_auth;
  ELSIF lower(p_stat) = 'reputation' THEN
    UPDATE public.users SET reputation = v_after WHERE auth_id = v_auth;
  ELSE
    UPDATE public.users SET health = v_after WHERE auth_id = v_auth;
  END IF;

  PERFORM public._notify_player_staff_action(
    v_auth,
    'staff_adjust_stat',
    format('%s güncellendi', upper(p_stat)),
    format('Önce: %s → Sonra: %s\nSebep: %s', v_before, v_after, left(p_reason, 300)),
    jsonb_build_object('stat', p_stat, 'delta', v_delta, 'before', v_before, 'after', v_after)
  );

  PERFORM public.staff_write_audit(
    v_actor, v_perm, 'adjust_player_stat', 'user', v_auth::text,
    jsonb_build_object('stat', p_stat, 'delta', v_delta, 'before', v_before, 'after', v_after, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object(
    'success', true,
    'stat', p_stat,
    'before', v_before,
    'after', v_after
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_adjust_player_stat(uuid, text, int, text) TO authenticated;

COMMIT;
