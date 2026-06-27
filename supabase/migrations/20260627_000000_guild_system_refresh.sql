-- =========================================================================================
-- MIGRATION: Guild System Refresh (PLAN_10 full compliance)
-- =========================================================================================

BEGIN;

-- ── 1. Monument level costs table ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.monument_level_costs (
  level INT PRIMARY KEY CHECK (level BETWEEN 1 AND 100),
  structural BIGINT NOT NULL DEFAULT 0,
  mystical BIGINT NOT NULL DEFAULT 0,
  critical BIGINT NOT NULL DEFAULT 0,
  gold BIGINT NOT NULL DEFAULT 0,
  blueprint_type TEXT CHECK (blueprint_type IS NULL OR blueprint_type IN ('phoenix','leviathan','titan','world_eater','eternal'))
);

CREATE OR REPLACE FUNCTION public.guild_size_multiplier(p_member_count INT)
RETURNS NUMERIC LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_member_count <= 10 THEN 0.35
    WHEN p_member_count <= 20 THEN 0.55
    WHEN p_member_count <= 30 THEN 0.75
    WHEN p_member_count <= 40 THEN 0.90
    ELSE 1.00
  END;
$$;

CREATE OR REPLACE FUNCTION public._monument_level_for_auth(p_auth_id UUID)
RETURNS INT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(g.monument_level, 0)
  FROM public.users u
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE u.auth_id = p_auth_id;
$$;

CREATE OR REPLACE FUNCTION public._monument_energy_bonus(p_level INT)
RETURNS INT LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  RETURN (CASE WHEN p_level >= 15 THEN 5 ELSE 0 END)
       + (CASE WHEN p_level >= 50 THEN 10 ELSE 0 END)
       + (CASE WHEN p_level >= 75 THEN 15 ELSE 0 END)
       + (CASE WHEN p_level >= 100 THEN 20 ELSE 0 END);
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_guild_member_monument_stats(p_guild_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_level INT;
BEGIN
  SELECT monument_level INTO v_level FROM public.guilds WHERE id = p_guild_id;
  IF NOT FOUND THEN RETURN; END IF;
  UPDATE public.users u
  SET max_energy = 100 + public._monument_energy_bonus(v_level)
  WHERE u.guild_id = p_guild_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.grant_monument_resource_items(
  p_auth_id UUID,
  p_structural INT DEFAULT 0,
  p_mystical INT DEFAULT 0,
  p_critical INT DEFAULT 0
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_res JSONB;
BEGIN
  IF p_structural > 0 THEN
    v_res := public.add_inventory_item_v2(jsonb_build_object('item_id','resource_structural','quantity',p_structural,'allow_stack',true), NULL);
    IF COALESCE((v_res->>'success')::boolean,false) = false THEN
      RETURN jsonb_build_object('success', false, 'error', COALESCE(v_res->>'error','structural add failed'));
    END IF;
  END IF;
  IF p_mystical > 0 THEN
    v_res := public.add_inventory_item_v2(jsonb_build_object('item_id','resource_mystical','quantity',p_mystical,'allow_stack',true), NULL);
    IF COALESCE((v_res->>'success')::boolean,false) = false THEN
      RETURN jsonb_build_object('success', false, 'error', COALESCE(v_res->>'error','mystical add failed'));
    END IF;
  END IF;
  IF p_critical > 0 THEN
    v_res := public.add_inventory_item_v2(jsonb_build_object('item_id','resource_critical','quantity',p_critical,'allow_stack',true), NULL);
    IF COALESCE((v_res->>'success')::boolean,false) = false THEN
      RETURN jsonb_build_object('success', false, 'error', COALESCE(v_res->>'error','critical add failed'));
    END IF;
  END IF;
  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_monument_dungeon_drops()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_zone INT;
  v_is_boss BOOLEAN;
  v_structural INT := 0;
  v_mystical INT := 0;
  v_critical INT := 0;
BEGIN
  IF NOT NEW.success THEN RETURN NEW; END IF;
  SELECT COALESCE(d.zone, 1), COALESCE(d.is_boss, false)
  INTO v_zone, v_is_boss
  FROM public.dungeons d WHERE d.id = NEW.dungeon_id;

  IF v_zone <= 3 THEN v_structural := 2 + floor(random() * 9)::INT;
  ELSIF v_zone <= 5 THEN v_structural := 5 + floor(random() * 16)::INT;
  ELSE v_structural := 10 + floor(random() * 21)::INT;
  END IF;

  IF v_is_boss THEN
    IF v_zone <= 3 THEN v_mystical := 5 + floor(random() * 16)::INT;
    ELSIF v_zone <= 5 THEN v_mystical := 15 + floor(random() * 26)::INT;
    ELSE v_mystical := 30 + floor(random() * 51)::INT;
    END IF;
  END IF;

  IF v_zone >= 6 AND random() <= CASE WHEN v_zone >= 7 THEN 0.50 ELSE 0.30 END THEN
    v_critical := CASE WHEN v_zone >= 7 THEN 2 + floor(random() * 4)::INT ELSE 1 + floor(random() * 3)::INT END;
  END IF;

  IF v_is_boss AND v_zone >= 5 THEN
    v_critical := v_critical + 5 + floor(random() * 11)::INT;
  END IF;

  PERFORM public.grant_monument_resource_items(NEW.player_id, v_structural, v_mystical, v_critical);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_monument_dungeon_drops ON public.dungeon_runs;
CREATE TRIGGER trg_monument_dungeon_drops
  AFTER INSERT ON public.dungeon_runs
  FOR EACH ROW EXECUTE FUNCTION public.apply_monument_dungeon_drops();

CREATE OR REPLACE FUNCTION public.get_monument_upgrade_preview(p_guild_id UUID)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_guild RECORD;
  v_cost RECORD;
  v_members INT;
  v_mult NUMERIC;
  v_next INT;
BEGIN
  SELECT * INTO v_guild FROM public.guilds WHERE id = p_guild_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error','Lonca bulunamadi'); END IF;
  v_next := v_guild.monument_level + 1;
  IF v_next > 100 THEN RETURN jsonb_build_object('max_level', true); END IF;
  SELECT * INTO v_cost FROM public.monument_level_costs WHERE level = v_next;
  IF NOT FOUND THEN RETURN jsonb_build_object('error','Maliyet tanimi yok'); END IF;
  SELECT COUNT(*)::INT INTO v_members FROM public.users WHERE guild_id = p_guild_id;
  v_mult := public.guild_size_multiplier(v_members);
  RETURN jsonb_build_object(
    'next_level', v_next,
    'structural', CEIL(v_cost.structural * v_mult)::BIGINT,
    'mystical', CEIL(v_cost.mystical * v_mult)::BIGINT,
    'critical', CEIL(v_cost.critical * v_mult)::BIGINT,
    'gold', CEIL(v_cost.gold * v_mult)::BIGINT,
    'blueprint_type', v_cost.blueprint_type,
    'size_multiplier', v_mult,
    'member_count', v_members
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_monument_upgrade_preview(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_guild_monument_bonuses(p_auth_id UUID DEFAULT auth.uid())
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_level INT;
  v_every5 INT;
BEGIN
  v_level := public._monument_level_for_auth(p_auth_id);
  v_every5 := (v_level / 5);
  RETURN jsonb_build_object(
    'monument_level', v_level,
    'xp_bonus_pct', (CASE WHEN v_level >= 5 THEN 5 ELSE 0 END + CASE WHEN v_level >= 50 THEN 5 ELSE 0 END + CASE WHEN v_level >= 75 THEN 8 ELSE 0 END) + v_every5 * 0.2,
    'gold_bonus_pct', (CASE WHEN v_level >= 10 THEN 3 ELSE 0 END) + v_every5 * 0.2,
    'max_energy_bonus', public._monument_energy_bonus(v_level),
    'overdose_reduction_pct', CASE WHEN v_level >= 20 THEN 10 ELSE 0 END,
    'facility_speed_pct', CASE WHEN v_level >= 25 THEN 5 ELSE 0 END,
    'loot_luck_bonus', CASE WHEN v_level >= 30 THEN 10 ELSE 0 END,
    'craft_success_pct', CASE WHEN v_level >= 35 THEN 3 ELSE 0 END,
    'pvp_gold_loss_reduction_pct', CASE WHEN v_level >= 40 THEN 10 ELSE 0 END,
    'enhancement_gold_reduction_pct', (CASE WHEN v_level >= 45 THEN 3 ELSE 0 END + CASE WHEN v_level >= 90 THEN 5 ELSE 0 END),
    'boss_success_pct', CASE WHEN v_level >= 55 THEN 5 ELSE 0 END,
    'hospital_reduction_pct', CASE WHEN v_level >= 60 THEN 10 ELSE 0 END,
    'reputation_bonus_pct', CASE WHEN v_level >= 70 THEN 5 ELSE 0 END,
    'stat_bonus_pct', v_every5 * 0.5
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_monument_bonuses(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.upgrade_monument(p_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user RECORD;
  v_guild RECORD;
  v_next_level INT;
  v_cost RECORD;
  v_members INT;
  v_mult NUMERIC;
  v_req_structural BIGINT;
  v_req_mystical BIGINT;
  v_req_critical BIGINT;
  v_req_gold BIGINT;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz islem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bir loncaya uye degilsiniz');
  END IF;

  IF COALESCE(v_user.guild_role, '') NOT IN ('leader', 'officer', 'commander') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkiniz yok (Lider veya Subay gerekli)');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_user.guild_id FOR UPDATE;
  v_next_level := v_guild.monument_level + 1;
  IF v_next_level > 100 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Anit zaten maksimum seviyede');
  END IF;

  SELECT * INTO v_cost FROM public.monument_level_costs WHERE level = v_next_level;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seviye maliyeti tanimli degil');
  END IF;

  SELECT COUNT(*)::INT INTO v_members FROM public.users WHERE guild_id = v_guild.id;
  v_mult := public.guild_size_multiplier(v_members);
  v_req_structural := CEIL(v_cost.structural * v_mult)::BIGINT;
  v_req_mystical := CEIL(v_cost.mystical * v_mult)::BIGINT;
  v_req_critical := CEIL(v_cost.critical * v_mult)::BIGINT;
  v_req_gold := CEIL(v_cost.gold * v_mult)::BIGINT;

  IF v_cost.blueprint_type IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.guild_blueprints
      WHERE guild_id = v_guild.id AND blueprint_type = v_cost.blueprint_type AND is_complete = true
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', v_cost.blueprint_type || ' blueprint tamamlanmali');
    END IF;
  END IF;

  IF v_guild.monument_structural < v_req_structural OR
     v_guild.monument_mystical < v_req_mystical OR
     v_guild.monument_critical < v_req_critical OR
     v_guild.monument_gold_pool < v_req_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli kaynak yok');
  END IF;

  UPDATE public.guilds SET
    monument_level = v_next_level,
    monument_structural = monument_structural - v_req_structural,
    monument_mystical = monument_mystical - v_req_mystical,
    monument_critical = monument_critical - v_req_critical,
    monument_gold_pool = monument_gold_pool - v_req_gold,
    monument_100_first = CASE WHEN v_next_level = 100 AND NOT EXISTS (SELECT 1 FROM public.guilds WHERE monument_level >= 100 AND id != v_guild.id) THEN true ELSE monument_100_first END,
    monument_100_at = CASE WHEN v_next_level = 100 THEN now() ELSE monument_100_at END
  WHERE id = v_guild.id;

  INSERT INTO public.monument_upgrades (guild_id, from_level, to_level, structural_spent, mystical_spent, critical_spent, gold_spent, upgraded_by)
  VALUES (v_guild.id, v_guild.monument_level, v_next_level, v_req_structural, v_req_mystical, v_req_critical, v_req_gold, p_user_id);

  PERFORM public.sync_guild_member_monument_stats(v_guild.id);

  RETURN jsonb_build_object('success', true, 'new_level', v_next_level);
END;
$$;

-- Facility collect: grant structural (+ mystical for high level facilities)
CREATE OR REPLACE FUNCTION public.grant_monument_facility_collect(
  p_auth_id UUID,
  p_facility_level INT,
  p_collected_count INT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_structural INT;
  v_mystical INT := 0;
BEGIN
  IF p_collected_count <= 0 THEN RETURN; END IF;
  v_structural := GREATEST(1, LEAST(5, 1 + p_collected_count / 10));
  IF p_facility_level >= 7 THEN
    v_mystical := GREATEST(0, LEAST(3, p_facility_level - 6));
  END IF;
  PERFORM public.grant_monument_resource_items(p_auth_id, v_structural, v_mystical, 0);
END;
$$;

-- Seed monument level costs (PLAN_10)
INSERT INTO public.monument_level_costs (level, structural, mystical, critical, gold, blueprint_type) VALUES
  (1, 100, 0, 0, 500000, NULL),
  (2, 200, 0, 0, 1000000, NULL),
  (3, 350, 10, 0, 1500000, NULL),
  (4, 500, 20, 0, 2000000, NULL),
  (5, 700, 30, 0, 3000000, NULL),
  (6, 900, 50, 0, 4000000, NULL),
  (7, 1200, 70, 0, 5000000, NULL),
  (8, 1500, 100, 0, 7000000, NULL),
  (9, 2000, 130, 0, 9000000, NULL),
  (10, 2500, 170, 0, 12000000, NULL),
  (11, 3000, 220, 0, 15000000, NULL),
  (12, 3500, 280, 0, 18000000, NULL),
  (13, 4000, 350, 0, 22000000, NULL),
  (14, 4500, 420, 0, 26000000, NULL),
  (15, 5000, 500, 5, 30000000, NULL),
  (16, 5500, 600, 10, 35000000, NULL),
  (17, 6000, 700, 15, 40000000, NULL),
  (18, 6500, 800, 20, 45000000, NULL),
  (19, 7000, 900, 30, 50000000, NULL),
  (20, 8000, 1000, 40, 60000000, NULL),
  (21, 9000, 1200, 50, 70000000, NULL),
  (22, 10000, 1400, 65, 80000000, NULL),
  (23, 11000, 1600, 80, 90000000, NULL),
  (24, 12000, 1800, 100, 100000000, NULL),
  (25, 13000, 2000, 120, 120000000, NULL),
  (26, 14000, 2500, 150, 140000000, NULL),
  (27, 15000, 3000, 180, 160000000, NULL),
  (28, 16000, 3500, 220, 180000000, NULL),
  (29, 17000, 4000, 260, 200000000, NULL),
  (30, 18000, 5000, 300, 250000000, NULL),
  (31, 19000, 5500, 350, 280000000, NULL),
  (32, 20000, 6000, 400, 310000000, NULL),
  (33, 21000, 6500, 450, 340000000, NULL),
  (34, 22000, 7000, 500, 370000000, NULL),
  (35, 23000, 8000, 560, 400000000, NULL),
  (36, 24000, 9000, 620, 440000000, NULL),
  (37, 25000, 10000, 680, 480000000, NULL),
  (38, 26000, 11000, 750, 520000000, NULL),
  (39, 27000, 12000, 820, 560000000, NULL),
  (40, 28000, 13000, 900, 600000000, NULL),
  (41, 30000, 14000, 1000, 650000000, NULL),
  (42, 32000, 15000, 1100, 700000000, NULL),
  (43, 34000, 16000, 1200, 750000000, NULL),
  (44, 36000, 17000, 1300, 800000000, NULL),
  (45, 38000, 18000, 1400, 850000000, NULL),
  (46, 40000, 19000, 1500, 900000000, NULL),
  (47, 42000, 20000, 1600, 950000000, NULL),
  (48, 44000, 22000, 1800, 1000000000, NULL),
  (49, 46000, 24000, 2000, 1100000000, NULL),
  (50, 50000, 26000, 2200, 1200000000, NULL),
  (51, 52000, 28000, 2500, 1300000000, NULL),
  (52, 54000, 30000, 2800, 1400000000, NULL),
  (53, 56000, 32000, 3100, 1500000000, NULL),
  (54, 58000, 34000, 3400, 1600000000, NULL),
  (55, 60000, 36000, 3700, 1700000000, NULL),
  (56, 63000, 38000, 4000, 1850000000, NULL),
  (57, 66000, 40000, 4300, 2000000000, NULL),
  (58, 69000, 42000, 4600, 2150000000, NULL),
  (59, 72000, 44000, 4900, 2300000000, NULL),
  (60, 75000, 48000, 5200, 2500000000, NULL),
  (61, 78000, 50000, 5500, 2700000000, NULL),
  (62, 81000, 52000, 5800, 2900000000, NULL),
  (63, 84000, 54000, 6200, 3100000000, NULL),
  (64, 87000, 56000, 6600, 3300000000, NULL),
  (65, 90000, 58000, 7000, 3500000000, NULL),
  (66, 93000, 60000, 7500, 3700000000, NULL),
  (67, 96000, 63000, 8000, 3900000000, NULL),
  (68, 100000, 66000, 8500, 4200000000, NULL),
  (69, 104000, 69000, 9000, 4500000000, NULL),
  (70, 108000, 72000, 9500, 4800000000, NULL),
  (71, 112000, 75000, 10000, 5100000000, NULL),
  (72, 116000, 78000, 10500, 5400000000, NULL),
  (73, 120000, 81000, 11000, 5700000000, NULL),
  (74, 125000, 85000, 11500, 6000000000, NULL),
  (75, 130000, 90000, 12000, 6500000000, NULL),
  (76, 135000, 95000, 13000, 7000000000, NULL),
  (77, 140000, 100000, 14000, 7500000000, NULL),
  (78, 145000, 105000, 15000, 8000000000, NULL),
  (79, 150000, 110000, 16000, 8500000000, NULL),
  (80, 160000, 120000, 18000, 10000000000, 'phoenix'),
  (81, 165000, 125000, 19000, 10500000000, NULL),
  (82, 170000, 130000, 20000, 11000000000, NULL),
  (83, 175000, 135000, 21000, 11500000000, NULL),
  (84, 180000, 140000, 22000, 12000000000, NULL),
  (85, 190000, 150000, 24000, 13000000000, 'leviathan'),
  (86, 195000, 155000, 25000, 13500000000, NULL),
  (87, 200000, 160000, 26000, 14000000000, NULL),
  (88, 210000, 165000, 28000, 15000000000, NULL),
  (89, 220000, 170000, 30000, 16000000000, NULL),
  (90, 230000, 180000, 32000, 18000000000, 'titan'),
  (91, 240000, 190000, 34000, 19000000000, NULL),
  (92, 250000, 200000, 36000, 20000000000, NULL),
  (93, 260000, 210000, 38000, 21000000000, NULL),
  (94, 270000, 220000, 40000, 22000000000, NULL),
  (95, 280000, 230000, 42000, 24000000000, 'world_eater'),
  (96, 300000, 245000, 45000, 26000000000, NULL),
  (97, 320000, 260000, 48000, 28000000000, NULL),
  (98, 340000, 280000, 52000, 30000000000, NULL),
  (99, 360000, 300000, 56000, 35000000000, NULL),
  (100, 400000, 350000, 60000, 50000000000, 'eternal')
ON CONFLICT (level) DO UPDATE SET structural=EXCLUDED.structural, mystical=EXCLUDED.mystical, critical=EXCLUDED.critical, gold=EXCLUDED.gold, blueprint_type=EXCLUDED.blueprint_type;

-- ── 2. Guild RPC fixes ───────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.search_guilds(p_query TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_results JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',            g.id,
      'guild_id',      g.id,
      'name',          g.name,
      'level',         g.level,
      'description',   g.description,
      'member_count',  (SELECT COUNT(*) FROM public.users WHERE guild_id = g.id),
      'max_members',   g.max_members,
      'total_power',   COALESCE((SELECT SUM(power) FROM public.users WHERE guild_id = g.id), 0)
    )
  )
  INTO v_results
  FROM public.guilds g
  WHERE g.name ILIKE '%' || p_query || '%'
  LIMIT 20;

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_guild(p_name TEXT, p_description TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_auth_id UUID;
  v_user    RECORD;
  v_guild   RECORD;
  v_tag     TEXT;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT id, guild_id, gold FROM public.users WHERE auth_id = v_auth_id INTO v_user;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanici bulunamadi');
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bir lonca uyesisiniz. Oncelikle loncayi terk edin');
  END IF;

  IF COALESCE(v_user.gold, 0) < 10000000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca kurmak icin 10.000.000 altin gerekli');
  END IF;

  p_name := trim(p_name);
  IF p_name IS NULL OR length(p_name) < 3 OR length(p_name) > 30 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca adi 3-30 karakter arasinda olmali');
  END IF;

  v_tag := left(upper(regexp_replace(p_name, '[^A-Z0-9]', '', 'g')), 30);
  IF v_tag = '' THEN v_tag := left(md5(random()::text), 8); END IF;

  INSERT INTO public.guilds (name, tag, leader_id, description)
  VALUES (p_name, v_tag, v_auth_id, p_description)
  RETURNING * INTO v_guild;

  UPDATE public.users
  SET guild_id = v_guild.id,
      guild_role = 'leader',
      gold = gold - 10000000
  WHERE auth_id = v_auth_id AND gold >= 10000000;

  IF NOT FOUND THEN
    DELETE FROM public.guilds WHERE id = v_guild.id;
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altin');
  END IF;

  INSERT INTO public.guild_contributions (guild_id, user_id)
  VALUES (v_guild.id, v_auth_id)
  ON CONFLICT (guild_id, user_id) DO NOTHING;

  PERFORM public.sync_guild_member_monument_stats(v_guild.id);

  RETURN jsonb_build_object(
    'success', true,
    'guild_id', v_guild.id,
    'name', v_guild.name,
    'role', 'leader'
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu lonca adi zaten alinmis');
END;
$$;

CREATE OR REPLACE FUNCTION public.join_guild(p_guild_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_auth_id UUID;
  v_user    RECORD;
  v_guild   RECORD;
  v_members BIGINT;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT id, guild_id FROM public.users WHERE auth_id = v_auth_id INTO v_user;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanici bulunamadi');
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bir lonca uyesisiniz. Oncelikle loncayi terk edin');
  END IF;

  SELECT * FROM public.guilds WHERE id = p_guild_id INTO v_guild;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca bulunamadi');
  END IF;

  SELECT COUNT(*) INTO v_members FROM public.users WHERE guild_id = p_guild_id;
  IF v_members >= 50 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca dolu (maks. 50 uye)');
  END IF;

  UPDATE public.users
  SET guild_id = p_guild_id,
      guild_role = 'member'
  WHERE auth_id = v_auth_id;

  INSERT INTO public.guild_contributions (guild_id, user_id)
  VALUES (p_guild_id, v_auth_id)
  ON CONFLICT (guild_id, user_id) DO NOTHING;

  PERFORM public.sync_guild_member_monument_stats(p_guild_id);

  RETURN jsonb_build_object(
    'success', true,
    'guild_id', p_guild_id,
    'name', v_guild.name,
    'role', 'member'
  );
END;
$$;

-- Crafting epic+ side product: mystical on successful claim
CREATE OR REPLACE FUNCTION public.grant_monument_craft_byproduct(
  p_auth_id UUID,
  p_output_rarity TEXT,
  p_quantity INT DEFAULT 1
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_mystical INT := 0;
BEGIN
  IF lower(COALESCE(p_output_rarity,'')) IN ('epic','legendary','mythic') THEN
    v_mystical := GREATEST(1, LEAST(5, p_quantity));
    PERFORM public.grant_monument_resource_items(p_auth_id, 0, v_mystical, 0);
  END IF;
END;
$$;

-- Patch collect_facility_resources_v2 to grant monument resources on collect
DO $$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'collect_facility_resources_v2'
  LIMIT 1;

  IF v_def IS NOT NULL AND v_def NOT LIKE '%grant_monument_facility_collect%' THEN
    v_def := replace(
      v_def,
      E'  UPDATE public.facilities\n  SET production_started_at = NULL, updated_at = now()\n  WHERE id = p_facility_id;',
      E'  PERFORM public.grant_monument_facility_collect(v_user_id, COALESCE(v_facility.level, 1), v_added_total);\n\n  UPDATE public.facilities\n  SET production_started_at = NULL, updated_at = now()\n  WHERE id = p_facility_id;'
    );
    EXECUTE v_def;
  END IF;
END $$;

-- Monument XP/Gold bonus in enter_dungeon success path
DO $$
DECLARE
  v_def TEXT;
  v_old TEXT := E'    v_gold := floor(v_gold * v_reward_mult);\n    v_xp   := floor(v_xp   * v_reward_mult);';
  v_new TEXT := E'    v_gold := floor(v_gold * v_reward_mult);\n    v_xp   := floor(v_xp   * v_reward_mult);\n    IF public._monument_level_for_auth(p_player_id) >= 5 THEN\n      v_xp := floor(v_xp * (1.05 + (public._monument_level_for_auth(p_player_id) / 5) * 0.002));\n    END IF;\n    IF public._monument_level_for_auth(p_player_id) >= 10 THEN\n      v_gold := floor(v_gold * (1.03 + (public._monument_level_for_auth(p_player_id) / 5) * 0.002));\n    END IF;';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'enter_dungeon'
  LIMIT 1;

  IF v_def IS NOT NULL AND v_def NOT LIKE '%_monument_level_for_auth%' THEN
    v_def := replace(v_def, v_old, v_new);
    EXECUTE v_def;
  END IF;
END $$;

-- Craft claim: mystical byproduct for epic+ outputs
DO $$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'claim_crafted_item'
  LIMIT 1;

  IF v_def IS NOT NULL AND v_def NOT LIKE '%grant_monument_craft_byproduct%' THEN
    v_def := replace(
      v_def,
      '  RETURN QUERY SELECT true',
      E'  PERFORM public.grant_monument_craft_byproduct(v_user_id, COALESCE((SELECT lower(rarity) FROM public.items WHERE id = v_recipe.output_item_id), ''common''), v_final_qty);\n\n  RETURN QUERY SELECT true'
    );
    EXECUTE v_def;
  END IF;
END $$;

-- Sync existing guild members max_energy from current monument levels
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.guilds LOOP
    PERFORM public.sync_guild_member_monument_stats(r.id);
  END LOOP;
END $$;

COMMIT;
