-- Challenger also gets notified when their PvP invite expires unanswered.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_unseen_pvp_results()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_me UUID;
  v_rows JSONB;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN '[]'::JSONB;
  END IF;

  UPDATE public.pvp_invites SET status = 'expired'
  WHERE status = 'pending' AND expires_at <= now();

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'invite_id', i.id,
    'wager', i.wager,
    'status', i.status,
    'result', i.result,
    'opponent', jsonb_build_object(
      'auth_id', u.auth_id,
      'username', u.username,
      'display_name', u.display_name,
      'avatar_url', u.avatar_url,
      'level', u.level,
      'power', u.power,
      'pvp_rating', COALESCE(u.pvp_rating, 1000)
    )
  ) ORDER BY i.created_at ASC), '[]'::JSONB)
  INTO v_rows
  FROM public.pvp_invites i
  JOIN public.users u ON u.auth_id = i.target_id
  WHERE i.challenger_id = v_me
    AND i.challenger_seen = false
    AND i.status IN ('accepted', 'declined', 'expired');

  RETURN v_rows;
END;
$function$;

COMMIT;
