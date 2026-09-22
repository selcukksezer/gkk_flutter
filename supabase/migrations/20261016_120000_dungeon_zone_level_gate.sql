-- Region (dungeon zone) level gates.
-- Gate is per ZONE, not per dungeon. enter_dungeon enforces; client mirrors UX.
-- Thresholds: Z1–Z2 from content power/500 floor; Z3–Z7 compressed to level_cap 70.

BEGIN;

CREATE TABLE IF NOT EXISTS public.dungeon_zones (
  zone_number INTEGER PRIMARY KEY CHECK (zone_number >= 1 AND zone_number <= 20),
  name TEXT NOT NULL,
  dungeon_min INTEGER NOT NULL,
  dungeon_max INTEGER NOT NULL,
  required_level INTEGER NOT NULL DEFAULT 1 CHECK (required_level >= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.dungeon_zones IS
  'Dungeon region catalog. required_level gates region access (not per-dungeon).';
COMMENT ON COLUMN public.dungeon_zones.required_level IS
  'Minimum player level to enter any dungeon in this zone.';

INSERT INTO public.dungeon_zones (zone_number, name, dungeon_min, dungeon_max, required_level)
VALUES
  (1, 'Gölgeli Orman',       1,  10,  1),
  (2, 'Derin Mağara',       11,  20, 15),
  (3, 'Ateş Çölü',          21,  30, 25),
  (4, 'Fırtına Dağı',       31,  40, 35),
  (5, 'Yeraltı Cehennemi',  41,  50, 45),
  (6, 'Kırık Gökyüzü',      51,  60, 55),
  (7, 'Efsanevi Tehlikeler', 61,  65, 65)
ON CONFLICT (zone_number) DO UPDATE SET
  name = EXCLUDED.name,
  dungeon_min = EXCLUDED.dungeon_min,
  dungeon_max = EXCLUDED.dungeon_max,
  required_level = EXCLUDED.required_level;

ALTER TABLE public.dungeon_zones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dungeon_zones_select_authenticated ON public.dungeon_zones;
CREATE POLICY dungeon_zones_select_authenticated
  ON public.dungeon_zones
  FOR SELECT
  TO authenticated
  USING (true);

GRANT SELECT ON public.dungeon_zones TO authenticated;
GRANT SELECT ON public.dungeon_zones TO anon;

CREATE OR REPLACE FUNCTION public.dungeon_zone_required_level(p_zone integer)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(
    (SELECT required_level FROM public.dungeon_zones WHERE zone_number = p_zone),
    1
  );
$$;

CREATE OR REPLACE FUNCTION public.dungeon_zone_level_gate_error(
  p_player_level integer,
  p_dungeon_id text,
  p_zone integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_zone integer;
  v_required integer;
BEGIN
  v_zone := COALESCE(
    NULLIF(p_zone, 0),
    public.dungeon_siege_zone_for_dungeon(p_dungeon_id)
  );
  IF v_zone IS NULL OR v_zone <= 0 THEN
    RETURN NULL;
  END IF;

  v_required := public.dungeon_zone_required_level(v_zone);
  IF COALESCE(p_player_level, 1) < v_required THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Level yetersiz. Gereken: ' || v_required,
      'error_code', 'zone_level_gate',
      'required_level', v_required,
      'zone', v_zone
    );
  END IF;

  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.dungeon_zone_required_level(integer) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.dungeon_zone_level_gate_error(integer, text, integer) TO authenticated, anon;

-- Patch enter_dungeon: declare gate var + reject below zone required_level.
DO $$
DECLARE
  v_def TEXT;
  v_decl_old TEXT := 'v_energy_cost       INT := 0;';
  v_decl_new TEXT := $d$v_energy_cost       INT := 0;
  v_zone_gate         JSONB;$d$;
  v_marker TEXT := $m$
  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'player_not_found');
  END IF;
$m$;
  v_replacement TEXT := $r$
  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'player_not_found');
  END IF;

  -- [GKK_ZONE_LEVEL_GATE_BEGIN]
  v_zone_gate := public.dungeon_zone_level_gate_error(
    COALESCE(v_player.level, 1),
    p_dungeon_id,
    COALESCE(v_dungeon.zone, 0)
  );
  IF v_zone_gate IS NOT NULL THEN
    RETURN v_zone_gate;
  END IF;
  -- [GKK_ZONE_LEVEL_GATE_END]
$r$;
BEGIN
  SELECT pg_get_functiondef('public.enter_dungeon(uuid, text)'::regprocedure)
  INTO v_def;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'enter_dungeon(uuid,text) not found for zone level gate';
  END IF;

  IF position('GKK_ZONE_LEVEL_GATE_BEGIN' IN v_def) > 0 THEN
    RAISE NOTICE 'enter_dungeon already has zone level gate — skip patch';
    RETURN;
  END IF;

  IF position(v_decl_old IN v_def) = 0 THEN
    RAISE EXCEPTION 'enter_dungeon decl marker (v_energy_cost) not found for zone level gate';
  END IF;
  v_def := replace(v_def, v_decl_old, v_decl_new);

  IF position(v_marker IN v_def) = 0 THEN
    RAISE EXCEPTION 'enter_dungeon player_not_found marker not found for zone level gate';
  END IF;
  v_def := replace(v_def, v_marker, v_replacement);

  EXECUTE v_def;
END;
$$;

COMMIT;
