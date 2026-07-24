-- Modest gem bump on codex milestones (gold unchanged).
BEGIN;

CREATE OR REPLACE FUNCTION public._codex_milestone_reward_config(p_threshold INTEGER)
RETURNS TABLE (
  gold_amount BIGINT,
  gem_amount INT,
  reward_label TEXT,
  reward_kind TEXT
)
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT t.gold_amount, t.gem_amount, t.reward_label, t.reward_kind
  FROM (VALUES
    (10,   100000::BIGINT,  0,  '100.000 Altın',                          'gold'),
    (20,   150000::BIGINT,  0,  '150.000 Altın',                          'gold'),
    (30,   200000::BIGINT,  0,  '200.000 Altın',                          'gold'),
    (40,   300000::BIGINT,  1,  '300.000 Altın + 1 Elmas',                'mixed'),
    (50,   400000::BIGINT,  3,  '400.000 Altın + 3 Elmas + loot şansı',  'mixed'),
    (75,   500000::BIGINT,  5,  '500.000 Altın + 5 Elmas',                'mixed'),
    (100,  750000::BIGINT,  8,  '750.000 Altın + 8 Elmas',                'mixed'),
    (125, 1000000::BIGINT, 10,  '1M Altın + 10 Elmas',                    'mixed'),
    (150, 1250000::BIGINT, 12,  '1.25M Altın + 12 Elmas',                 'mixed'),
    (200, 1500000::BIGINT, 15,  '1.5M Altın + 15 Elmas',                  'mixed'),
    (250, 2000000::BIGINT, 18,  '2M Altın + 18 Elmas',                    'mixed'),
    (300, 2500000::BIGINT, 25,  '2.5M Altın + 25 Elmas',                  'mixed'),
    (350, 3500000::BIGINT, 30,  '3.5M Altın + 30 Elmas',                  'mixed'),
    (400, 5000000::BIGINT, 45,  '5M Altın + 45 Elmas + rozet + unvan',   'mixed')
  ) AS t(threshold, gold_amount, gem_amount, reward_label, reward_kind)
  WHERE t.threshold = p_threshold;
$$;

COMMIT;
