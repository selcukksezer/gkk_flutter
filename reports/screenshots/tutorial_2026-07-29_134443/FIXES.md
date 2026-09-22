# Tutorial LIVE Smoke — Düzeltme Notları

- run: tutorial_2026-07-29_134443
- verdict: **FAIL** (17/28)
- failures: inventory_equip, inventory_to_character, character_check_power, character_stat_panel, character_class_abilities, character_open_menu, character_tap_enhance, enhance_pick_item, enhance_tap_forge, enhance_result, core_complete_check
- steps_logged: 28

## onboarding_welcome

- pass: True
- after: `01_after_onboarding_welcome.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## onboarding_game_loop

- pass: True
- after: `02_after_onboarding_game_loop.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## onboarding_home_promo

- pass: True
- after: `03_after_onboarding_home_promo.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## onboarding_home_hero

- pass: True
- after: `04_after_onboarding_home_hero.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## onboarding_hud_energy

- pass: True
- after: `05_after_onboarding_hud_energy.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## onboarding_hud_gold

- pass: True
- after: `06_after_onboarding_hud_gold.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## onboarding_hud_gems

- pass: True
- after: `07_after_onboarding_hud_gems.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## onboarding_nav_intro

- pass: True
- after: `08_after_onboarding_nav_intro.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## onboarding_tap_dungeon_tab

- pass: True
- after: `09_after_onboarding_tap_dungeon_tab.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## dungeon_intro

- pass: True
- after: `10_after_dungeon_intro.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## dungeon_pick_zone

- pass: True
- after: `11_after_dungeon_pick_zone.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## dungeon_enter_btn

- pass: True
- after: `12_after_dungeon_enter_btn.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## dungeon_confirm_enter

- pass: True
- after: `13_after_dungeon_confirm_enter.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## dungeon_tap_attack

- pass: True
- after: `14_after_dungeon_tap_attack.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## dungeon_first_win

- pass: True
- after: `15_after_dungeon_first_win.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## dungeon_to_inventory

- pass: True
- after: `16_after_dungeon_to_inventory.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## inventory_first_item

- pass: True
- after: `17_after_inventory_first_item.png`
- error: `-`
- fix_notes:
  - OK — no fix required for this step.

## inventory_equip

- pass: False
- after: `18_after_inventory_equip.png`
- error: `equip_success not observed; step=inventory_equip`
- fix_notes:
  - FAIL: equip_success not observed; step=inventory_equip
  - Inventory equip dialog: add onTutorialTap on KUSAN + smoke tap KUSAN text.

## inventory_to_character

- pass: False
- after: `19_after_inventory_to_character.png`
- error: `stuck at inventory_equip`
- fix_notes:
  - FAIL: stuck at inventory_equip
  - Cascade fail after inventory_equip — fix equip first.

## character_check_power

- pass: False
- after: `20_after_character_check_power.png`
- error: `stuck at inventory_equip`
- fix_notes:
  - FAIL: stuck at inventory_equip
  - Cascade fail after inventory_equip — fix equip first.

## character_stat_panel

- pass: False
- after: `21_after_character_stat_panel.png`
- error: `stuck at inventory_equip`
- fix_notes:
  - FAIL: stuck at inventory_equip
  - Cascade fail after inventory_equip — fix equip first.

## character_class_abilities

- pass: False
- after: `22_after_character_class_abilities.png`
- error: `stuck at inventory_equip`
- fix_notes:
  - FAIL: stuck at inventory_equip
  - Cascade fail after inventory_equip — fix equip first.

## character_open_menu

- pass: False
- after: `23_after_character_open_menu.png`
- error: `stuck at inventory_equip`
- fix_notes:
  - FAIL: stuck at inventory_equip
  - Cascade fail after inventory_equip — fix equip first.

## character_tap_enhance

- pass: False
- after: `24_after_character_tap_enhance.png`
- error: `stuck at inventory_equip`
- fix_notes:
  - FAIL: stuck at inventory_equip
  - Cascade fail after inventory_equip — fix equip first.

## enhance_pick_item

- pass: False
- after: `25_after_enhance_pick_item.png`
- error: `stuck at inventory_equip`
- fix_notes:
  - FAIL: stuck at inventory_equip
  - Cascade fail after inventory_equip — fix equip first.

## enhance_tap_forge

- pass: False
- after: `26_after_enhance_tap_forge.png`
- error: `stuck at inventory_equip`
- fix_notes:
  - FAIL: stuck at inventory_equip
  - Cascade fail after inventory_equip — fix equip first.

## enhance_result

- pass: False
- after: `27_after_enhance_result.png`
- error: `stuck at inventory_equip`
- fix_notes:
  - FAIL: stuck at inventory_equip
  - Cascade fail after inventory_equip — fix equip first.

## core_complete_check

- pass: False
- after: `28_after_core_complete_check.png`
- error: `enhancement not progressed: {}`
- fix_notes:
  - FAIL: enhancement not progressed: {}
  - Inspect screenshot `28_after_core_complete_check.png`.

