-- ============================================================
-- Migration: Guild War v2 — attack logs, detail RPCs, territory fields
-- ============================================================

BEGIN;

-- Territory extra fields
ALTER TABLE public.guild_war_territories
  ADD COLUMN IF NOT EXISTS defense_line_level integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS trade_income integer DEFAULT 0;

-- ─────────────────────────────────────────────────────────────
-- TABLE: guild_war_attack_logs
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.guild_war_attack_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  territory_id uuid NOT NULL REFERENCES public.guild_war_territories(id) ON DELETE CASCADE,
  attacker_guild_id uuid NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  defender_guild_id uuid REFERENCES public.guilds(id) ON DELETE SET NULL,
  attack_power integer NOT NULL DEFAULT 0,
  defense_power integer NOT NULL DEFAULT 0,
  success boolean NOT NULL DEFAULT false,
  points_gained integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_guild_war_attack_logs_territory
  ON public.guild_war_attack_logs(territory_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_guild_war_attack_logs_attacker
  ON public.guild_war_attack_logs(attacker_guild_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_guild_war_attack_logs_defender
  ON public.guild_war_attack_logs(defender_guild_id, created_at DESC);

ALTER TABLE public.guild_war_attack_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view attack logs" ON public.guild_war_attack_logs;
CREATE POLICY "Anyone can view attack logs"
  ON public.guild_war_attack_logs FOR SELECT USING (true);

-- ─────────────────────────────────────────────────────────────
-- RPC: get_guild_war_season (extended with end_at)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_guild_war_season()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_season record;
BEGIN
  SELECT season_number, week_number, end_at
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1
  INTO v_season;

  IF v_season IS NULL THEN
    RETURN json_build_object('season', 1, 'week', 1, 'end_at', null);
  END IF;

  RETURN json_build_object(
    'season', v_season.season_number,
    'week', v_season.week_number,
    'end_at', v_season.end_at
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- RPC: get_guild_war_territories (extended fields)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_guild_war_territories()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_result
  FROM (
    SELECT
      t.id,
      t.name,
      t.owner_guild_id,
      COALESCE(g.name, 'Sahipsiz') AS "owner_guild",
      t.defense_power,
      t.base_defense_power,
      t.defense_line_level,
      t.reward,
      COALESCE(t.trade_income, 0) AS trade_income
    FROM public.guild_war_territories t
    LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
    ORDER BY t.name
  ) t;

  RETURN v_result;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- RPC: get_guild_war_attack_logs
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_guild_war_attack_logs(
  p_limit integer DEFAULT 50,
  p_guild_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_result
  FROM (
    SELECT
      l.id,
      l.territory_id,
      ter.name AS territory_name,
      l.attacker_guild_id,
      ag.name AS attacker_guild_name,
      l.defender_guild_id,
      dg.name AS defender_guild_name,
      l.attack_power,
      l.defense_power,
      l.success,
      l.points_gained,
      l.created_at
    FROM public.guild_war_attack_logs l
    JOIN public.guild_war_territories ter ON ter.id = l.territory_id
    JOIN public.guilds ag ON ag.id = l.attacker_guild_id
    LEFT JOIN public.guilds dg ON dg.id = l.defender_guild_id
    WHERE p_guild_id IS NULL
       OR l.attacker_guild_id = p_guild_id
       OR l.defender_guild_id = p_guild_id
    ORDER BY l.created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100))
  ) t;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_war_attack_logs(integer, uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- RPC: get_tournament_participants
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_tournament_participants(
  p_tournament_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_result
  FROM (
    SELECT
      p.id,
      p.guild_id,
      g.name AS guild_name,
      p.joined_at
    FROM public.guild_war_participants p
    JOIN public.guilds g ON g.id = p.guild_id
    WHERE p.tournament_id = p_tournament_id
    ORDER BY p.joined_at ASC
  ) t;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_tournament_participants(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- RPC: get_territory_detail
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_territory_detail(
  p_territory_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_territory json;
  v_recent_attacks json;
BEGIN
  SELECT row_to_json(t)
  INTO v_territory
  FROM (
    SELECT
      t.id,
      t.name,
      t.owner_guild_id,
      COALESCE(g.name, 'Sahipsiz') AS owner_guild,
      t.defense_power,
      t.base_defense_power,
      t.defense_line_level,
      t.reward,
      COALESCE(t.trade_income, 0) AS trade_income,
      t.defense_added_at,
      t.updated_at
    FROM public.guild_war_territories t
    LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
    WHERE t.id = p_territory_id
  ) t;

  IF v_territory IS NULL THEN
    RETURN json_build_object('error', 'Bölge bulunamadı.');
  END IF;

  SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json)
  INTO v_recent_attacks
  FROM (
    SELECT
      l.id,
      l.attacker_guild_id,
      ag.name AS attacker_guild_name,
      l.defender_guild_id,
      dg.name AS defender_guild_name,
      l.attack_power,
      l.defense_power,
      l.success,
      l.points_gained,
      l.created_at
    FROM public.guild_war_attack_logs l
    JOIN public.guilds ag ON ag.id = l.attacker_guild_id
    LEFT JOIN public.guilds dg ON dg.id = l.defender_guild_id
    WHERE l.territory_id = p_territory_id
    ORDER BY l.created_at DESC
    LIMIT 5
  ) a;

  RETURN json_build_object(
    'territory', v_territory,
    'recent_attacks', v_recent_attacks
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_territory_detail(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- RPC: attack_guild_war_territory (with attack log insert)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.attack_guild_war_territory(
  p_territory_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_guild_id uuid;
  v_territory record;
  v_attack_power integer;
  v_success boolean;
  v_points_gained integer;
  v_active_season_id uuid;
BEGIN
  SELECT guild_id INTO v_guild_id
  FROM public.users
  WHERE auth_id = v_player_id;

  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  SELECT * INTO v_territory
  FROM public.guild_war_territories
  WHERE id = p_territory_id;

  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  SELECT COALESCE(level * 50, 100) INTO v_attack_power
  FROM public.users WHERE auth_id = v_player_id;

  v_success := (random() * v_attack_power) > (random() * GREATEST(v_territory.defense_power, 1));
  v_points_gained := CASE WHEN v_success THEN 100 ELSE 10 END;

  SELECT id INTO v_active_season_id
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_active_season_id IS NOT NULL THEN
    INSERT INTO public.guild_war_rankings (season_id, guild_id, points, wins, losses)
    VALUES (
      v_active_season_id,
      v_guild_id,
      v_points_gained,
      CASE WHEN v_success THEN 1 ELSE 0 END,
      CASE WHEN v_success THEN 0 ELSE 1 END
    )
    ON CONFLICT (season_id, guild_id)
    DO UPDATE SET
      points = guild_war_rankings.points + v_points_gained,
      wins = guild_war_rankings.wins + (CASE WHEN v_success THEN 1 ELSE 0 END),
      losses = guild_war_rankings.losses + (CASE WHEN v_success THEN 0 ELSE 1 END),
      updated_at = now();
  END IF;

  IF v_success THEN
    UPDATE public.guild_war_territories
    SET owner_guild_id = v_guild_id,
        defense_power = v_attack_power,
        updated_at = now()
    WHERE id = p_territory_id;
  END IF;

  INSERT INTO public.guild_war_attack_logs (
    territory_id,
    attacker_guild_id,
    defender_guild_id,
    attack_power,
    defense_power,
    success,
    points_gained
  ) VALUES (
    p_territory_id,
    v_guild_id,
    v_territory.owner_guild_id,
    v_attack_power,
    v_territory.defense_power,
    v_success,
    v_points_gained
  );

  RETURN json_build_object(
    'success', v_success,
    'message', CASE WHEN v_success THEN 'Bölge ele geçirildi!' ELSE 'Saldırı başarısız!' END,
    'points_gained', v_points_gained,
    'attack_power', v_attack_power,
    'defense_power', v_territory.defense_power,
    'territory_name', v_territory.name
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.attack_guild_war_territory(uuid) TO authenticated;

COMMIT;
