-- Krallık kasası ledger: yalnızca son 10 altın girişi/çıkışı.
CREATE OR REPLACE FUNCTION public.get_kingdom_treasury_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_row public.kingdom_treasury%ROWTYPE;
  v_is_king BOOLEAN := false;
BEGIN
  SELECT * INTO v_row FROM public.kingdom_treasury WHERE id = 1;
  IF v_actor IS NOT NULL THEN
    v_is_king := public.is_current_king(v_actor);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'gold_balance', COALESCE(v_row.gold_balance, 0),
    'gems_balance', COALESCE(v_row.gems_balance, 0),
    'max_gift_amount', 1000000,
    'is_king', v_is_king,
    'recent_gifts', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', g.id,
          'king_username', ku.username,
          'recipient_username', ru.username,
          'currency', g.currency,
          'amount', g.amount,
          'created_at', g.created_at
        ) AS row
        FROM public.kingdom_king_gifts g
        JOIN public.users ku ON ku.auth_id = g.king_auth_id
        JOIN public.users ru ON ru.auth_id = g.recipient_auth_id
        ORDER BY g.created_at DESC
        LIMIT 12
      ) sub
    ), '[]'::jsonb),
    'recent_ledger', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'kind', l.kind,
          'currency', l.currency,
          'amount', l.amount,
          'created_at', l.created_at,
          'note', l.note
        ) AS row
        FROM public.kingdom_treasury_ledger l
        WHERE l.currency = 'gold'
        ORDER BY l.created_at DESC
        LIMIT 10
      ) sub2
    ), '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_kingdom_treasury_status() TO authenticated;
