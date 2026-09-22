# AI Live-Play — Runner notes

## Seed 300

```bash
./scripts/qa_seed_bots.sh 300
```

## Swarm

```bash
AI_BOTS=300 AI_WORKERS=1 ./scripts/run_ai_swarm.sh
# parallel shards:
AI_FROM=1 AI_TO=300 AI_WORKERS=10 ./scripts/run_ai_swarm.sh
```

Reports → `reports/ai_swarm_300_<timestamp>/`

## UI spot-check

```bash
./scripts/run_ai_ui_spotcheck.sh
# AI_SPOT_BOT=1 AI_DEVICE=<id> ./scripts/run_ai_ui_spotcheck.sh
```

## Wipe (launch)

See [WIPE_CHECKLIST.md](WIPE_CHECKLIST.md).

```bash
./scripts/qa_wipe_bots.sh
```

## Architecture

- SQL: `qa_seed_live_play_bots` / `qa_live_play_run_bot` / `qa_live_play_swarm` / `qa_wipe_live_play_bots`
- Dart: `integration_test/agent/*` (registry, mesh, headless driver, reports)
- Unit: `test/smoke/ai_swarm_coverage_test.dart`
