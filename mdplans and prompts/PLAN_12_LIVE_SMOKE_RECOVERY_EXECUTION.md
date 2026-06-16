# PLAN 12 - Backup-First Remediation + Live Ultra Smoke

Status: Draft for execution
Owner: QA + Game Design + Economy + LiveOps + Security
Date: 2026-06-13

## 0) Hard Gate - Full Backup First

No backup, no change. Rule hard.

### 0.1 Backup Scope (full, data included)
- Postgres full logical dump (`schema + data + auth + public + storage metadata`).
- Supabase Storage objects full export (all buckets, all files).
- Current migrations snapshot (`supabase/migrations/*`).
- Runtime config snapshot (RLS policies, functions, triggers, extensions).

### 0.2 Current Local Blockers
- `supabase` CLI: missing.
- `pg_dump`: missing.

### 0.3 Install Tools (operator step)
```bash
brew install supabase/tap/supabase
brew install libpq
echo 'export PATH="/opt/homebrew/opt/libpq/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
supabase --version
pg_dump --version
```

### 0.4 Full Backup Commands (run before any migration)
`<PROJECT_REF>`, `<DB_HOST>`, `<DB_PORT>`, `<DB_NAME>`, `<DB_USER>`, `<DB_PASSWORD>` fill from Supabase project settings.

```bash
TS=$(date +%Y%m%d_%H%M%S)
mkdir -p backups/$TS

# 1) Full DB dump (schema + data)
PGPASSWORD='<DB_PASSWORD>' pg_dump \
  --host='<DB_HOST>' \
  --port='<DB_PORT>' \
  --username='<DB_USER>' \
  --dbname='<DB_NAME>' \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file="backups/$TS/full_db.dump"

# 2) Plain SQL mirror (human diff)
PGPASSWORD='<DB_PASSWORD>' pg_dump \
  --host='<DB_HOST>' \
  --port='<DB_PORT>' \
  --username='<DB_USER>' \
  --dbname='<DB_NAME>' \
  --format=plain \
  --no-owner \
  --no-privileges \
  --file="backups/$TS/full_db.sql"

# 3) Storage export (all buckets)
# Option A: Supabase Storage API script with service role key.
# Option B: Dashboard export if API export script unavailable.

# 4) Integrity hash
shasum -a 256 backups/$TS/full_db.dump > backups/$TS/full_db.dump.sha256
shasum -a 256 backups/$TS/full_db.sql > backups/$TS/full_db.sql.sha256
```

### 0.5 Restore Drill (must pass)
- Restore to staging clone first.
- Open app with staging env.
- Critical checks:
  - Login works.
  - User inventory count matches prod snapshot.
  - Market order count matches prod snapshot.
  - Guild + PvP + dungeon rows readable.

Restore command sample:
```bash
PGPASSWORD='<STAGING_DB_PASSWORD>' pg_restore \
  --host='<STAGING_DB_HOST>' \
  --port='<STAGING_DB_PORT>' \
  --username='<STAGING_DB_USER>' \
  --dbname='<STAGING_DB_NAME>' \
  --clean --if-exists --no-owner --no-privileges \
  "backups/$TS/full_db.dump"
```

Gate pass condition:
- Backup files exist.
- Hash files exist.
- Staging restore pass.

---

## 1) Execution Rules
- One phase at time.
- Each phase after deploy:
  - Regression check.
  - Error tests.
  - KPI compare vs baseline.
- Any fail: stop, rollback, RCA, fix, retest.

Go / No-Go:
- Go only if all phase tests green.
- No-Go if P0/P1 bug, economy drift > threshold, crash spike, auth/RLS break.

---

## 2) Phase Plan (teker teker hayata geçirme)

### Phase 1 - Security + DB Hardening
Scope:
- `SECURITY DEFINER` functions add explicit `SET search_path`.
- RLS enabled/no-policy findings close.
- RPC permission review (`authenticated` only needed funcs).

Tests:
- Function call auth tests (allowed/denied).
- RLS table read/write tests.
- SQL injection guard tests on text inputs.

Exit:
- Advisor security findings down to accepted baseline.
- No unauthorized cross-user data access.

### Phase 2 - Exploit Shields
Scope:
- Multi-account funnel detection.
- Market anti-manipulation guardrails (median band + outlier reject + listing cap).
- Premium duplicate grant protection (idempotency key).
- Cooldown nonce/server-time enforcement.

Tests:
- 50 exploit scripts replay.
- False positive check on normal users.

Exit:
- Exploit success rate < %5.

### Phase 3 - Economy Rebalance
Scope:
- Gold sinks increase (maintenance/tax/upgrade wear).
- Item sinks increase (durability + bind rules + craft burn).
- Reward inflation trim (quest/dungeon/pvp payout scaling).

Tests:
- 30-day sim compare old/new.
- Segment impact check (newbie/casual not crushed).

Exit thresholds:
- Gold inflation < %12 / 30 day.
- Item inflation < %15 / 30 day.

### Phase 4 - Retention Loops
Scope:
- D1-D7 onboarding chain redesign.
- Casual 10-15 min high-value loop.
- Midgame objective ladder (D7-D30).

Tests:
- Funnel instrumentation validation.
- Session-quality survey hooks.

Exit:
- D7 retention +10 puan target.

### Phase 5 - PvP Fairness
Scope:
- Bracket matchmaking (level + rating band).
- Newbie shield (first 7 days / level cap).
- Smurf detection.

Tests:
- Mismatch simulation (low vs high level).
- Rage-quit predictor trend.

Exit:
- Newbie-vs-high mismatch < %2.

### Phase 6 - Hospital/Prison Monetization Rework
Scope:
- Dynamic gem cost curve.
- Daily cap + escalating repeat penalty.
- Value clarity UI (minutes saved vs gem cost).

Tests:
- A/B price points.
- Conversion vs churn balance.

Exit:
- Skip conversion rise.
- Churn not worse.

### Phase 7 - 1000+ Mekan UX + Perf
Scope:
- Search + filter + sort.
- Recommended / popular / active tabs.
- Presence batching.

Tests:
- 1000, 5000, 10000 mekan synthetic list.
- Low-end device fps + memory.

Exit:
- Scroll jank acceptable.
- Query p95 within target.

### Phase 8 - Final Live Ultra Smoke
Scope:
- Bigger bot load.
- All top bar menus + all sub screens.
- End-to-end flows with heavy activity.

Exit:
- P0/P1 zero.
- KPI thresholds pass.

---

## 3) Test Matrix - Top Bar + Alt Ekran Full Coverage

Source: `lib/components/layout/game_chrome.dart` drawer routes + `lib/routing/app_router.dart`.

### 3.1 Top Menu Main Screens
- Ana Sayfa
- Karakter
- İtibar
- Zindan
- PvP
- Sıralama
- Mevsim
- Lonca
- Lonca Savaşı
- Anıt
- Kasa & Çark
- Pazar
- Mağaza
- Banka
- Ticaret
- Zanaat
- Güçlendirme
- Tesisler
- Mekanlar
- Görevler
- Hastane
- Hapishane
- Sohbet
- Ayarlar

### 3.2 Sub-Screen Mandatory Coverage
- Tesis detay (`/facilities/:type`)
- Guild war tournament detail (`/guild-war/tournament/:id`)
- Guild war territory detail (`/guild-war/territory/:id`)
- Guild war logs
- Guild war battle result
- Mekan detail (`/mekans/:id`)
- Mekan arena (`/mekans/:id/arena`)
- My Mekan
- PvP history
- PvP tournament
- Dungeon battle
- Quest tabs
- Market tabs (browse/sell/my market)
- Loot tabs
- Crafting tabs

### 3.3 Screen Test Template (for each screen)
- Load time (cold/warm).
- API errors handling.
- Empty state.
- High-data state.
- Navigation in/out.
- Back button behavior.
- Crash-free interaction (10 repeated actions).
- Currency/resource sync correctness.

---

## 4) Live Ultra Smoke - Bigger Population + More Activity

### 4.1 Bot Load Plan
- 1000 base bots.
- +200 spike bots (hardcore/whale).
- +100 exploit bots (multi/exploit).
- Total: 1300 bots.

### 4.2 Activity Amplification
- 2x market actions.
- 2.5x pvp attacks.
- 2x dungeon runs.
- 1.8x crafting.
- 2x guild actions.
- 2x mekan actions.

### 4.3 Time Horizon
- Sim checkpoints: D1, D3, D7, D14, D30.
- Plus stress day: D0 burst (peak concurrency emulation).

### 4.4 Mandatory Metrics
- Retention: D1/D3/D7/D14/D30.
- Economy: gold/item mint vs sink.
- Monetization: gem spend, skip conversion.
- Exploit: attempted vs success.
- Stability: error rate, timeout rate, RPC fail rate.
- Performance: p50/p95/p99 endpoint latency.

---

## 5) Regression + Error Test Pack (every phase)

### Functional Regression
- Auth/login/register/session refresh.
- Inventory equip/unequip/split/merge.
- Market list/buy/sell/cancel.
- Dungeon enter/resolve/reward.
- PvP attack/result/rating.
- Guild create/join/donate/war.
- Hospital/prison entry/escape/release.
- Craft queue start/complete/claim.
- Mekan create/upgrade/arena.

### Error Injection Tests
- RPC timeout.
- DB lock contention.
- Duplicate request replay.
- Race condition on currency updates.
- Invalid payload + boundary values.

### Data Integrity Tests
- Negative currency guard.
- Double-spend guard.
- Orphan rows check.
- FK consistency checks.

---

## 6) Rollback Plan
- Trigger rollback if:
  - P0 bug found.
  - economy drift > threshold.
  - crash/timeout spike > baseline * 2.
- Rollback order:
  1. Disable new feature flags.
  2. Revert latest migration batch.
  3. Restore staging proof.
  4. If needed restore prod from backup snapshot window.

---

## 7) Deliverables
- `backups/<timestamp>/full_db.dump`
- `backups/<timestamp>/full_db.sql`
- `backups/<timestamp>/*.sha256`
- `reports/phase_<n>_regression.md` for each phase
- `reports/live_ultra_smoke_<date>.md`
- Final go/no-go summary + risk register

---

## 8) Immediate Next Actions
1. Install backup tools.
2. Take full backup + checksum.
3. Restore drill staging.
4. Freeze baseline metrics.
5. Start Phase 1 only after Gate 0 pass.
