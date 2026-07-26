-- Fix staff item catalog search visibility + clearer permission gate.

BEGIN;

CREATE OR REPLACE FUNCTION public.staff_search_items(
  p_query TEXT DEFAULT NULL,
  p_limit INT DEFAULT 80
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
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum gerekli.');
  END IF;

  IF NOT (
    public.staff_is_admin(v_actor)
    OR public.staff_has_permission(v_actor, 'player.adjust_inventory')
    OR public.staff_has_permission(v_actor, 'player.view_detail')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Envanter görüntüleme yetkisi yok.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'name')
      FROM (
        SELECT jsonb_build_object(
          'id', i.id,
          'name', i.name,
          'item_type', lower(COALESCE(i.type, 'misc')),
          'rarity', lower(COALESCE(i.rarity, 'common')),
          'is_stackable', COALESCE(i.is_stackable, false),
          'max_stack', GREATEST(1, COALESCE(i.max_stack, 999))
        ) AS row
        FROM public.items i
        WHERE v_q = ''
           OR lower(i.id) LIKE '%' || v_q || '%'
           OR lower(COALESCE(i.name, '')) LIKE '%' || v_q || '%'
        ORDER BY i.name
        LIMIT LEAST(GREATEST(COALESCE(p_limit, 80), 1), 150)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_search_items(text, int) TO authenticated;

COMMIT;
