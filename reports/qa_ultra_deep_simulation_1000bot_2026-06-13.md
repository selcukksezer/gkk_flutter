# MMORPG / Crime RPG Ultra Deep Simulation — 1000 Bot Full Report

Date: 2026-06-13  
Run ID: `f2d0f436-0360-473f-845a-f79ecb912a6f`  
Project: znvsyzstmxhqvdkkmgdt  
Method: V2 DB simulation + 1000 mekan scale seed + static UI action inventory  
Roles: QA · Economy · LiveOps · Game Design · Retention · Monetization · Exploit Hunter · Security · MMO Analyst

---

## EXECUTIVE SUMMARY

| Layer | Scope | Status |
|-------|-------|--------|
| 1000 bot × 30 day sim | DB activity model | **DONE** |
| 10 behavior segments proportional | 150 newbie … 10 exploit | **DONE** |
| 1000 mekan seed + DB query perf | 0.545ms top-50 sort | **DONE** |
| Flutter UI button/action test | 350 actions / 76 screens | **NOT DONE** (gap) |
| Real RPC replay all screens | ~70+ RPC surface | **PARTIAL** (6 exploit types) |

**Gate:** Economy + exploit + retention red. UI smoke blocking release.

---

## TEST EXECUTION LOG (what actually ran)

### Step 0 — Preconditions
```sql
SELECT set_config('app.qa_mode', 'true', false);
SELECT public.qa_cleanup_bots();          -- FK-safe cleanup
```

### Step 1 — Bot seed (1000)
```sql
SELECT public.qa_seed_bots(1000);
```
Result segments:

| Segment | Bots | % | Behavior model |
|---------|------|---|----------------|
| newbie | 150 | 15% | first_time_no_guide_fast_bored |
| casual | 200 | 20% | daily_15_min |
| normal | 200 | 20% | daily_60_120_min |
| hardcore | 150 | 15% | full_energy_optimizer |
| whale | 100 | 10% | vip_premium_spender |
| trader | 80 | 8% | buy_sell_flip_market |
| pvp | 60 | 6% | constant_attack |
| guild | 40 | 4% | social_coop |
| multi | 10 | 1% | alt_account_farmer |
| exploit | 10 | 1% | abuse_hunter |

Per-bot variance: level/gold/gems/energy/inventory 3–15 items, classes warrior/alchemist/shadow, tutorial flag off for non-newbie, staggered account age 0–25d.

### Step 2 — 30-day simulation
```sql
SELECT public.qa_run_30_day_simulation(30);
```
- Events written: **30,000** (1000 × 30)
- Checkpoints: D1, D3, D7, D14, D30
- Side effects: `dungeon_runs`, `pvp_matches`, `market_orders` rows inserted
- Post-run: `qa_run_exploit_battery(run_id)` measured exploits

### Step 3 — Mekan scale
```sql
SELECT public.qa_seed_mekans(1000);
```
- QA mekans in DB: **1000** (+ 2 prod mekans)
- `EXPLAIN ANALYZE` top-50 by fame: **0.545ms** (seq scan — index gap at scale)

### Step 4 — UI inventory (static code audit)
- Script: `reports/_ui_action_inventory.json`
- 76 screen files, **350** tap/button handlers, **27** inline screen RPCs
- Automated click test: **0/350** (not executed)

---

## 30-DAY SIMULATION — GLOBAL RESULTS

### Retention curve (1000 cohort)

| Day | Active | Rate | Avg session (min) | Cum gold in | Cum gold out | Cum gems out |
|-----|--------|------|-------------------|-------------|--------------|--------------|
| D1 | 918 | 91.8% | 72.7 | 501,815 | 270,502 | 2,104 |
| D3 | 832 | 83.2% | 70.7 | 1,438,806 | 773,984 | 6,312 |
| D7 | 675 | 67.5% | 60.6 | 3,078,664 | 1,658,516 | 13,572 |
| D14 | 510 | 51.0% | 50.7 | 5,334,667 | 2,860,168 | 24,354 |
| D30 | 263 | 26.3% | 30.5 | 8,624,376 | 4,627,058 | 42,040 |

### Segment retention D30 (critical)

| Segment | Cohort | D30 active | D30 rate | Verdict |
|---------|--------|------------|----------|---------|
| whale | 100 | 54 | **54%** | Sticky payers |
| hardcore | 150 | 71 | **47%** | Core loop works |
| normal | 200 | 50 | 25% | Mid decay |
| pvp | 60 | 26 | 43% | Niche sticky |
| trader | 80 | 23 | 29% | OK |
| casual | 200 | 15 | **7.5%** | FAIL |
| newbie | 150 | 9 | **6%** | FAIL |
| guild | 40 | 11 | 28% | Weak social hook |
| multi | 10 | 2 | 20% | Expected |
| exploit | 10 | 2 | 20% | Expected |

### Total simulated activity (30 days)

| Activity | Total actions | Per active bot/day (avg) |
|----------|---------------|---------------------------|
| Quests | 31,780 | 1.06 |
| Dungeon runs | 22,472 | 0.75 |
| PvP attacks | 41,719 | 1.39 |
| Market (buy+sell) | 54,092 | 1.80 |
| Craft actions | 19,691 | 0.66 |
| Guild actions | 23,372 | 0.78 |
| Mekan actions | 15,750 | 0.53 |
| Hospital minutes | 168,632 | — |
| Prison minutes | 152,232 | — |
| Auto hospital skip events | 6,285 | — |
| Auto prison skip events | 5,449 | — |

Mapped to requested daily behaviors:

| Requested behavior | Sim coverage | Gap |
|--------------------|--------------|-----|
| görev yap | quests_done | OK |
| savaş | pvp + dungeon | OK |
| item bul | items_minted | OK |
| item sat | market_sells | OK |
| market kullan | market_buys/sells | OK |
| guild kur/katıl | guild_actions aggregate | No create/join RPC split |
| zindana gir | dungeon_runs + rows | OK |
| hastane/hapishane | minutes + auto skip flags | OK |
| VIP/premium | whale gems + buy_vip_pass replay | Partial |
| craft | craft_actions | No queue RPC |
| ticaret (P2P) | **NOT SIMULATED** | trade RPC missing in sim |
| UI page/button | **NOT SIMULATED** | integration_test gap |

---

## ECONOMY TEST

### Global mint/sink (D30 cumulative)

| Metric | Value |
|--------|-------|
| Gold produced | 8,624,376 |
| Gold consumed | 4,627,058 |
| Net gold | **+3,997,318** |
| Inflation ratio | **46.3%** (net/gross in) |
| Items minted | 15,652 |
| Items burned (sim field) | 0* |
| Item inflation | **100%** accumulation |
| Gems spent | 42,040 |

\*Sim `items_burned` formula under-reports; checkpoint shows 0 — **metric bug**, not necessarily zero sinks in live game.

### Segment economy (top sinks)

| Segment | Gold in | Gold out | Net | Gems out | Avg session |
|---------|---------|----------|-----|----------|-------------|
| hardcore | 1.75M | 944K | +806K | 4,888 | 173.8 min |
| normal | 1.69M | 905K | +789K | 4,632 | 81.4 min |
| whale | 1.27M | 675K | +590K | **21,766** | 148.6 min |
| casual | 1.26M | 686K | +577K | 3,564 | **17.6 min** |
| newbie | 707K | 378K | +328K | 1,915 | **9.5 min** |

Whale gem share: 21,766 / 42,040 = **51.8%** of all gem spend.

### Economy design questions

| Question | Answer | Strong enough? |
|----------|--------|----------------|
| Oyuncu neden para harcasın? | Market buys, craft, guild — sinks exist but **46% net gold gain** → hoarding optimal | **NO** |
| Oyuncu neden item satsın? | Gold inflation makes selling profitable; no bind-on-equip pressure in sim | **WEAK** |
| Oyuncu neden mekan alsın? | Fame/rent loop unclear; mekan_actions low vs grind | **WEAK** |
| Oyuncu neden guild kursun? | guild_actions without tangible daily payout in sim | **WEAK** |
| Oyuncu neden VIP alsın? | Skip time + status; double-buy exploit undermines trust | **PARTIAL** |
| Oyuncu neden oyunda kalsın? | Hardcore/whale yes; casual/newbie **no clear 15-min win** | **FAIL** casual/newbie |

---

## HOSPITAL & PRISON TEST

### Behavior split (as requested)

| Group | Sim rule | Segments |
|-------|----------|----------|
| Auto gem skip | hospital/prison_escape_auto=true | whale, hardcore mostly |
| Wait full duration | auto=false | casual, newbie mostly |

### Gem skip efficiency (minutes saved per gem)

| Segment | Hosp min/gem | Prison min/gem | Player feel |
|---------|--------------|----------------|-------------|
| whale | 1.11 | 1.10 | **Expensive** — whale still pays (21K gems) |
| hardcore | 6.66 | 5.89 | Best ratio — optimizers |
| normal | 5.85 | 6.06 | Borderline |
| casual | 6.55 | 4.21 | Skip rare (448 hosp auto events) |
| newbie | 6.38 | 5.78 | Skip rare — **wait or quit** |

### Analysis
- Gem skip **mantıklı mı?** Hardcore/whale için evet; casual/newbie için fiyat algısı zayıf.
- **Gerçekten kullanır mı?** Whale/hardcore: 1776+2497 auto hosp events. Casual: 448 / 200 bots / 30d ≈ 0.07/bot/day.
- **Fiyat doğru mu?** Whale segment 1.1 min/gem → monetization friction; churn risk on waiters.

---

## EXPLOIT TEST (measured)

| Exploit | Yapılabilir? | Nasıl | Etki (sim) | Engelleme | Öncelik |
|---------|--------------|-------|------------|-----------|---------|
| multi_account gold funnel | **EVET** 81.4% | multi segment PvP gold transfer | 105 success, 85,831 gold | transfer graph + escrow | **Kritik** |
| premium_stack_abuse | **EVET** 10% | `buy_vip_pass` 2× whale replay | 3 duplicate grants | idempotency key | **Kritik** |
| hospital_escape_abuse | Düşük 0.8% | gem/min ratio spam | 41 gems | escalating cost | Orta |
| market_price_manipulation | Hayır* | inflated listing | 0 success in band test | median guard still OK | Yüksek watch |
| prison_escape_abuse | Hayır* | gem skip spam | 0 | caps OK | Yüksek watch |
| cooldown_bypass | Hayır* | 4+ dungeon/day | 0 | server cooldown OK | Orta |
| item transfer abuse | **NOT TESTED** | trade RPC | — | — | Kritik gap |
| guild abuse | **NOT TESTED** | alt fill guild | — | — | Yüksek gap |
| energy abuse | **NOT TESTED** | — | — | — | Yüksek gap |

\*Battery uses capped INSERT limits (300–400) — attempt counts upper-bound, not exact.

---

## PVP TEST

| Metric | Value |
|--------|-------|
| Total PvP matches (QA bots, 35d window) | 12,913 |
| Avg level gap attacker-defender | **1.9** |
| Matches with gap ≥15 levels | **0** |
| Avg gold stolen | 744 |

**Finding:** Sim pairs random QA bots with similar levels → **does not model** newbie crushing. Live game risk remains HIGH for organic players.

**Recommend:** Level bracket + rating band + 7d newbie shield.

---

## 1000+ MEKAN SCENARIO

| Test | Result |
|------|--------|
| DB mekan count | 1000 QA + 2 prod |
| Search/filter in app | **Missing** — code audit |
| List query p95 (DB only) | 0.545ms @ 1000 rows |
| Client 1000 card render | **NOT TESTED** — predicted jank |
| Player visibility model | Not implemented in sim |

**UX answers:**
- Oyuncu mekan bulabilir mi? → **Hayır** without search at 1000+
- Arama gerekir mi? → **Evet**
- Filtre gerekir mi? → **Evet** (type, level, active)
- Son aktif vs rastgele? → **Son aktif + benzer güç** önerilir

---

## UI / SCREEN / BUTTON COVERAGE

**Critical honesty:** 1000 bot sim **does not** open Flutter screens. Coverage = static inventory + route registry test.

| Metric | Count |
|--------|-------|
| Routes in matrix | 39 unique paths |
| Screen files | 76 |
| Button/tap handlers | 350 |
| Automated UI tests run | **0** |
| Route registry unit tests | 3 pass |

Full per-screen matrix: [`qa_ui_action_coverage_matrix_2026-06-13.md`](qa_ui_action_coverage_matrix_2026-06-13.md)

To satisfy "her sayfa her buton": need `integration_test` + Patrol/Maestro with QA creds — **estimated 350 test steps**, not yet executed.

---

# ÇIKTI FORMATI (required sections)

## 1) Kritik Buglar

1. **UI smoke absent** — 0/350 actions tested; release gate false positive risk.
2. **items_burned checkpoint always 0** — economy report unreliable for item sinks.
3. **Exploit battery LIMIT caps** — attempt counts distorted (400 max rows).
4. **Trade/guild-create RPCs not in sim** — major loops untested at DB layer.
5. **PvP sim random pairing** — hides low-level crushing; false PvP safety signal.
6. **`trg_bp_pvp_match_fn` loser_id** — fixed this session; was production bug.

## 2) Kritik Exploitler

1. Multi-account PvP gold funnel — **81.4%** success, ~86K gold/exfil sim window.
2. Premium double VIP — **10%** replay success on second `buy_vip_pass`.

## 3) Ekonomi Sorunları

- 46.3% gold inflation / 30d
- Item accumulation with no burned reporting
- Hoarding dominates spend motivation
- Whale owns 51.8% gem sink

## 4) Retention Sorunları

| Churn point | Why |
|-------------|-----|
| D1 | 8.2% inactive — onboarding friction, tutorial off on alts |
| D3 | casual session 17.6 min but weak reward pulse |
| D7 | casual 115/200, newbie 62/150 — midgame goal gap |
| D30 | casual **7.5%**, newbie **6%** — no reason to stay |

## 5) Oyuncuyu Sıkan Sistemler

1. Hospital/prison wait without compelling skip (casual/newbie)
2. Grind repetition: 31K quests / 41K PvP / 22K dungeons — low novelty
3. Mekan discovery at 1000+ without search
4. Market noise — 54K actions, weak strategic outcomes

## 6) Gereksiz Sistemler

1. Micro market churn for casual (low decision quality)
2. Early craft before meaningful sink attachment
3. Chat moderation complexity vs newbie usage (untested UI)

## 7) Eksik Sistemler

1. Anti-alt-account graph
2. Market median guard (live verify pending)
3. Newbie PvP shield
4. Mekan search/filter/recommended
5. **Automated UI+RPC bot harness**
6. P2P trade in sim
7. Dynamic hospital/prison pricing UI

## 8) Monetizasyon Sorunları

- Whale 51.8% gem spend — concentration risk
- Casual gem ROI unclear (skip rare)
- VIP double-buy erodes trust
- 1.1 min/gem whale skip — feels bad vs hardcore 6.6

## 9) Performans Sorunları

- DB mekan list OK; **client render untested**
- 1000 mekans seq scan — needs index before 10K+
- 30K event sim + 12K PvP inserts — OK; 10× scale needs staging branch

## 10) 30 Günlük Simülasyon Sonuçları

See tables above. **Run ID `f2d0f436-0360-473f-845a-f79ecb912a6f`**.

## 11) Oyunun Çökebileceği Senaryolar

1. Multi-account funnel + open trade (untested) → economy collapse
2. VIP stack live → revenue fraud + backlash
3. Casual/newbie churn → dead servers
4. 1000 mekan UI on mid Android → OOM/jank crash spike

## 12) Ölçeklenme Sorunları

1. QA bots pollute prod-adjacent tables
2. MCP/HTTP timeout on long sim (use async job)
3. No staging isolation
4. UI test gap scales linearly with features

## 13) En Acil İlk 20 Madde

1. Build integration_test 350-action matrix
2. Block multi-account gold funnel
3. VIP idempotency on `buy_vip_pass`
4. Fix items_burned reporting in sim + live sinks
5. Newbie 7d PvP shield
6. D1-D7 onboarding reward chain
7. Casual 15-min guaranteed win loop
8. Mekan search + filter + recommended
9. Hospital/prison dynamic gem curve
10. Market median guard + listing cap
11. Trade RPC abuse test suite
12. Guild alt-fill detection
13. Remove exploit battery LIMIT caps
14. PvP bracket matchmaking
15. Mekan DB indexes (fame, type, last_active)
16. Move QA to staging branch only
17. Segment churn dashboard
18. Gold sink rebalance (target <12% inflation)
19. Client mekan list virtualization/batching
20. Full backup + restore drill before Phase 1 security

---

# SISTEM BAZLI DETAY (abbreviated — full set in appendix)

## Sistem: Hastane
- **Açıklama:** Gem ile çıkış veya bekleme.
- **Güçlü:** Whale/hardcore skip kullanıyor.
- **Zayıf:** 1.1 min/gem whale; casual skip nadir.
- **Exploit:** 0.8% abuse pattern.
- **Psikoloji:** Bekleyen casual sinir → quit.
- **Ekonomi:** 42K gems sink — iyi ama konsantre.
- **Retention:** Negatif casual/newbie.
- **Monetizasyon:** Whale harcar ama ROI düşük algı.
- **Fix:** Dynamic pricing + value UI.
- **Öncelik:** Kritik

## Sistem: PvP
- **Güçlü:** 41K attacks — engagement var.
- **Zayıf:** Sim ezilmeyi göstermiyor; live risk yüksek.
- **Exploit:** Multi-account funnel 81%.
- **Retention:** Newbie live'da kaçar (sim masked).
- **Fix:** Bracket + shield.
- **Öncelik:** Kritik

## Sistem: Market
- **Güçlü:** 54K actions.
- **Zayıf:** Enflasyon + spam listings.
- **Monetizasyon:** Tax/sink artırılabilir.
- **Öncelik:** Yüksek

## Sistem: VIP / Premium
- **Güçlü:** Whale sticky 54% D30.
- **Zayıf:** Double-buy 10% success.
- **Öncelik:** Kritik

*(Remaining systems: Guild, Mekan, Dungeon, Craft, Trade, Bank, Loot, Season, Chat, Settings — same template in matrix file.)*

---

## REPRODUCE

```sql
SELECT set_config('app.qa_mode', 'true', false);
SELECT public.qa_cleanup_bots();
SELECT public.qa_seed_bots(1000);
SELECT public.qa_run_30_day_simulation(30);
SELECT public.qa_seed_mekans(1000);
SELECT public.qa_export_run_summary('f2d0f436-0360-473f-845a-f79ecb912a6f');
```

---

## FILES

| File | Purpose |
|------|---------|
| This report | 1000 bot ultra deep sim |
| `qa_ui_action_coverage_matrix_2026-06-13.md` | Per-screen buttons/RPCs |
| `_ui_action_inventory.json` | Machine-readable UI map |
| `qa_ultra_smoke_v2_2026-06-13.md` | Prior 100-bot pilot |
