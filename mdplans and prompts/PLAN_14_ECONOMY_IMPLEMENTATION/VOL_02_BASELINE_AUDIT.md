# PLAN 14 — Cilt 2: Taban Çizgisi Denetimi (Baseline Audit)

> **Öncelik:** P0 — Faz 0 zorunlu  
> **Çıktı:** `reports/plan14_baseline_YYYYMMDD.json`

---

## 1. Amaç

Tüm ekonomi düzeltmelerinden **önce** mevcut durumu ölçülebilir şekilde kaydetmek. Sonraki fazlarda "iyileşti mi?" sorusu bu taban çizgisine karşı yanıtlanır.

---

## 2. Ölçüm Paketi

### 2.1 Simülasyon taban çizgisi

```bash
cd /workspace
./scripts/run_comprehensive_smoke_10k.sh 10000 30
cp reports/comprehensive_smoke_10000_30d.json \
   reports/plan14_baseline_smoke_$(date +%Y%m%d).json
```

Kaydedilecek alanlar:

| Alan | Mevcut referans (2026-06-29) |
|------|------------------------------|
| gold_inflation_pct | 56.33 |
| item_inflation_pct | 50.02 |
| gold_in | 202427892 |
| gold_out | 88405844 |
| gems_out | 46476 |
| exploit success | 0% |
| D30 retention | 29.0% |

### 2.2 Loot Geri Ödeme Oranı taban çizgisi

Staging veya production veritabanında APPENDIX_B Script 1 çalıştır. Sonucu CSV olarak kaydet:

```bash
# psql veya supabase db query
\copy (SELECT ...) TO 'reports/plan14_baseline_loot_rtp.csv' CSV HEADER
```

Her aktif kutu için: `id`, `vendor_rtp_pct`, `theme_id`, `price`, `currency_type`.

### 2.3 Vendor satış davranış taban çizgisi

Test hesabı ile:

1. Bilinen `vendor_sell_price = 10000` eşya al
2. `sell_inventory_item_by_row` çağır
3. Dönen `gold_earned` değerini kaydet

**Beklenen mevcut:** 10000 (tam fiyat)  
**Hedef:** 3500 (%35)

### 2.4 Zindan ödül taban çizgisi

Test hesabı seviye 20, dng_010, 10 koşu:

```sql
-- QA hesabı ile enter_dungeon 10 kez log
-- Ortalama gold/run kaydet
```

Referans (denetim): ~29000 ortalama, farm mult 1.0 on-level.

### 2.5 IAP durum taban çizgisi

| Kontrol | Beklenen |
|---------|----------|
| pubspec.yaml in_app_purchase | Yok |
| verify_and_grant_gems RPC | Yok |
| shop _buyGemPackage | Toast only |

---

## 3. Taban Çizgisi JSON Şeması

```json
{
  "audit_date": "2026-07-21",
  "environment": "staging",
  "simulation": { "gold_inflation_pct": 56.33, "...": "..." },
  "loot_rtp": { "boxes_out_of_target": 0, "details": [] },
  "vendor_sell": { "sample_item_id": "...", "gold_earned_current": 10000 },
  "dungeon": { "dng_010_avg_gold_per_run": 29000 },
  "iap": { "integrated": false },
  "security": {
    "currency_trigger_active": true,
    "shop_server_price": true
  }
}
```

---

## 4. Alt Görevler (Genişletilebilir)

| ID | Görev | Tahmini detay |
|----|-------|---------------|
| 2.1 | Sim taban çizgisi çalıştır | 20 sayfa — ortam kurulum, hata giderme |
| 2.2 | Loot RTP CSV export | 15 sayfa — SQL, yorumlama |
| 2.3 | Manuel vendor satış testi | 10 sayfa |
| 2.4 | Zindan 10 koşu log | 15 sayfa |
| 2.5 | Güvenlik trigger doğrulama | 20 sayfa |

---

## 5. Çıkış Kriterleri

- [ ] `plan14_baseline_*.json` arşivlendi
- [ ] Loot RTP CSV mevcut
- [ ] Vendor satış mevcut davranışı belgelendi
- [ ] Tüm ölçümler tarih damgalı
