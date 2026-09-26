# PLAN 14 — Cilt 5B: Zindan Altın Eğrisi Bölge 5–7

> **Öncelik:** P0 (Faz 1B — VOL_05 sonrası)  
> **Migration:** `20260722_150000_dungeon_gold_zone567_multiplier.sql`

---

## 1. Kapsam

VOL_05 yalnızca Bölge 2–4. End-game PLAN_06 günlük hedef **80M–265M** — Bölge 5–7 gerekli.

| Bölge | Zindan | Örnek avg (seed) | Önerilen çarpan | Yeni avg |
|-------|--------|------------------|-----------------|----------|
| 5 | dng_041–050 | ~757K | ×10 | ~7.57M |
| 6 | dng_051–060 | ~2.05M | ×12 | ~24.6M |
| 7 | dng_061–065 | ~4.8M | ×15 | ~72M |

---

## 2. Migration

```sql
UPDATE public.dungeons SET
  gold_min = FLOOR(gold_min * CASE zone WHEN 5 THEN 10 WHEN 6 THEN 12 WHEN 7 THEN 15 ELSE 1 END),
  gold_max = FLOOR(gold_max * CASE zone WHEN 5 THEN 10 WHEN 6 THEN 12 WHEN 7 THEN 15 ELSE 1 END)
WHERE zone BETWEEN 5 AND 7;
```

---

## 3. Alt Görevler

`dng_041` … `dng_065` — 25 zindan band doğrulama (tasks genişletilecek)

---

## 4. Kabul

- [ ] dng_065 on-level daily projeksiyon PLAN üst banda ±30%
- [ ] Overlevel farm cezası hâlâ min %9
- [ ] Sim hardcore segment gold_in artışı ölçüldü
