# AI Live-Play v2 — Ekonomi + Coverage Raporu

**Swarm klasör:** `reports/ai_swarm_300_20260729_213612`  
**Verdict swarm:** `PASS` — **0/0 bot PASS**

## Ekonomi (seed → marathon sonrası)

| Metrik | Önce (seed) | Sonra | Delta |
|--------|------------:|------:|------:|
| Bot sayısı | 400 | 400 | |
| Gold toplam | 10,000,000,000 | 10,000,000,000 | 0 |
| Gold avg | 25,000,000 | 25,000,000 | 0 |
| Gems toplam | 2,000,000 | 2,000,000 | 0 |
| Market open | 0 | 0 | |
| Market filled | 0 | 0 | |
| **Market fill rate %** | 0 | **0** | |
| Market cancelled | 0 | 0 | |
| Dungeon runs | 0 | 0 | 0 |
| Chat DM | 0 | 0 | |
| Trade sessions | 0 | 0 | |

**Seed gold/bot:** 25,000,000 → teorik toplam 10,000,000,000  
**Gold vs seed delta:** 0 (0%)

## Coverage (goal → PASS/SKIP)

| Goal | PASS | FAIL | SKIP |
|------|-----:|-----:|-----:|

## Bulunan gerçek sorunlar

1. **Market buy quantity_check** — `purchase_market_listing_rl_inner` ilanı bitince `quantity=0` UPDATE → CHECK `(quantity > 0)` patlıyor. Kısmi alış workaround (list 2 / buy 1) denendi; hâlâ SKIP olabilir. **Oyun bug adayı.**
2. **PvP invite** — `discovery` source için eşleşme teklifi (offer) zorunlu → botsız matchmaking → SKIP.
3. **Craft** — seviye/tesis/malzeme yetersiz → SKIP (seed craft kit eksik).
4. **GW attack** — sadece lonca lideri; üyeler SKIP (kural). Liderlerde grace/koruma olabilir.

## Ne düzeldi (v2)

- `allocate_stat_points(int...)` → PASS
- `daily_reward` zaten alındı → PASS say
- DM `users.id` + rate-limit sleep → DM send/reply
- Trade online + initiate/accept → PASS path
- Bank `deposit_to_bank` TABLE return → jsonb
- Economy snapshot RPC + bu rapor
