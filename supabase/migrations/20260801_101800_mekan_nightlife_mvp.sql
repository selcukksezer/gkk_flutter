-- =========================================================================================
-- MEKAN NIGHTLIFE MVP (Faz B)
-- Hang out / start party / join party. Facilities untouched.
-- Party window reuses mekans.happy_hour_until (discount + nightlife gate).
-- Vibe = users.nightlife_vibe (new). Risk → hospital System2 via hospital_until.
-- =========================================================================================

-- ── Visitor nightlife state ───────────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nightlife_vibe integer NOT NULL DEFAULT 0;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nightlife_hang_cd_until timestamptz;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nightlife_party_cd_until timestamptz;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nightlife_gold_day date;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nightlife_gold_earned_day integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.users.nightlife_vibe IS 'Nightlife / club vibe progression (mekan hang-out & party).';

-- ── Type balance helpers ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._mekan_nightlife_type_params(p_type text)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  RETURN CASE lower(COALESCE(p_type, 'bar'))
    WHEN 'bar' THEN jsonb_build_object(
      'hang_energy', 3, 'party_energy', 8, 'cover', 0,
      'fight_w', 0.06, 'scam_w', 0.08, 'good_w', 0.58,
      'gold_mult', 1.0, 'vibe_mult', 1.0
    )
    WHEN 'kahvehane' THEN jsonb_build_object(
      'hang_energy', 3, 'party_energy', 8, 'cover', 0,
      'fight_w', 0.03, 'scam_w', 0.05, 'good_w', 0.62,
      'gold_mult', 0.9, 'vibe_mult', 1.1
    )
    WHEN 'dovus_kulubu' THEN jsonb_build_object(
      'hang_energy', 4, 'party_energy', 10, 'cover', 50,
      'fight_w', 0.18, 'scam_w', 0.08, 'good_w', 0.48,
      'gold_mult', 1.1, 'vibe_mult', 1.0
    )
    WHEN 'luks_lounge' THEN jsonb_build_object(
      'hang_energy', 5, 'party_energy', 12, 'cover', 250,
      'fight_w', 0.07, 'scam_w', 0.18, 'good_w', 0.50,
      'gold_mult', 1.3, 'vibe_mult', 1.4
    )
    WHEN 'yeralti' THEN jsonb_build_object(
      'hang_energy', 5, 'party_energy', 12, 'cover', 100,
      'fight_w', 0.12, 'scam_w', 0.12, 'good_w', 0.50,
      'gold_mult', 1.5, 'vibe_mult', 1.3
    )
    ELSE jsonb_build_object(
      'hang_energy', 4, 'party_energy', 10, 'cover', 0,
      'fight_w', 0.08, 'scam_w', 0.10, 'good_w', 0.55,
      'gold_mult', 1.0, 'vibe_mult', 1.0
    )
  END;
END;
$$;

REVOKE ALL ON FUNCTION public._mekan_nightlife_type_params(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._mekan_nightlife_type_params(text) TO service_role;

-- Apply daily gold softcap (net positive nightlife gold).
CREATE OR REPLACE FUNCTION public._mekan_nightlife_apply_gold_cap(
  p_user_id uuid,
  p_delta bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_day date := (timezone('utc', now()))::date;
  v_earned int;
  v_cap int := 5000;
  v_room int;
  v_apply bigint;
BEGIN
  IF p_delta IS NULL OR p_delta = 0 THEN
    RETURN 0;
  END IF;

  -- Losses always apply fully.
  IF p_delta < 0 THEN
    RETURN p_delta;
  END IF;

  SELECT
    CASE WHEN nightlife_gold_day = v_day THEN COALESCE(nightlife_gold_earned_day, 0) ELSE 0 END
  INTO v_earned
  FROM public.users
  WHERE auth_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  v_room := GREATEST(0, v_cap - v_earned);
  v_apply := LEAST(p_delta, v_room::bigint);

  UPDATE public.users
  SET nightlife_gold_day = v_day,
      nightlife_gold_earned_day = v_earned + v_apply::int
  WHERE auth_id = p_user_id;

  RETURN v_apply;
END;
$$;

REVOKE ALL ON FUNCTION public._mekan_nightlife_apply_gold_cap(uuid, bigint) FROM PUBLIC;

-- Shared session roll for hang out / join party.
CREATE OR REPLACE FUNCTION public._mekan_nightlife_session(
  p_mekan_id uuid,
  p_mode text -- 'hang' | 'party'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_gate jsonb;
  v_mekan record;
  v_user record;
  v_params jsonb;
  v_energy_cost int;
  v_cd_until timestamptz;
  v_cd_seconds int;
  v_cover bigint := 0;
  v_fight_w numeric;
  v_scam_w numeric;
  v_good_w numeric;
  v_gold_mult numeric;
  v_vibe_mult numeric;
  v_roll numeric;
  v_outcome text;
  v_energy_delta int;
  v_reward_gold bigint := 0;
  v_scam_loss bigint := 0;
  v_gold_delta bigint := 0;
  v_vibe_delta int := 0;
  v_hospital boolean := false;
  v_hospital_minutes int := 0;
  v_owner_cut bigint := 0;
  v_fame_bump int := 1;
  v_suspicion_bump int := 0;
  v_msg text;
  v_party_active boolean;
  v_rate jsonb;
  v_new_vibe int;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli', 'error_code', 'not_authenticated');
  END IF;

  IF p_mode NOT IN ('hang', 'party') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz mod', 'error_code', 'bad_mode');
  END IF;

  v_gate := public.assert_player_combat_ready(v_uid, false);
  IF COALESCE((v_gate->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_gate;
  END IF;

  -- Abuse brake (does not replace per-action cooldown).
  v_rate := public.enforce_rate_limit('mekan_nightlife_' || p_mode, 40, 600);
  IF v_rate IS NOT NULL THEN
    RETURN v_rate;
  END IF;

  PERFORM public.apply_energy_regen(v_uid);
  PERFORM public.sync_expired_hospital(v_uid);

  SELECT * INTO v_mekan
  FROM public.mekans
  WHERE id = p_mekan_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadi', 'error_code', 'mekan_not_found');
  END IF;

  IF COALESCE(v_mekan.is_open, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan kapali', 'error_code', 'mekan_closed');
  END IF;

  IF v_mekan.closed_until IS NOT NULL AND v_mekan.closed_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan baskin nedeniyle kapali', 'error_code', 'mekan_raid');
  END IF;

  v_party_active := v_mekan.happy_hour_until IS NOT NULL AND v_mekan.happy_hour_until > now();
  IF p_mode = 'party' AND NOT v_party_active THEN
    RETURN jsonb_build_object('success', false, 'error', 'Su an parti yok', 'error_code', 'no_party');
  END IF;

  v_params := public._mekan_nightlife_type_params(v_mekan.mekan_type);
  v_energy_cost := CASE
    WHEN p_mode = 'party' THEN COALESCE((v_params->>'party_energy')::int, 10)
    ELSE COALESCE((v_params->>'hang_energy')::int, 4)
  END;
  v_cd_seconds := CASE WHEN p_mode = 'party' THEN 12 * 60 ELSE 3 * 60 END;
  v_cover := CASE
    WHEN p_mode = 'party' AND v_mekan.owner_id IS DISTINCT FROM v_uid
      THEN COALESCE((v_params->>'cover')::bigint, 0)
    ELSE 0
  END;
  v_fight_w := COALESCE((v_params->>'fight_w')::numeric, 0.08);
  v_scam_w := COALESCE((v_params->>'scam_w')::numeric, 0.10);
  v_good_w := COALESCE((v_params->>'good_w')::numeric, 0.55);
  v_gold_mult := COALESCE((v_params->>'gold_mult')::numeric, 1.0);
  v_vibe_mult := COALESCE((v_params->>'vibe_mult')::numeric, 1.0);

  IF p_mode = 'party' THEN
    v_fight_w := LEAST(0.35, v_fight_w * 1.35);
    v_scam_w := LEAST(0.30, v_scam_w * 1.25);
    v_fame_bump := 2;
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE auth_id = v_uid
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadi', 'error_code', 'player_not_found');
  END IF;

  v_cd_until := CASE
    WHEN p_mode = 'party' THEN v_user.nightlife_party_cd_until
    ELSE v_user.nightlife_hang_cd_until
  END;
  IF v_cd_until IS NOT NULL AND v_cd_until > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Biraz beklemelisin',
      'error_code', 'cooldown',
      'cooldown_until', v_cd_until
    );
  END IF;

  IF COALESCE(v_user.energy, 0) < v_energy_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Enerji yetersiz', 'error_code', 'no_energy');
  END IF;

  IF v_cover > 0 AND COALESCE(v_user.gold, 0) < v_cover THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cover icin altin yetersiz', 'error_code', 'no_gold');
  END IF;

  -- Spend energy (+ cover if any) first.
  UPDATE public.users
  SET energy = energy - v_energy_cost,
      gold = gold - v_cover,
      energy_last_updated = COALESCE(energy_last_updated, now()),
      updated_at = now()
  WHERE auth_id = v_uid
    AND energy >= v_energy_cost
    AND gold >= v_cover;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kaynak yetersiz', 'error_code', 'resource');
  END IF;

  v_energy_delta := -v_energy_cost;

  IF v_cover > 0 AND v_mekan.owner_id IS NOT NULL AND v_mekan.owner_id <> v_uid THEN
    UPDATE public.users SET gold = gold + v_cover WHERE auth_id = v_mekan.owner_id;
    UPDATE public.mekans
    SET total_revenue = total_revenue + v_cover
    WHERE id = p_mekan_id;
    v_owner_cut := v_owner_cut + v_cover;
  END IF;

  -- Outcome roll
  v_roll := random();
  IF v_roll < v_fight_w THEN
    v_outcome := 'fight';
  ELSIF v_roll < (v_fight_w + v_scam_w) THEN
    v_outcome := 'scam';
  ELSIF v_roll < (v_fight_w + v_scam_w + v_good_w) THEN
    v_outcome := 'good';
  ELSE
    v_outcome := 'neutral';
  END IF;

  IF v_outcome = 'good' THEN
    v_vibe_delta := GREATEST(1, floor((CASE WHEN p_mode = 'party' THEN 6 + floor(random() * 5) ELSE 3 + floor(random() * 4) END) * v_vibe_mult)::int);
    v_reward_gold := public._mekan_nightlife_apply_gold_cap(
      v_uid,
      GREATEST(0, floor((CASE WHEN p_mode = 'party' THEN 120 + floor(random() * 280) ELSE 40 + floor(random() * 160) END) * v_gold_mult)::bigint)
    );
    v_msg := CASE WHEN p_mode = 'party'
      THEN 'Parti alevlendi — vibe ve nakit geldi.'
      ELSE 'Iyi bir gece — vibe kazandin.'
    END;
  ELSIF v_outcome = 'neutral' THEN
    v_vibe_delta := GREATEST(1, floor((CASE WHEN p_mode = 'party' THEN 2 ELSE 1 END) * v_vibe_mult)::int);
    v_msg := CASE WHEN p_mode = 'party'
      THEN 'Kalabalikta kayboldun — az vibe.'
      ELSE 'Takildin, o kadar.'
    END;
  ELSIF v_outcome = 'scam' THEN
    v_vibe_delta := CASE WHEN random() < 0.4 THEN 1 ELSE 0 END;
    v_scam_loss := GREATEST(
      50,
      LEAST(
        COALESCE((SELECT gold FROM public.users WHERE auth_id = v_uid), 0),
        floor((CASE WHEN p_mode = 'party' THEN 200 + floor(random() * 400) ELSE 80 + floor(random() * 220) END) * v_gold_mult)::bigint
      )
    );
    v_msg := 'Dolandirildin — cebin sizdi.';
  ELSE
    -- fight
    v_vibe_delta := GREATEST(0, floor((1 + floor(random() * 2)) * v_vibe_mult)::int);
    v_msg := 'Kavga cikti.';
    IF random() < (CASE WHEN p_mode = 'party' THEN 0.40 ELSE 0.28 END) THEN
      v_hospital := true;
      v_hospital_minutes := 20 + floor(random() * 21)::int;
      UPDATE public.users
      SET hospital_until = now() + (v_hospital_minutes || ' minutes')::interval,
          hospital_reason = 'Gece kavgası',
          hospital_lifetime_count = COALESCE(hospital_lifetime_count, 0) + 1,
          updated_at = now()
      WHERE auth_id = v_uid;
      v_msg := 'Kavga — hastaneye dustun.';
    ELSE
      UPDATE public.users
      SET health = GREATEST(1, COALESCE(health, 100) - (5 + floor(random() * 15)::int)),
          updated_at = now()
      WHERE auth_id = v_uid;
      v_msg := 'Kavga — yara aldin ama ayaktasin.';
    END IF;
  END IF;

  -- Net gold for client: -cover + reward - scam
  v_gold_delta := -v_cover + v_reward_gold - v_scam_loss;

  UPDATE public.users
  SET nightlife_vibe = COALESCE(nightlife_vibe, 0) + GREATEST(0, v_vibe_delta),
      gold = GREATEST(0, gold + v_reward_gold - v_scam_loss),
      nightlife_hang_cd_until = CASE
        WHEN p_mode = 'hang' THEN now() + (v_cd_seconds || ' seconds')::interval
        ELSE nightlife_hang_cd_until
      END,
      nightlife_party_cd_until = CASE
        WHEN p_mode = 'party' THEN now() + (v_cd_seconds || ' seconds')::interval
        ELSE nightlife_party_cd_until
      END,
      current_mekan_id = p_mekan_id,
      last_active_at = now(),
      updated_at = now()
  WHERE auth_id = v_uid
  RETURNING nightlife_vibe INTO v_new_vibe;

  IF v_outcome = 'good' AND v_reward_gold > 0
     AND v_mekan.owner_id IS NOT NULL AND v_mekan.owner_id <> v_uid THEN
    v_owner_cut := v_owner_cut + floor(v_reward_gold * 0.10)::bigint;
    UPDATE public.users
    SET gold = gold + floor(v_reward_gold * 0.10)::bigint
    WHERE auth_id = v_mekan.owner_id;
  END IF;

  IF v_mekan.mekan_type = 'yeralti' THEN
    v_suspicion_bump := CASE WHEN p_mode = 'party' THEN 2 ELSE 1 END;
  END IF;

  UPDATE public.mekans
  SET fame = fame + v_fame_bump,
      suspicion = LEAST(100, suspicion + v_suspicion_bump)
  WHERE id = p_mekan_id;

  RETURN jsonb_build_object(
    'success', true,
    'mode', p_mode,
    'outcome', v_outcome,
    'message', v_msg,
    'energy_delta', v_energy_delta,
    'energy_cost', v_energy_cost,
    'gold_delta', v_gold_delta,
    'cover_paid', v_cover,
    'vibe_delta', GREATEST(0, v_vibe_delta),
    'nightlife_vibe', COALESCE(v_new_vibe, 0),
    'hospital', v_hospital,
    'hospital_minutes', v_hospital_minutes,
    'hospital_reason', CASE WHEN v_hospital THEN 'Gece kavgası' ELSE NULL END,
    'owner_cut', v_owner_cut,
    'party_active', v_party_active OR p_mode = 'party',
    'cooldown_until', now() + (v_cd_seconds || ' seconds')::interval,
    'cooldown_seconds', v_cd_seconds,
    'mekan_id', p_mekan_id,
    'mekan_type', v_mekan.mekan_type
  );
END;
$$;

REVOKE ALL ON FUNCTION public._mekan_nightlife_session(uuid, text) FROM PUBLIC;

-- ── Public RPCs ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mekan_hang_out(p_mekan_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  RETURN public._mekan_nightlife_session(p_mekan_id, 'hang');
END;
$$;

CREATE OR REPLACE FUNCTION public.mekan_join_party(p_mekan_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  RETURN public._mekan_nightlife_session(p_mekan_id, 'party');
END;
$$;

CREATE OR REPLACE FUNCTION public.mekan_start_party(
  p_mekan_id uuid,
  p_duration_minutes integer DEFAULT 60
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_mekan record;
  v_mins int;
  v_until timestamptz;
  v_rate jsonb;
  v_cost bigint := 500;
  v_gate jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli', 'error_code', 'not_authenticated');
  END IF;

  v_gate := public.assert_player_combat_ready(v_uid, false);
  IF COALESCE((v_gate->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_gate;
  END IF;

  v_rate := public.enforce_rate_limit('mekan_start_party', 3, 86400);
  IF v_rate IS NOT NULL THEN
    RETURN v_rate;
  END IF;

  v_mins := GREATEST(30, LEAST(120, COALESCE(p_duration_minutes, 60)));

  SELECT * INTO v_mekan
  FROM public.mekans
  WHERE id = p_mekan_id AND owner_id = v_uid
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadi veya size ait degil', 'error_code', 'not_owner');
  END IF;

  IF COALESCE(v_mekan.is_open, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'Once mekani ac', 'error_code', 'mekan_closed');
  END IF;

  IF v_mekan.closed_until IS NOT NULL AND v_mekan.closed_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Baskin nedeniyle kapali', 'error_code', 'mekan_raid');
  END IF;

  IF v_mekan.happy_hour_until IS NOT NULL AND v_mekan.happy_hour_until > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Parti zaten canli',
      'error_code', 'party_active',
      'happy_hour_until', v_mekan.happy_hour_until
    );
  END IF;

  UPDATE public.users
  SET gold = gold - v_cost,
      updated_at = now()
  WHERE auth_id = v_uid AND gold >= v_cost;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Parti baslatmak icin 500 altin gerekli', 'error_code', 'no_gold');
  END IF;

  v_until := now() + (v_mins || ' minutes')::interval;

  UPDATE public.mekans
  SET happy_hour_until = v_until,
      fame = fame + 5,
      suspicion = CASE
        WHEN mekan_type = 'yeralti' THEN LEAST(100, suspicion + 5)
        ELSE suspicion
      END
  WHERE id = p_mekan_id;

  RETURN jsonb_build_object(
    'success', true,
    'happy_hour_until', v_until,
    'party_until', v_until,
    'duration_minutes', v_mins,
    'gold_cost', v_cost,
    'message', 'Parti basladi — ziyaretciler katilabilir.'
  );
END;
$$;

-- Soft alias: keep happy-hour RPC; starting also works as party host shortcut.
-- (Existing set_mekan_happy_hour unchanged.)

GRANT EXECUTE ON FUNCTION public.mekan_hang_out(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mekan_join_party(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mekan_start_party(uuid, integer) TO authenticated;

REVOKE ALL ON FUNCTION public.mekan_hang_out(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mekan_join_party(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mekan_start_party(uuid, integer) FROM PUBLIC, anon;
