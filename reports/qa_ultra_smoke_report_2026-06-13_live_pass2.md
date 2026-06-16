# MMORPG / Crime RPG Ultra Deep Simulation Smoke Test (Live Pass 2)

Date: 2026-06-13
Project: znvsyzstmxhqvdkkmgdt
Scope: Backup-first execution + 1300 bot, 30-day live simulation + security/performance lint pass

## 1) Backup Gate Status

- In-DB full snapshot backup: PASS
  - backup_id: `bkp_20260613_081424`
  - backup_schema: `backup_20260613_081424`
  - captured_tables: 74
  - captured_rows: 43353
- External pg_dump all-schema: BLOCKED by Supabase role permissions (`auth` schema lock denied)
- External pg_dump public-schema: BLOCKED by table permission (`public.items` lock denied)
- Supabase CLI `db dump`: BLOCKED locally because Docker daemon is required and unavailable

Decision applied for continuation:
- Proceeded with in-DB full snapshot as rollback anchor.

## 2) Phase-1 Hardening Applied

Migration applied:
- `phase1_security_hardening_search_path`
  - Action: set `search_path` to `public, pg_temp` for all `public` functions
- `phase1_performance_add_missing_fk_indexes`
  - Action: auto-create missing FK-leading indexes in `public`

## 3) 1300 Bot / 30 Day Live Simulation Run

- Seed call: `select * from public.qa_seed_bots(1300);`
  - Result: `seeded_bots = 1300`
- Run call: `select * from public.qa_run_30_day_simulation(30);`
  - Result:
    - success: true
    - run_id: `b82690d4-548e-43ef-a261-4cd03dfbdbe7`
    - days: 30
    - bots: 1300
    - events: 39000

## 4) Economy / Activity Metrics

From `qa_sim_daily_events` and `qa_sim_checkpoints` for run `b82690d4-548e-43ef-a261-4cd03dfbdbe7`:

- total_events: 39000
- distinct_active_bots: 1300
- avg_session_minutes (active): 47.76
- total_gold_earned: 60321288
- total_gold_spent: 38825634
- total_gems_spent: 253798
- total_items_minted: 136145
- total_items_burned: 77727
- exploit_findings: 6

Economic pressure signal:
- net_gold_inflation = 60321288 - 38825634 = 21495654 (positive inflation)

## 5) Retention Curve (Checkpointed)

Checkpoint data:

- Day 1: active 1238 / retained 1300
- Day 3: active 1158 / retained 1158
- Day 7: active 1054 / retained 1054
- Day 14: active 834 / retained 834
- Day 30: active 538 / retained 538

Derived rates (base cohort 1300):

- D1 active rate: 95.23%
- D7 active rate: 81.08%
- D30 active rate: 41.38%

Interpretation:
- Mid-term decay is acceptable for synthetic load testing but Day-30 is low for target MMORPG retention goals.

## 6) Exploit Findings (Top Risk)

- critical: `multi_account_gold_funnel`
  - attempts: 260
  - success: 83
  - impact: 1,850,000 gold + 1,200 gems
- critical: `premium_stack_abuse`
  - attempts: 90
  - success: 14
  - impact: 480,000 gold
- high: `market_price_manipulation`
  - attempts: 190
  - success: 71
  - impact: 1,240,000 gold
- high: `cooldown_bypass`
  - attempts: 110
  - success: 19
  - impact: 320,000 gold + 170 gems
- high: `prison_escape_abuse`
  - attempts: 126
  - success: 46
  - impact: 260,000 gold + 710 gems
- medium: `hospital_escape_abuse`
  - attempts: 140
  - success: 52
  - impact: 620 gems

## 7) Advisor Snapshot After Phase-1

Security lints total: 416
- `anon_security_definer_function_executable`: 194
- `authenticated_security_definer_function_executable`: 194
- `rls_disabled_in_public`: 21
- `security_definer_view`: 2
- `function_search_path_mutable`: 2
- `rls_enabled_no_policy`: 2
- `auth_leaked_password_protection`: 1

Performance lints total: 360
- `unused_index`: 162
- `no_primary_key`: 74
- `multiple_permissive_policies`: 60
- `auth_rls_initplan`: 58
- `duplicate_index`: 6

Interpretation:
- Search-path hardening in `public` is complete, but remaining mutable search path issues are in `game` schema functions.
- Largest remaining risk is broad SECURITY DEFINER execution exposure and missing RLS coverage.

## 8) Regression Status

- DB migrations applied successfully: PASS
- 1300x30 simulation run completed: PASS
- Backup/rollback anchor present: PASS (in-DB snapshot)
- External offline backup artifact: FAIL (permission + docker constraints)

## 9) Immediate Remediation Queue

Priority-0:
- Restrict EXECUTE on SECURITY DEFINER functions from `anon` and `authenticated`; expose only vetted RPC wrappers.
- Enable RLS on all externally exposed `public` gameplay tables where disabled.

Priority-1:
- Add explicit policies on `game.user_quests` and `public.mekan_pvp_matches` (currently RLS enabled but no policy).
- Remove SECURITY DEFINER from views unless strictly required.

Priority-2:
- Tune index set (drop unused/duplicate after query-plan validation).
- Add PKs to missing tables where data model allows stable identifiers.

## 10) Final Verdict

- Live smoke objective executed with larger cohort (1300 bots) and 30-day horizon.
- System is load-test runnable but NOT production-hardening complete due to critical security lint backlog and exploit success rates.
- Recommended release gate: BLOCK until Priority-0 is closed and revalidated with another 1300x30 run.
