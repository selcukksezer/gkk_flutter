# Comprehensive Smoke — 10.000 bot × 30 gün

**Tarih:** 2026-06-29  
**RPC:** `qa_smoke_comprehensive_10k(10000, 30)`  
**Süre:** ~58s  
**Olay:** 300.000 `qa_sim_daily_events`  
**Rapor JSON:** `reports/comprehensive_smoke_10000_30d.json.raw`

## PLAN_11 — Sınıf pasifleri (gerçek RPC) ✅

| Test | Sonuç |
|------|-------|
| Gölge etkin şüphe tavanı 80 | ✅ |
| Tesis şüphe birikimi −30% (28→19) | ✅ |
| Rüşvet 5→4 gem (gölge) | ✅ |
| Simyacı detox +25% (50→31 tolerans) | ✅ |
| `character_classes` passive_bonuses seed | ✅ |

**Ek düzeltme:** `detox_minor` `sub_type` boştu → `use_detox` reddediyordu. Migration `20260629_040000` ile düzeltildi.

## PLAN_13 — Ekonomi & exploit

| KPI | Değer | PLAN_13 hedef | Durum |
|-----|-------|---------------|-------|
| Exploit başarı oranı | 0% | <5% | ✅ |
| D1 retention | 92.4% | — | ✅ |
| D7 retention | 69.5% | — | ✅ |
| D30 retention | 29.0% | casual>15%, newbie>10% | ✅ |
| Gold inflation (net/brüt) | 56.3% | <12% | ⚠️ sim artifact* |
| Item inflation | 50.0% | <15% | ⚠️ sim artifact* |

\*Bulk sim rastgele gold üretir; gerçek sink oranları PLAN_06 RPC’lerinden gelmez. Ekonomi gate’i staging’de tam `qa_run_30_day_simulation` (side insert’li) ile doğrulanmalı.

## Oynanış / sınıf dengesi (PLAN_06 proxy)

| Sınıf | Bot | Ort. gold/gün (D30) | Ort. session dk |
|-------|-----|---------------------|-----------------|
| warrior | 3333 | 678 | 62.1 |
| alchemist | 3334 | 674 | 61.9 |
| shadow | 3333 | 673 | 62.0 |

Sınıflar arası gold farkı <%1 — domine sınıf yok.

## Tesisler stress (2000 bot) ✅

`qa_smoke_facilities_stress(2000)` — fetch 2000/2000, çift unlock engellendi.

## Segment dağılımı (PLAN_13 oranları)

newbie 1500 · casual 2000 · normal 2000 · hardcore 1500 · whale 1000 · trader 800 · pvp 600 · guild 400 · multi 100 · exploit 100

## Tekrar çalıştırma

```bash
./scripts/run_comprehensive_smoke_10k.sh 10000 30
```

`app.qa_mode=true` zorunlu (staging). Prod’da QA botları `qa_cleanup_bots()` ile silinir.
