BEGIN;

-- Add defense_added_at to territories to track when defense was last added
ALTER TABLE public.guild_war_territories ADD COLUMN IF NOT EXISTS defense_added_at timestamptz;

-- Add territory_income to guilds to track income from territories
ALTER TABLE public.guilds ADD COLUMN IF NOT EXISTS territory_income integer DEFAULT 0;

-- RPC to add defense to a territory
DROP FUNCTION IF EXISTS public.add_territory_defense(uuid, integer) CASCADE;
CREATE OR REPLACE FUNCTION public.add_territory_defense(
  p_territory_id uuid,
  p_gems integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_guild_id uuid;
  v_territory record;
  v_player_gems integer;
  v_defense_increase integer;
BEGIN
  -- Get player's guild
  SELECT guild_id INTO v_guild_id 
  FROM public.users 
  WHERE auth_id = v_player_id;

  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  -- Get territory
  SELECT * INTO v_territory 
  FROM public.guild_war_territories 
  WHERE id = p_territory_id;

  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  -- Check ownership
  IF v_territory.owner_guild_id != v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Sadece kendi bölgenize savunma ekleyebilirsiniz.');
  END IF;

  -- Check player gems
  SELECT gems INTO v_player_gems
  FROM public.users
  WHERE auth_id = v_player_id;

  IF v_player_gems < p_gems THEN
    RETURN json_build_object('success', false, 'error', 'Yeterli elmasınız yok.');
  END IF;

  -- Calculate defense increase (e.g., 1 gem = 10 defense power)
  v_defense_increase := p_gems * 10;

  -- Deduct gems
  UPDATE public.users
  SET gems = gems - p_gems
  WHERE auth_id = v_player_id;

  -- Add defense
  UPDATE public.guild_war_territories
  SET defense_power = defense_power + v_defense_increase,
      defense_added_at = now()
  WHERE id = p_territory_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Savunma başarıyla eklendi.',
    'new_defense', v_territory.defense_power + v_defense_increase
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_territory_defense(uuid, integer) TO authenticated;

-- RPC to distribute territory income
CREATE OR REPLACE FUNCTION public.distribute_territory_income(
  p_amount integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_guild record;
  v_member_count integer;
  v_amount_per_member integer;
BEGIN
  -- Get player's guild and check if leader
  SELECT g.* INTO v_guild
  FROM public.guilds g
  JOIN public.users u ON u.guild_id = g.id
  WHERE u.auth_id = v_player_id AND g.leader_id = v_player_id;

  IF v_guild IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Sadece lonca lideri gelir dağıtabilir.');
  END IF;

  -- Check guild income
  IF v_guild.territory_income < p_amount THEN
    RETURN json_build_object('success', false, 'error', 'Loncanın yeterli geliri yok.');
  END IF;

  -- Get member count
  SELECT COUNT(*) INTO v_member_count
  FROM public.users
  WHERE guild_id = v_guild.id;

  IF v_member_count = 0 THEN
    RETURN json_build_object('success', false, 'error', 'Loncada üye yok.');
  END IF;

  -- Calculate amount per member
  v_amount_per_member := p_amount / v_member_count;

  -- Deduct from guild income
  UPDATE public.guilds
  SET territory_income = territory_income - p_amount
  WHERE id = v_guild.id;

  -- Add to members' gold
  UPDATE public.users
  SET gold = gold + v_amount_per_member
  WHERE guild_id = v_guild.id;

  RETURN json_build_object(
    'success', true,
    'message', 'Gelir başarıyla dağıtıldı.',
    'amount_per_member', v_amount_per_member
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.distribute_territory_income(integer) TO authenticated;

-- RPC to collect territory income (called periodically, e.g., daily)
CREATE OR REPLACE FUNCTION public.collect_territory_income()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Add income to guilds based on territories they own
  -- Example: 1000 gold per territory
  UPDATE public.guilds g
  SET territory_income = territory_income + (
    SELECT COUNT(*) * 1000
    FROM public.guild_war_territories t
    WHERE t.owner_guild_id = g.id
  );
END;
$$;

COMMIT;
