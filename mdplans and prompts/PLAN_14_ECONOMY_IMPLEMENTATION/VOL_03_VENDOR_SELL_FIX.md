# PLAN 14 — Cilt 3: Vendor Satış %35 Düzeltmesi

> **Öncelik:** P0 — Faz 1 ilk adım  
> **Migration:** `20260722_010000_vendor_sell_35_percent.sql`  
> **Sınıf:** S1 Kritik

---

## 1. Problem

`sell_inventory_item_by_row` fonksiyonu eşyayı satıcıya **tam `vendor_sell_price`** ile satıyor:

```40:40:supabase/migrations/20260224_236000_enforce_gold_only_sales.sql
  v_gold_earned := GREATEST(0, v_vendor_sell_price * v_sell_qty);
```

PLAN_06 ve `EconomyConstants.goldSources` metni **base_price'ın yaklaşık %35'i** hedefler. Tam vendor fiyat:

- Loot kutusu Geri Ödeme Oranı hesabını bozar (oyuncu kasadan fazla altın alır)
- Eşya → altın dönüşümü aşırı cömert
- Simülasyon gold enflasyonuna katkı sağlar

---

## 2. Hedef Davranış

```
gold_earned = FLOOR(vendor_sell_price × 0.35) × quantity
```

Minimum 1 altın (sıfır vendor fiyatında 0 kalır).

**Alternatif (tercih edilmez):** `items.vendor_sell_price` seed değerlerini %35'e göre yeniden yaz — migration sayısı artar, loot pool etkilenir.

**Önerilen:** RPC içinde %35 uygula; `vendor_sell_price` loot RTP math için referans olarak kalır.

---

## 3. Migration Taslağı

```sql
-- 20260722_010000_vendor_sell_35_percent.sql
BEGIN;

CREATE OR REPLACE FUNCTION public.sell_inventory_item_by_row(
  p_row_id uuid,
  p_quantity int DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_current_qty int;
  v_vendor_sell_price int;
  v_unit_gold int;
  v_sell_qty int;
  v_gold_earned int := 0;
  v_sell_rate constant numeric := 0.35;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
  END IF;

  SELECT quantity, COALESCE(vendor_sell_price, 0)
  INTO v_current_qty, v_vendor_sell_price
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = v_user_id
  FOR UPDATE;

  IF v_current_qty IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned');
  END IF;

  v_sell_qty := LEAST(v_current_qty, p_quantity);
  v_unit_gold := GREATEST(0, FLOOR(v_vendor_sell_price * v_sell_rate)::int);
  v_gold_earned := v_unit_gold * v_sell_qty;

  -- ... envanter güncelleme ve users.gold aynı kalır ...

  RETURN jsonb_build_object(
    'success', true,
    'sold_quantity', v_sell_qty,
    'currency', 'gold',
    'gold_earned', v_gold_earned,
    'sell_rate', v_sell_rate,
    'gems_earned', 0
  );
END;
$$;

COMMIT;
```

---

## 4. Yan Etki Analizi

| Sistem | Etki |
|--------|------|
| Loot kutusu açılış | Değişmez (eşya verir, satış ayrı) |
| Loot Geri Ödeme Oranı gerçek değer | Düşer — hedef bandına yaklaşır |
| **Tesis collect → vendor satış** | **Aynı RPC** — %35 uygulanır (VOL_17) |
| **Loot drop → vendor satış loop** | Musluk %65 azalır — RTP ile uyumlu |
| Oyuncu pazarı | Satış farklı RPC — etkilenmez |
| Quest "5000 altın topla" | Daha yavaş ilerler — kabul edilebilir |

**Tesis satış yolu doğrulama (VOL_03_TASK_002 — zorunlu):**

```bash
rg "sell_inventory|vendor_sell" supabase/migrations/*facility*
rg "collect_facility" supabase/migrations/ -A5
```

Beklenen: `collect_facility_resources_v2` item verir → oyuncu `sell_inventory_item_by_row` çağırır → %35 altın.

---

## 5. Flutter Değişiklikleri

| Dosya | Değişiklik |
|-------|------------|
| `lib/core/constants/economy_constants.dart` | goldSources metni doğrula (%35) |
| `lib/screens/inventory/inventory_screen.dart` | Satış önizlemesi: `vendor_sell × 0.35` göster |
| Envanter satış dialog | Tahmini altın = floor(vendor × 0.35) × qty |

---

## 6. Test Senaryoları

| # | Senaryo | Beklenen |
|---|---------|----------|
| T1 | vendor=10000, qty=1 | gold_earned=3500 |
| T2 | vendor=0 | gold_earned=0 |
| T3 | vendor=100, qty=5 | gold_earned=175 (35×5) |
| T4 | Yetkisiz row_id | error |
| T5 | quantity > owned | partial sell |
| T6 | Sim 10k bot 30g | gold_inflation düşüş |

---

## 7. Kabul Kriterleri

- [ ] RPC staging'de T1–T5 geçer
- [ ] Sim gold_inflation_pct önceki taban çizgisinden en az 15 puan düşer
- [ ] Envanter UI doğru tahmini gösterir
- [ ] Rollback script APPENDIX_E'de test edildi

---

## 8. Geri Alma

Önceki `sell_inventory_item_by_row` tanımını `20260224_236000` dosyasından restore et.

---

## 9. Alt Görev Genişletme (20+ sayfa each)

- 3.1 RPC implementasyon ve code review checklist
- 3.2 Tesis satış zinciri impact analizi
- 3.3 Oyuncu iletişim metni ve SSS
- 3.4 Sim before/after karşılaştırma raporu şablonu
