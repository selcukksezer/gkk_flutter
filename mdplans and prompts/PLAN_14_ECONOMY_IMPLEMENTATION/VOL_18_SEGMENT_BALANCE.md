# PLAN 14 — Cilt 18: Segment Dengesi (Whale / Casual / Hardcore)

> **Öncelik:** P0  
> **Kaynak:** Sim 10K — hardcore max mint; casual D30 retention risk

---

## 1. PLAN_06 Hedef Tablosu

| Ay 12 | Hardcore | Casual | Whale |
|-------|----------|--------|-------|
| Level | 68–70 | 55–60 | 65–68 |
| Power | 420K–450K | 250K–320K | 380K–430K |
| Gold kümülatif | ~38B | ~12B | ~25B + gem |

---

## 2. Sim Bulguları

| Segment | Bot | Session dk | Rol |
|---------|-----|------------|-----|
| hardcore | 1500 | 129 | max gold mint |
| whale | 1000 | 117 | mint + gem sink |
| casual | 2000 | 8.9 | düşük sink, retention risk |

**Sorun:** Gold spread sınıflar arası <%1 — enerji bypass whale'de gizli.

---

## 3. Tune Paketi

| Segment | Aksiyon |
|---------|---------|
| Whale | Enerji refill cap (VOL_16); horse race daily bet limit |
| Casual | dng_001 fix; günlük ödül erken band; D1–D7 faucet |
| Hardcore | Bölge 5–7 gold (VOL_05B); enhancement sink erişim |

---

## 4. Kabul

- [ ] Segment economy JSON (VOL_13)
- [ ] Casual D30 sim ≥ 10% (tam sim, gate fix sonrası)
- [ ] Whale gold/day cap veya enerji limit sim'de
