-- Optional server-side ban filter for staff player search.
BEGIN;

CREATE OR REPLACE FUNCTION public.staff_search_players(
  p_query TEXT,
  p_limit INT DEFAULT 20,
  p_banned_filter TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_q TEXT := lower(btrim(COALESCE(p_query, '')));
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'player.view_detail') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  IF char_length(v_q) < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'En az 2 karakter girin.');
  END IF;

  IF p_banned_filter IS NOT NULL AND p_banned_filter NOT IN ('active', 'banned') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz ban filtresi.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'auth_id', u.auth_id,
        'username', u.username,
        'display_name', u.display_name,
        'level', u.level,
        'is_banned', COALESCE(u.is_banned, false),
        'staff_badge', public.get_public_staff_badge(u.auth_id)
      ) ORDER BY u.username)
      FROM public.users u
      WHERE (
          lower(u.username) LIKE v_q || '%'
          OR lower(COALESCE(u.display_name, '')) LIKE '%' || v_q || '%'
        )
        AND (
          p_banned_filter IS NULL
          OR (p_banned_filter = 'banned' AND COALESCE(u.is_banned, false) = true)
          OR (p_banned_filter = 'active' AND COALESCE(u.is_banned, false) = false)
        )
      LIMIT v_limit
    ), '[]'::jsonb)
  );
END;
$$;

COMMIT;
