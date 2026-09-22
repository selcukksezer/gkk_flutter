# Stat Inflation — Smoke (2026-07-31)

**Target:** live Supabase MCP `project-0-gkk_flutter-supabase`  
**Plan:** `RAPOR.md` §10 IMPLEMENTED + residual HP  
**Post-fix migration:** `stat_inflation_hp_cut_potion_pct` / repo `20261017_230000_…`

---

## Summary

| Area | Result |
|------|--------|
| Luck unbake / hard ceiling | **PASS** |
| Effective luck wired | **PASS** |
| Enhance +10 = 2.04 | **PASS** |
| Mythic catalog factors | **PASS** (HP further cut this pass) |
| Client power = `profile.power` | **PASS** (code path) |
| Etkin şans UI | **PASS** (code path) |
| Potion client/server | **FAIL→FIXED** |
| Sheet HP band 40–60k @+10 | **WARN→PASS** after HP cut |
| ATK/DEF still baked | **WARN** (deferred) |
| PvP power impact of HP cut | **PASS** (~−1.5k on whale) |

---

## A) Checks

### A1. Whale sample — `theking`

| Metric | Pre-HP-fix (smoke) | Post-HP-fix | Verdict |
|--------|---------------------:|-------------:|---------|
| `users.luck` | 123 | 123 | PASS (base-only, ≪1500) |
| `equip_bonus_luck` | 14,642 | 14,642 | PASS (loot raw) |
| `effective_player_luck(auth_id)` | 623 | 623 | PASS (≤1500) |
| `equip_bonus_health` | 68,224 | **34,115** | PASS (×0.50 catalog) |
| `max_health` | 69,469 | **35,360** | PASS |
| `attack` / `defense` | 48,018 / 51,184 | same | WARN baked |
| `power` | 174,840 | **173,372** | PASS (−1,468 ≈ HP/10) |
| `health` current | 34,884 | 34,884 | clamped under new max |

**Note:** `effective_player_luck(users.id)` → 0. Fn keys on **`auth_id`**. Smoke must use `auth_id`. `enter_dungeon` passes `auth.uid()` → OK.

### A2. Global luck

| Check | Value | Verdict |
|-------|------:|---------|
| `COUNT(*) WHERE luck > 1500` | **0** | PASS |
| `MAX(users.luck)` | 284 | PASS |
| `MAX(effective_player_luck(auth_id))` | **775.5** | PASS |

### A3. `enter_dungeon` uses effective luck

Body contains `public.effective_player_luck(p_player_id)` for success / hospital / gold / XP / loot.  
Success itself = **power ratio** vs `power_requirement` (+ luck ≤+5%). **HP not in dungeon success.**  
Verdict: **PASS**

### A4. Enhance +10 multiplier

| enh | mult |
|----:|-----:|
| 0 | 1.00 |
| 4 | 1.48 |
| 6 | 1.72 |
| 10 | **2.04** |

Verdict: **PASS**

### A5. Mythic / legendary catalog (post-fix)

| Rarity | avg HP (gear slots) | max HP | Notes |
|--------|--------------------:|-------:|-------|
| mythic | 2,738 | 7,067 | phase2 ×0.40 then this ×0.50 |
| legendary | 3,169 | 8,080 | this pass ×0.40 (was tankier than mythic) |

Phase2 ATK/DEF ×0.70 + luck ×0.35 still in place (not re-applied).  
Verdict: **PASS** (HP cut); legendary catch-up **PASS**

### A6. Client power / etkin şans

| Check | Evidence | Verdict |
|-------|----------|---------|
| Character + inventory power | `readPlayerTotalPower` → `resolveDungeonCombatPower` prefers `profile.power` | PASS |
| Etkin şans | `character_screen` → `effectivePlayerLuckFromProfile` + subtitle `baz N` | PASS |
| Client enh / luck mirror | `enhancement_stats.dart`, `effective_luck.dart` match SQL | PASS |

### A7. Potions vs max_hp

**Before fix (FAIL):**

- Catalog: `heal_amount` 5k/20k/50k but **`health_restore = 0`**
- Client only read `health_restore` → preview/labels broken / “0 can”
- Preview used `addictionLevel` instead of `tolerance` → wrong efficiency
- Flat 5k on 69k HP ≈ 7% — felt trivial or weird vs label mismatch

**After fix:**

| Potion | Heal model | @ theking max_hp 35,360 |
|--------|------------|-------------------------|
| minor | 25% max_hp | 8,840 |
| major | 50% | 17,680 |
| supreme | 100% | 35,360 |
| Restoratio | 40% | 14,144 |

`health_restore` mirrored from `heal_amount`; `potion_type='health'`.  
Client: `heal_amount` fallback + `%` preview + tolerance fix.  
Verdict: **PASS** (after fix)

### A8. Stat points vs gear vs power

| Source | Scale @ Lv70 whale | vs gear | Verdict |
|--------|-------------------:|---------|---------|
| Allocate HP (×10) | ≤ ~2,070 | vs eq HP 34k | negligible |
| Class+level base HP | ~1,245 (`base_hp`) | vs eq | small |
| Power | item_power Σ + lvl×500 + base_luck×50 | ATK/DEF sheet **not** in power | PASS consistent |
| Gear HP in power | `hp/10` only | −1.5k after cut | PASS |

Verdict: **PASS** — enflasyon gear; allocate not culprit.

### A9. +10 immortal band (post-fix proj)

| Metric | +4 live | +10 proj (same set) | Goal | Verdict |
|--------|--------:|--------------------:|------|---------|
| max_health | 35,360 | ~48.3k | 40–60k | **PASS** |
| power | 173k | ~225k class (prior smoke) | ≤420k | PASS |
| `users.luck` | 123 | 123 | ≤1500 | PASS |

---

## B) Diagnosis (mismatch root causes)

1. **HP still felt wrong after luck unbake**  
   Only luck unbaked. ATK/DEF/HP still `base + Σ enhanced(item.*)`. Mythic HP ×0.40 left whale @ **69k**; goal was 40–60k @+10.

2. **Potions**  
   Server flat `heal_amount`; client `health_restore=0` → UI broken. Flat heals poorly track max_hp swings. Tolerance preview used wrong field.

3. **Stat points vs equip**  
   Two paths: allocate → base; equip → `equip_bonus_*` baked into sheet. Power ignores sheet ATK/DEF; uses item_power. → Sheet “god stats” ≠ dungeon math.

4. **Dungeon**  
   Uses **`power`** (and effective luck softcaps). **Not** `max_health` for success. HP mismatch = UX/hospital/potion feel, not clear-rate bug.

---

## C) Fix shipped this pass

| Change | Where |
|--------|-------|
| Mythic HP ×0.50 again | live items + resync |
| Legendary HP ×0.40 | live (parity) |
| Potion heal = % max_hp | `use_potion` |
| `health_restore` sync + `potion_type` | items |
| Client heal_amount / % / tolerance | `potion_health.dart`, inventory repo/provider/models |
| Repo mirror | `supabase/migrations/20261017_230000_stat_inflation_hp_cut_potion_pct.sql` |

### PvP note

Guild war snapshots **power**; damage often **% max_health**.  
HP cut → smaller absolute HP bars; **% damage ratios unchanged**.  
Whale power −~1.5k (−0.8%). **No silent PvP wipe.** ATK/DEF sheet unchanged this pass.

---

## D) Open / deferred

- [ ] ATK/DEF Model-C unbake + display split
- [ ] Epic HP still high vs new mythic (avg ~5.1k) — optional next cut
- [ ] Potion UI still shows flat `health_restore` numbers in some places; labels prefer `%` when `itemId` known
- [ ] Faz 3 telemetry / garrison softcap
- [ ] Power `luck×2` → `luck_combat×0.5` still not applied
- [ ] Mythic +4 power ~173k under plan mid-band 220–320k (ladder-safe; market impact open)

---

## Smoke operator note

Always call `effective_player_luck(auth_id)` — never `users.id`.
