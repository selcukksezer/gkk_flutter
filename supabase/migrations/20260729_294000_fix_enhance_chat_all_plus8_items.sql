-- Fix: +8 chat announcements when item is already +8+ (not only +8→+9 attempts).
-- Covers +8, +9, +10 attempts: success (green), burn (red), fail/downgrade (warning).

BEGIN;

CREATE OR REPLACE FUNCTION public._post_enhance_global_chat(
  p_player_auth_id UUID,
  p_player_name TEXT,
  p_item_name TEXT,
  p_previous_level INT,
  p_new_level INT,
  p_success BOOLEAN,
  p_destroyed BOOLEAN
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_prev INT := COALESCE(p_previous_level, 0);
  v_new INT := COALESCE(p_new_level, v_prev);
  v_attempted INT := v_prev + 1;
  v_body TEXT;
  v_kind TEXT;
  v_tone TEXT;
  v_name TEXT;
  v_item TEXT;
BEGIN
  IF p_player_auth_id IS NULL OR v_prev < 8 THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.qa_bot_profiles qb WHERE qb.bot_auth_id = p_player_auth_id
  ) THEN
    RETURN;
  END IF;

  v_name := public._ticker_clip_name(COALESCE(p_player_name, 'Oyuncu'));
  v_item := public._ticker_clip_label(COALESCE(p_item_name, 'eşya'), 'eşya');

  IF COALESCE(p_destroyed, false) THEN
    v_body := '💥 ' || v_name || ' +' || v_prev::text || ' ' || v_item || ' yandı!';
    v_kind := 'enhance_burn';
    v_tone := 'danger';
  ELSIF COALESCE(p_success, false) THEN
    v_body := '✨ ' || v_name || ' +' || v_new::text || ' ' || v_item
      || ' güçlendirdi! (+' || v_prev::text || ' → +' || v_new::text || ')';
    v_kind := 'enhance_success';
    v_tone := 'success';
  ELSE
    v_body := '💨 ' || v_name || ' +' || v_prev::text || ' ' || v_item
      || ' basamadı (+' || v_attempted::text || ' denemesi, +' || v_new::text || ')';
    v_kind := 'enhance_fail';
    v_tone := 'warning';
  END IF;

  PERFORM public._post_global_announcement_chat(
    p_player_auth_id,
    v_body,
    v_kind,
    jsonb_build_object(
      'tone', v_tone,
      'previous_level', v_prev,
      'new_level', v_new,
      'attempted_level', v_attempted,
      'destroyed', COALESCE(p_destroyed, false),
      'success', COALESCE(p_success, false)
    )
  );
END;
$$;

COMMIT;
