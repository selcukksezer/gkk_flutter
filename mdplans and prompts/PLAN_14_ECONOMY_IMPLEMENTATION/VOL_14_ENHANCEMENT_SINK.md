# PLAN 14 — Cilt 14: Enhancement Altın Sink

> **Öncelik:** P0  
> **RPC:** `enhance_item` — `20260307_040000_plan_05_enhancement_system.sql`  
> **Config:** `get_enhancement_config` — `20260720_100000`

---

## 1. Ekonomi Rolü

Enhancement = **birincil end-game altın sink**. Mythic +10 tek parça perfect ~3.34B; destroy ile MC ~142B/parça.

PLAN_06 hedef: mythic +10 set (8 parça) destroy dahil ~535B. Impl MC ~1.14T — **2× pahalı** (kasıtlı ultra sink veya tune gerekir).

---

## 2. Mevcut Parametreler

| Level | Success % | Destroy on fail |
|-------|-----------|-----------------|
| 0–3 | 100% | downgrade |
| 4–5 | 70–60% | downgrade |
| 6+ | 50→3% | **100% destroy** (rune yoksa) |

**Maliyet:** `floor(base_cost[level] × rarity_mult)` — mythic ×12

**Monument Lv90+:** %5 gold indirim

---

## 3. Tune Önerileri

| Param | Mevcut | Öneri | Gerekçe |
|-------|--------|-------|---------|
| +9→+10 base | 200M × 12 = 2.4B | Koru veya −10% | End-game bariyer |
| Destroy L6+ | 100% | Koru | PLAN_06 tasarım |
| Sim item inflation | +50% | Destroy rate sim'de modelle | VOL_13 |

**Migration (opsiyonel tune):** `20260722_120000_enhancement_cost_audit.sql` — yalnızca sim + canlı metrik sonrası

---

## 4. Rune / Scroll Loop

- `rune_protection`, `rune_blessed` — destroy engel
- `scroll_upgrade_low/middle/high` — consume on enhance
- VOL_30 ile koordinasyon

---

## 5. Flutter

- `enhancement_screen.dart` — server `get_enhancement_config` ile client fallback sync
- Maliyet preview monument discount göstersin

---

## 6. Test

| ID | Senaryo |
|----|---------|
| EN-01 | +0→+1 mythic 1.2M gold deduct |
| EN-02 | L6 fail destroy (no rune) |
| EN-03 | rune_protection fail no destroy |
| EN-04 | Monument discount 5% |
| EN-05 | Sim 10k enhancement gold_out > 0 |

---

## 7. Kabul

- [ ] Sim'de enhancement gold_out ölçülüyor
- [ ] Client/server maliyet uyumu
- [ ] Item inflation tam sim ≤ 15%
