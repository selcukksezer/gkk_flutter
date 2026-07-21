-- Extend sync_tutorial_progress to deep-merge completed_tracks / steps
-- while still flipping tutorial_completed from core_completed | skipped_all.

CREATE OR REPLACE FUNCTION public.sync_tutorial_progress(p_progress jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_existing jsonb;
  v_merged jsonb;
  v_completed boolean := false;
  v_tracks jsonb;
  v_steps jsonb;
  v_key text;
  v_local_steps jsonb;
  v_remote_steps jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT COALESCE(tutorial_progress, '{}'::jsonb)
  INTO v_existing
  FROM public.users
  WHERE auth_id = v_user_id;

  -- Shallow merge first, then union array fields used by tutorial v2.
  v_merged := COALESCE(v_existing, '{}'::jsonb) || COALESCE(p_progress, '{}'::jsonb);

  -- Union completed_tracks
  SELECT COALESCE(jsonb_agg(DISTINCT t), '[]'::jsonb)
  INTO v_tracks
  FROM (
    SELECT jsonb_array_elements_text(
      COALESCE(v_existing->'completed_tracks', '[]'::jsonb)
    ) AS t
    UNION
    SELECT jsonb_array_elements_text(
      COALESCE(p_progress->'completed_tracks', '[]'::jsonb)
    ) AS t
  ) u;

  v_merged := jsonb_set(v_merged, '{completed_tracks}', COALESCE(v_tracks, '[]'::jsonb));

  -- Union steps map (per-track string arrays)
  v_steps := COALESCE(v_existing->'steps', '{}'::jsonb);
  v_remote_steps := COALESCE(p_progress->'steps', '{}'::jsonb);
  FOR v_key IN SELECT DISTINCT k FROM (
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

  v_completed := COALESCE((v_merged->>'core_completed')::boolean, false)
    OR COALESCE((v_merged->>'skipped_all')::boolean, false);

  UPDATE public.users
  SET tutorial_progress = v_merged,
      tutorial_completed = CASE WHEN v_completed THEN true ELSE tutorial_completed END,
      updated_at = now()
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'tutorial_progress', v_merged,
    'tutorial_completed', v_completed
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_tutorial_progress(jsonb) TO authenticated;
