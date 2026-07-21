-- Temporary: every catalog item buyable in shop (QA / dev convenience).
-- Facility resource seeds had shop_available=false by design; user wants full catalog for now.

UPDATE public.items
SET shop_available = true
WHERE shop_available IS NOT TRUE;

-- Ensure buy_shop_item has a non-zero catalog price where missing.
UPDATE public.items
SET base_price = GREATEST(
  COALESCE(NULLIF(vendor_sell_price, 0), 0) * 3,
  CASE lower(COALESCE(rarity, 'common'))
    WHEN 'common' THEN 500
    WHEN 'uncommon' THEN 2000
    WHEN 'rare' THEN 8000
    WHEN 'epic' THEN 30000
    WHEN 'legendary' THEN 120000
    WHEN 'mythic' THEN 500000
    ELSE 500
  END
)
WHERE COALESCE(base_price, 0) = 0;

UPDATE public.items
SET shop_currency = 'gold'
WHERE shop_currency IS NULL OR btrim(shop_currency) = '';
