# MMORPG / Crime RPG Ultra Smoke Test V2 — Live Run

Date: 2026-06-13  
Run ID: `93791bbf-9f70-44ae-8398-f186ad6761ab`  
Bots: 100 (proportional segments)  
Days: 30  
Events: 3,000

## Status: PASS (V2 methodology valid)

Previous timeout run `c1b4bf74` actually completed on stale 1300-bot cohort — discarded for gate.

---

## 1) Migration / Fix Applied

| Item | Status |
|------|--------|
| V2 segment scaling | PASS — exploit 1/100 not 1201/1300 |
| Measured exploit battery | PASS — counts differ from hardcoded 260/83 |
| Cumulative checkpoints | PASS |
| `trg_bp_pvp_match_fn` loser_id fix | PASS — derives loser from winner_id |
| Flutter route smoke tests | PASS — 3/3 |

---

## 2) Segment Distribution (verified)

| segment | count |
|---------|-------|
| newbie | 15 |
| casual | 20 |
| normal | 20 |
| hardcore | 15 |
| whale | 10 |
| trader | 8 |
| pvp | 6 |
| guild | 4 |
| multi | 1 |
| exploit | 1 |

---

## 3) Retention (100 bots, 30d)

| Checkpoint | Active | Rate |
|------------|--------|------|
| D1 | 87 | 87.0% |
| D7 | 67 | 67.0% |
| D30 | 24 | 24.0% |

Casual/newbie decay still high — design signal unchanged.

---

## 4) Economy (cumulative D30)

- gold_in: **876,730**
- gold_out: **459,808**
- net inflation: **+416,922** (+47.6% gross gap)
- item_in: 1,579 | item_out: 0 (items_burned sim metric under-reporting in summary)
- gems_out: 4,280

Gate target (<12% inflation) — **FAIL** (expected until Phase 3 rebalance).

---

## 5) Exploits (measured, not hardcoded)

| exploit | attempts | success | success % | severity |
|---------|----------|---------|-----------|----------|
| multi_account_gold_funnel | 9 | 8 | 88.9% | critical |
| premium_stack_abuse | 20 | 3 | 15.0% | critical |
| prison_escape_abuse | 49 | 1 | 2.0% | high |
| market_price_manipulation | 400* | 0 | 0% | high |
| hospital_escape_abuse | 76 | 0 | 0% | medium |
| cooldown_bypass | 300* | 0 | 0% | high |

\*Battery `LIMIT 400/300` caps inflate attempt counts — tune in next migration.

**Premium double-buy:** 3/20 whale replay succeeded on 2nd call — idempotency gap confirmed.

---

## 6) Blockers Found During Run

1. **MCP timeout** on 1300-bot sim (~5min) — client interrupt, DB still finished. Use 100-bot pilot or async job for full load.
2. **qa_cleanup_bots FK fail** — must delete `market_orders`, `pvp_matches`, `dungeon_runs` first. Manual pre-clean applied; migration fix pending.
3. **pvp trigger bug** — `NEW.loser_id` missing; fixed via `20260613_091000_fix_bp_pvp_match_trigger.sql`.

---

## 7) Verdict

| Gate | Result |
|------|--------|
| V2 sim trustworthy | YES |
| Release ready | NO — economy + premium exploit + UI integration smoke pending |
| Next step | 1000-bot run off-peak OR staging branch; fix cleanup migration; integration_test with QA creds |

---

## Commands Used

```sql
SELECT set_config('app.qa_mode', 'true', false);
-- pre-clean FK refs then:
SELECT public.qa_cleanup_bots();
SELECT public.qa_seed_bots(100);
SELECT public.qa_run_30_day_simulation(30);
SELECT public.qa_export_run_summary('93791bbf-9f70-44ae-8398-f186ad6761ab');
```
