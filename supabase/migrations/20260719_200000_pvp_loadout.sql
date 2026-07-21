-- ============================================================================
-- PVP DÜELLO SAVAŞ EKRANI: oyuncu loadout RPC
-- VS ekranında iki tarafın istatistikleri + kuşanılı itemleri gösterilir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_pvp_loadout(p_auth_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user RECORD;
  v_items JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_auth_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı');
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'item_id', inv.item_id,
    'name', COALESCE(it.name_tr, it.name, inv.item_id),
    'icon', COALESCE(it.icon, ''),
    'rarity', COALESCE(it.rarity, 'common'),
    'type', COALESCE(it.type, ''),
    'enhancement_level', COALESCE(inv.enhancement_level, 0)
  ) ORDER BY it.type), '[]'::JSONB)
  INTO v_items
  FROM public.inventory inv
  LEFT JOIN public.items it ON it.id = inv.item_id
  WHERE inv.user_id = p_auth_id AND inv.is_equipped = true;

  RETURN jsonb_build_object(
    'success', true,
    'player', jsonb_build_object(
      'auth_id', v_user.auth_id,
      'username', v_user.username,
      'display_name', v_user.display_name,
      'avatar_url', v_user.avatar_url,
      'level', v_user.level,
      'power', v_user.power,
      'attack', COALESCE(v_user.attack, 10),
      'defense', COALESCE(v_user.defense, 10),
      'pvp_rating', COALESCE(v_user.pvp_rating, 1000),
      'pvp_wins', COALESCE(v_user.pvp_wins, 0),
      'pvp_losses', COALESCE(v_user.pvp_losses, 0),
      'character_class', COALESCE(v_user.character_class, '')
    ),
    'items', v_items
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_pvp_loadout(UUID) TO authenticated;
