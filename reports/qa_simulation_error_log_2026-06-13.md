# QA Simulation Error Log

Run date: 2026-06-13
Target run_id: fe1e6dcc-4738-49e1-a48a-3057babb3d8c

## Error 1: Bot Seed Collision
- Stage: `select public.qa_seed_bots(100)`
- Error:
  - `duplicate key value violates unique constraint users_auth_id_key`
  - Cause: inserting into `auth.users` likely triggered auto profile insert into `public.users`, then explicit insert collided on `auth_id`.
- Fix applied:
  - `qa_seed_bots` changed to `INSERT ... ON CONFLICT (auth_id) DO UPDATE` in `public.users` write path.
- Result: seed passed (`seeded_bots=100`).

## Error 2: Interval Type Mismatch
- Stage: `select public.qa_run_30_day_simulation(30)`
- Error:
  - `function make_interval(mins => bigint) does not exist`
  - Cause: aggregated minute values were bigint; `make_interval` expected integer argument.
- Fix applied:
  - cast to int (`make_interval(mins => value::int)`) and redeployed simulation function.
- Result: simulation completed (`events=3000`).

## Stability Note
- No fatal runtime error after fixes.
- Remaining risk:
  - `public` functions without explicit `SET search_path`: 210 (security hardening backlog).
