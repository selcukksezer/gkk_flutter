# PLAN 14 — Cilt 16: Enerji Ekonomisi (Gold Faucet Gate)

> **Öncelik:** P0  
> **Tasarım:** PLAN_06 §4 — regen yok; Han item + quest + günlük

---

## 1. Problem

Enerji = doğal günlük aktivite limiti. Bypass → sınırsız zindan → altın musluğu.

**Whale yolu:** elmas → enerji refill → sınırsız koşu (PLAN_06 §7.2 P2W sınırı ihlali riski)

---

## 2. Enerji Kaynakları (Mevcut)

| Kaynak | Miktar | Not |
|--------|--------|-----|
| Han/Mekan pot | 50–100 | trade yasak (PLAN_07) |
| Quest | 10–30 | |
| Günlük ödül | 30 | |
| Gem refill | 50–100 | günde max 2 (PLAN_06) |

---

## 3. Tune Önerileri

| Param | Hedef |
|-------|-------|
| Gem enerji refill | 50 elmas, günde **max 2** — RPC enforce |
| Han pot market | `is_market_tradeable=false` doğrula |
| Zindan enerji maliyeti | Bölge 4+ 18–25 — koru |

---

## 4. Cross-Balance Matrisi

```
günlük_enerji_arz ≈ 150–350
günlük_enerji_harcama ≈ 130–325 (8–15 zindan)
→ Doğal tavan: ~15 koşu/gün on-level
```

Whale sim segment: gold/day cap veya enerji refill cap sim'de enforce.

---

## 5. Migration

`20260722_140000_energy_refill_daily_cap.sql` — gem enerji refill sayacı

---

## 6. Kabul

- [ ] Gem refill günde 2 cap RPC
- [ ] Whale sim gold/day sim band içinde
- [ ] Casual segment D7 retention sim ≥ 15% (enerji-correct sim)
