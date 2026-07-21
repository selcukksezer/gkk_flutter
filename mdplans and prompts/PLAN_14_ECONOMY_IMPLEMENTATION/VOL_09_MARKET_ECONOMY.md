# PLAN 14 — Cilt 9: Oyuncu Pazarı Ekonomisi

> **Öncelik:** P1  
> **Migration:** `20260722_070000_market_price_bands.sql`

---

## 1. Mevcut Durum

- **Komisyon:** %5 altın yok edilir (kalıcı sink)
- **Fiyat kısıtı:** Yalnızca `price > 0`
- **Sipariş süresi:** `expires_at` column var, RPC enforce yok
- **Rate limit:** 30 işlem / 5 dakika

**Ekonomi etkisi:** Yüksek hacim → deflationary; düşük hacim → zayıf sink.

---

## 2. Önerilen Fiyat Bantları

```
min_price = FLOOR(items.vendor_sell_price × 0.5)
max_price = CEIL(items.base_price × 3.0)
```

`place_sell_order` ve `purchase_market_listing` içinde validate.

**Gerekçe:** Manipülasyon önleme; NPC değerine yakın fiyatlandırma.

---

## 3. Sipariş Süresi

```sql
expires_at := now() + interval '7 days'
-- Cron: cancel_expired_market_orders() günlük
```

Escrow iade — envanter veya altın geri.

---

## 4. Maksimum Aktif İlan

Kullanıcı başına max 20 aktif sell order (envanter slot ile uyumlu).

---

## 5. Flutter

| Dosya | Değişiklik |
|-------|------------|
| `lib/screens/market/widgets/market_sell_tab.dart` | Min/max fiyat göster |
| `lib/repositories/market_repository.dart` | Hata mesajları Türkçe |

---

## 6. Kabul Kriterleri

- [ ] Fiyat band dışı listing reject
- [ ] 7 gün sonra otomatik iptal
- [ ] Sim item inflation etkilenmez veya iyileşir

---

## 7. Alt Görevler

- 9.1 place_sell_order migration
- 9.2 Expiry cron pg_cron
- 9.3 Market UI bant gösterimi
- 9.4 Ticaret hacmi metrikleri (VOL_12)
