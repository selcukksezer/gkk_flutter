-- ============================================================
-- Migration: Guild War RPCs — Eksik fonksiyonlar
-- ============================================================
-- Bu migration:
--   1) guild_war_seasons tablosu (yoksa)
--   2) guild_war_tournaments tablosu (yoksa)
--   3) guild_war_territories tablosu (yoksa)
--   4) get_guild_war_season() RPC
--   5) get_guild_war_tournaments() RPC
--   6) get_guild_war_territories() RPC
--   7) get_guild_war_rankings() RPC
--   8) join_guild_war() RPC
--   9) attack_guild_war_territory() RPC
-- ============================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- TABLO 1: guild_war_seasons
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.guild_war_seasons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_number integer NOT NULL,
  week_number integer NOT NULL,
  start_at timestamptz NOT NULL DEFAULT now(),
  end_at timestamptz NOT NULL DEFAULT now() + interval '7 days',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.guild_war_seasons ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view guild war seasons" ON public.guild_war_seasons FOR SELECT USING (true);

-- ─────────────────────────────────────────────────────────────
-- TABLO 2: guild_war_tournaments
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.guild_war_tournaments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id uuid REFERENCES public.guild_war_seasons(id) ON DELETE CASCADE,
  name text NOT NULL,
  status text DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'active', 'completed')),
  guild_count integer DEFAULT 0,
  prize_pool text DEFAULT '0',
  start_at timestamptz,
  end_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.guild_war_tournaments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view tournaments" ON public.guild_war_tournaments FOR SELECT USING (true);

-- ─────────────────────────────────────────────────────────────
-- TABLO 3: guild_war_territories
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.guild_war_territories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  owner_guild_id uuid REFERENCES public.guilds(id) ON DELETE SET NULL,
  defense_power integer DEFAULT 0,
  reward text DEFAULT '',
  base_defense_power integer DEFAULT 1000,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.guild_war_territories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view territories" ON public.guild_war_territories FOR SELECT USING (true);

-- ─────────────────────────────────────────────────────────────
-- TABLO 4: guild_war_rankings
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.guild_war_rankings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id uuid REFERENCES public.guild_war_seasons(id) ON DELETE CASCADE,
  guild_id uuid REFERENCES public.guilds(id) ON DELETE CASCADE,
  points integer DEFAULT 0,
  wins integer DEFAULT 0,
  losses integer DEFAULT 0,
  updated_at timestamptz DEFAULT now(),
  UNIQUE (season_id, guild_id)
);

ALTER TABLE public.guild_war_rankings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view rankings" ON public.guild_war_rankings FOR SELECT USING (true);

-- ─────────────────────────────────────────────────────────────
-- TABLO 5: guild_war_participants
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.guild_war_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id uuid REFERENCES public.guild_war_tournaments(id) ON DELETE CASCADE,
  guild_id uuid REFERENCES public.guilds(id) ON DELETE CASCADE,
  joined_at timestamptz DEFAULT now(),
  UNIQUE (tournament_id, guild_id)
);

ALTER TABLE public.guild_war_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view participants" ON public.guild_war_participants FOR SELECT USING (true);

-- ─────────────────────────────────────────────────────────────
-- RPC 1: get_guild_war_season
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_guild_war_season()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_season record;
BEGIN
  SELECT season_number, week_number 
  FROM public.guild_war_seasons 
  WHERE is_active = true 
  ORDER BY created_at DESC 
  LIMIT 1 
  INTO v_season;

  IF v_season IS NULL THEN
    RETURN json_build_object('season', 1, 'week', 1);
  END IF;

  RETURN json_build_object(
    'season', v_season.season_number,
    'week', v_season.week_number
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_war_season() TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- RPC 2: get_guild_war_tournaments
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_guild_war_tournaments()
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
      t.status,
      COALESCE(t.guild_count, 0) AS "guildCount",
      t.prize_pool AS "prizePool"
    FROM public.guild_war_tournaments t
    ORDER BY t.created_at DESC
  ) t;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_war_tournaments() TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- RPC 3: get_guild_war_territories
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
      COALESCE(g.name, '—') AS "owner_guild",
      t.defense_power AS "defense_power",
      t.reward
    FROM public.guild_war_territories t
    LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
    ORDER BY t.name
  ) t;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_war_territories() TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- RPC 4: get_guild_war_rankings
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_guild_war_rankings()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_active_season_id uuid;
  v_result json;
BEGIN
  SELECT id INTO v_active_season_id 
  FROM public.guild_war_seasons 
  WHERE is_active = true 
  ORDER BY created_at DESC 
  LIMIT 1;

  IF v_active_season_id IS NULL THEN
    RETURN '[]'::json;
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_result
  FROM (
    SELECT 
      ROW_NUMBER() OVER (ORDER BY r.points DESC) AS rank,
      g.name AS "guild_name",
      r.points,
      r.wins,
      r.losses
    FROM public.guild_war_rankings r
    JOIN public.guilds g ON g.id = r.guild_id
    WHERE r.season_id = v_active_season_id
    ORDER BY r.points DESC
    LIMIT 50
  ) t;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_war_rankings() TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- RPC 5: join_guild_war
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.join_guild_war(
  p_tournament_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_guild_id uuid;
BEGIN
  -- Oyuncunun loncasını bul
  SELECT guild_id INTO v_guild_id 
  FROM public.users 
  WHERE auth_id = v_player_id;

  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  -- Zaten katılmış mı?
  IF EXISTS (
    SELECT 1 FROM public.guild_war_participants 
    WHERE tournament_id = p_tournament_id AND guild_id = v_guild_id
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Zaten bu turnuvaya katıldınız.');
  END IF;

  -- Katıl
  INSERT INTO public.guild_war_participants (tournament_id, guild_id)
  VALUES (p_tournament_id, v_guild_id);

  -- Lonca sayısını güncelle
  UPDATE public.guild_war_tournaments 
  SET guild_count = guild_count + 1 
  WHERE id = p_tournament_id;

  RETURN json_build_object('success', true, 'message', 'Turnuvaya katıldınız!');
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_guild_war(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- RPC 6: attack_guild_war_territory
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
  -- Oyuncunun loncasını bul
  SELECT guild_id INTO v_guild_id 
  FROM public.users 
  WHERE auth_id = v_player_id;

  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  -- Bölgeyi getir
  SELECT * INTO v_territory 
  FROM public.guild_war_territories 
  WHERE id = p_territory_id;

  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  -- Kendi loncasına saldırmasın
  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  -- Saldırı gücü hesapla (oyuncu seviyesine göre basit bir hesaplama)
  SELECT COALESCE(level * 50, 100) INTO v_attack_power 
  FROM public.users WHERE auth_id = v_player_id;

  -- Başarı şansı: saldırı gücü / savunma gücü
  v_success := (random() * v_attack_power) > (random() * v_territory.defense_power);
  v_points_gained := CASE WHEN v_success THEN 100 ELSE 10 END;

  -- Aktif sezonu bul
  SELECT id INTO v_active_season_id 
  FROM public.guild_war_seasons 
  WHERE is_active = true 
  ORDER BY created_at DESC 
  LIMIT 1;

  -- Skoru güncelle
  IF v_active_season_id IS NOT NULL THEN
    INSERT INTO public.guild_war_rankings (season_id, guild_id, points, wins, losses)
    VALUES (v_active_season_id, v_guild_id, v_points_gained, CASE WHEN v_success THEN 1 ELSE 0 END, CASE WHEN v_success THEN 0 ELSE 1 END)
    ON CONFLICT (season_id, guild_id) 
    DO UPDATE SET 
      points = guild_war_rankings.points + v_points_gained,
      wins = guild_war_rankings.wins + (CASE WHEN v_success THEN 1 ELSE 0 END),
      losses = guild_war_rankings.losses + (CASE WHEN v_success THEN 0 ELSE 1 END),
      updated_at = now();
  END IF;

  -- Başarılı olursa bölge sahibini değiştir
  IF v_success THEN
    UPDATE public.guild_war_territories 
    SET owner_guild_id = v_guild_id, 
        defense_power = v_attack_power, 
        updated_at = now()
    WHERE id = p_territory_id;
  END IF;

  RETURN json_build_object(
    'success', v_success,
    'message', CASE WHEN v_success THEN 'Bölge ele geçirildi!' ELSE 'Saldırı başarısız!' END,
    'points_gained', v_points_gained
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.attack_guild_war_territory(uuid) TO authenticated;

COMMIT;