-- Display name scroll-only rename, ban status RPC, chat mute staff guard, guild war smoke.

BEGIN;

-- ---------------------------------------------------------------------------
-- Display name uniqueness (case-insensitive, like username)
-- ---------------------------------------------------------------------------
UPDATE public.users
SET display_name = NULL
WHERE btrim(COALESCE(display_name, '')) = '';

WITH ranked AS (
  SELECT
    auth_id,
    lower(btrim(display_name)) AS norm,
    row_number() OVER (
      PARTITION BY lower(btrim(display_name))
      ORDER BY created_at NULLS LAST, auth_id
    ) AS rn
  FROM public.users
  WHERE display_name IS NOT NULL AND btrim(display_name) <> ''
)
UPDATE public.users u
SET display_name = u.display_name || '_' || substr(u.auth_id::text, 1, 4)
FROM ranked r
WHERE u.auth_id = r.auth_id
  AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS users_display_name_lower_unique
  ON public.users (lower(btrim(display_name)))
  WHERE display_name IS NOT NULL AND btrim(display_name) <> '';

-- ---------------------------------------------------------------------------
-- Profile update: avatar only — display name via scroll only
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_user_profile(
  p_display_name TEXT DEFAULT NULL,
  p_avatar_url TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_display_name IS NOT NULL AND btrim(p_display_name) <> '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Görünen isim yalnızca mağazadan alınan İsim Değiştirme Kağıdı ile değiştirilir.'
    );
  END IF;

  UPDATE public.users
  SET avatar_url = COALESCE(p_avatar_url, avatar_url),
      updated_at = NOW()
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object('success', true, 'message', 'Profil güncellendi');
END;
$$;

-- ---------------------------------------------------------------------------
-- Name change scroll (gem shop consumable)
-- ---------------------------------------------------------------------------
INSERT INTO public.items (
  id, name, type, description, rarity,
  base_price, vendor_sell_price,
  is_tradeable, is_stackable, max_stack,
  shop_available, shop_currency, icon
) VALUES (
  'scroll_name_change',
  'İsim Değiştirme Kağıdı',
  'consumable',
  'Görünen ismini değiştirir. İsim benzersiz olmalıdır.',
  'epic',
  299, 0,
  false, true, 5,
  true, 'gems', '📜'
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  type = EXCLUDED.type,
  base_price = EXCLUDED.base_price,
  shop_available = EXCLUDED.shop_available,
  shop_currency = EXCLUDED.shop_currency,
  icon = EXCLUDED.icon;

CREATE OR REPLACE FUNCTION public.use_name_change_scroll(
  p_row_id UUID,
  p_new_display_name TEXT,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inv RECORD;
  v_clean TEXT;
  v_norm TEXT;
BEGIN
  IF p_user_id IS NULL OR p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz işlem');
  END IF;

  v_clean := btrim(COALESCE(p_new_display_name, ''));
  IF char_length(v_clean) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'İsim en az 3 karakter olmalı');
  END IF;
  IF char_length(v_clean) > 24 THEN
    RETURN jsonb_build_object('success', false, 'error', 'İsim en fazla 24 karakter olabilir');
  END IF;

  v_norm := lower(v_clean);

  IF EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_id <> p_user_id
      AND (
        lower(btrim(u.username)) = v_norm
        OR lower(btrim(COALESCE(u.display_name, ''))) = v_norm
      )
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu isim zaten kullanılıyor');
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = p_row_id
    AND user_id = p_user_id
    AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşya bulunamadı');
  END IF;

  IF v_inv.item_id <> 'scroll_name_change' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşya');
  END IF;

  IF NOT public._consume_inventory_row(p_row_id, p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşya tüketilemedi');
  END IF;

  UPDATE public.users
  SET display_name = v_clean,
      updated_at = NOW()
  WHERE auth_id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Görünen isim güncellendi',
    'display_name', v_clean
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.use_name_change_scroll(UUID, TEXT, UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Ban status for client gate (auto-expire timed bans)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_ban_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_u RECORD;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  UPDATE public.users
  SET is_banned = false,
      ban_reason = NULL,
      banned_until = NULL
  WHERE auth_id = v_user
    AND COALESCE(is_banned, false) = true
    AND banned_until IS NOT NULL
    AND banned_until <= now();

  SELECT is_banned, ban_reason, banned_until
  INTO v_u
  FROM public.users
  WHERE auth_id = v_user;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı.');
  END IF;

  IF COALESCE(v_u.is_banned, false) = true
     AND (v_u.banned_until IS NULL OR v_u.banned_until > now()) THEN
    RETURN jsonb_build_object(
      'success', true,
      'is_banned', true,
      'ban_reason', COALESCE(v_u.ban_reason, 'Hesabınız askıya alındı.'),
      'banned_until', v_u.banned_until
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'is_banned', false);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_ban_status() TO authenticated;

-- Patch staff ban: inbox notification
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
  v_body TEXT;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.ban');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_target_user_id IS NULL OR btrim(COALESCE(p_reason, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef ve sebep gerekli.');
  END IF;

  IF public.staff_is_admin(p_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin hesabı banlanamaz.');
  END IF;

  UPDATE public.users
  SET is_banned = true,
      ban_reason = left(p_reason, 500),
      banned_until = p_until
  WHERE auth_id = p_target_user_id;

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
    p_target_user_id,
    'account_ban',
    'Hesabınız askıya alındı',
    v_body,
    jsonb_build_object('reason', p_reason, 'banned_until', p_until)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'player.ban', 'ban_player', 'user', p_target_user_id::text,
    jsonb_build_object('reason', p_reason, 'until', p_until),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Oyuncu banlandı.');
END;
$$;

-- Chat mute: staff/admin/GM immune
CREATE OR REPLACE FUNCTION public.is_chat_mute_protected(p_user_id UUID)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.staff_is_admin(p_user_id)
      OR public.staff_active_assignment(p_user_id) IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION public.block_chat_user(p_blocked_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_blocked_user_id IS NULL OR p_blocked_user_id = v_user.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz kullanici');
  END IF;

  IF public.is_chat_mute_protected(p_blocked_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkili oyuncular susturulamaz.');
  END IF;

  INSERT INTO public.chat_blocks (blocker_user_id, blocked_user_id)
  VALUES (v_user.id, p_blocked_user_id)
  ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;

  PERFORM public.write_chat_audit(v_user.id, 'user_blocked', p_blocked_user_id, NULL, '{}'::jsonb);

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ---------------------------------------------------------------------------
-- Guild war economy smoke (QA mode)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qa_smoke_guild_war_economy()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_leader UUID := gen_random_uuid();
  v_member UUID := gen_random_uuid();
  v_guild_id UUID := gen_random_uuid();
  v_territory_id UUID;
  v_tournament_id UUID := gen_random_uuid();
  v_results jsonb := '[]'::jsonb;
  v_pending BIGINT;
  v_vault BIGINT;
  v_collect jsonb;
  v_dist jsonb;
  v_prize jsonb;
  v_member_gold BIGINT;
  v_ok boolean;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM public.guild_vault_ledger WHERE guild_id IN (
    SELECT id FROM public.guilds WHERE name = 'qa_gw_smoke_guild'
  );
  DELETE FROM public.guild_vault_items WHERE guild_id IN (
    SELECT id FROM public.guilds WHERE name = 'qa_gw_smoke_guild'
  );
  DELETE FROM public.guild_war_tournament_matches WHERE tournament_id IN (
    SELECT id FROM public.guild_war_tournaments WHERE name = 'QA GW Smoke Cup'
  );
  DELETE FROM public.guild_war_tournaments WHERE name = 'QA GW Smoke Cup';
  DELETE FROM public.users WHERE username LIKE 'qa_gw_smoke_%'
    OR email LIKE 'qa_gw_smoke_%@sim.local';
  DELETE FROM public.guilds WHERE name = 'qa_gw_smoke_guild';
  DELETE FROM auth.users WHERE email LIKE 'qa_gw_smoke_%@sim.local';

  INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES
    (v_leader, 'authenticated', 'authenticated', 'qa_gw_smoke_leader@sim.local', now(), now(), now(),
     jsonb_build_object('provider', 'email'), jsonb_build_object('username', 'qa_gw_smoke_leader')),
    (v_member, 'authenticated', 'authenticated', 'qa_gw_smoke_member@sim.local', now(), now(), now(),
     jsonb_build_object('provider', 'email'), jsonb_build_object('username', 'qa_gw_smoke_member'));

  INSERT INTO public.users (
    id, auth_id, username, email, display_name, level, gold, gems, energy, max_energy,
    attack, defense, health, max_health, power, created_at, updated_at
  ) VALUES
    (v_leader, v_leader, 'qa_gw_smoke_leader', 'qa_gw_smoke_leader@sim.local', 'QA Leader', 10, 0, 0, 100, 100, 20, 20, 100, 100, 100, now(), now()),
    (v_member, v_member, 'qa_gw_smoke_member', 'qa_gw_smoke_member@sim.local', 'QA Member', 10, 0, 0, 100, 100, 20, 20, 100, 100, 100, now(), now())
  ON CONFLICT (auth_id) DO UPDATE SET
    username = EXCLUDED.username,
    email = EXCLUDED.email,
    display_name = EXCLUDED.display_name,
    gold = EXCLUDED.gold,
    updated_at = now();

  INSERT INTO public.guilds (id, name, tag, leader_id, vault_gold, vault_gold_pending, vault_last_accrual_at, created_at, updated_at)
  VALUES (v_guild_id, 'qa_gw_smoke_guild', 'QGS', v_leader, 0, 0, now() - interval '25 hours', now(), now());

  UPDATE public.users SET guild_id = v_guild_id, guild_role = 'leader' WHERE auth_id = v_leader;
  UPDATE public.users SET guild_id = v_guild_id, guild_role = 'member' WHERE auth_id = v_member;

  SELECT id INTO v_territory_id
  FROM public.guild_war_territories
  WHERE owner_guild_id IS NULL
  LIMIT 1;

  IF v_territory_id IS NOT NULL THEN
    UPDATE public.guild_war_territories
    SET owner_guild_id = v_guild_id,
        trade_income = GREATEST(COALESCE(trade_income, 0), 24000)
    WHERE id = v_territory_id;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_leader::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

  v_pending := public._accrue_guild_vault(v_guild_id);
  v_ok := v_pending > 0;
  v_results := v_results || jsonb_build_object(
    'step', 'accrue_pending',
    'ok', v_ok,
    'pending', v_pending
  );

  v_collect := public.collect_guild_vault_rewards();
  v_ok := COALESCE((v_collect->>'success')::boolean, false);
  SELECT vault_gold INTO v_vault FROM public.guilds WHERE id = v_guild_id;
  v_results := v_results || jsonb_build_object(
    'step', 'collect_rewards',
    'ok', v_ok AND v_vault > 0,
    'vault_gold', v_vault,
    'collected', v_collect->>'collected'
  );

  v_dist := public.distribute_guild_vault_gold(jsonb_build_object('mode', 'equal', 'amount', LEAST(v_vault, 1000)));
  v_ok := COALESCE((v_dist->>'success')::boolean, false);
  SELECT gold INTO v_member_gold FROM public.users WHERE auth_id = v_member;
  v_results := v_results || jsonb_build_object(
    'step', 'distribute_equal',
    'ok', v_ok AND v_member_gold > 0,
    'member_gold', v_member_gold,
    'distributed', v_dist->>'distributed'
  );

  INSERT INTO public.guild_war_tournaments (
    id, name, status, start_at, end_at, prize_gold, winner_guild_id, prize_paid_at
  ) VALUES (
    v_tournament_id, 'QA GW Smoke Cup', 'completed',
    now() - interval '2 days', now() - interval '1 hour',
    50000, v_guild_id, NULL
  );

  v_prize := public.grant_guild_war_tournament_prize(v_tournament_id, v_guild_id);
  v_ok := COALESCE((v_prize->>'success')::boolean, false);
  SELECT vault_gold_pending INTO v_pending FROM public.guilds WHERE id = v_guild_id;
  v_results := v_results || jsonb_build_object(
    'step', 'tournament_prize',
    'ok', v_ok AND v_pending >= 50000,
    'pending_after_prize', v_pending
  );

  v_prize := public.grant_guild_war_tournament_prize(v_tournament_id, v_guild_id);
  v_ok := COALESCE((v_prize->>'already_paid')::boolean, false);
  v_results := v_results || jsonb_build_object(
    'step', 'tournament_prize_idempotent',
    'ok', v_ok,
    'already_paid', v_prize->>'already_paid'
  );

  RETURN jsonb_build_object(
    'success', NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_results) e
      WHERE COALESCE((e->>'ok')::boolean, false) = false
    ),
    'results', v_results
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.qa_smoke_guild_war_economy() TO authenticated;

COMMIT;
