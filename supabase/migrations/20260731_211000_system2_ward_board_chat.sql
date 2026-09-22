-- System 2 A: Ward board + ward chat (ward_hospital / ward_prison)
-- Board: guild-only default; friends opt-in; city opt-in show_on_ward_board
-- Tags: generic hospital/prison only. Time bands: <1h / 1–3h / 3h+. Max 40 + self pin.
-- Chat: read+write only while same restriction + same ward type.
-- Rate: 1 msg / 5s, 80 char, 60/day Istanbul ward-local.

BEGIN;

-- ── Extend chat channel CHECKs ───────────────────────────────────────────────

ALTER TABLE public.chat_messages DROP CONSTRAINT IF EXISTS chat_messages_channel_check;
ALTER TABLE public.chat_messages
  ADD CONSTRAINT chat_messages_channel_check
  CHECK (channel = ANY (ARRAY[
    'global'::text, 'guild'::text, 'dm'::text, 'trade'::text, 'system'::text,
    'ward_hospital'::text, 'ward_prison'::text
  ]));

ALTER TABLE public.chat_bans DROP CONSTRAINT IF EXISTS chat_bans_channel_check;
ALTER TABLE public.chat_bans
  ADD CONSTRAINT chat_bans_channel_check
  CHECK ((channel IS NULL) OR (channel = ANY (ARRAY[
    'global'::text, 'guild'::text, 'dm'::text, 'trade'::text, 'system'::text,
    'ward_hospital'::text, 'ward_prison'::text
  ])));

ALTER TABLE public.chat_filters DROP CONSTRAINT IF EXISTS chat_filters_channel_check;
ALTER TABLE public.chat_filters
  ADD CONSTRAINT chat_filters_channel_check
  CHECK ((channel IS NULL) OR (channel = ANY (ARRAY[
    'global'::text, 'guild'::text, 'dm'::text, 'trade'::text, 'system'::text,
    'ward_hospital'::text, 'ward_prison'::text
  ])));

-- Daily ward message counter (Istanbul day)
CREATE TABLE IF NOT EXISTS public.ward_chat_daily (
  user_id uuid NOT NULL,
  ward_type text NOT NULL CHECK (ward_type IN ('hospital', 'prison')),
  used_on date NOT NULL,
  msg_count integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, ward_type, used_on)
);

ALTER TABLE public.ward_chat_daily ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ward_chat_daily_select_own ON public.ward_chat_daily;
CREATE POLICY ward_chat_daily_select_own ON public.ward_chat_daily
  FOR SELECT USING (auth.uid() = user_id);

-- ── get_ward_board ───────────────────────────────────────────────────────────

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

  -- Must be in matching restriction to read board
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
        -- friendships store auth.uid(), not users.id
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
       -- Guild-only default: rank 1 always; friends/city need opt-in (already in rank)
  ),
  ranked AS (
    SELECT
      user_id,
      display_name,
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

  -- Self pin (always, even if not in top 40)
  v_self := jsonb_build_object(
    'user_id', v_me.id,
    'display_name', COALESCE(NULLIF(v_me.display_name, ''), v_me.username, 'Sen'),
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
    'entries', v_rows
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_ward_board(text) TO authenticated;

-- Toggle city board opt-in
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
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE public.users
  SET show_on_ward_board = COALESCE(p_show_on_city, show_on_ward_board),
      ward_board_friends_opt_in = COALESCE(p_friends_opt_in, ward_board_friends_opt_in),
      updated_at = now()
  WHERE auth_id = v_auth;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_ward_board_visibility(boolean, boolean) TO authenticated;

-- ── send_ward_message ────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.send_ward_message(
  p_ward_type text,
  p_content text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_clean text;
  v_filtered text;
  v_channel text;
  v_last_at timestamptz;
  v_ban public.chat_bans%ROWTYPE;
  v_message_id uuid;
  v_today date := public._istanbul_today();
  v_count integer := 0;
  v_policy jsonb;
  v_acct jsonb;
BEGIN
  v_policy := public.policy_require_acceptance();
  IF (v_policy->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_policy->>'error', 'policy_required', true);
  END IF;

  v_acct := public.assert_player_not_banned();
  IF (v_acct->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_acct->>'error');
  END IF;

  IF p_ward_type NOT IN ('hospital', 'prison') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid ward');
  END IF;

  v_channel := CASE p_ward_type
    WHEN 'hospital' THEN 'ward_hospital'
    ELSE 'ward_prison'
  END;

  v_user := public.get_current_chat_user();

  IF p_ward_type = 'hospital' THEN
    IF v_user.hospital_until IS NULL OR v_user.hospital_until <= now() THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hastanede degilsin');
    END IF;
  ELSE
    IF v_user.prison_until IS NULL OR v_user.prison_until <= now() THEN
      RETURN jsonb_build_object('success', false, 'error', 'Cezaevinde degilsin');
    END IF;
  END IF;

  v_clean := public.normalize_chat_content(p_content);
  IF char_length(v_clean) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bos mesaj gonderilemez');
  END IF;
  IF char_length(v_clean) > 80 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj en fazla 80 karakter olabilir');
  END IF;

  -- 5s rate (ward)
  SELECT created_at INTO v_last_at
  FROM public.chat_messages
  WHERE sender_user_id = v_user.id
    AND channel = v_channel
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_last_at IS NOT NULL AND v_last_at > now() - interval '5 seconds' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cok hizli mesaj gonderiyorsunuz');
  END IF;

  -- 60/day Istanbul
  SELECT msg_count INTO v_count
  FROM public.ward_chat_daily
  WHERE user_id = v_user.auth_id
    AND ward_type = p_ward_type
    AND used_on = v_today;

  IF COALESCE(v_count, 0) >= 60 THEN
    RETURN jsonb_build_object('success', false, 'error', 'daily_limit', 'message', 'Gunluk koğuş mesaj limiti (60)');
  END IF;

  v_ban := public.get_active_chat_ban(v_user.id, v_channel, v_user.guild_id);
  IF v_ban.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Sohbetten gecici olarak uzaklastirildiniz',
      'ban_expires_at', v_ban.expires_at
    );
  END IF;

  v_filtered := public.apply_chat_filters(v_clean, v_channel, v_user.guild_id);

  INSERT INTO public.chat_messages (
    channel, sender_user_id, recipient_user_id, guild_id, sender_name, content, metadata
  ) VALUES (
    v_channel,
    v_user.id,
    NULL,
    NULL,
    COALESCE(NULLIF(v_user.display_name, ''), v_user.username),
    v_filtered,
    jsonb_build_object('ward_type', p_ward_type, 'original_length', char_length(v_clean))
  )
  RETURNING id INTO v_message_id;

  INSERT INTO public.ward_chat_daily (user_id, ward_type, used_on, msg_count)
  VALUES (v_user.auth_id, p_ward_type, v_today, 1)
  ON CONFLICT (user_id, ward_type, used_on)
  DO UPDATE SET msg_count = public.ward_chat_daily.msg_count + 1;

  RETURN jsonb_build_object(
    'success', true,
    'message_id', v_message_id,
    'content', v_filtered,
    'channel', v_channel
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_ward_message(text, text) TO authenticated;

-- ── get_ward_chat_history ────────────────────────────────────────────────────

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

-- Extend send_chat_message whitelist for ward channels (gates via send_ward_message preferred)
CREATE OR REPLACE FUNCTION public.send_chat_message(
  p_channel TEXT,
  p_content TEXT,
  p_recipient_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_recipient public.users%ROWTYPE;
  v_clean TEXT;
  v_filtered TEXT;
  v_last_message_at TIMESTAMPTZ;
  v_ban public.chat_bans%ROWTYPE;
  v_message_id UUID;
  v_sender_name TEXT;
  v_sender_guild_name TEXT;
  v_policy JSONB;
  v_acct JSONB;
  v_ward_type text;
BEGIN
  v_policy := public.policy_require_acceptance();
  IF (v_policy->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_policy->>'error', 'policy_required', true);
  END IF;

  v_acct := public.assert_player_not_banned();
  IF (v_acct->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_acct->>'error');
  END IF;

  v_user := public.get_current_chat_user();

  IF p_channel IN ('ward_hospital', 'ward_prison') THEN
    v_ward_type := CASE p_channel WHEN 'ward_hospital' THEN 'hospital' ELSE 'prison' END;
    RETURN public.send_ward_message(v_ward_type, p_content);
  END IF;

  IF p_channel NOT IN ('global', 'guild', 'dm', 'trade') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz kanal');
  END IF;

  v_clean := public.normalize_chat_content(p_content);
  IF char_length(v_clean) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bos mesaj gonderilemez');
  END IF;

  IF char_length(v_clean) > 200 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj en fazla 200 karakter olabilir');
  END IF;

  IF p_channel = 'guild' AND v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca sohbeti icin bir loncaya ait olmalisiniz');
  END IF;

  IF p_channel = 'dm' AND p_recipient_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ozel mesaj icin hedef kullanici gerekli');
  END IF;

  IF p_channel = 'dm' THEN
    SELECT * INTO v_recipient FROM public.users WHERE id = p_recipient_user_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hedef oyuncu bulunamadi');
    END IF;

    IF v_recipient.id = v_user.id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Kendinize ozel mesaj gonderemezsiniz');
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.chat_blocks cb
      WHERE (cb.blocker_user_id = v_user.id AND cb.blocked_user_id = v_recipient.id)
         OR (cb.blocker_user_id = v_recipient.id AND cb.blocked_user_id = v_user.id)
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Bu oyuncu ile ozel mesaj kullanilamiyor');
    END IF;
  END IF;

  SELECT created_at INTO v_last_message_at
  FROM public.chat_messages
  WHERE sender_user_id = v_user.id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_last_message_at IS NOT NULL AND v_last_message_at > now() - interval '2 seconds' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cok hizli mesaj gonderiyorsunuz');
  END IF;

  v_ban := public.get_active_chat_ban(v_user.id, p_channel, v_user.guild_id);
  IF v_ban.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Sohbetten gecici olarak uzaklastirildiniz',
      'ban_expires_at', v_ban.expires_at,
      'ban_reason', v_ban.reason
    );
  END IF;

  v_filtered := public.apply_chat_filters(v_clean, p_channel, v_user.guild_id);
  v_sender_name := COALESCE(NULLIF(v_user.display_name, ''), v_user.username);

  SELECT g.name
  INTO v_sender_guild_name
  FROM public.guilds g
  WHERE g.id = v_user.guild_id;

  INSERT INTO public.chat_messages (
    channel, sender_user_id, recipient_user_id, guild_id, sender_name, content, metadata
  ) VALUES (
    p_channel, v_user.id, p_recipient_user_id,
    CASE WHEN p_channel = 'guild' THEN v_user.guild_id ELSE NULL END,
    v_sender_name, v_filtered,
    jsonb_build_object(
      'original_length', char_length(v_clean),
      'sender_guild_name', v_sender_guild_name
    )
  )
  RETURNING id INTO v_message_id;

  PERFORM public.write_chat_audit(v_user.id, 'message_sent', NULL, v_message_id, jsonb_build_object('channel', p_channel));

  RETURN jsonb_build_object(
    'success', true,
    'message_id', v_message_id,
    'content', v_filtered,
    'sender_staff_badge', public.get_public_staff_badge(v_user.auth_id),
    'sender_king_badge', public.get_public_king_badge(v_user.auth_id),
    'sender_guild_name', v_sender_guild_name
  );
END;
$$;

COMMIT;
