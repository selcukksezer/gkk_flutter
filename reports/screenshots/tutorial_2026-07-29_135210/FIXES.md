# Tutorial LIVE Smoke — Düzeltme Notları

- verdict: **FAIL**
- pass: 9/20
- screenshot_dir: 

## onboarding_welcome

- pass: True
- after: 
- fix_notes:
  - OK — no fix required for this step.

## onboarding_game_loop

- pass: True
- after: 
- fix_notes:
  - OK — no fix required for this step.

## onboarding_home_promo

- pass: True
- after: 
- fix_notes:
  - OK — no fix required for this step.

## onboarding_home_hero

- pass: True
- after: 
- fix_notes:
  - OK — no fix required for this step.

## onboarding_hud_energy

- pass: True
- after: 
- fix_notes:
  - OK — no fix required for this step.

## onboarding_hud_gold

- pass: True
- after: 
- fix_notes:
  - OK — no fix required for this step.

## onboarding_hud_gems

- pass: True
- after: 
- fix_notes:
  - OK — no fix required for this step.

## onboarding_nav_intro

- pass: True
- after: 
- fix_notes:
  - OK — no fix required for this step.

## onboarding_tap_dungeon_tab

- pass: True
- after: 
- fix_notes:
  - OK — no fix required for this step.

## dungeon_intro

- pass: False
- after: 
- error: 
- fix_notes:
  - FAIL: stuck at null
  - Inspect screenshot + tutorial_controller / host for dungeon_intro.

## dungeon_pick_zone

- pass: False
- after: 
- error: 
- fix_notes:
  - FAIL: stuck at null
  - Dungeon anchors — dungeon_screen zone/enter/confirm wiring.

## dungeon_enter_btn

- pass: False
- after: 
- error: 
- fix_notes:
  - FAIL: stuck at null
  - Dungeon anchors — dungeon_screen zone/enter/confirm wiring.

## dungeon_confirm_enter

- pass: False
- after: 
- error: 
- fix_notes:
  - FAIL: stuck at null
  - Dungeon anchors — dungeon_screen zone/enter/confirm wiring.

## dungeon_tap_attack

- pass: False
- after: 
- error: 
- fix_notes:
  - FAIL: stuck at null
  - dungeon.attack_btn — battle screen energy/power gate or anchor.

## dungeon_first_win

- pass: False
- after: 
- error: 
- fix_notes:
  - FAIL: stuck at null (battle win hold timeout)
  - Win hold — TutorialTriggers.onDungeonWin / revealHeldDungeonWin.

## dungeon_to_inventory

- pass: False
- after: 
- error: 
- fix_notes:
  - FAIL: stuck at null
  - Inspect screenshot + tutorial_controller / host for dungeon_to_inventory.

## inventory_first_item

- pass: False
- after: 
- error: 
- fix_notes:
  - FAIL: stuck at null
  - inventory.first_weapon — no loot weapon? Seed QA inventory.

## inventory_equip

- pass: False
- after: 
- error: 
- fix_notes:
  - FAIL: step timeout 120s at inventory_equip
  - equip_success event — inventory_screen onEquipSuccess trigger.

## inventory_to_character

- pass: False
- after: 
- error: 
- fix_notes:
  - FAIL: stuck at null
  - Inspect screenshot + tutorial_controller / host for inventory_to_character.

## core_complete_check

- pass: False
- after: 
- error: 
- fix_notes:
  - FAIL: enhancement not progressed: {}
  - Inspect screenshot + tutorial_controller / host for core_complete_check.

