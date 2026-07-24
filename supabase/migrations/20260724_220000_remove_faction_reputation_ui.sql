-- Migrate energy_refill shop item from faction to global reputation.
-- Faction reputation UI removed from client; keep DB tables for now.

UPDATE public.reputation_shop_catalog
SET
  cost_type = 'global',
  cost_amount = 500,
  description_tr = '+20 enerji — global itibar ile.'
WHERE id = 'energy_refill';

-- Shop RPC: only return global-cost items (faction rep UI removed).
CREATE OR REPLACE FUNCTION public.get_reputation_shop()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_global_rep integer := 0;
  v_faction_reps jsonb := '[]'::jsonb;
  v_active_buffs jsonb := '[]'::jsonb;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT COALESCE(reputation, 0) INTO v_global_rep
  FROM public.users WHERE auth_id = v_me;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'faction_id', pfr.faction_id,
    'reputation', pfr.reputation
  ) ORDER BY pfr.faction_id), '[]'::jsonb)
  INTO v_faction_reps
  FROM public.player_faction_reputation pfr
  WHERE pfr.user_id = v_me;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'buff_key', prb.buff_key,
    'buff_value', prb.buff_value,
    'expires_at', prb.expires_at
  ) ORDER BY prb.expires_at DESC), '[]'::jsonb)
  INTO v_active_buffs
  FROM public.player_reputation_buffs prb
  WHERE prb.user_id = v_me AND prb.expires_at > now();

  RETURN jsonb_build_object(
    'success', true,
    'global_reputation', v_global_rep,
    'faction_reputations', v_faction_reps,
    'active_buffs', v_active_buffs,
    'items', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name_tr,
        'description', c.description_tr,
        'icon_key', c.icon_key,
        'cost_type', c.cost_type,
        'cost_amount', c.cost_amount,
        'rarity', c.rarity,
        'effect_key', c.effect_key,
        'effect_value', c.effect_value,
        'duration_minutes', c.duration_minutes,
        'sort_order', c.sort_order
      ) ORDER BY c.sort_order), '[]'::jsonb)
      FROM public.reputation_shop_catalog c
      WHERE c.is_active
        AND c.cost_type = 'global'
    )
  );
END;
$$;
