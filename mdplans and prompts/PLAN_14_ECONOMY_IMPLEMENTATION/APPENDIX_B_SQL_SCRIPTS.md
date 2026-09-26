# PLAN 14 — Ek B: Üretim SQL Script Paketi

> Loot Geri Ödeme Oranı ve ekonomi doğrulama — staging/production

---

## Script 1 — Tüm Aktif Kutular RTP Tablosu

```sql
SELECT
  b.id,
  b.name,
  b.theme_id,
  b.currency_type,
  b.price,
  b.reward_multiplier,
  (public.qa_loot_box_ev(b.id)->>'vendor_rtp_pct')::numeric AS vendor_rtp_pct,
  (public.qa_loot_box_ev(b.id)->>'ev_vendor_sell')::numeric AS beklenen_vendor_degeri,
  (public.qa_loot_box_ev(b.id)->>'cost_gold_equiv')::numeric AS maliyet_altin_esdegeri,
  (public.qa_loot_box_ev(b.id)->>'jackpot_rate_pct')::numeric AS jackpot_orani
FROM public.loot_box_configs b
WHERE b.is_active = TRUE
ORDER BY b.currency_type, b.display_order;
```

---

## Script 2 — Hedef Dışı Kutular

```sql
WITH rtp AS (
  SELECT
    b.id, b.name, b.currency_type, b.theme_id, b.price,
    (public.qa_loot_box_ev(b.id)->>'vendor_rtp_pct')::numeric AS rtp
  FROM public.loot_box_configs b
  WHERE b.is_active = TRUE
)
SELECT *, CASE
  WHEN currency_type = 'gems' AND (rtp < 48 OR rtp > 58) THEN 'ELMAS HEDEF DISI'
  WHEN currency_type = 'gold' AND (rtp < 38 OR rtp > 45) THEN 'ALTIN HEDEF DISI'
  ELSE 'OK'
END AS durum
FROM rtp
WHERE (currency_type = 'gems' AND (rtp < 48 OR rtp > 58))
   OR (currency_type = 'gold' AND (rtp < 38 OR rtp > 45))
ORDER BY rtp;
```

---

## Script 3 — Sıfır Vendor Fiyatlı Pool Eşyaları

```sql
SELECT e.box_id, e.item_id, i.name, i.rarity, i.vendor_sell_price, e.weight
FROM public.loot_box_drop_entries e
JOIN public.items i ON i.id = e.item_id
JOIN public.loot_box_configs b ON b.id = e.box_id
WHERE b.is_active AND e.is_active AND COALESCE(i.vendor_sell_price, 0) = 0
ORDER BY e.box_id, e.weight DESC;
```

---

## Script 4 — Tema Bazında Ortalama RTP

```sql
SELECT b.theme_id, b.currency_type,
  COUNT(*) AS kutu_sayisi,
  ROUND(AVG((qa_loot_box_ev(b.id)->>'vendor_rtp_pct')::numeric), 2) AS ort_rtp,
  ROUND(MIN((qa_loot_box_ev(b.id)->>'vendor_rtp_pct')::numeric), 2) AS min_rtp,
  ROUND(MAX((qa_loot_box_ev(b.id)->>'vendor_rtp_pct')::numeric), 2) AS max_rtp
FROM public.loot_box_configs b
WHERE b.is_active
GROUP BY b.theme_id, b.currency_type
ORDER BY b.currency_type, ort_rtp;
```

---

## Script 5 — Tek Kutu Detay JSON

```sql
SELECT jsonb_pretty(public.qa_loot_box_ev('box_01'));
```

---

## Script 6 — Ekonomi Trigger Doğrulama

```sql
-- Direct gold update engellenmeli
-- authenticated role ile test (beklenen: ERROR)
UPDATE public.users SET gold = gold + 999999 WHERE auth_id = auth.uid();
```

---

## Script 7 — Günlük Altın Akış Özeti (Canlı)

```sql
-- bank_transactions, dungeon_runs log varsa:
-- Örnek — tablo yapısına göre uyarla
SELECT date_trunc('day', created_at) AS gun,
  SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS gold_in,
  SUM(CASE WHEN amount < 0 THEN -amount ELSE 0 END) AS gold_out
FROM public.bank_transactions
WHERE created_at > now() - interval '30 days'
GROUP BY 1 ORDER BY 1;
```

---

## Script 8 — IAP İşlem Audit

```sql
SELECT date_trunc('day', verified_at) AS gun,
  COUNT(*) AS islem,
  SUM(gems_granted) AS elmas_verildi
FROM public.iap_transactions
WHERE verified_at > now() - interval '30 days'
GROUP BY 1 ORDER BY 1;
```

---

## Export Komutları

```bash
# CSV export (psql)
\pset format csv
\o reports/plan14_loot_rtp.csv
-- Script 1
\o
```

```bash
# Supabase CLI
supabase db query --linked "$(cat script1.sql)" -o json > reports/plan14_rtp.json
```
