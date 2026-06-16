-- Rebalance gem rewards to be proportional to wheel price.
-- Also expose reward_id in preview RPC for deterministic client-side mapping.

DROP FUNCTION IF EXISTS public.get_spin_wheel_rewards(TEXT);

CREATE OR REPLACE FUNCTION public.get_spin_wheel_rewards(p_wheel_id TEXT)
RETURNS TABLE (
  reward_id BIGINT,
  reward_type TEXT,
  item_id TEXT,
  item_name TEXT,
  icon TEXT,
  rarity TEXT,
  amount_min INTEGER,
  amount_max INTEGER,
  weight NUMERIC,
  drop_rate NUMERIC,
  is_jackpot BOOLEAN,
  reward_label TEXT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT
    r.id AS reward_id,
    r.reward_type,
    r.item_id,
    CASE
      WHEN r.reward_type = 'item' THEN i.name
      WHEN r.reward_type = 'gold' THEN 'Gold'
      WHEN r.reward_type = 'gems' THEN 'Elmas'
      ELSE 'Odul'
    END AS item_name,
    COALESCE(i.icon, '') AS icon,
    COALESCE(i.rarity, 'common') AS rarity,
    r.amount_min,
    r.amount_max,
    r.weight,
    (r.weight / NULLIF(SUM(r.weight) OVER (), 0) * 100)::NUMERIC AS drop_rate,
    r.is_jackpot,
    COALESCE(r.label, '') AS reward_label
  FROM public.spin_wheel_reward_entries r
  LEFT JOIN public.items i ON i.id = r.item_id
  WHERE r.wheel_id = p_wheel_id
    AND r.is_active = TRUE
    AND r.show_in_preview = TRUE
  ORDER BY drop_rate DESC, reward_type ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_spin_wheel_rewards(TEXT) TO authenticated;

-- Gems in gem-priced wheels: proportional refund band.
-- Example target range: ~15% to ~40% of spin cost.
UPDATE public.spin_wheel_reward_entries r
SET
  amount_min = GREATEST(1, FLOOR(w.price * 0.15)::INTEGER),
  amount_max = GREATEST(
    GREATEST(1, FLOOR(w.price * 0.15)::INTEGER) + 1,
    FLOOR(w.price * 0.40)::INTEGER
  ),
  updated_at = now()
FROM public.spin_wheel_configs w
WHERE r.wheel_id = w.id
  AND r.reward_type = 'gems'
  AND r.item_id IS NULL
  AND r.is_active = TRUE
  AND w.currency_type = 'gems';

-- Gems in gold-priced wheels: keep lower but still proportional to gold sink.
-- Uses conservative scaling to avoid economy inflation.
UPDATE public.spin_wheel_reward_entries r
SET
  amount_min = GREATEST(1, FLOOR(w.price / 250000.0)::INTEGER),
  amount_max = GREATEST(
    GREATEST(1, FLOOR(w.price / 250000.0)::INTEGER) + 1,
    FLOOR(w.price / 100000.0)::INTEGER
  ),
  updated_at = now()
FROM public.spin_wheel_configs w
WHERE r.wheel_id = w.id
  AND r.reward_type = 'gems'
  AND r.item_id IS NULL
  AND r.is_active = TRUE
  AND w.currency_type = 'gold';
