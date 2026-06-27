-- Raise multiplier caps so high-risk horses can reach target RTP.
-- Fair mult for win_prob p: (1/p) * house_edge. At p≈9.5% and RTP=92% → mult≈9.62.
-- Prior caps (gold 5, gem 3.5) forced EV ≈ p*cap → ~48% gold / ~33% gems on highest-mult picks.

ALTER TABLE public.horse_race_settings
  ALTER COLUMN gold_max_multiplier SET DEFAULT 12.00,
  ALTER COLUMN gem_max_multiplier SET DEFAULT 12.00;

UPDATE public.horse_race_settings
SET
  gold_max_multiplier = 12.00,
  gem_max_multiplier = 12.00
WHERE id = 'default';

COMMENT ON COLUMN public.horse_race_settings.gold_max_multiplier IS
  'Upper clamp for displayed/paid gold multiplier. Must exceed house_edge / min_win_prob for full RTP on long-shot horses (e.g. 0.92/0.095 ≈ 9.7 at ~9.5% win).';

COMMENT ON COLUMN public.horse_race_settings.gem_max_multiplier IS
  'Upper clamp for displayed/paid gem multiplier. Same RTP formula as gold; cap must not bind typical sort_order-6 horses.';
