# Game Polish QA Audit & Adversarial Review Report

**Date**: 2026-10-28T21:30:00Z  
**Auditor**: polish_5_game_reviewer (Teamwork Archetype: Reviewer & Adversarial Critic)  
**Target Scope**:
- Character Screen (`lib/screens/character/`)
- Inventory & Crafting Screens (`lib/screens/inventory/`, `lib/screens/crafting/`)
- PvP & Guild War Screens (`lib/screens/pvp/`, `lib/screens/guild_war/`)
- Market & Trade Screens (`lib/screens/market/`, `lib/screens/trade/`)

---

## 1. Executive Summary & Verdict

### Verdict: **REQUEST_CHANGES** ❌

While significant modernized visual assets, 3D turntable viewports, and Aion 2 design tokens have been drafted across several screens, the current codebase **fails production mobile quality and compilation gates**.

### Primary Blockers:
1. **Compilation Failures**: Target screen code in `lib/screens/pvp/pvp_screen.dart` and `lib/screens/inventory/widgets/` fails to compile due to missing required arguments and missing static members. All integration/route tests (`route_registry_test.dart`) abort at compilation time.
2. **Mobile Touch Target Violations (< 48dp)**: Several interactive buttons directly violate the mandatory mobile hit target threshold:
   - `lib/screens/trade/trade_screen.dart`: **12dp** touch hit target for item removal from trade offer (`Icon(Icons.close, size: 12)`).
   - `lib/screens/crafting/widgets/crafting_preview_panel.dart`: **32dp** batch decrement/increment buttons (`SizedBox(width: 32, height: 32)`).
   - `lib/screens/inventory/widgets/inventory_item_detail_flow.dart`: **36dp** modal close button (`minWidth: 36, minHeight: 36`).
   - `lib/screens/pvp/pvp_history_screen.dart`: **~30dp** filter chips.
3. **Failing Domain Tests**: Unit tests directly tied to modernized character and inventory models fail (`player_model_test.dart` serialization regression, `player_health_test.dart` health potion label mismatch).
4. **Theme Inconsistency**: Despite newly added components (`CodexScreen`, `EquipmentSocketDock`), `CharacterScreen` modal pickers, `PvpScreen`, and `TradeScreen` remain largely built with flat boxes (`AppColors.carbonVoid`, `ListTile`) lacking unified frosted glassmorphism and Aion 2 runic visual fidelity.

---

## 2. Findings Matrix

| Finding ID | Severity | Category | Affected File(s) | Impact |
|---|---|---|---|---|
| **CRIT-01** | **Critical** | Build / Compile | `lib/screens/pvp/pvp_screen.dart:704` | Missing `onWagerSelected` parameter in `PvpThumbActionDeck` breaks build |
| **CRIT-02** | **Critical** | Build / Compile | `lib/screens/inventory/widgets/inventory_item_detail_flow.dart:194,216,227,241,251`, `inventory_item_detail_panel.dart:294` | Missing static members (`cardBg`, `textMuted`, `textPrimary`, `textBody`) & unhandled nullable callback |
| **CRIT-03** | **Critical** | Mobile UX / Accessibility | `lib/screens/trade/trade_screen.dart:821-825` | 12x12dp touch hit target on trade item deletion (Severe mis-tap risk) |
| **CRIT-04** | **Critical** | Mobile UX / Accessibility | `lib/screens/crafting/widgets/crafting_preview_panel.dart:334-371` | 32x32dp batch stepper buttons (`-` and `+`) |
| **CRIT-05** | **Critical** | Regression / Test | `test/models/player_model_test.dart`, `test/core/utils/player_health_test.dart` | `PlayerProfile` serialization map mismatch (`equip_bonus_luck`), potion text mismatch |
| **MAJ-01** | **Major** | Mobile UX / Accessibility | `lib/screens/inventory/widgets/inventory_item_detail_flow.dart:230` | 36x36dp close button (`BoxConstraints(minWidth: 36, minHeight: 36)`) |
| **MAJ-02** | **Major** | Mobile UX / Accessibility | `lib/screens/pvp/pvp_history_screen.dart:133-150` | Filter chips height ~28-30dp without 48dp min constraints |
| **MAJ-03** | **Major** | Visual / Aesthetic | `lib/screens/character/character_screen.dart:326-568` | Customization pickers use standard flat `ListTile` instead of glassmorphism dialogs |
| **MAJ-04** | **Major** | Visual / Aesthetic | `lib/screens/trade/trade_screen.dart` | 1700+ lines of flat dark boxes without frosted glass, glow, or runic framing |
| **MAJ-05** | **Major** | QA / Test Coverage | `lib/screens/` across all 7 target domains | Zero widget tests exist for modernized production screens |
| **MIN-01** | **Minor** | Code Quality / Lint | `lib/screens/trade/trade_screen.dart:492` | Linter `use_build_context_synchronously` across async gap |
| **MIN-02** | **Minor** | UX / Layout | `lib/screens/crafting/crafting_screen.dart:401-423` | Expanded `_QueueSection` (up to 260dp) risks obscuring recipe grid tiles |

---

## 3. Detailed Findings

### CRIT-01: Compile Error in `pvp_screen.dart`
- **Location**: `lib/screens/pvp/pvp_screen.dart:704:33`
- **Observation**:
  ```dart
  lib/screens/pvp/pvp_screen.dart:704:33: Error: Required named parameter 'onWagerSelected' must be provided.
                PvpThumbActionDeck(
                                  ^
  lib/screens/pvp/widgets/pvp_thumb_action_deck.dart:10:9: Context: Found this candidate, but the arguments don't match.
    const PvpThumbActionDeck({
  ```
- **Why It Matters**: The constructor for `PvpThumbActionDeck` defines `required ValueChanged<int> onWagerSelected`, but the instantiation in `PvpScreen` omitted this argument. This completely prevents compilation of the app and any tests depending on route wiring.
- **Remediation**: Pass a handler to `PvpThumbActionDeck` (e.g. `onWagerSelected: (wager) => ...`) in `pvp_screen.dart`.

---

### CRIT-02: Missing Static Constants & Null Safety Error in Inventory Widgets
- **Location**: `lib/screens/inventory/widgets/inventory_item_detail_flow.dart:194, 216, 227, 241, 251` and `inventory_item_detail_panel.dart:294`
- **Observation**:
  ```dart
  lib/screens/inventory/widgets/inventory_item_detail_flow.dart:194:51: Error: Member not found: 'cardBg'.
                    color: InventoryItemDetailPanel.cardBg,
                                                    ^^^^^^
  lib/screens/inventory/widgets/inventory_item_detail_panel.dart:294:30: Error: Can't use an expression of type 'void Function()?' as a function because it's potentially null.
  Try calling using ?.call instead.
                  primaryAction();
                               ^
  ```
- **Why It Matters**: `InventoryItemDetailPanel` had its style constants removed during recent refactoring, breaking `inventory_item_detail_flow.dart`. In addition, calling `primaryAction()` without `?.call()` triggers a Dart compilation error.
- **Remediation**: Restore or redirect the color tokens in `InventoryItemDetailPanel` (or use `AppColors.spaceNavy`, `AppColors.textPrimary`), and change `primaryAction();` to `primaryAction?.call();`.

---

### CRIT-03: Extreme Mobile Touch Target Violation in `TradeScreen` (12dp)
- **Location**: `lib/screens/trade/trade_screen.dart:821-825`
- **Observation**:
  ```dart
  if (isMine && allowRemove) ...<Widget>[
    const SizedBox(width: 4),
    GestureDetector(
      onTap: () => unawaited(_removeFromOffer(offer['row_id'].toString())),
      child: const Icon(Icons.close, size: 12, color: AppColors.mysticRuby),
    ),
  ],
  ```
- **Why It Matters**: The touch hit area is restricted to a 12x12 dp icon with zero padding or hit margin. On mobile touchscreens, users attempting to remove an item will fail or accidentally click neighbouring items.
- **Remediation**: Wrap the remove button in an `IconButton` or `Padding` with a minimum hit target constraint of `BoxConstraints(minWidth: 48, minHeight: 48)`.

---

### CRIT-04: Batch Increment/Decrement Stepper Sub-48dp in `CraftingPreviewPanel` (32dp)
- **Location**: `lib/screens/crafting/widgets/crafting_preview_panel.dart:334-371`
- **Observation**:
  ```dart
  SizedBox(
    width: 32,
    height: 32,
    child: TextButton(
      onPressed: batchCount < craftingBatchLimit ? onBatchIncrement : null,
      ...
    ),
  ),
  ```
- **Why It Matters**: Mobile users frequently adjust batch counts before crafting. Stepper buttons constrained to 32x32dp fall short of the 48dp mobile touch requirement.
- **Remediation**: Increase the stepper button container size to at least 48x48dp, or expand the tap padding using `materialTapTargetSize: MaterialTapTargetSize.padded`.

---

### CRIT-05: Regressed Domain Unit Tests
- **Location**:
  1. `test/models/player_model_test.dart`
  2. `test/core/utils/player_health_test.dart`
- **Observation**:
  - `player_model_test.dart`: Serialization test failed because `PlayerProfile.toJson()` recently added `'equip_bonus_luck'`, but the test expected the old key map without updating the schema assertion.
  - `player_health_test.dart`: Potion label assertion expected `+5000 can`, but returned `+25% max can`.
- **Why It Matters**: Code changes were committed without updating or verifying the corresponding unit tests, violating project regression standards.
- **Remediation**: Align `test/models/player_model_test.dart` and `test/core/utils/player_health_test.dart` with the new domain models and calculation logic.

---

### MAJ-01 & MAJ-02: Modal Close Button & Filter Chips Sub-48dp
- **Location**:
  - `lib/screens/inventory/widgets/inventory_item_detail_flow.dart:230`: `minWidth: 36, minHeight: 36` on the empty slot close icon button.
  - `lib/screens/pvp/pvp_history_screen.dart:133-150`: Filter tab buttons (`Tümü`, `Kazandım`, `Kaybettim`, `NEMESIS`) rendered with only `padding: const EdgeInsets.symmetric(vertical: 8)` and font size 12, yielding a total height under 30dp.
- **Remediation**: Provide `constraints: BoxConstraints(minHeight: 48)` and ensure adequate horizontal and vertical tap padding.

---

### MAJ-03 & MAJ-04: Inconsistent Aion 2 Glassmorphism Aesthetic
- **Observation**:
  - While `CodexScreen` and `EquipmentSocketDock` employ high-fidelity dark-fantasy Aion 2 aesthetics (`BackdropFilter`, radiant runic glowing borders, dynamic pulses, gold/cyber-fuchsia palettes), older sheets such as `_showAvatarPicker`, `_showFramePicker` in `CharacterScreen`, and dialogs in `PvpScreen` and `TradeScreen` use standard flat dark cards with default material `ListTile` widgets and solid borders.
  - `TradeScreen` in particular lacks any glassmorphism, blur filters, or luminous accents, feeling disconnected from the rest of the overhauled application.
- **Remediation**: Refactor modal bottom sheets in `CharacterScreen`, `PvpScreen`, and `TradeScreen` to use `AionRarityGlowBorder`, frosted glass blur (`ImageFilter.blur(sigmaX: 12, sigmaY: 12)`), and unified typography tokens.

---

### MAJ-05: Missing Production Widget Tests
- **Observation**: The repository contains extensive tests for background systems (`crowd_10k_stress_test.dart`, `gpu_instancing_batcher_test.dart`, `vat_crowd_renderer_test.dart`), but **zero widget tests** exist verifying that `CharacterScreen`, `InventoryScreen`, `CraftingScreen`, `PvpScreen`, `GuildWarHubScreen`, `MarketScreen`, or `TradeScreen` mount properly without runtime layout overflow on mobile viewports.
- **Remediation**: Create widget smoke tests for each overhauled screen in `test/screens/` testing standard mobile viewports (e.g. 360x640, 390x844).

---

## 4. Adversarial Stress-Test Challenges

### Scenario 1: Compact Android Phone (360dp Width)
- **Attack**: Simulating a budget Android device (360dp logical width) with active keyboard or dynamic bottom gesture inset.
- **Findings**:
  - In `CraftingScreen`, when `_QueueSection` is expanded to view 4+ queued craft jobs, it requests `maxHeight: 260`. On an 800dp tall screen with keyboard or bottom navigation bar, this consumes >40% of the viewport and obscures the bottom rows of the `GridView`, preventing recipe selection.
  - In `CharacterScreen`, the floating `EquipmentSocketDock` places 4 sockets on the left and 4 on the right around a 380dp turntable viewport. On a 360dp width screen, the 52dp sockets leave only 256dp in the center, which causes tight touch spacing between the turntable touch handler and socket tap targets.

### Scenario 2: Rapid Item Deletion in Trade Offer
- **Attack**: User attempts to remove 3 items rapidly from trade offer on a bumpy mobile commute.
- **Findings**: Because the close icon in `TradeScreen` is only 12dp wide with no padding, rapid tapping fails or triggers accidental navigation, leading to high frustration and trade confirmation errors.

---

## 5. Verification Command Logs

1. **`flutter analyze`**:
   - Exit code: **1**
   - Result: **477 issues found** (including compile-breaking undefined parameters and methods).
2. **`flutter test` (Full Suite)**:
   - Result: `04:34 +799 -17: Some tests failed.`
   - 17 unit test failures + compilation halts on multiple screen suites.
3. **`flutter test test/smoke/route_registry_test.dart`**:
   - Exit code: **1** (Failed during compilation due to errors in `pvp_screen.dart`, `inventory_item_detail_flow.dart`, and `inventory_item_detail_panel.dart`).

---

## 6. Actionable Resolution Checklist

Before this review can transition to **APPROVE**, the following items must be resolved:
- [ ] Fix compile error in `lib/screens/pvp/pvp_screen.dart:704` by supplying `onWagerSelected` to `PvpThumbActionDeck`.
- [ ] Fix compile errors in `lib/screens/inventory/widgets/inventory_item_detail_flow.dart` and `inventory_item_detail_panel.dart`.
- [ ] Fix compile errors in `lib/components/restriction/ward_panel.dart` and `lib/screens/staff/staff_liveops_screen.dart` (`activeThumbColor`).
- [ ] Increase touch targets to >= 48dp on:
  - `TradeScreen` offer remove icon (`size: 12` -> 48dp tap target).
  - `CraftingPreviewPanel` batch stepper buttons (`32dp` -> 48dp tap target).
  - `InventoryItemDetailFlow` empty slot close button (`36dp` -> 48dp tap target).
  - `PvpHistoryScreen` filter tabs (ensure minimum 48dp height).
- [ ] Update and pass regressed tests: `test/models/player_model_test.dart` and `test/core/utils/player_health_test.dart`.
- [ ] Add basic widget tests in `test/screens/` to guarantee zero runtime layout overflow on mobile form factors.
