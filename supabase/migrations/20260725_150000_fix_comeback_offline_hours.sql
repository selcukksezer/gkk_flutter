-- Fix comeback "0 dk yoktun":
-- Heartbeat set_online_status() was overwriting last_active_at before get_comeback_summary,
-- so offline_hours ≈ 0 while pending_count still forced the modal open every launch.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS comeback_resume_from TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS comeback_seen_at TIMESTAMPTZ;

COMMENT ON COLUMN public.users.comeback_resume_from IS
  'Frozen last_active_at from before this online session; used for comeback offline_hours.';
COMMENT ON COLUMN public.users.comeback_seen_at IS
  'When player dismissed comeback summary; suppresses re-show spam.';

CREATE OR REPLACE FUNCTION public.set_online_status(
  p_is_online boolean,
  p_mekan_id uuid DEFAULT NULL::uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.users
  SET
    -- Capture true offline gap once per return-to-online (ignore heartbeat churn).
    comeback_resume_from = CASE
      WHEN p_is_online
        AND comeback_resume_from IS NULL
        AND last_active_at IS NOT NULL
        AND last_active_at < now() - interval '5 minutes'
      THEN last_active_at
      WHEN NOT p_is_online THEN comeback_resume_from
      ELSE comeback_resume_from
    END,
    is_online = p_is_online,
    last_active_at = now(),
    current_mekan_id = CASE WHEN p_is_online THEN p_mekan_id ELSE NULL END
  WHERE auth_id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_comeback_summary_seen()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  UPDATE public.users
  SET
    comeback_resume_from = NULL,
    comeback_seen_at = now(),
    last_active_at = now(),
    updated_at = now()
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Patch get_comeback_summary last_seen + show rules (+ retention items if missing).
DO $patch$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef('public.get_comeback_summary()'::regprocedure) INTO v_def;

  IF v_def IS NULL THEN
    RAISE NOTICE 'get_comeback_summary missing — skip';
    RETURN;
  END IF;

  -- Prefer frozen resume timestamp over heartbeat last_active_at.
  IF position('comeback_resume_from' IN v_def) = 0 THEN
    v_def := replace(
      v_def,
      'COALESCE(u.last_active_at, u.last_login_at, u.updated_at, u.created_at) AS last_seen',
      'COALESCE(u.comeback_resume_from, u.last_active_at, u.last_login_at, u.updated_at, u.created_at) AS last_seen,
    u.comeback_seen_at'
    );
  END IF;

  -- Pending-only spam: require ≥1h offline; cooldown 4h after dismiss unless ≥8h offline.
  IF position('comeback_seen_at IS NULL' IN v_def) = 0 THEN
    v_def := replace(
      v_def,
      'v_show_summary := v_offline_hours >= v_offline_threshold_hours
    OR v_pending_count >= v_min_pending_for_summary;',
      'v_show_summary := (
      v_offline_hours >= v_offline_threshold_hours
      OR (v_pending_count >= v_min_pending_for_summary AND v_offline_hours >= 1)
    )
    AND (
      v_player.comeback_seen_at IS NULL
      OR v_offline_hours >= v_offline_threshold_hours
      OR v_player.comeback_seen_at < now() - interval ''4 hours''
    );'
    );
  END IF;

  -- Re-attach retention rows if patch marker missing.
  IF position('_comeback_retention_items' IN v_def) = 0
     AND position('v_pending_count :=' IN v_def) > 0 THEN
    v_def := replace(
      v_def,
      'v_pending_count := (',
      'v_items := v_items || public._comeback_retention_items(v_user_id);

  v_pending_count := ('
    );
  END IF;

  EXECUTE v_def;
END;
$patch$;

GRANT EXECUTE ON FUNCTION public.set_online_status(boolean, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_comeback_summary_seen() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_comeback_summary() TO authenticated;
