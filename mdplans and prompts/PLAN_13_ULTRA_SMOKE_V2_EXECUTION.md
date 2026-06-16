# PLAN 13 — Ultra Smoke Test V2 (Corrected Framework)

Status: Ready for execution  
Date: 2026-06-13  
Supersedes: Pass 1/2 reports (invalid exploit + segment bugs)  
Companion audit: `reports/qa_ultra_smoke_report_2026-06-13_pass3_audit.md`

---

## 0) Why V2 Exists

Pass 1/2 failed three gate criteria from original prompt:

1. **Exploit section fabricated** — hardcoded INSERT in `qa_run_30_day_simulation`
2. **UI smoke never ran** — 0/42 screens tested
3. **1300-bot run invalid** — 92% bots assigned `exploit` segment

V2 fixes methodology before any remediation phase uses bad data.

---

## 1) Hard Gate — Full Backup (unchanged, mandatory)

### 1.1 Operator setup
```bash
brew install supabase/tap/supabase libpq
echo 'export PATH="/opt/homebrew/opt/libpq/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 1.2 Backup scope
| Artifact | Method | Pass criteria |
|----------|--------|---------------|
| Full DB (all schemas) | Supabase Dashboard → Database Backups OR service-role pg_dump | File exists + sha256 |
| Public + game schema | pg_dump with service role | Restorable |
| Storage buckets | API export script / dashboard | Object count logged |
| Migrations snapshot | git tag `pre-smoke-v2-<TS>` | Tag pushed |
| In-DB snapshot (secondary) | existing backup RPC | backup_id recorded |

### 1.3 Restore drill (staging clone)
- Restore dump to staging branch
- Verify: login, inventory count, market orders, guild rows, mekan rows
- **No Phase 2+ until drill PASS**

### 1.4 Post-QA cleanup rule
After every bot run on any environment:
```sql
-- Run via staging only in production recovery scenarios
DELETE FROM auth.users WHERE email LIKE 'qa_bot_%@qa.local';
DELETE FROM public.users WHERE username LIKE 'qa_bot_%';
-- Truncate qa_sim_* tables
```

---

## 2) V2 Test Architecture (4 Layers)

```
Layer A: Backup + staging isolation
Layer B: DB bot simulation (fixed, proportional segments)
Layer C: Exploit replay harness (real RPC attacks)
Layer D: Flutter integration smoke (all routes + actions)
Layer E: Scale fixtures (1000 mekan synthetic seed)
```

All layers must PASS for release gate.

---

## 3) Layer B — Fixed Bot Simulation

### 3.1 Migration fixes required

**File:** new migration `20260613_090000_qa_simulation_v2_fixes.sql`

#### Fix 1: Proportional segment assignment
Replace fixed index thresholds with percentage buckets:

| segment | % of cohort |
|---------|-------------|
| newbie | 15% |
| casual | 20% |
| normal | 20% |
| hardcore | 15% |
| whale | 10% |
| trader | 8% |
| pvp | 6% |
| guild | 4% |
| multi | 1% |
| exploit | 1% |

Implementation: `segment = CASE floor((v_idx-1)::numeric / p_bot_count * 100) ...`

#### Fix 2: Remove hardcoded exploit INSERT
Replace with `qa_run_exploit_battery(p_run_id)` that:
- Picks N bots per exploit type
- Calls real RPCs (trade, market, heal, prison, vip, craft)
- Records actual success/fail from RPC response + row deltas
- Computes impact from `users.gold/gems` before/after

#### Fix 3: Staging-only guard
```sql
IF current_setting('app.qa_mode', true) IS DISTINCT FROM 'true' THEN
  RAISE EXCEPTION 'QA sim requires app.qa_mode=true on staging branch';
END IF;
```

#### Fix 4: Checkpoint labeling
Add columns: `cumulative_gold_earned`, `cumulative_gold_spent` vs `daily_*` to prevent misread.

### 3.2 Bot load plan (staging)

| Cohort | Bots | Notes |
|--------|------|-------|
| Base simulation | 1000 | Proportional segments |
| Spike load | +200 | hardcore + whale only |
| Exploit battery | +100 | multi + exploit segments |
| **Total** | **1300** | Same count as pass2, valid mix |

### 3.3 Simulation horizon
- Days: 30
- Checkpoints: D1, D3, D7, D14, D30
- Stress burst: D0 (all bots active, 2× action multipliers)

### 3.4 Mandatory metrics (auto-export to JSON)
```json
{
  "retention": {"d1": 0.0, "d7": 0.0, "d30": 0.0},
  "economy": {"gold_in": 0, "gold_out": 0, "item_in": 0, "item_out": 0},
  "monetization": {"gems_spent": 0, "skip_conversion": 0.0},
  "exploits": [{"key": "", "attempts": 0, "success": 0, "impact_gold": 0}],
  "segments": {"casual_d30": 0.0, "whale_d30": 0.0}
}
```

### 3.5 Exit thresholds (30-day sim)
| KPI | Target |
|-----|--------|
| Gold inflation (net/gross) | < 12% |
| Item inflation | < 15% |
| Exploit success rate (any) | < 5% |
| Casual D30 retention | > 15% |
| Newbie D30 retention | > 10% |

---

## 4) Layer C — Exploit Replay Battery

Each exploit: **attempt → measure → document → mitigation test**

### 4.1 Scenarios (minimum 50 scripts)

| ID | Exploit | Method | Expected block |
|----|---------|--------|----------------|
| E01 | Multi-account gold funnel | Bot A trades to Bot B same device fingerprint | Transfer hold + flag |
| E02 | Market price pump | 10 bots list same item 500% over median | Outlier reject |
| E03 | Wash trading | A sells to B, B sells to A loop | Wash detector |
| E04 | Premium stack | Call buy_vip_pass 3× same day | Idempotent grant |
| E05 | Cooldown bypass | Replay attack_dungeon RPC within cooldown | Server reject |
| E06 | Hospital gem abuse | Repeat heal_with_gems spam | Escalating cost |
| E07 | Prison bail abuse | release_from_prison loop | Daily cap |
| E08 | Craft queue double-claim | Parallel claim_crafted_item | Row lock |
| E09 | Negative gold | Force spend > balance via race | CHECK constraint |
| E10 | Guild alt fill | 20 alts join guild for rewards | Alt graph |
| E11-E50 | Extend per system | ... | ... |

### 4.2 Report format (per exploit)
```
Sistem: [name]
Yapılabilir mi: evet/hayır (measured)
Nasıl: [steps]
Etki: [gold/gems/retention % estimate]
Engelleme: [fix]
Öncelik: Kritik/Yüksek/Orta/Düşük
```

---

## 5) Layer D — Flutter Integration Smoke

### 5.1 Tooling
```yaml
# pubspec.yaml dev_dependencies
integration_test:
  sdk: flutter
patrol: ^3.0.0  # optional, for native dialogs
```

### 5.2 Test structure
```
integration_test/
  smoke/
    auth_flow_test.dart
    drawer_navigation_test.dart
    screen_matrix_test.dart
  flows/
    market_flow_test.dart
    dungeon_flow_test.dart
    hospital_prison_flow_test.dart
    mekan_flow_test.dart
    guild_flow_test.dart
    trade_flow_test.dart
```

### 5.3 Screen matrix (must hit 100%)

#### Top drawer (23 routes)
Ana Sayfa, Karakter, İtibar, Zindan, PvP, Sıralama, Mevsim, Lonca, Lonca Savaşı, Anıt, Kasa & Çark, Pazar, Mağaza, Banka, Ticaret, Zanaat, Güçlendirme, Tesisler, Mekanlar, Görevler, Hastane, Hapishane, Sohbet, Ayarlar

#### Sub-screens (16+)
All paths from `lib/routing/app_router.dart` dynamic segments.

#### Per-screen template
- [ ] Cold load < 3s (p95)
- [ ] Warm load < 1s
- [ ] Empty state renders
- [ ] Error state (RPC fail mock) renders retry
- [ ] Primary CTA works once
- [ ] Back navigation correct
- [ ] Gold/gems/energy sync after action
- [ ] 10× repeat no crash

### 5.4 CI command
```bash
flutter test integration_test/smoke/screen_matrix_test.dart \
  --dart-define=SUPABASE_URL=$STAGING_URL \
  --dart-define=SUPABASE_ANON_KEY=$STAGING_ANON
```

---

## 6) Layer E — 1000+ Mekan Scale Test

### 6.1 Synthetic seed (staging only)
```sql
-- qa_seed_mekans(1000) generates mekans with varied:
-- owner, level, category, last_active, player_count, region
```

### 6.2 UX tests
| Scenario | Pass |
|----------|------|
| List 1000 mekans first paint | < 2s p95 |
| Scroll 60fps mid Android | > 55fps avg |
| Search by name | < 300ms |
| Filter category + sort active | < 500ms |
| Presence: show last-active not all | UI readable |

### 6.3 Design decisions to validate
- Oyuncu mekan bulabilir mi? → search + recommended required
- Filtre gerekir mi? → yes at 100+ rows
- Son aktif vs rastgele oyuncu? → recommend last-active + similar power

---

## 7) Hospital & Prison Dedicated Test

### 7.1 Bot behavior split (per 100 hospital/prison events)
| Group | Behavior | % |
|-------|----------|---|
| A | Auto gem skip (whale/hardcore) | 40% |
| B | Wait full duration | 40% |
| C | Quit app (simulate churn) | 20% |

### 7.2 Metrics
- gem cost per minute saved
- skip conversion by segment
- churn correlation with wait > 30 min
- abuse: repeat entry within 24h

### 7.3 Balance targets
- Casual skip conversion: 8-15%
- Whale skip conversion: 40-60%
- min value: 5 min/gem at low remaining time, 15 min/gem at high

---

## 8) Economy Deep Analysis Template

For each system answer:

| Question | If no good answer → flag system |
|----------|--------------------------------|
| Oyuncu neden para harcasın? | |
| Oyuncu neden item satsın? | |
| Oyuncu neden mekan alsın? | |
| Oyuncu neden guild kursun? | |
| Oyuncu neden VIP alsın? | |
| Oyuncu neden oyunda kalsın? | |

Compute from sim data:
- `gold_mint_rate` per segment per day
- `gold_sink_rate` per segment per day
- `Gini(gold)` across bot population
- `item_velocity` = burned/minted

---

## 9) Remediation Phases (after V2 baseline)

Execute only after V2 baseline JSON exported.

| Phase | Scope | Re-test |
|-------|-------|---------|
| P1 Security | RLS + SD function EXECUTE restrict + search_path | Exploit battery |
| P2 Exploit shields | transfer graph, market band, VIP idempotency | Exploit battery |
| P3 Economy | sinks + reward trim | 30d sim compare |
| P4 Retention | D1-D7 chain, casual loop | Segment retention |
| P5 PvP fairness | bracket + newbie shield | PvP mismatch sim |
| P6 Hospital/prison | dynamic pricing | Skip conversion A/B |
| P7 Mekan UX | search/filter/batch | 1000 mekan perf |
| P8 Final gate | Full V2 re-run | All layers |

---

## 10) Deliverables Checklist

- [ ] `backups/<TS>/full_db.dump` + sha256
- [ ] Staging restore proof screenshot/log
- [ ] `supabase/migrations/20260613_090000_qa_simulation_v2_fixes.sql`
- [ ] `reports/qa_ultra_smoke_v2_<date>.md` (no hardcoded metrics)
- [ ] `reports/qa_exploit_battery_<date>.json`
- [ ] `reports/qa_screen_matrix_<date>.md`
- [ ] `reports/qa_mekan_scale_<date>.md`
- [ ] `integration_test/smoke/*` in repo
- [ ] Go/no-go memo with risk register

---

## 11) Immediate Next Actions (ordered)

1. **STOP** using pass1/pass2 exploit numbers in decisions
2. Install backup tools; full dump + restore drill
3. Create Supabase **staging branch** for all QA writes
4. Apply QA sim v2 migration (segment fix + remove hardcoded exploits)
5. Cleanup 1300 qa_bot users from live (`b82690d4` run pollution)
6. Scaffold `integration_test/smoke/screen_matrix_test.dart`
7. Run Layer B+C+D on staging
8. Export V2 baseline JSON
9. Begin Phase P1 only after baseline locked

---

## 12) System Report Template (every feature)

Use for each system in final V2 report:

```markdown
### Sistem: [name]
**Açıklama:** ...
**Güçlü Yanları:** ...
**Zayıf Yanları:** ...
**Exploitler:** ... (measured, not hypothetical)
**Oyuncu Psikolojisi:** ...
**Ekonomik Etkisi:** ... (+X% gold velocity est.)
**Retention Etkisi:** ... (+/- Y pt D7 est.)
**Monetizasyon Etkisi:** ... (+/- Z% gem conv est.)
**Önerilen Düzeltmeler:** ...
**Öncelik:** Kritik | Yüksek | Orta | Düşük
```

Systems list: Auth, Home, Character, Inventory, Reputation, Dungeon, PvP, Leaderboard, Season/BP, Guild, Guild War, Monument, Loot, Market, Shop, Bank, Trade, Craft, Enhancement, Facilities, Mekan, Quests, Hospital, Prison, Chat, Settings, VIP/Premium, Economy (global).

---

## 13) Success Definition

V2 smoke PASS when:
- Backup + restore drill: PASS
- Sim segments within ±1% of target distribution at N=1300
- Exploit metrics vary run-to-run and match replay logs
- integration_test screen matrix: 0 failures
- 1000 mekan perf within targets
- All output categories from original prompt populated with **measured** data
- P0 exploit success < 5% OR documented accepted risk with mitigation timeline
