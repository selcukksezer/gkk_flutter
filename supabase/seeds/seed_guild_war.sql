-- ============================================================
-- Seed: Guild War — Varsayılan sezon, turnuva, bölge, sıralama
-- ============================================================
-- Bu seed, guild_war RPC'lerinin boş dönmemesi için gerekli temel verileri ekler.
-- Not: Tablolar mevcut değilse önce migration çalıştırılmalıdır.

BEGIN;

-- 1. Varsayılan aktif sezon
INSERT INTO public.guild_war_seasons (id, season_number, week_number, start_at, end_at, is_active)
VALUES (
  '00000000-0000-0000-0000-000000010001',
  1,
  1,
  now(),
  now() + interval '7 days',
  true
)
ON CONFLICT (id) DO NOTHING;

-- 2. Turnuvalar
INSERT INTO public.guild_war_tournaments (id, season_id, name, status, guild_count, prize_pool, start_at, end_at)
VALUES
  (
    '00000000-0000-0000-0000-000000020001',
    '00000000-0000-0000-0000-000000010001',
    'Haftalık Arena',
    'active',
    0,
    '50,000 Altın',
    now(),
    now() + interval '7 days'
  ),
  (
    '00000000-0000-0000-0000-000000020002',
    '00000000-0000-0000-0000-000000010001',
    'Sezon Finali',
    'upcoming',
    0,
    '250,000 Altın + Efsanevi Eşya',
    now() + interval '14 days',
    now() + interval '21 days'
  )
ON CONFLICT (id) DO NOTHING;

-- 3. Bölgeler (daha önce seed eklenmiş mi diye kontrol)
INSERT INTO public.guild_war_territories (id, name, owner_guild_id, defense_power, reward, base_defense_power, trade_income, defense_line_level)
VALUES
  ('00000000-0000-0000-0000-000000030001', 'Demir Kalesi', NULL, 1200, '5,000 Altın/gün', 1000, 5000, 2),
  ('00000000-0000-0000-0000-000000030002', 'Altın Ovası', NULL, 800, '3,000 Altın/gün', 800, 3000, 1),
  ('00000000-0000-0000-0000-000000030003', 'Ejderha Tepesi', NULL, 2500, 'Efsanevi Eşya Şansı', 2500, 8000, 3),
  ('00000000-0000-0000-0000-000000030004', 'Karanlık Liman', NULL, 600, '2,000 Altın/gün', 600, 2000, 1)
ON CONFLICT (id) DO NOTHING;

-- 4. Sıralama (mevcut loncalardan)
INSERT INTO public.guild_war_rankings (season_id, guild_id, points, wins, losses)
SELECT
  '00000000-0000-0000-0000-000000010001'::uuid,
  g.id,
  (3000 - (ROW_NUMBER() OVER (ORDER BY g.created_at) * 400))::integer,
  (5 - ROW_NUMBER() OVER (ORDER BY g.created_at))::integer + 3,
  ROW_NUMBER() OVER (ORDER BY g.created_at)::integer
FROM public.guilds g
ORDER BY g.created_at
LIMIT 5
ON CONFLICT (season_id, guild_id) DO UPDATE SET
  points = EXCLUDED.points,
  wins = EXCLUDED.wins,
  losses = EXCLUDED.losses,
  updated_at = now();

-- 5. Turnuva katılımcıları
INSERT INTO public.guild_war_participants (tournament_id, guild_id)
SELECT
  '00000000-0000-0000-0000-000000020001'::uuid,
  g.id
FROM public.guilds g
ORDER BY g.created_at
LIMIT 4
ON CONFLICT (tournament_id, guild_id) DO NOTHING;

UPDATE public.guild_war_tournaments
SET guild_count = (
  SELECT COUNT(*) FROM public.guild_war_participants
  WHERE tournament_id = '00000000-0000-0000-0000-000000020001'::uuid
)
WHERE id = '00000000-0000-0000-0000-000000020001'::uuid;

-- 6. Krallık seçimi (7 gün süreli aktif seçim)
INSERT INTO public.kingdom_elections (id, month, status, start_at, end_at)
VALUES (
  '00000000-0000-0000-0000-000000050001',
  date_trunc('month', now())::date,
  'active',
  now(),
  now() + interval '7 days'
)
ON CONFLICT (month) DO UPDATE SET
  status = 'active',
  start_at = now(),
  end_at = now() + interval '7 days',
  winner_guild_id = NULL;

-- 7. Savaş kayıtları (lonca varsa)
INSERT INTO public.guild_war_attack_logs (
  id, territory_id, attacker_guild_id, defender_guild_id,
  attack_power, defense_power, success, points_gained, created_at
)
SELECT
  '00000000-0000-0000-0000-000000040001'::uuid,
  '00000000-0000-0000-0000-000000030001'::uuid,
  g1.id,
  NULL,
  1500, 1200, true, 100,
  now() - interval '2 hours'
FROM public.guilds g1
ORDER BY g1.created_at
LIMIT 1
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.guild_war_attack_logs (
  id, territory_id, attacker_guild_id, defender_guild_id,
  attack_power, defense_power, success, points_gained, created_at
)
SELECT
  '00000000-0000-0000-0000-000000040002'::uuid,
  '00000000-0000-0000-0000-000000030002'::uuid,
  g1.id,
  g2.id,
  800, 1200, false, 10,
  now() - interval '5 hours'
FROM public.guilds g1
JOIN public.guilds g2 ON g2.id != g1.id
ORDER BY g1.created_at, g2.created_at
LIMIT 1
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.guild_war_attack_logs (
  id, territory_id, attacker_guild_id, defender_guild_id,
  attack_power, defense_power, success, points_gained, created_at
)
SELECT
  '00000000-0000-0000-0000-000000040003'::uuid,
  '00000000-0000-0000-0000-000000030003'::uuid,
  g1.id,
  g2.id,
  2200, 2500, false, 10,
  now() - interval '1 day'
FROM public.guilds g1
JOIN public.guilds g2 ON g2.id != g1.id
ORDER BY g1.created_at DESC, g2.created_at
LIMIT 1
ON CONFLICT (id) DO NOTHING;

COMMIT;