-- System 2 residual: ad timer challenge attestation + clinic wallet + ward flag read-back
-- Ad: short-lived one-time token before reduce_timer_with_ad (no Play Integrity / App Attest)
-- Day boundary: Europe/Istanbul via _istanbul_today()
-- Residual risk: client still proves "watched ad" only via holding a prior challenge token;
--   mocked/debug rewards + rooted clients can still complete the flow without a real SSV.

BEGIN;

-- ── Ad challenge tables ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.ad_timer_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  timer_type text NOT NULL CHECK (timer_type IN ('prison', 'hospital')),
  token uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  placement text,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  redeemed_at timestamptz,
  superseded_at timestamptz
);

CREATE INDEX IF NOT EXISTS ad_timer_challenges_user_timer_idx
  ON public.ad_timer_challenges (user_id, timer_type, created_at DESC);

ALTER TABLE public.ad_timer_challenges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ad_timer_challenges_select_own ON public.ad_timer_challenges;
CREATE POLICY ad_timer_challenges_select_own ON public.ad_timer_challenges
  FOR SELECT USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.ad_timer_anomaly_log (
  id bigserial PRIMARY KEY,
  user_id uuid,
  timer_type text,
  reason text NOT NULL,
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ad_timer_anomaly_log_created_idx
  ON public.ad_timer_anomaly_log (created_at DESC);

ALTER TABLE public.ad_timer_anomaly_log ENABLE ROW LEVEL SECURITY;
-- No client SELECT — service/ops only via SQL editor / service_role

CREATE OR REPLACE FUNCTION public._log_ad_timer_anomaly(
  p_user_id uuid,
  p_timer text,
  p_reason text,
  p_detail jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.ad_timer_anomaly_log (user_id, timer_type, reason, detail)
  VALUES (p_user_id, p_timer, p_reason, COALESCE(p_detail, '{}'::jsonb));
END;
$$;

-- Issue short-lived challenge before ad show
CREATE OR REPLACE FUNCTION public.issue_ad_timer_challenge(
  p_timer text,
  p_placement text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_user record;
  v_until timestamptz;
  v_uses integer := 0;
  v_daily_limit constant integer := 3;
  v_today date := public._istanbul_today();
  v_token uuid;
  v_expires timestamptz;
  v_ttl constant interval := interval '5 minutes';
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_timer NOT IN ('prison', 'hospital') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid timer');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  v_until := CASE p_timer
    WHEN 'prison' THEN v_user.prison_until
    ELSE v_user.hospital_until
  END;

  IF v_until IS NULL OR v_until <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aktif süre yok');
  END IF;

  SELECT uses INTO v_uses
  FROM public.ad_timer_reductions
  WHERE user_id = v_user_id AND timer_type = p_timer AND used_on = v_today;

  IF COALESCE(v_uses, 0) >= v_daily_limit THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'daily_limit',
      'message', 'Bugünlük reklam hakkın bitti (3/3).',
      'uses_left', 0
    );
  END IF;

  -- Supersede outstanding challenges for this timer
  UPDATE public.ad_timer_challenges
  SET superseded_at = now()
  WHERE user_id = v_user_id
    AND timer_type = p_timer
    AND redeemed_at IS NULL
    AND superseded_at IS NULL;

  v_expires := now() + v_ttl;
  INSERT INTO public.ad_timer_challenges (user_id, timer_type, placement, expires_at)
  VALUES (v_user_id, p_timer, NULLIF(trim(COALESCE(p_placement, '')), ''), v_expires)
  RETURNING token INTO v_token;

  RETURN jsonb_build_object(
    'success', true,
    'challenge_token', v_token,
    'expires_at', v_expires,
    'uses_left', v_daily_limit - COALESCE(v_uses, 0),
    'min_watch_ms', 2000
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.issue_ad_timer_challenge(text, text) TO authenticated;

-- Redeem: require valid one-time challenge token
DROP FUNCTION IF EXISTS public.reduce_timer_with_ad(text);

CREATE OR REPLACE FUNCTION public.reduce_timer_with_ad(
  p_timer text,
  p_challenge_token uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_user record;
  v_uses integer := 0;
  v_daily_limit constant integer := 3;
  v_reduction constant interval := interval '30 minutes';
  v_until timestamptz;
  v_new_until timestamptz;
  v_today date := public._istanbul_today();
  v_challenge record;
  v_min_watch constant interval := interval '2 seconds';
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_timer NOT IN ('prison', 'hospital') THEN
    PERFORM public._log_ad_timer_anomaly(v_user_id, p_timer, 'invalid_timer', '{}'::jsonb);
    RETURN jsonb_build_object('success', false, 'error', 'Invalid timer');
  END IF;

  IF p_challenge_token IS NULL THEN
    PERFORM public._log_ad_timer_anomaly(
      v_user_id, p_timer, 'missing_token',
      jsonb_build_object('note', 'blind reduce_timer_with_ad rejected')
    );
    RETURN jsonb_build_object(
      'success', false,
      'error', 'challenge_required',
      'message', 'Reklam doğrulama gerekli. Tekrar dene.'
    );
  END IF;

  SELECT * INTO v_challenge
  FROM public.ad_timer_challenges
  WHERE token = p_challenge_token
  FOR UPDATE;

  IF NOT FOUND THEN
    PERFORM public._log_ad_timer_anomaly(
      v_user_id, p_timer, 'unknown_token',
      jsonb_build_object('token', p_challenge_token)
    );
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_challenge',
      'message', 'Reklam doğrulama geçersiz. Tekrar dene.'
    );
  END IF;

  IF v_challenge.user_id IS DISTINCT FROM v_user_id THEN
    PERFORM public._log_ad_timer_anomaly(
      v_user_id, p_timer, 'token_user_mismatch',
      jsonb_build_object('token', p_challenge_token, 'owner', v_challenge.user_id)
    );
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_challenge',
      'message', 'Reklam doğrulama geçersiz. Tekrar dene.'
    );
  END IF;

  IF v_challenge.timer_type IS DISTINCT FROM p_timer THEN
    PERFORM public._log_ad_timer_anomaly(
      v_user_id, p_timer, 'token_timer_mismatch',
      jsonb_build_object('token', p_challenge_token, 'challenge_timer', v_challenge.timer_type)
    );
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_challenge',
      'message', 'Reklam doğrulama geçersiz. Tekrar dene.'
    );
  END IF;

  IF v_challenge.redeemed_at IS NOT NULL THEN
    PERFORM public._log_ad_timer_anomaly(
      v_user_id, p_timer, 'token_already_redeemed',
      jsonb_build_object('token', p_challenge_token, 'redeemed_at', v_challenge.redeemed_at)
    );
    RETURN jsonb_build_object(
      'success', false,
      'error', 'challenge_used',
      'message', 'Bu reklam ödülü zaten kullanıldı.'
    );
  END IF;

  IF v_challenge.superseded_at IS NOT NULL THEN
    PERFORM public._log_ad_timer_anomaly(
      v_user_id, p_timer, 'token_superseded',
      jsonb_build_object('token', p_challenge_token)
    );
    RETURN jsonb_build_object(
      'success', false,
      'error', 'challenge_stale',
      'message', 'Reklam doğrulama süresi doldu. Tekrar dene.'
    );
  END IF;

  IF v_challenge.expires_at <= now() THEN
    PERFORM public._log_ad_timer_anomaly(
      v_user_id, p_timer, 'token_expired',
      jsonb_build_object('token', p_challenge_token, 'expires_at', v_challenge.expires_at)
    );
    RETURN jsonb_build_object(
      'success', false,
      'error', 'challenge_expired',
      'message', 'Reklam doğrulama süresi doldu. Tekrar dene.'
    );
  END IF;

  IF v_challenge.created_at + v_min_watch > now() THEN
    PERFORM public._log_ad_timer_anomaly(
      v_user_id, p_timer, 'redeem_too_fast',
      jsonb_build_object(
        'token', p_challenge_token,
        'elapsed_ms', EXTRACT(EPOCH FROM (now() - v_challenge.created_at)) * 1000
      )
    );
    RETURN jsonb_build_object(
      'success', false,
      'error', 'watch_incomplete',
      'message', 'Reklam tamamlanmadı. Tekrar dene.'
    );
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  v_until := CASE p_timer
    WHEN 'prison' THEN v_user.prison_until
    ELSE v_user.hospital_until
  END;

  IF v_until IS NULL OR v_until <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aktif süre yok');
  END IF;

  SELECT uses INTO v_uses
  FROM public.ad_timer_reductions
  WHERE user_id = v_user_id AND timer_type = p_timer AND used_on = v_today;

  IF COALESCE(v_uses, 0) >= v_daily_limit THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'daily_limit',
      'message', 'Bugünlük reklam hakkın bitti (3/3).'
    );
  END IF;

  -- Consume token first (one-time)
  UPDATE public.ad_timer_challenges
  SET redeemed_at = now()
  WHERE id = v_challenge.id AND redeemed_at IS NULL;
  IF NOT FOUND THEN
    PERFORM public._log_ad_timer_anomaly(
      v_user_id, p_timer, 'token_race',
      jsonb_build_object('token', p_challenge_token)
    );
    RETURN jsonb_build_object(
      'success', false,
      'error', 'challenge_used',
      'message', 'Bu reklam ödülü zaten kullanıldı.'
    );
  END IF;

  v_new_until := v_until - v_reduction;
  IF v_new_until <= now() THEN
    v_new_until := NULL;
  END IF;

  IF p_timer = 'prison' THEN
    UPDATE public.users
    SET prison_until = v_new_until,
        in_prison = (v_new_until IS NOT NULL),
        prison_reason = CASE WHEN v_new_until IS NULL THEN NULL ELSE prison_reason END,
        updated_at = now()
    WHERE auth_id = v_user_id;
  ELSE
    UPDATE public.users
    SET hospital_until = v_new_until,
        updated_at = now()
    WHERE auth_id = v_user_id;
  END IF;

  INSERT INTO public.ad_timer_reductions (user_id, timer_type, used_on, uses)
  VALUES (v_user_id, p_timer, v_today, 1)
  ON CONFLICT (user_id, timer_type, used_on)
  DO UPDATE SET uses = public.ad_timer_reductions.uses + 1;

  RETURN jsonb_build_object(
    'success', true,
    'new_until', v_new_until,
    'released', v_new_until IS NULL,
    'reduction_minutes', 30,
    'uses_left', v_daily_limit - COALESCE(v_uses, 0) - 1
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.reduce_timer_with_ad(text, uuid) TO authenticated;

-- ── Ward board flag read-back ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_ward_board(p_ward_type text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_me record;
  v_rows jsonb := '[]'::jsonb;
  v_self jsonb;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_ward_type NOT IN ('hospital', 'prison') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid ward');
  END IF;

  SELECT * INTO v_me FROM public.users WHERE auth_id = v_auth;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF p_ward_type = 'hospital' THEN
    IF v_me.hospital_until IS NULL OR v_me.hospital_until <= now() THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hastanede degilsin');
    END IF;
  ELSE
    IF v_me.prison_until IS NULL OR v_me.prison_until <= now() THEN
      RETURN jsonb_build_object('success', false, 'error', 'Cezaevinde degilsin');
    END IF;
  END IF;

  WITH candidates AS (
    SELECT
      u.id AS user_id,
      u.auth_id,
      COALESCE(NULLIF(u.display_name, ''), u.username, 'Oyuncu') AS display_name,
      COALESCE(u.character_class, '') AS character_class,
      CASE
        WHEN p_ward_type = 'hospital' THEN u.hospital_until
        ELSE u.prison_until
      END AS until_ts,
      CASE
        WHEN p_ward_type = 'hospital' THEN 'hospital'
        ELSE 'prison'
      END AS reason_tag,
      CASE
        WHEN u.guild_id IS NOT NULL AND u.guild_id = v_me.guild_id THEN 1
        -- friendships.requester_id/addressee_id = auth.uid(), NOT users.id
        WHEN EXISTS (
          SELECT 1 FROM public.friendships f
          WHERE f.status = 'accepted'
            AND (
              (f.requester_id = v_me.auth_id AND f.addressee_id = u.auth_id)
              OR (f.addressee_id = v_me.auth_id AND f.requester_id = u.auth_id)
            )
        ) AND COALESCE(u.ward_board_friends_opt_in, false) THEN 2
        WHEN COALESCE(u.show_on_ward_board, false) THEN 3
        ELSE 0
      END AS visibility_rank,
      (u.auth_id = v_auth) AS is_self
    FROM public.users u
    WHERE u.auth_id <> v_auth
      AND (
        (p_ward_type = 'hospital' AND u.hospital_until IS NOT NULL AND u.hospital_until > now())
        OR (p_ward_type = 'prison' AND u.prison_until IS NOT NULL AND u.prison_until > now())
      )
  ),
  visible AS (
    SELECT *
    FROM candidates
    WHERE visibility_rank > 0
  ),
  ranked AS (
    SELECT
      user_id,
      display_name,
      character_class,
      reason_tag,
      CASE
        WHEN EXTRACT(EPOCH FROM (until_ts - now())) < 3600 THEN '<1h'
        WHEN EXTRACT(EPOCH FROM (until_ts - now())) < 10800 THEN '1-3h'
        ELSE '3h+'
      END AS time_band,
      visibility_rank,
      is_self
    FROM visible
    ORDER BY
      CASE visibility_rank WHEN 1 THEN 0 WHEN 2 THEN 1 ELSE 2 END,
      until_ts ASC
    LIMIT 40
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'user_id', user_id,
      'display_name', display_name,
      'character_class', character_class,
      'reason_tag', reason_tag,
      'time_band', time_band,
      'scope', CASE visibility_rank
        WHEN 1 THEN 'guild'
        WHEN 2 THEN 'friends'
        ELSE 'city'
      END,
      'is_self', false
    )
  ), '[]'::jsonb)
  INTO v_rows
  FROM ranked;

  v_self := jsonb_build_object(
    'user_id', v_me.id,
    'display_name', COALESCE(NULLIF(v_me.display_name, ''), v_me.username, 'Sen'),
    'character_class', COALESCE(v_me.character_class, ''),
    'reason_tag', p_ward_type,
    'time_band', CASE
      WHEN EXTRACT(EPOCH FROM (
        CASE WHEN p_ward_type = 'hospital' THEN v_me.hospital_until ELSE v_me.prison_until END - now()
      )) < 3600 THEN '<1h'
      WHEN EXTRACT(EPOCH FROM (
        CASE WHEN p_ward_type = 'hospital' THEN v_me.hospital_until ELSE v_me.prison_until END - now()
      )) < 10800 THEN '1-3h'
      ELSE '3h+'
    END,
    'scope', 'self',
    'is_self', true
  );

  RETURN jsonb_build_object(
    'success', true,
    'ward_type', p_ward_type,
    'self', v_self,
    'entries', v_rows,
    'show_on_city', COALESCE(v_me.show_on_ward_board, false),
    'friends_opt_in', COALESCE(v_me.ward_board_friends_opt_in, false)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_ward_board(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_ward_board_visibility(
  p_show_on_city boolean DEFAULT NULL,
  p_friends_opt_in boolean DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_city boolean;
  v_friends boolean;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE public.users
  SET show_on_ward_board = COALESCE(p_show_on_city, show_on_ward_board),
      ward_board_friends_opt_in = COALESCE(p_friends_opt_in, ward_board_friends_opt_in),
      updated_at = now()
  WHERE auth_id = v_auth
  RETURNING show_on_ward_board, ward_board_friends_opt_in
  INTO v_city, v_friends;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'show_on_city', COALESCE(v_city, false),
    'friends_opt_in', COALESCE(v_friends, false)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_ward_board_visibility(boolean, boolean) TO authenticated;

-- ── Clinic dashboard: member wallet for donate UX ────────────────────────────

CREATE OR REPLACE FUNCTION public.get_clinic_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_user record;
  v_guild record;
  v_today date := public._istanbul_today();
  v_used text;
  v_next_cost record;
  v_structural_owned bigint := 0;
  v_mystical_owned bigint := 0;
  v_critical_owned bigint := 0;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_auth;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca yok');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_user.guild_id;

  SELECT use_kind INTO v_used
  FROM public.guild_clinic_daily_uses
  WHERE user_id = v_auth AND used_on = v_today;

  SELECT * INTO v_next_cost
  FROM public.clinic_level_costs
  WHERE level = COALESCE(v_guild.clinic_level, 0) + 1;

  SELECT COALESCE(SUM(quantity), 0)::bigint INTO v_structural_owned
  FROM public.inventory
  WHERE user_id = v_auth AND item_id = 'resource_structural';

  SELECT COALESCE(SUM(quantity), 0)::bigint INTO v_mystical_owned
  FROM public.inventory
  WHERE user_id = v_auth AND item_id = 'resource_mystical';

  SELECT COALESCE(SUM(quantity), 0)::bigint INTO v_critical_owned
  FROM public.inventory
  WHERE user_id = v_auth AND item_id = 'resource_critical';

  RETURN jsonb_build_object(
    'success', true,
    'clinic_level', COALESCE(v_guild.clinic_level, 0),
    'clinic_structural', COALESCE(v_guild.clinic_structural, 0),
    'clinic_mystical', COALESCE(v_guild.clinic_mystical, 0),
    'clinic_critical', COALESCE(v_guild.clinic_critical, 0),
    'vault_gold', COALESCE(v_guild.vault_gold, 0),
    'monument_level', COALESCE(v_guild.monument_level, 0),
    'cut_pct', public._clinic_cut_pct(COALESCE(v_guild.clinic_level, 0)),
    'daily_use_kind', v_used,
    'daily_available', v_used IS NULL,
    'my_wallet', jsonb_build_object(
      'structural', v_structural_owned,
      'mystical', v_mystical_owned,
      'critical', v_critical_owned,
      'gold', COALESCE(v_user.gold, 0)
    ),
    'next_cost', CASE WHEN v_next_cost.level IS NULL THEN NULL ELSE jsonb_build_object(
      'level', v_next_cost.level,
      'structural', v_next_cost.structural,
      'mystical', v_next_cost.mystical,
      'critical', v_next_cost.critical,
      'gold', v_next_cost.gold
    ) END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_clinic_dashboard() TO authenticated;

-- ── FIX: get_ward_chat_history ORDER BY wrong alias (was t.created_at → 400) ─
CREATE OR REPLACE FUNCTION public.get_ward_chat_history(
  p_ward_type text,
  p_limit integer DEFAULT 40
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_channel text;
  v_rows jsonb;
BEGIN
  IF p_ward_type NOT IN ('hospital', 'prison') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid ward');
  END IF;

  v_user := public.get_current_chat_user();
  v_channel := CASE p_ward_type WHEN 'hospital' THEN 'ward_hospital' ELSE 'ward_prison' END;

  IF p_ward_type = 'hospital' THEN
    IF v_user.hospital_until IS NULL OR v_user.hospital_until <= now() THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hastanede degilsin');
    END IF;
  ELSE
    IF v_user.prison_until IS NULL OR v_user.prison_until <= now() THEN
      RETURN jsonb_build_object('success', false, 'error', 'Cezaevinde degilsin');
    END IF;
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at ASC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      cm.id,
      cm.channel,
      cm.sender_user_id AS sender_id,
      cm.sender_name,
      CASE
        WHEN cm.deleted_at IS NOT NULL THEN '[silindi]'
        ELSE cm.content
      END AS content,
      cm.created_at
    FROM public.chat_messages cm
    WHERE cm.channel = v_channel
      AND cm.created_at > now() - interval '24 hours'
    ORDER BY cm.created_at DESC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 40), 1), 100)
  ) t;

  RETURN jsonb_build_object('success', true, 'messages', v_rows, 'channel', v_channel);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_ward_chat_history(text, integer) TO authenticated;

COMMIT;
