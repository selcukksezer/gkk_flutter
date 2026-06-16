-- ============================================================
-- Seed: Guild War v2 — demo attack logs + territory fields
-- ============================================================

BEGIN;

UPDATE public.guild_war_territories
SET
  trade_income = CASE id::text
    WHEN '00000000-0000-0000-0000-000000030001' THEN 5000
    WHEN '00000000-0000-0000-0000-000000030002' THEN 3000
    WHEN '00000000-0000-0000-0000-000000030003' THEN 8000
    WHEN '00000000-0000-0000-0000-000000030004' THEN 2000
    ELSE trade_income
  END,
  defense_line_level = CASE id::text
    WHEN '00000000-0000-0000-0000-000000030001' THEN 2
    WHEN '00000000-0000-0000-0000-000000030002' THEN 1
    WHEN '00000000-0000-0000-0000-000000030003' THEN 3
    WHEN '00000000-0000-0000-0000-000000030004' THEN 1
    ELSE defense_line_level
  END
WHERE id IN (
  '00000000-0000-0000-0000-000000030001',
  '00000000-0000-0000-0000-000000030002',
  '00000000-0000-0000-0000-000000030003',
  '00000000-0000-0000-0000-000000030004'
);

-- Demo attack logs (only if guilds exist — skip on conflict)
INSERT INTO public.guild_war_attack_logs (
  id,
  territory_id,
  attacker_guild_id,
  defender_guild_id,
  attack_power,
  defense_power,
  success,
  points_gained,
  created_at
)
SELECT
  '00000000-0000-0000-0000-000000040001'::uuid,
  '00000000-0000-0000-0000-000000030001'::uuid,
  g1.id,
  NULL,
  1500,
  1200,
  true,
  100,
  now() - interval '2 hours'
FROM public.guilds g1
LIMIT 1
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.guild_war_attack_logs (
  id,
  territory_id,
  attacker_guild_id,
  defender_guild_id,
  attack_power,
  defense_power,
  success,
  points_gained,
  created_at
)
SELECT
  '00000000-0000-0000-0000-000000040002'::uuid,
  '00000000-0000-0000-0000-000000030002'::uuid,
  g1.id,
  g2.id,
  800,
  1200,
  false,
  10,
  now() - interval '5 hours'
FROM public.guilds g1
CROSS JOIN public.guilds g2
WHERE g1.id != g2.id
LIMIT 1
ON CONFLICT (id) DO NOTHING;

COMMIT;
