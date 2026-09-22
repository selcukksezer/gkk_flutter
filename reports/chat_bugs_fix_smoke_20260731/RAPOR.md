# Chat Bugs Fix + Smoke — Master Report

**Tarih:** 2026-07-31  
**Workspace:** `/Users/selcuk/Documents/gkk-web/gkk_flutter`  
**Kanıt:** canlı Supabase MCP + repo code + `scripts/zone_level_gate_smoke_100chars.py` re-run  
**Verdict:** Functional chat bugs **closed**. Store **NO-GO** (legal/signing/icons still open).

---

## 1. Executive summary

| Bucket | Count |
|--------|------:|
| Already OK (verified this pass) | **9** |
| Fixed this pass | **6** |
| Smoke PASS | **8** |
| Smoke FAIL | **0** |
| Residual store blockers (manual / non-code) | **see §4** |

**This pass shipped:**
1. Strip illegal equipped gear + full equip-stat/power resync (`strip_illegal_equipped_resync`)
2. Android `INTERNET` + `ACCESS_NETWORK_STATE` in main manifest
3. Display name → `GKK` (Android / iOS / `AppConstants`)
4. `StaffHubDebugLog` gated behind `kDebugMode`
5. Release: stub IAP gem catalog hidden (placeholder copy only)
6. Release: mock ad CTAs hidden (prison / hospital / box-open)

---

## 2. Inventory table

| # | Bug | Was | Status | Fix / evidence |
|---|-----|-----|--------|----------------|
| A1 | BP quest pacing (1 quest → 3–4 rewards) | OPEN→LIVE earlier | **OK** | Live `bp_quest_templates`: daily 150–250, weekly 500–700. `max_weekly=700 < 1000` → 0.7 level. Mig `bp_season_quest_pacing` (`20260731141214`) |
| A2 | Horse race HUD covering track | Reported fixed | **OK** | Code: B slim `_BroadcastHud` + D peek standings + A `trackEndY=0.10` + bet chip (`horse_race_live_view.dart`, `horse_race_track_painter.dart`) |
| A3 | Equip level gate missing | FIXED mig | **OK** + residual closed | Live `equip_item` has `Level yetersiz` + `sync_user_equipment_stats`. Client gate in inventory. **Residual:** 9 illegal equipped → stripped this pass |
| A4 | Equip stats not on character | FIXED | **OK** | `sync_user_equipment_stats` live; equip path calls it |
| A4b | Luck double-count → ~2.5M power | FIXED | **OK** | `calculate_user_total_power` uses `luck - equip_bonus_luck`. Client `power_formula.dart` mirrors. `theking` stored=live **13409** post-strip (was 276164 with illegal mythic; pre-luck-fix 2.5M) |
| A5 | Dungeon XP breakdown UI | FIXED | **OK** | Live `enter_dungeon` / `attack_dungeon_rl_inner` contain `xp_breakdown`. Client `DungeonXpBreakdown` + banner |
| A6 | Enhancement page no scroll | FIXED | **OK** | Anvil in `SingleChildScrollView`; inventory `GameScrollLayout.bottomInset` |
| A7 | Chat/bottom bar swallows taps | FIXED | **OK** | `ColoredBox` removed; Stack + `IgnorePointer` gradient (`game_chrome.dart`) |
| A8 | Region zone level gates | FIXED | **OK** | Live zones Z1–Z7 gates 1/15/25/35/45/55/65. Smoke HEALTHY |
| A9 | Power spike ~2.5M | FIXED | **OK** | See A4b; synthetic epic+4=122700, mythic+4=331770 |
| C1 | Strip illegal already-equipped | OPEN residual | **FIXED this pass** | Mig `20261016_140000_strip_illegal_equipped_resync.sql` → remote `20260731141425_strip_illegal_equipped_resync`. Illegal count **9 → 0** |
| C2 | Resync all users power | OPEN residual | **FIXED this pass** | Same mig: loop `sync_user_equipment_stats` + power recalc |
| C3 | Confirm BP BPP live | Verify | **OK** | weekly max 700, daily max 250 |
| B1 | Android INTERNET main manifest | OPEN | **FIXED this pass** | `android/app/src/main/AndroidManifest.xml` |
| B2 | Stub IAP / mock ads in release | OPEN | **FIXED this pass** | Gem tab placeholder in `kReleaseMode`; ad buttons only if `MockAdService.allowMockReward` |
| B3 | Debug logger in release | OPEN | **FIXED this pass** | early `if (!kDebugMode) return;` |
| B4 | Placeholder app name | OPEN | **FIXED this pass** | label/display → `GKK` |
| B5 | Placeholder Android icons | OPEN | **RESIDUAL** | Still Flutter default tiny PNGs (~0.4–1.4KB). No brand asset in repo to replace |

---

## 3. Smoke results

### 3.1 Pass / fail table

| Smoke | Result | Detail |
|-------|--------|--------|
| Zone gate 100-char re-run | **PASS** | `reports/zone_level_gate_smoke_100chars_20260731_rerun` — HEALTHY; FP=0 FN=0; softlock FAIL=0; 789 attempts |
| BP pacing (max weekly BPP) | **PASS** | max weekly **700** < 1000 → 1 claim < 1 level |
| Illegal equipped count | **PASS** | **0** after strip |
| Equip level gate (fn body) | **PASS** | `Level yetersiz` present; calls `sync_user_equipment_stats` |
| Power no double luck | **PASS** | fn uses `equip_bonus_luck`; live users stored=live_power |
| Synthetic power builds | **PASS** | epic+4 **122,700**; mythic+4 **331,770** (not millions) |
| XP breakdown in RPC | **PASS** | `enter_dungeon` + `attack_dungeon_rl_inner` contain `xp_breakdown` |
| Dart analyzer (touched files) | **PASS** | 0 errors; 2 unused warnings + deprecation infos pre-existing in `game_chrome` |

### 3.2 Live hero probes (post-strip)

| User | Lv | power | equip_bonus_luck | live_power | Notes |
|------|---:|------:|-----------------:|-----------:|-------|
| theking | 23 | 13,409 | 0 | 13,409 | All 8 illegal mythic stripped |
| gercek1 | 5 | 5,545 | 406 | 5,545 | Illegal epic boots stripped; other legal gear remains |
| testet | 53 | 61,147 | 4,072 | 61,147 | Unchanged / consistent |
| selcukksezer | 99 | 57,741 | 556 | 57,741 | Unchanged / consistent |

### 3.3 Zone smoke re-run summary

- Characters: 100 · Attempts: 789 · ALLOW_OK 424 · DENY_OK 365  
- Softlock: OK 54 / WARN 46 / **FAIL 0**  
- Verdict: **HEALTHY**  
- Out: `reports/zone_level_gate_smoke_100chars_20260731_rerun/`

### 3.4 Migrations live (relevant)

| Remote version | Name |
|----------------|------|
| 20260731111254 | equip_level_gate_stat_sync |
| 20260731111437 | enter_dungeon_xp_breakdown |
| 20260731140734 | dungeon_zone_level_gate |
| 20260731140851 | fix_power_exclude_equip_luck |
| 20260731141214 | bp_season_quest_pacing |
| **20260731141425** | **strip_illegal_equipped_resync** ← this pass |

---

## 4. Residual store blockers (NOT store-ready)

Code-fixable items from readiness audit handled above. Still **manual / external**:

| Blocker | Why not fixed here |
|---------|-------------------|
| Release signing = debug keystore | Needs upload key / `key.properties` / Play App Signing (secrets) |
| Public Privacy Policy / Terms URL | Must host externally; do not invent URLs |
| Android launcher icons still Flutter default | No brand icon assets in repo; need designer 512 + adaptive |
| Real IAP (StoreKit / Play Billing) | Not wired; release now shows “yakında” only |
| Real AdMob + ATT / Data safety | Mock fail-closed; release CTAs hidden |
| Exact alarm permissions review | Play policy questionnaire |
| App Store Connect / Play Console metadata | External |
| PrivacyInfo.xcprivacy app-level | Packaging |
| CI store pipeline | Not in repo |
| Bundle ID polish (`com.gkk.gkk_flutter` vs `com.gkk.gkkFlutter`) | Product decision |

**Do not claim store-ready.**

---

## 5. Playtest checklist

- [ ] Login `theking` → power ~13k (not 2.5M / not 276k with mythic) until legal gear re-equipped at Lv55
- [ ] Lv10 try equip Lv55 → RPC reject + client “SEVIYE YETERSIZ”
- [ ] Equip legal HP armor → character `max_health` / ATK / DEF rise; unequip → drop
- [ ] Weekly BP claim → BPP +≤700; no multi-level jump
- [ ] Horse race live ~90% → track/horses visible under slim HUD + peek standings
- [ ] Enhancement small screen → anvil + grid scroll; bottom cells tappable left of chat FAB
- [ ] Dungeon win with monument → XP breakdown banner shows
- [ ] Zone: Lv14 cannot enter Z2; Lv15 can
- [ ] Release build: Gem tab “yakında” (no fake prices); no Reklam İzle on prison/hospital
- [ ] Release APK: network works (INTERNET in main)
- [ ] Home screen label shows **GKK**

---

## 6. Files touched this pass

| Path | Change |
|------|--------|
| `supabase/migrations/20261016_140000_strip_illegal_equipped_resync.sql` | Strip + resync |
| `android/app/src/main/AndroidManifest.xml` | INTERNET + NETWORK_STATE; label GKK |
| `ios/Runner/Info.plist` | Display/Name GKK |
| `lib/core/constants/app_constants.dart` | appName GKK |
| `lib/core/debug/staff_hub_debug_log.dart` | `kDebugMode` gate |
| `lib/screens/shop/shop_screen.dart` | Release IAP stub hide |
| `lib/screens/prison/prison_screen.dart` | Hide ad CTA when mock off |
| `lib/screens/hospital/hospital_screen.dart` | Hide ad CTA when mock off |
| `lib/screens/inventory/widgets/inventory_item_detail_flow.dart` | Hide ad box option when mock off |
| `reports/chat_bugs_fix_smoke_20260731/RAPOR.md` | this report |

---

## 7. Counts for handoff

- **Fixed this pass:** 6  
- **Already OK verified:** 9  
- **Smoke PASS / FAIL:** 8 / 0  
- **Master MD:** `reports/chat_bugs_fix_smoke_20260731/RAPOR.md`  
- **Store:** still NO-GO (signing, privacy URL, Android icons, real IAP/ads)
