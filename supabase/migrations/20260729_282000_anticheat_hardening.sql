-- Anti-cheat hardening: device session server gate, protected columns, kingdom RPC lockdown, tutorial forge block.

BEGIN;

-- ── Request headers (Supabase PostgREST) ─────────────────────────────────────

CREATE OR REPLACE FUNCTION public._request_header(p_name TEXT)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(
    btrim(
      COALESCE(
        current_setting('request.headers', true)::json ->> lower(p_name),
        current_setting('request.headers', true)::json ->> p_name
      )
    ),
    ''
  );
$$;

-- Returns {ok:true} or {ok:false, error, error_code}. NULL auth → error.
CREATE OR REPLACE FUNCTION public.assert_active_device_session()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth UUID := auth.uid();
  v_row public.users%ROWTYPE;
  v_header_device TEXT;
  v_header_epoch BIGINT;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Oturum bulunamadı.',
      'error_code', 'not_authenticated'
    );
  END IF;

  SELECT * INTO v_row FROM public.users WHERE auth_id = v_auth;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Kullanıcı bulunamadı.');
  END IF;

  IF v_row.active_device_id IS NULL OR COALESCE(v_row.session_epoch, 0) < 1 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Cihaz oturumu doğrulanmadı. Tekrar giriş yap.',
      'error_code', 'device_session_unclaimed'
    );
  END IF;

  v_header_device := public._request_header('x-gkk-device-id');
  v_header_epoch := NULLIF(public._request_header('x-gkk-session-epoch'), '')::BIGINT;

  IF v_header_device IS NULL OR v_header_epoch IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Cihaz doğrulama bilgisi eksik. Uygulamayı güncelleyip tekrar giriş yap.',
      'error_code', 'device_session_header_missing'
    );
  END IF;

  IF v_header_device <> v_row.active_device_id
     OR v_header_epoch <> COALESCE(v_row.session_epoch, 0) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Hesabın başka bir cihazda açıldı. Tekrar giriş yap.',
      'error_code', 'device_session_superseded'
    );
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.assert_active_device_session() TO authenticated;

-- Ban check + device session for acting player.
CREATE OR REPLACE FUNCTION public.assert_player_not_banned(p_user_id UUID DEFAULT auth.uid())
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_u RECORD;
  v_sess JSONB;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT is_banned, ban_reason, banned_until
  INTO v_u
  FROM public.users
  WHERE auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Kullanıcı bulunamadı.');
  END IF;

  IF COALESCE(v_u.is_banned, false) = true
     AND (v_u.banned_until IS NULL OR v_u.banned_until > now()) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', COALESCE(v_u.ban_reason, 'Hesabınız askıya alındı.'),
      'banned_until', v_u.banned_until
    );
  END IF;

  IF p_user_id = auth.uid() THEN
    v_sess := public.assert_active_device_session();
    IF COALESCE((v_sess->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN v_sess;
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_player_combat_ready(
  p_user_id UUID,
  p_as_target BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_hospital TIMESTAMPTZ;
  v_prison TIMESTAMPTZ;
  v_ban JSONB;
  v_sess JSONB;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Oturum bulunamadı.',
      'error_code', 'not_authenticated'
    );
  END IF;

  v_ban := public.assert_player_not_banned(p_user_id);
  IF COALESCE((v_ban->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', v_ban->>'error',
      'error_code', COALESCE(v_ban->>'error_code', 'account_banned')
    );
  END IF;

  IF NOT p_as_target AND p_user_id = auth.uid() THEN
    v_sess := public.assert_active_device_session();
    IF COALESCE((v_sess->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', v_sess->>'error',
        'error_code', COALESCE(v_sess->>'error_code', 'device_session_superseded')
      );
    END IF;
  END IF;

  SELECT u.hospital_until, u.prison_until
  INTO v_hospital, v_prison
  FROM public.users u
  WHERE u.auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE WHEN p_as_target THEN 'Rakip bulunamadı.' ELSE 'Oyuncu bulunamadı.' END,
      'error_code', 'player_not_found'
    );
  END IF;

  IF v_hospital IS NOT NULL AND v_hospital > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN p_as_target THEN 'Rakip hastanede.'
        ELSE 'Hastanedesiniz.'
      END,
      'error_code', 'hospital'
    );
  END IF;

  IF v_prison IS NOT NULL AND v_prison > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN p_as_target THEN 'Rakip hapishanede.'
        ELSE 'Hapishanedesiniz.'
      END,
      'error_code', 'prison'
    );
  END IF;

  RETURN NULL;
END;
$$;

-- Block direct client PATCH of session columns (same pattern as currency trigger).
CREATE OR REPLACE FUNCTION public.enforce_users_session_via_rpc_only()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND (
       NEW.active_device_id IS DISTINCT FROM OLD.active_device_id
       OR NEW.session_epoch IS DISTINCT FROM OLD.session_epoch
     )
     AND current_user IN ('authenticated', 'anon') THEN
    RAISE EXCEPTION 'Direct session updates are not allowed'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_session_rpc_only ON public.users;
CREATE TRIGGER trg_users_session_rpc_only
  BEFORE UPDATE OF active_device_id, session_epoch ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_users_session_via_rpc_only();

-- Kingdom election: internal only (get_current_election still finalizes via SECURITY DEFINER).
REVOKE EXECUTE ON FUNCTION public.finalize_kingdom_election(UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.start_kingdom_election(TIMESTAMPTZ, DATE, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.ensure_monthly_kingdom_election() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_kingdom_election(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.start_kingdom_election(TIMESTAMPTZ, DATE, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION public.ensure_monthly_kingdom_election() TO service_role;

REVOKE EXECUTE ON FUNCTION public._ensure_guild_war_rankings(UUID) FROM PUBLIC, anon, authenticated;

-- Tutorial: ignore client-forged skip/complete flags; only merge progress blobs.
CREATE OR REPLACE FUNCTION public.sync_tutorial_progress(p_progress JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_existing JSONB;
  v_merged JSONB;
  v_completed BOOLEAN := false;
  v_tracks JSONB;
  v_steps JSONB;
  v_key TEXT;
  v_local_steps JSONB;
  v_remote_steps JSONB;
  v_incoming JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_incoming := COALESCE(p_progress, '{}'::jsonb)
    - 'skipped_all'
    - 'core_completed'
    - 'hard_reset';

  SELECT COALESCE(tutorial_progress, '{}'::jsonb)
  INTO v_existing
  FROM public.users
  WHERE auth_id = v_user_id;

  v_merged := COALESCE(v_existing, '{}'::jsonb) || v_incoming;

  SELECT COALESCE(jsonb_agg(DISTINCT t), '[]'::jsonb)
  INTO v_tracks
  FROM (
    SELECT jsonb_array_elements_text(COALESCE(v_existing->'completed_tracks', '[]'::jsonb)) AS t
    UNION
    SELECT jsonb_array_elements_text(COALESCE(v_incoming->'completed_tracks', '[]'::jsonb)) AS t
  ) u;

  v_merged := jsonb_set(v_merged, '{completed_tracks}', COALESCE(v_tracks, '[]'::jsonb));
  v_merged := jsonb_set(v_merged, '{skipped_all}', 'false'::jsonb);
  v_merged := jsonb_set(v_merged, '{core_completed}', 'false'::jsonb);

  v_steps := COALESCE(v_existing->'steps', '{}'::jsonb);
  v_remote_steps := COALESCE(v_incoming->'steps', '{}'::jsonb);
  FOR v_key IN
    SELECT DISTINCT k FROM (
      SELECT jsonb_object_keys(v_steps) AS k
      UNION
      SELECT jsonb_object_keys(v_remote_steps) AS k
    ) keys
  LOOP
    SELECT COALESCE(jsonb_agg(DISTINCT s), '[]'::jsonb)
    INTO v_local_steps
    FROM (
      SELECT jsonb_array_elements_text(COALESCE(v_steps->v_key, '[]'::jsonb)) AS s
      UNION
      SELECT jsonb_array_elements_text(COALESCE(v_remote_steps->v_key, '[]'::jsonb)) AS s
    ) step_union;
    v_steps := jsonb_set(v_steps, ARRAY[v_key], COALESCE(v_local_steps, '[]'::jsonb));
  END LOOP;
  v_merged := jsonb_set(v_merged, '{steps}', COALESCE(v_steps, '{}'::jsonb));

  SELECT COALESCE(tutorial_completed, false)
  INTO v_completed
  FROM public.users
  WHERE auth_id = v_user_id;

  UPDATE public.users
  SET tutorial_progress = v_merged,
      updated_at = now()
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'tutorial_progress', v_merged,
    'tutorial_completed', v_completed
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_tutorial_progress(JSONB) TO authenticated;

-- Economy RPCs: require ban + device session (assert_player_not_banned).
CREATE OR REPLACE FUNCTION public.claim_daily_reward()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user_id UUID;
  v_acct JSONB;
  v_today DATE;
  v_player RECORD;
  v_state RECORD;
  v_config public.daily_reward_config%ROWTYPE;
  v_grant JSONB;
  v_gold INTEGER;
  v_gems INTEGER;
  v_xp INTEGER;
  v_energy INTEGER;
  v_new_streak INTEGER;
  v_add_result JSONB;
  v_rewards_granted JSONB;
  v_item_id TEXT;
  v_item_qty INTEGER;
  v_item_granted BOOLEAN := false;
  v_item_skipped BOOLEAN := false;
  v_warning TEXT := NULL;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_acct := public.assert_player_not_banned(v_user_id);
  IF COALESCE((v_acct->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_acct->>'error');
  END IF;

  v_today := (now() AT TIME ZONE 'UTC')::date;

  SELECT * INTO v_player
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı profili bulunamadı.');
  END IF;

  IF v_player.hospital_until IS NOT NULL AND v_player.hospital_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastanedeyken günlük ödül alınamaz.');
  END IF;

  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hapishanedeyken günlük ödül alınamaz.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.daily_reward_claims
    WHERE user_id = v_user_id AND claim_date = v_today
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bugünkü ödül zaten alındı.');
  END IF;

  SELECT * INTO v_state
  FROM public.daily_reward_resolve_state(v_user_id, v_today);

  IF NOT v_state.can_claim THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül alınamaz durumda.');
  END IF;

  SELECT * INTO v_config
  FROM public.daily_reward_config
  WHERE cycle_day = v_state.next_cycle_day;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül konfigürasyonu bulunamadı.');
  END IF;

  v_grant := public.daily_reward_build_grant(v_state.next_cycle_day, v_player.level);
  v_gold := COALESCE((v_grant->>'gold')::INTEGER, 0);
  v_gems := COALESCE((v_grant->>'gems')::INTEGER, 0);
  v_xp := COALESCE((v_grant->>'xp')::INTEGER, 0);
  v_energy := COALESCE((v_grant->>'energy')::INTEGER, 0);

  v_item_id := NULLIF(BTRIM(COALESCE(v_config.item_id, '')), '');
  v_item_qty := COALESCE(v_config.item_quantity, 0);
  IF v_item_id IS NULL OR v_item_qty <= 0 THEN
    v_item_id := NULL;
    v_item_qty := 0;
  END IF;

  v_new_streak := CASE
    WHEN v_state.next_cycle_day = 1 AND (v_state.streak_length = 0) THEN 1
    ELSE v_state.streak_length + 1
  END;

  UPDATE public.users
  SET
    gold = COALESCE(gold, 0) + v_gold,
    gems = COALESCE(gems, 0) + v_gems,
    xp = COALESCE(xp, 0) + v_xp,
    energy = CASE
      WHEN v_energy > 0 THEN LEAST(COALESCE(max_energy, 100), COALESCE(energy, 0) + v_energy)
      ELSE energy
    END,
    updated_at = now()
  WHERE auth_id = v_user_id;

  IF v_item_id IS NOT NULL AND v_item_qty > 0 THEN
    v_add_result := public.add_inventory_item_v2(
      jsonb_build_object(
        'item_id', v_item_id,
        'quantity', v_item_qty,
        'allow_stack', true
      ),
      NULL
    );

    IF COALESCE((v_add_result->>'success')::BOOLEAN, FALSE) THEN
      v_item_granted := true;
    ELSE
      v_item_skipped := true;
      v_warning := 'Envanter dolu — eşya verilemedi. Altın/elmas/XP alındı; yer açıp bir sonraki ödülü kaçırma.';
    END IF;
  END IF;

  v_rewards_granted := v_grant;
  IF v_item_skipped THEN
    v_rewards_granted := v_rewards_granted
      || jsonb_build_object(
        'item_id', NULL,
        'item_name', NULL,
        'item_quantity', 0,
        'item_skipped', true,
        'item_skip_reason', COALESCE(v_add_result->>'error', 'Envanter dolu')
      );
  ELSIF v_item_id IS NULL THEN
    v_rewards_granted := v_rewards_granted
      || jsonb_build_object('item_id', NULL, 'item_name', NULL, 'item_quantity', 0);
  END IF;

  INSERT INTO public.daily_reward_claims (
    user_id, claim_date, cycle_day, streak_length, rewards_granted
  ) VALUES (
    v_user_id, v_today, v_state.next_cycle_day, v_new_streak, v_rewards_granted
  );

  SELECT gold, gems, xp, energy
  INTO v_player.gold, v_player.gems, v_player.xp, v_player.energy
  FROM public.users
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE
      WHEN v_item_skipped THEN v_warning
      ELSE 'Günlük ödül alındı!'
    END,
    'cycle_day', v_state.next_cycle_day,
    'streak_length', v_new_streak,
    'rewards_granted', v_rewards_granted,
    'item_granted', v_item_granted,
    'item_skipped', v_item_skipped,
    'warning', v_warning,
    'new_balances', jsonb_build_object(
      'gold', v_player.gold,
      'gems', v_player.gems,
      'xp', v_player.xp,
      'energy', v_player.energy
    )
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bugünkü ödül zaten alındı.');
END;
$$;

CREATE OR REPLACE FUNCTION public.exchange_gems_for_gold(p_gems INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_auth_id UUID;
  v_acct JSONB;
  v_gold BIGINT;
  v_gems INTEGER;
  v_current_gems NUMERIC;
  v_current_gold BIGINT;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_acct := public.assert_player_not_banned(v_auth_id);
  IF COALESCE((v_acct->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_acct->>'error');
  END IF;

  v_gems := p_gems;
  v_gold := CASE v_gems
    WHEN 10 THEN 5000
    WHEN 25 THEN 15000
    WHEN 75 THEN 50000
    WHEN 200 THEN 150000
    ELSE NULL
  END;

  IF v_gold IS NULL OR v_gems IS NULL OR v_gems <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid package');
  END IF;

  SELECT gold, gems INTO v_current_gold, v_current_gems
  FROM public.users
  WHERE auth_id = v_auth_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_current_gems < v_gems THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
  END IF;

  UPDATE public.users
  SET gems = gems - v_gems,
      gold = gold + v_gold
  WHERE auth_id = v_auth_id;

  RETURN jsonb_build_object(
    'success', true,
    'gems_spent', v_gems,
    'gold_gained', v_gold,
    'gems', (v_current_gems - v_gems),
    'gold', (v_current_gold + v_gold)
  );
END;
$$;

COMMIT;
