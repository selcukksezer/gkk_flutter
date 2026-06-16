# MMORPG / Crime RPG Ultra Deep Simulation — Pass 3 Independent Audit

Date: 2026-06-13  
Auditor: Independent re-run (DB live verify + code audit + report cross-check)  
Project: znvsyzstmxhqvdkkmgdt

## Executive Verdict

**Previous smoke test: NOT correct, NOT consistent. Do NOT use for release gate.**

| Dimension | Pass 1 (100 bot) | Pass 2 (1300 bot) | Required by original prompt | Status |
|-----------|------------------|-------------------|----------------------------|--------|
| DB bot simulation | Partial | Partial | Yes | ⚠️ Synthetic only |
| Exploit testing | **Hardcoded** | **Hardcoded** | Real attack replay | ❌ Invalid |
| Segment distribution @ N>100 | OK | **92% exploit segment** | Proportional 10 segments | ❌ Broken |
| Top bar UI screen coverage | **0%** | **0%** | 100% screens + subs | ❌ Missing |
| RPC / game function coverage | ~5% insert side-effects | Same | All flows | ❌ Missing |
| Full external backup | No | No (in-DB only) | pg_dump + storage | ❌ Incomplete |
| 1000+ mekan scenario | Theoretical | Theoretical | Real UX/perf test | ❌ Only 2 mekans in DB |
| Automated test suite | Dummy test only | Same | Regression pack | ❌ Missing |

**Release recommendation: HARD BLOCK** until Pass 4 (V2 framework) completes.

---

## 1) Critical Integrity Failures in Existing Reports

### 1.1 Exploit findings are static placeholders

Both runs store **identical** exploit counts:

| exploit_key | pass1 attempts/success | pass2 attempts/success |
|-------------|------------------------|------------------------|
| multi_account_gold_funnel | 260 / 83 | 260 / 83 |
| market_price_manipulation | 190 / 71 | 190 / 71 |
| premium_stack_abuse | 90 / 14 | 90 / 14 |
| cooldown_bypass | 110 / 19 | 110 / 19 |
| prison_escape_abuse | 126 / 46 | 126 / 46 |
| hospital_escape_abuse | 140 / 52 | 140 / 52 |

Source: `qa_run_30_day_simulation` ends with hardcoded `INSERT ... VALUES (260, 83, ...)` — no exploit replay logic exists.

**Impact:** All "Kritik Exploitler" sections in prior reports are **narrative fiction**, not measured results. Success rates (%31.9 etc.) cannot be trusted.

### 1.2 Pass 2 segment distribution invalid

Live DB after 1300-bot seed:

| segment | count | expected ~% |
|---------|-------|-------------|
| exploit | **1201** | ~0.8% |
| casual | 20 | ~15% |
| normal | 20 | ~20% |
| newbie | 15 | ~15% |
| hardcore | 15 | ~15% |
| whale | 10 | ~10% |
| trader | 8 | ~8% |
| pvp | 6 | ~6% |
| guild | 4 | ~4% |
| multi | 1 | ~1% |

Cause: `qa_seed_bots` uses fixed index thresholds (`v_idx <= 15` → newbie) regardless of `p_bot_count`.

**Impact:** Pass 2 retention (D1 95%, D30 41%) is **not comparable** to Pass 1 (D1 86%, D30 25%). Pass 2 numbers are skewed by 92% "exploit hunter" bots with high `qa_active_probability`.

### 1.3 Checkpoint gold totals inconsistent with cumulative economy

Pass 2 checkpoint `total_gold_earned` at D30 ≈ 1.98M per day snapshot, but cumulative run total = **60.3M earned / 38.8M spent**. Checkpoints store **single-day** totals, reports read them as cumulative — misleading inflation narrative scale.

### 1.4 UI / navigation smoke never executed

Original prompt required: *"top bar menüde bulunan bütün sayfalar + alt sayfalar + bütün fonksiyonlar"*.

Evidence:
- `test/rpc_test.dart` = dummy `expect(true, isTrue)`
- No integration_test / patrol / maestro flows
- No screen load matrix in either report
- 42 screen files exist, **0** marked tested

### 1.5 Backup gate partially met only

- In-DB snapshot `backup_20260613_081424` exists (74 tables, 43353 rows)
- External pg_dump: blocked (auth/items permissions)
- Storage bucket export: not documented
- Restore drill: not evidenced

---

## 2) Pass 3 Live DB Verification (Fresh Queries)

### 2.1 Simulation runs on record

| run_id | bots × days | events |
|--------|-------------|--------|
| fe1e6dcc… (pass1) | 100 × 30 | 3,000 |
| b82690d4… (pass2) | 1300 × 30 | 39,000 |

### 2.2 Pass 2 economy (cumulative, verified)

- gold_earned: **60,321,288**
- gold_spent: **38,825,634**
- net gold inflation: **+21,495,654** (+35.6% gross mint/sink gap)
- gems_spent: **253,798**
- items_minted: **136,145** | burned: **77,727** (+58,418 net)
- pvp_attacks: **97,749** | quests: **78,213**
- hospital_minutes: **381,317** | prison_minutes: **331,810**
- auto hospital escape events: **17,598** | auto prison: **13,795**

Gem skip efficiency (pass2 synthetic):
- total skip gem spend ≈ 253,798
- total minutes skipped (auto escape) ≈ 713,127
- **≈ 2.81 min/gem** (prior report claimed 1.27 — different calc basis; still weak for casual)

### 2.3 Real content scale

- **mekans in DB: 2** (not 1000+) — mekan UX/perf claims are extrapolation only
- **qa_bot users live: 1300** — pollutes prod-adjacent data; cleanup required after test

### 2.4 Security advisor (post phase-1)

Still open at scale:
- SECURITY DEFINER callable by anon/authenticated: ~388 combined
- RLS disabled in public: 21 tables
- RLS enabled, no policy: 2 tables
- function search_path mutable in `game` schema: residual

---

## 3) Static UI / RPC Smoke Matrix (Pass 3 — Code Audit)

### 3.1 Top drawer routes (23) — test status: **UNTESTED**

| Screen | Route | Key RPCs / actions | Smoke status |
|--------|-------|-------------------|--------------|
| Ana Sayfa | /home | loadProfile, loadInventory | ❌ |
| Karakter | /character | loadProfile, claim_alchemist_detox | ❌ |
| İtibar | /reputation | get_reputation | ❌ |
| Zindan | /dungeon | get_dungeons → attack_dungeon | ❌ |
| PvP | /pvp | attack flows | ❌ |
| Sıralama | /leaderboard | leaderboard RPCs | ❌ |
| Mevsim | /season | bp_* battle pass | ❌ |
| Lonca | /guild | get_my_guild, create/join/leave | ❌ |
| Lonca Savaşı | /guild-war | 5× guild war RPCs | ❌ |
| Anıt | /guild/monument | upgrade/donate monument | ❌ |
| Kasa & Çark | /loot | get_loot_boxes, spin wheels | ❌ |
| Pazar | /market | browse/sell/my orders | ❌ |
| Mağaza | /shop | shop purchase RPCs | ❌ |
| Banka | /bank | 7× bank RPCs | ❌ |
| Ticaret | /trade | initiate/confirm/cancel trade | ❌ |
| Zanaat | /crafting | 8× craft queue RPCs | ❌ |
| Güçlendirme | /enhancement | enhance item | ❌ |
| Tesisler | /facilities | get_player_facilities_with_queue | ❌ |
| Mekanlar | /mekans | mekan list/detail/arena | ❌ |
| Görevler | /quests | get/complete/claim quests | ❌ |
| Hastane | /hospital | heal_with_gems, attempt_hospital_escape | ❌ |
| Hapishane | /prison | release_from_prison, attempt_prison_escape | ❌ |
| Sohbet | /chat | chat history + moderation RPCs | ❌ |
| Ayarlar | /settings | update_user_profile, delete_account | ❌ |

### 3.2 Sub-screens (mandatory) — **UNTESTED**

- /facilities/:type, /guild-war/tournament/:id, /guild-war/territory/:id
- /guild-war/logs, /guild-war/battle-result
- /mekans/create, /mekans/:id, /mekans/:id/arena, /my-mekan
- /pvp/history, /pvp/tournament, /dungeon/battle
- /inventory (bottom nav), /onboarding/character-select
- Market tabs: browse | sell | my market
- Quest tabs ×4, Loot tabs, Craft tabs

### 3.3 Unique RPC surface (~70+ calls in lib/) — automated coverage: **0%**

High-risk RPCs needing exploit replay in Pass 4:
- `heal_with_gems`, `attempt_hospital_escape`, `release_from_prison`, `attempt_prison_escape`
- `initiate_trade`, `confirm_trade`, `add_trade_item`
- `start_crafting`, `claim_crafted_item`, `finalize_crafted_item`
- market list/buy/sell (repository layer)
- mekan create/upgrade/PvP wrappers
- `buy_vip_pass`, premium entitlements

---

## 4) What Pass 1 Got Right (Keep)

Pass 1 (100 bots, correct segment mix) synthetic economy signals **directionally useful**:

| Metric | Pass 1 value | Interpretation |
|--------|--------------|----------------|
| Gold inflation ratio | +36.8% | Sink lag — credible |
| Item inflation ratio | +44.1% | Mint > burn — credible |
| D1→D30 retention | 29.1% | Casual 0/20, Newbie 1/15 — credible pain |
| Whale D30 | 8/10 | Whale stickiness — credible |
| Hospital/prison wait | 32,669 min total | Friction high — credible |

These align with game design review even though exploit section is invalid.

---

## 5) Pass 3 Output Categories (Corrected)

### Kritik Buglar
1. QA sim reports fake exploit metrics as live findings
2. QA seed breaks segment mix when bot count > 100
3. Zero UI/integration test coverage despite release gate claim
4. 1300 qa_bot_* users + dungeon/pvp/market rows written to live DB without isolated staging
5. Checkpoint metrics mislabeled (daily vs cumulative)

### Kritik Exploitler (requires Pass 4 replay — NOT measured yet)
1. Multi-account gold funnel — **unverified**; design risk HIGH (trade + market + no graph detection)
2. Premium stack / duplicate VIP grant — **unverified**; `buy_vip_pass` idempotency unknown
3. Market wash / price pump — **unverified**; no median guard in code review
4. Cooldown bypass — **unverified**; client-trust patterns exist in several screens
5. Hospital/prison gem skip escalation — **unverified**; RPC exists, abuse path not replayed

### Ekonomi Sorunları
- Synthetic 30d net gold +35.6% (pass2 cumulative) — inflation confirmed in model
- Item net +42.9% mint/burn gap
- Non-whale gem spend motivation weak (skip value ~2.8 min/gem)
- **Why spend gold?** Sinks exist but sim spends 64% of earn rate — real player may hoard harder

### Retention Sorunları (pass1 valid cohort only)
- Casual cohort D30: **0%** — session loop fails 10-15 min design goal
- Newbie D30: **6.7%** — onboarding chain insufficient
- Midgame (D7-D14) session drop 38→21 min in report — grind repetition without reward pivot

### Oyuncuyu Sıkan Sistemler
1. Hospital/prison passive wait without compelling skip value
2. Quest/dungeon/PvP loop repetition (100 bot: 3274/2355/4015 actions — low novelty)
3. Mekan discovery with 2 real mekans — scale UX untested

### Gereksiz Sistemler (hypothesis — needs player telemetry)
1. Micro market churn without strategic pricing
2. Early craft before meaningful sink attachment
3. Reputation display without clear midgame spend hook

### Eksik Sistemler
1. Anti-alt-account graph + device fingerprint
2. Market median band + outlier reject
3. Newbie PvP shield (7d / level bracket)
4. D7-D30 objective ladder
5. Mekan search/filter/recommended tabs at scale
6. **Real QA automation layer**

### Monetizasyon Sorunları
- VIP value concentrated; non-whale gem ROI unclear
- Skip pricing feels expensive vs time saved
- Whale dependency risk for gem sink

### Performans Sorunları
- 1000+ mekan list: no load test with real 1000 rows (DB has 2)
- Client-side card render + presence join = predicted jank on mid devices
- 162 unused indexes + 58 auth_rls_initplan = query latency debt

### 30 Günlük Simülasyon Sonuçları
- Pass 1: directionally valid for economy/retention **only**
- Pass 2: **invalid** for retention/segment analysis; economy scale ~13× linear (expected) but segment-skewed

### Oyunun Çökebileceği Senaryolar
1. SECURITY DEFINER + weak RLS → cross-user data leak at scale
2. Sim bots left in prod → leaderboard/market pollution
3. Alt-account funnel (if real) + open trade → economy collapse
4. Mekan list at 1000+ without pagination/batch → mobile OOM/jank

### Ölçeklenme Sorunları
1. QA functions DELETE/INSERT into auth.users on live project
2. No staging branch isolation for 1300-bot runs
3. Backup cannot restore auth schema offline — DR incomplete

---

## 6) En Acil İlk 20 Madde (Re-prioritized)

| # | Item | Priority | Est. impact |
|---|------|----------|-------------|
| 1 | Fix QA sim: remove hardcoded exploits; add real replay harness | P0 | Report trust |
| 2 | Fix qa_seed_bots segment scaling for任意 N | P0 | Valid cohort sim |
| 3 | Move QA to staging branch / isolated schema | P0 | Prod safety |
| 4 | Complete external backup + restore drill | P0 | DR |
| 5 | Build integration_test matrix (23 routes + subs) | P0 | UI gate |
| 6 | Restrict SECURITY DEFINER EXECUTE to service role | P0 | Security |
| 7 | Enable RLS on 21 exposed public tables | P0 | Security |
| 8 | Cleanup qa_bot_* users + sim artifacts from live | P0 | Data hygiene |
| 9 | Multi-account transfer graph detection | P1 | −30% fraud gold |
| 10 | Market median guardrail | P1 | −40% manipulation |
| 11 | VIP idempotency on buy_vip_pass | P1 | −100% stack abuse |
| 12 | Newbie PvP bracket 7d | P1 | +8-12pt D7 retention |
| 13 | D1-D7 onboarding reward chain | P1 | +10-15pt D7 |
| 14 | Casual 15-min high-value loop | P1 | +20pt casual D30 |
| 15 | Hospital/prison dynamic gem curve | P1 | +15-25% skip conv |
| 16 | Gold/item sink rebalance (target <12% inflation) | P1 | Economy health |
| 17 | Mekan search/filter/recommended UX | P2 | Scale UX |
| 18 | Presence batching for mekan list | P2 | FPS + battery |
| 19 | Segment churn dashboard D1/D3/D7 | P2 | LiveOps |
| 20 | Re-run Pass 4 sim after fixes; compare KPIs | P2 | Release gate |

---

## 7) Pass 4 Requirement Summary

See: `mdplans and prompts/PLAN_13_ULTRA_SMOKE_V2_EXECUTION.md`

Pass 4 must produce:
- Verified backup artifacts + restore proof
- 1000 bots with proportional segments on **staging**
- Real exploit replay scripts (50+ scenarios) with measured success rates
- integration_test / patrol coverage ≥ 90% routes
- Synthetic 1000 mekan seed for perf UX test
- Honest go/no-go with no hardcoded metrics

---

## Artefacts

- This audit: `reports/qa_ultra_smoke_report_2026-06-13_pass3_audit.md`
- Execution plan: `mdplans and prompts/PLAN_13_ULTRA_SMOKE_V2_EXECUTION.md`
- Prior reports (deprecated for gate): pass1, pass2 live_pass2
