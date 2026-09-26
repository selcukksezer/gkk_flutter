# PLAN 14 — Cilt 7: Simülasyon Kapıları ve Kalite Güvencesi

> **Öncelik:** P0 — Her ekonomi migration sonrası  
> **Script:** `./scripts/run_comprehensive_smoke_10k.sh`  
> **RPC:** `qa_smoke_comprehensive_10k`

---

## 1. Amaç

10.000 bot × 30 gün simülasyonu, ekonomi değişikliklerinin toplu etkisini ölçer. PLAN_13 kapıları geçilmeden production deploy yapılmaz.

---

## 2. Mevcut Kapılar (PLAN_13)

| KPI | Mevcut | Hedef | Durum |
|-----|--------|-------|-------|
| gold_inflation_pct | 56.33 | ≤ 12 | FAIL |
| item_inflation_pct | 50.02 | ≤ 15 | FAIL |
| exploit success | 0% | < 5% | PASS |
| D1 retention | 92.4% | — | PASS |
| D7 retention | 69.5% | — | PASS |
| D30 retention (overall) | 29.0% | — | PASS |
| Class gold spread | <1% | <5% | PASS |
| Facilities stress 2000 | PASS | PASS | PASS |

**Formül:**
```
gold_inflation = (gold_in - gold_out) / gold_in
item_inflation = (item_in - item_out) / item_in
```

---

## 3. Simülasyon Sınırlamaları

Mevcut smoke `qa_sim_skip_side_inserts=true` kullanır:
- Enhancement, tesis, pazar sink'leri **eksik** sayılabilir
- Enflasyon **gerçekten daha yüksek** olabilir

**Faz 1 sonrası zorunlu:** Tam simülasyon (`qa_run_30_day_simulation`, side insert açık) staging'de bir kez çalıştır.

---

## 4. Çalıştırma Prosedürü

```bash
# 1. Staging'de qa_mode
SELECT set_config('app.qa_mode', 'true', true);

# 2. Smoke
./scripts/run_comprehensive_smoke_10k.sh 10000 30

# 3. Sonuç
cat reports/comprehensive_smoke_10000_30d.json | jq '.gates.plan13'
```

**Süre:** ~60 saniye (10K bot)

---

## 5. Migration Sonrası Beklenen Etki

| Değişiklik | gold_in | gold_out | Net enflasyon |
|------------|---------|----------|---------------|
| Vendor %35 | — | — (satış ↓) | ↓↓ |
| Zindan ×3–8 | ↑↑ | — | ↑ (risk) |
| Loot tune | — | ↑ (kasa maliyeti) | ↓ |

**Denge hedefi:** Vendor düşüşü + loot tune, zindan artışını absorbe etmeli → net ≤12%.

---

## 6. FAIL Durumunda Karar Ağacı

```
gold_inflation > 12%?
  ├─ gold_in çok yüksek → zindan çarpanını düşür (Bölge 4 ×8 → ×6)
  ├─ gold_out çok düşük → sink güçlendir (craft maliyet, shop)
  └─ sim artifact → tam simülasyon çalıştır, karşılaştır
```

---

## 7. Ek Test Paketleri

| Script | Amaç |
|--------|------|
| `horse_race_fairness_smoke` | At yarışı RTP post-cap |
| `comprehensive_smoke_10k` | Ana ekonomi |
| Facilities stress 2000 | RPC stabilite |
| PLAN_11 class passives | Sınıf dengesi |

---

## 8. CI Entegrasyonu (Öneri)

```yaml
# .github/workflows/economy-smoke.yml
on:
  pull_request:
    paths:
      - 'supabase/migrations/**'
      - 'lib/**/economy/**'
jobs:
  smoke:
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/run_comprehensive_smoke_10k.sh 1000 7  # PR'da hızlı
```

PR: 1000 bot × 7 gün (hızlı)  
Merge main: 10000 bot × 30 gün (tam kapı)

---

## 9. Kabul Kriterleri

- [ ] 10K/30G smoke gold_inflation ≤ 12%
- [ ] item_inflation ≤ 15%
- [ ] exploit 0%
- [ ] Sonuç JSON arşivlendi (`reports/plan14_post_vol035_*.json`)

---

## 10. Alt Görevler

- 7.1 Sim artifact analiz raporu
- 7.2 Tam simülasyon migration spec
- 7.3 Segment bazlı gold_in/out JSON genişletmesi
- 7.4 CI workflow implementasyonu
- 7.5 Retention gate miswire düzeltmesi (casual_d30 JSON bug)
