BEGIN;

-- Admin/staff tooling: remove arbitrary numeric caps. Keep auth + required-field checks only.

ALTER TABLE public.night_market_offers
  DROP CONSTRAINT IF EXISTS night_market_offers_stock_per_player_check;

CREATE OR REPLACE FUNCTION public.staff_liveops_upsert_night_market_offer(
  p_offer_id UUID,
  p_payload JSONB,
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
  v_item_id TEXT;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.night_market');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  v_item_id := NULLIF(trim(p_payload->>'item_id'), '');
  IF v_item_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşya seçilmeli.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.items i WHERE i.id = v_item_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşya.');
  END IF;

  IF p_offer_id IS NULL THEN
    INSERT INTO public.night_market_offers (item_id, gem_price, stock_per_player, rotation_week)
    VALUES (
      v_item_id,
      COALESCE((p_payload->>'price_gems')::bigint, 0),
      COALESCE((p_payload->>'stock')::int, 0),
      COALESCE((p_payload->>'rotation_week')::date, CURRENT_DATE)
    );
  ELSE
    UPDATE public.night_market_offers
    SET
      item_id = v_item_id,
      gem_price = COALESCE((p_payload->>'price_gems')::bigint, gem_price),
      stock_per_player = COALESCE((p_payload->>'stock')::int, stock_per_player),
      rotation_week = COALESCE((p_payload->>'rotation_week')::date, rotation_week)
    WHERE id = p_offer_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Teklif bulunamadı.');
    END IF;
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.night_market', 'upsert_night_market', 'night_market', COALESCE(p_offer_id::text, v_item_id),
    jsonb_build_object('payload', p_payload, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
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
    END
  INTO v_before
  FROM public.users
  WHERE auth_id = v_auth
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  v_after := v_before + v_delta;

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

  RETURN jsonb_build_object('success', true, 'before', v_before, 'after', v_after);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_suggest_bug_reward(
  p_report_id UUID,
  p_gems INT,
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
  v_gems INT := COALESCE(p_gems, 0);
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'bug.triage');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF v_gems <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Elmas miktarı 0 olamaz.');
  END IF;

  UPDATE public.bug_reports
  SET suggested_gems = v_gems,
      suggested_by = v_actor,
      suggested_at = now(),
      status = CASE WHEN status = 'submitted' THEN 'triaged' ELSE status END,
      review_note = COALESCE(NULLIF(btrim(COALESCE(p_note, '')), ''), review_note)
  WHERE id = p_report_id AND status NOT IN ('approved', 'rejected', 'duplicate');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı veya kapatılmış.');
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'bug.triage', 'suggest_reward', 'bug_report', p_report_id::text,
    jsonb_build_object('gems', v_gems),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'suggested_gems', v_gems);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_approve_bug_report(
  p_report_id UUID,
  p_gems INT,
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
  v_report RECORD;
  v_gems INT := COALESCE(p_gems, 0);
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'bug.approve_reward');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF v_gems <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Elmas miktarı 0 olamaz.');
  END IF;

  SELECT * INTO v_report FROM public.bug_reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı.');
  END IF;

  IF v_report.status IN ('approved', 'rejected', 'duplicate') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor zaten kapatılmış.');
  END IF;

  IF v_report.player_id = v_actor THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi raporunuzu onaylayamazsınız.');
  END IF;

  UPDATE public.users
  SET gems = COALESCE(gems, 0) + v_gems
  WHERE auth_id = v_report.player_id;

  INSERT INTO public.gem_transactions (user_id, amount, reason, reference_type, reference_id, created_by)
  VALUES (v_report.player_id, v_gems, 'bug_reward', 'bug_report', p_report_id::text, v_actor);

  UPDATE public.bug_reports
  SET status = 'approved',
      reward_gems_approved = v_gems,
      reviewed_by = v_actor,
      reviewed_at = now(),
      review_note = NULLIF(btrim(COALESCE(p_note, '')), '')
  WHERE id = p_report_id;

  PERFORM public._notify_player_inbox(
    v_report.player_id,
    'bug_approved',
    'Bug raporu onaylandı',
    format('+%s elmas hesabınıza eklendi.', v_gems),
    jsonb_build_object('report_id', p_report_id, 'gems', v_gems)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'bug.approve_reward', 'approve_bug', 'bug_report', p_report_id::text,
    jsonb_build_object('gems', v_gems, 'player_id', v_report.player_id),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'gems_granted', v_gems);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_create_broadcast(
  p_message TEXT,
  p_max_passes INT DEFAULT 3
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_id UUID;
  v_passes INT := GREATEST(COALESCE(p_max_passes, 3), 1);
  v_body TEXT;
  v_msg TEXT := btrim(COALESCE(p_message, ''));
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.broadcast');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF v_msg = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duyuru metni gerekli.');
  END IF;

  UPDATE public.staff_broadcasts SET is_active = false WHERE is_active = true;

  UPDATE public.live_ticker_manual_events
  SET expires_at = now()
  WHERE event_type = 'staff_broadcast';

  INSERT INTO public.staff_broadcasts (
    message, created_by, is_active, expires_at, max_passes, passes_completed
  )
  VALUES (
    v_msg,
    v_actor,
    true,
    now() + interval '7 days',
    v_passes,
    0
  )
  RETURNING id INTO v_id;

  v_body := CASE
    WHEN left(v_msg, 2) = '📣' THEN v_msg
    ELSE '📣 ' || v_msg
  END;

  PERFORM public._post_global_announcement_chat(
    v_actor,
    v_body,
    'staff_broadcast',
    jsonb_build_object('broadcast_id', v_id)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.broadcast', 'create_broadcast', 'staff_broadcast', v_id::text,
    jsonb_build_object('message', v_msg, 'max_passes', v_passes),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object(
    'success', true,
    'broadcast_id', v_id,
    'max_passes', v_passes
  );
END;
$$;

COMMIT;
