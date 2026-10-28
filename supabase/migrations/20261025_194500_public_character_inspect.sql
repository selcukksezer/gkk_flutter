-- =============================================================================
-- Public Character Inspection & Live Moradon Online Players Power/Gear RPCs
-- Enables tapping any character on Home Screen (Moradon Plaza, Hospital Ward,
-- Prison Cellblock) to inspect their real Total Power, Combat Stats, PvP record,
-- and Equipped Items safely via SECURITY DEFINER (without exposing backpack,
-- gold, gems, email, or private account columns).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_public_character_inspect(p_target_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_u record;
  v_equipped jsonb := '[]'::jsonb;
  v_gear_power bigint := 0;
  v_total_power bigint := 0;
BEGIN
  IF auth.uid() IS NULL
     AND current_user NOT IN ('postgres', 'service_role', 'supabase_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_target_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid target');
  END IF;

  SELECT
    u.id,
    u.auth_id,
    u.username,
    u.display_name,
    u.character_class,
    u.level,
    u.power,
    u.attack,
    u.defense,
    u.health,
    u.max_health,
    u.luck,
    u.equip_bonus_luck,
    u.reputation,
    u.pvp_rating,
    u.pvp_wins,
    u.pvp_losses,
    u.guild_id,
    u.guild_role,
    u.cosmetic_title,
    u.avatar_url,
    u.is_online,
    u.last_active_at,
    u.hospital_until,
    u.prison_until,
    g.name AS guild_name
  INTO v_u
  FROM public.users u
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE u.id = p_target_id OR u.auth_id = p_target_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Character not found');
  END IF;

  WITH eq AS (
    SELECT
      COALESCE(NULLIF(inv.equip_slot, ''), NULLIF(it.equip_slot, ''), 'weapon') AS slot_key,
      inv.item_id,
      COALESCE(NULLIF(it.name_tr, ''), NULLIF(it.name, ''), inv.item_id) AS item_name,
      COALESCE(it.description, inv.description, '') AS item_desc,
      COALESCE(NULLIF(it.icon, ''), NULLIF(inv.icon, ''), '') AS item_icon,
      COALESCE(NULLIF(it.type, ''), 'armor') AS item_type,
      COALESCE(NULLIF(it.rarity, ''), 'common') AS rarity,
      LEAST(GREATEST(COALESCE(inv.enhancement_level, 0), 0), 10) AS enh,
      COALESCE(it.attack, 0) AS base_attack,
      COALESCE(it.defense, 0) AS base_defense,
      COALESCE(it.health, 0) AS base_health,
      COALESCE(it.power, 0) AS base_power,
      COALESCE(it.luck, 0) AS base_luck,
      COALESCE(NULLIF(it.weapon_type, ''), NULLIF(inv.weapon_type, ''), 'none') AS weapon_type,
      COALESCE(NULLIF(it.armor_type, ''), NULLIF(inv.armor_type, ''), 'none') AS armor_type,
      COALESCE(it.required_level, inv.required_level, 1) AS required_level
    FROM public.inventory inv
    LEFT JOIN public.items it ON it.id = inv.item_id
    WHERE (inv.user_id = v_u.auth_id OR inv.user_id = v_u.id)
      AND COALESCE(inv.is_equipped, false) = true
  ),
  eq_scored AS (
    SELECT
      eq.*,
      CASE
        WHEN eq.enh <= 0 THEN 1.0::numeric
        WHEN eq.enh <= 6 THEN (1.0 + eq.enh * 0.12)::numeric
        ELSE (1.72 + (eq.enh - 6) * 0.08)::numeric
      END AS mult
    FROM eq
  )
  SELECT
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'equip_slot', s.slot_key,
          'item_id', s.item_id,
          'name', s.item_name,
          'description', s.item_desc,
          'icon', s.item_icon,
          'item_type', s.item_type,
          'rarity', s.rarity,
          'enhancement_level', s.enh,
          'attack', s.base_attack,
          'defense', s.base_defense,
          'health', s.base_health,
          'power', s.base_power,
          'luck', s.base_luck,
          'weapon_type', s.weapon_type,
          'armor_type', s.armor_type,
          'required_level', s.required_level
        )
        ORDER BY CASE s.slot_key
          WHEN 'weapon' THEN 1
          WHEN 'head' THEN 2
          WHEN 'chest' THEN 3
          WHEN 'gloves' THEN 4
          WHEN 'legs' THEN 5
          WHEN 'boots' THEN 6
          WHEN 'necklace' THEN 7
          WHEN 'ring' THEN 8
          ELSE 9
        END
      ),
      '[]'::jsonb
    ),
    COALESCE(
      SUM(
        FLOOR(
          (s.base_attack + s.base_defense + (s.base_health / 10.0) + (s.base_luck * 2.0))
          * s.mult
        )::bigint
      ),
      0
    )
  INTO v_equipped, v_gear_power
  FROM eq_scored s;

  v_total_power := CASE
    WHEN COALESCE(v_u.power, 0) > 0 THEN v_u.power::bigint
    ELSE (
      COALESCE(v_u.level, 1)::bigint * 500
      + FLOOR(COALESCE(v_u.reputation, 0)::numeric * 0.1)::bigint
      + GREATEST(COALESCE(v_u.luck, 0), 0)::bigint * 50
      + v_gear_power
    )
  END;

  RETURN jsonb_build_object(
    'success', true,
    'character', jsonb_build_object(
      'user_id', v_u.id,
      'username', COALESCE(NULLIF(v_u.username, ''), 'Savaşçı'),
      'display_name', COALESCE(NULLIF(v_u.display_name, ''), NULLIF(v_u.username, ''), 'Savaşçı'),
      'character_class', COALESCE(v_u.character_class, 'savasci'),
      'level', COALESCE(v_u.level, 1),
      'power', v_total_power,
      'attack', COALESCE(v_u.attack, 10),
      'defense', COALESCE(v_u.defense, 10),
      'health', COALESCE(v_u.health, 100),
      'max_health', GREATEST(COALESCE(v_u.max_health, 100), COALESCE(v_u.health, 100)),
      'luck', COALESCE(v_u.luck, 0) + COALESCE(v_u.equip_bonus_luck, 0),
      'reputation', COALESCE(v_u.reputation, 0),
      'pvp_rating', COALESCE(v_u.pvp_rating, 1000),
      'pvp_wins', COALESCE(v_u.pvp_wins, 0),
      'pvp_losses', COALESCE(v_u.pvp_losses, 0),
      'guild_name', v_u.guild_name,
      'guild_role', v_u.guild_role,
      'cosmetic_title', v_u.cosmetic_title,
      'avatar_url', v_u.avatar_url,
      'is_online', public.is_user_online(v_u.is_online, v_u.last_active_at),
      'in_hospital', (v_u.hospital_until IS NOT NULL AND v_u.hospital_until > now()),
      'in_prison', (v_u.prison_until IS NOT NULL AND v_u.prison_until > now()),
      'equipped_items', v_equipped
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_public_character_inspect(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_character_inspect(uuid) TO authenticated, service_role;


CREATE OR REPLACE FUNCTION public.get_online_moradon_players()
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rows jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL
     AND current_user NOT IN ('postgres', 'service_role', 'supabase_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  PERFORM public.sweep_stale_online_users();

  WITH online_plaza AS (
    SELECT
      u.id,
      u.auth_id,
      COALESCE(NULLIF(u.username, ''), 'Savaşçı') AS username,
      COALESCE(NULLIF(u.display_name, ''), NULLIF(u.username, ''), 'Savaşçı') AS display_name,
      COALESCE(u.character_class, 'savasci') AS character_class,
      COALESCE(u.level, 1) AS level,
      CASE
        WHEN COALESCE(u.power, 0) > 0 THEN u.power::bigint
        ELSE (
          COALESCE(u.level, 1)::bigint * 500
          + FLOOR(COALESCE(u.reputation, 0)::numeric * 0.1)::bigint
          + GREATEST(COALESCE(u.luck, 0), 0)::bigint * 50
        )
      END AS power,
      g.name AS guild_name,
      u.cosmetic_title,
      u.last_active_at,
      wpn.weapon_name,
      wpn.weapon_enh,
      wpn.weapon_type,
      wpn.weapon_icon
    FROM public.users u
    LEFT JOIN public.guilds g ON g.id = u.guild_id
    LEFT JOIN LATERAL (
      SELECT
        COALESCE(NULLIF(it.name_tr, ''), NULLIF(it.name, ''), inv.item_id) AS weapon_name,
        LEAST(GREATEST(COALESCE(inv.enhancement_level, 0), 0), 10) AS weapon_enh,
        COALESCE(NULLIF(it.weapon_type, ''), NULLIF(inv.weapon_type, ''), 'none') AS weapon_type,
        COALESCE(NULLIF(it.icon, ''), NULLIF(inv.icon, ''), '') AS weapon_icon
      FROM public.inventory inv
      LEFT JOIN public.items it ON it.id = inv.item_id
      WHERE (inv.user_id = u.auth_id OR inv.user_id = u.id)
        AND COALESCE(inv.is_equipped, false) = true
        AND COALESCE(NULLIF(inv.equip_slot, ''), NULLIF(it.equip_slot, '')) = 'weapon'
      LIMIT 1
    ) wpn ON true
    WHERE public.is_user_online(u.is_online, u.last_active_at) = true
      AND COALESCE(u.is_banned, false) = false
      AND u.character_class IS NOT NULL
      AND (u.hospital_until IS NULL OR u.hospital_until <= now())
      AND (u.prison_until IS NULL OR u.prison_until <= now())
    ORDER BY u.last_active_at DESC
    LIMIT 28
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'username', p.username,
        'display_name', p.display_name,
        'character_class', p.character_class,
        'level', p.level,
        'power', p.power,
        'guild_name', p.guild_name,
        'cosmetic_title', p.cosmetic_title,
        'weapon_name', p.weapon_name,
        'weapon_enh', COALESCE(p.weapon_enh, 0),
        'weapon_type', p.weapon_type,
        'weapon_icon', p.weapon_icon,
        'is_online', true,
        'last_active_at', p.last_active_at
      )
    ),
    '[]'::jsonb
  )
  INTO v_rows
  FROM online_plaza p;

  RETURN jsonb_build_object(
    'success', true,
    'entries', v_rows
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_online_moradon_players() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_online_moradon_players() TO authenticated, service_role;
