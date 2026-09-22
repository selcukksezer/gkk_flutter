-- Quest progress hits max → auto-complete (inbox "ödül hazır").
-- Same rarity/slot item groups get distinct role extras (not identical clones).

BEGIN;

CREATE OR REPLACE FUNCTION public.increment_quest_progress(
  p_user_id uuid,
  p_trigger_event text,
  p_amount integer DEFAULT 1
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  UPDATE public.player_quests pq
  SET
    progress = LEAST(pq.progress + p_amount, pq.progress_max),
    status = CASE
      WHEN LEAST(pq.progress + p_amount, pq.progress_max) >= pq.progress_max
        THEN 'completed'
      ELSE pq.status
    END,
    completed_at = CASE
      WHEN LEAST(pq.progress + p_amount, pq.progress_max) >= pq.progress_max
        AND pq.status = 'active'
        THEN COALESCE(pq.completed_at, now())
      ELSE pq.completed_at
    END
  FROM public.quests q
  WHERE pq.quest_id = q.quest_id
    AND pq.user_id = p_user_id
    AND pq.status = 'active'
    AND q.trigger_event = p_trigger_event;
END;
$$;

-- Catch already-full active quests left behind before auto-complete.
UPDATE public.player_quests
SET
  status = 'completed',
  completed_at = COALESCE(completed_at, now())
WHERE status = 'active'
  AND progress_max > 0
  AND progress >= progress_max;

-- Spread flat secondary stats inside each rarity+slot group (role identity).
WITH ranked AS (
  SELECT
    id,
    attack,
    defense,
    health,
    luck,
    lower(rarity) AS rarity_key,
    row_number() OVER (
      PARTITION BY lower(rarity), equip_slot
      ORDER BY id
    ) AS rn,
    count(*) OVER (PARTITION BY lower(rarity), equip_slot) AS grp_n,
    min(luck) OVER (PARTITION BY lower(rarity), equip_slot) AS min_luck,
    max(luck) OVER (PARTITION BY lower(rarity), equip_slot) AS max_luck,
    CASE lower(rarity)
      WHEN 'common' THEN 80
      WHEN 'uncommon' THEN 180
      WHEN 'rare' THEN 350
      WHEN 'epic' THEN 700
      WHEN 'legendary' THEN 1200
      WHEN 'mythic' THEN 2000
      ELSE 100
    END AS tier
  FROM public.items
  WHERE equip_slot IN (
    'weapon', 'head', 'chest', 'legs', 'boots', 'gloves', 'ring', 'necklace', 'shield'
  )
),
rolled AS (
  SELECT
    id,
    CASE (rn - 1) % 4
      WHEN 0 THEN attack + tier / 4          -- glass: more atk
      WHEN 1 THEN GREATEST(0, attack - tier / 8)  -- tank: less atk
      WHEN 2 THEN attack                    -- lucky: flat atk
      ELSE attack + tier / 10               -- hybrid
    END AS new_attack,
    CASE (rn - 1) % 4
      WHEN 0 THEN GREATEST(0, defense - tier / 10)
      WHEN 1 THEN defense + tier / 3
      WHEN 2 THEN defense
      ELSE defense + tier / 8
    END AS new_defense,
    CASE (rn - 1) % 4
      WHEN 0 THEN GREATEST(0, health - tier / 8)
      WHEN 1 THEN health + tier / 2
      WHEN 2 THEN health
      ELSE health + tier / 6
    END AS new_health,
    CASE
      -- If whole group shared identical luck, force spread.
      WHEN min_luck = max_luck AND grp_n > 1 THEN
        GREATEST(0, luck + ((rn - 1) - (grp_n - 1) / 2) * (tier / 3))
      ELSE
        CASE (rn - 1) % 4
          WHEN 0 THEN GREATEST(0, luck - tier / 8)
          WHEN 1 THEN GREATEST(0, luck - tier / 10)
          WHEN 2 THEN luck + tier / 2
          ELSE luck + tier / 6
        END
    END AS new_luck
  FROM ranked
)
UPDATE public.items i
SET
  attack = r.new_attack,
  defense = r.new_defense,
  health = r.new_health,
  luck = r.new_luck,
  power = r.new_attack + r.new_defense + (r.new_health / 10) + (r.new_luck * 2),
  updated_at = now()
FROM rolled r
WHERE i.id = r.id;

-- Explicit common weapon identities (clear extras).
UPDATE public.items SET
  attack = 1100, defense = 0, health = 0, luck = 80,
  power = 1100 + 160,
  description = CASE
    WHEN coalesce(description, '') ILIKE '%saldırı odaklı%' THEN description
    ELSE trim(both E'\n' FROM coalesce(description, '')) || E'\nEkstra: saldırı odaklı — düz hasar.'
  END
WHERE id = 'wpn_sword_common';

UPDATE public.items SET
  attack = 850, defense = 0, health = 0, luck = 280,
  power = 850 + 560,
  description = CASE
    WHEN coalesce(description, '') ILIKE '%şans odaklı%' THEN description
    ELSE trim(both E'\n' FROM coalesce(description, '')) || E'\nEkstra: şans odaklı — kritik / drop.'
  END
WHERE id = 'wpn_axe_common';

UPDATE public.items SET
  attack = 720, defense = 0, health = 0, luck = 220,
  power = 720 + 440,
  description = CASE
    WHEN coalesce(description, '') ILIKE '%hızlı delici%' THEN description
    ELSE trim(both E'\n' FROM coalesce(description, '')) || E'\nEkstra: hızlı delici — yüksek şans.'
  END
WHERE id = 'wpn_dagger_common';

UPDATE public.items SET
  attack = 620, defense = 50, health = 320, luck = 90,
  power = 620 + 50 + 32 + 180,
  description = CASE
    WHEN coalesce(description, '') ILIKE '%can odaklı%' THEN description
    ELSE trim(both E'\n' FROM coalesce(description, '')) || E'\nEkstra: can odaklı — dayanıklılık.'
  END
WHERE id = 'wpn_staff_common';

UPDATE public.items SET
  attack = 480, defense = 80, health = 120, luck = 260,
  power = 480 + 80 + 12 + 520,
  description = CASE
    WHEN coalesce(description, '') ILIKE '%şans eldiveni%' THEN description
    ELSE trim(both E'\n' FROM coalesce(description, '')) || E'\nEkstra: şans eldiveni.'
  END
WHERE id = 'gloves_mitts_common';

UPDATE public.items SET
  attack = 560, defense = 140, health = 0, luck = 140,
  power = 560 + 140 + 280,
  description = CASE
    WHEN coalesce(description, '') ILIKE '%dengeli bileklik%' THEN description
    ELSE trim(both E'\n' FROM coalesce(description, '')) || E'\nEkstra: dengeli bileklik.'
  END
WHERE id = 'gloves_bracers_common';

COMMIT;
