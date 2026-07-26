-- Fix regression from 20260729_289000: staff broadcast must post to global chat
-- and manual ticker (restores 20260729_277000 behavior, keeps default 3 passes).

BEGIN;

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
  v_passes INT := GREATEST(1, LEAST(COALESCE(p_max_passes, 3), 500));
  v_body TEXT;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.broadcast');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF btrim(COALESCE(p_message, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duyuru metni gerekli.');
  END IF;

  UPDATE public.staff_broadcasts SET is_active = false WHERE is_active = true;

  INSERT INTO public.staff_broadcasts (
    message, created_by, is_active, expires_at, max_passes, passes_completed
  )
  VALUES (
    left(btrim(p_message), 280),
    v_actor,
    true,
    now() + interval '7 days',
    v_passes,
    0
  )
  RETURNING id INTO v_id;

  v_body := CASE
    WHEN left(btrim(p_message), 2) = '📣' THEN left(btrim(p_message), 200)
    ELSE '📣 ' || left(btrim(p_message), 180)
  END;

  PERFORM public._post_global_announcement_chat(
    v_actor,
    v_body,
    'staff_broadcast',
    jsonb_build_object('broadcast_id', v_id)
  );

  PERFORM public._push_live_ticker_manual_event(
    'staff_broadcast',
    v_body,
    v_actor,
    v_id::text
  );

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.broadcast', 'create_broadcast', 'staff_broadcast', v_id::text,
    jsonb_build_object('message', p_message, 'max_passes', v_passes),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object(
    'success', true,
    'broadcast_id', v_id,
    'max_passes', v_passes
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_liveops_create_broadcast(text, int) TO authenticated;

COMMIT;
