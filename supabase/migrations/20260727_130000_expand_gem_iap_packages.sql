-- Expand gem IAP catalog: 4 → 8 tiers (starter through whale).
-- Client source of truth: EconomyConstants.gemIapPackages

BEGIN;

INSERT INTO public.gem_iap_packages (id, gems, price_usd_cents, price_try, store_product_id, is_best_value, display_order)
VALUES
  ('gem_starter', 100, 99, 39, 'com.gkk.gems.starter', false, 1),
  ('gem_mini', 250, 199, 79, 'com.gkk.gems.mini', false, 2),
  ('gem_standard', 500, 499, 199, 'com.gkk.gems.standard', false, 3),
  ('gem_plus', 800, 699, 279, 'com.gkk.gems.plus', false, 4),
  ('gem_best_value', 1200, 999, 399, 'com.gkk.gems.best_value', true, 5),
  ('gem_mega', 2600, 1999, 799, 'com.gkk.gems.mega', false, 6),
  ('gem_ultra', 5500, 3999, 1599, 'com.gkk.gems.ultra', false, 7),
  ('gem_legend', 12000, 7999, 3199, 'com.gkk.gems.legend', false, 8)
ON CONFLICT (id) DO UPDATE SET
  gems = EXCLUDED.gems,
  price_usd_cents = EXCLUDED.price_usd_cents,
  price_try = EXCLUDED.price_try,
  store_product_id = EXCLUDED.store_product_id,
  is_best_value = EXCLUDED.is_best_value,
  display_order = EXCLUDED.display_order,
  is_active = TRUE,
  updated_at = now();

COMMIT;
