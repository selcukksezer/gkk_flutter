# PLAN 14 — Cilt 22: At Yarışı Ekonomisi

> **Öncelik:** P1  
> **RPC:** `place_horse_race_bet`, `_horse_race_resolve_round`  
> **Smoke:** `horse_race_fairness_smoke_10000.json`

---

## Parametreler

| Param | Değer |
|-------|-------|
| house_edge | 0.92 |
| gold bet | 10K – 5M |
| gem bet | 1 – 50 |
| max multiplier | 12.0 |
| min win share | 8%/at |
| daily_bet_limit | **NULL** → set önerilir |

---

## RTP (10K sim)

| Strateji | RTP |
|----------|-----|
| En düşük mult | ~92% gold / ~90% gem |
| En yüksek mult | ~48% gold / ~33% gem |

Optimal: favori at — longshot trap (tasarım OK).

---

## Tune

- `daily_bet_limit` default: 100 round/user/day
- Whale segment sim kontrol

---

## Kabul

- [ ] Fairness smoke PASS post-cap
- [ ] daily_bet_limit migration
- [ ] Net gold/gem flow dashboard
