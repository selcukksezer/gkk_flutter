# UI Action Coverage Matrix — 1000 Bot Test Gap

Date: 2026-06-13
Run: `f2d0f436-0360-473f-845a-f79ecb912a6f`

**Status legend:**
- DB-SIM: covered by 1000-bot database simulation (activity counters)
- RPC-REPLAY: covered by exploit battery RPC replay
- AUTO: route registry unit test only
- **UNTESTED**: no automated click/integration test executed

| Screen file | Actions | RPCs | DB-SIM | UI test |
|-------------|---------|------|--------|---------|
| `lib/screens/home/home_screen.dart` | 18 | — | Partial | **UNTESTED** |
| `lib/screens/inventory/inventory_screen.dart` | 17 | — | Partial | **UNTESTED** |
| `lib/screens/guild/guild_screen.dart` | 16 | — | Partial | **UNTESTED** |
| `lib/screens/bank/bank_screen.dart` | 15 | — | Partial | **UNTESTED** |
| `lib/screens/chat/chat_screen.dart` | 15 | — | No | **UNTESTED** |
| `lib/screens/chat/chat_screen_new.dart` | 13 | — | No | **UNTESTED** |
| `lib/screens/crafting/crafting_screen.dart` | 13 | — | Partial | **UNTESTED** |
| `lib/screens/dungeon/dungeon_screen.dart` | 13 | — | Partial | **UNTESTED** |
| `lib/screens/mekans/my_mekan_screen.dart` | 13 | — | Partial | **UNTESTED** |
| `lib/screens/quests/quests_screen.dart` | 12 | claim_quest_reward, complete_quest, get_available_quests | Partial | **UNTESTED** |
| `lib/screens/shop/shop_screen.dart` | 12 | — | Partial | **UNTESTED** |
| `lib/screens/trade/trade_screen.dart` | 12 | add_trade_item, cancel_trade, confirm_trade, get_trade_history… | Partial | **UNTESTED** |
| `lib/screens/hospital/hospital_screen.dart` | 10 | attempt_hospital_escape, heal_with_gems | Partial | **UNTESTED** |
| `lib/screens/facilities/facility_detail_screen.dart` | 9 | — | Partial | **UNTESTED** |
| `lib/screens/loot/loot_hub_screen.dart` | 9 | get_loot_boxes_with_stats, get_spin_wheels_with_stats | Partial | **UNTESTED** |
| `lib/screens/mekans/mekans_screen.dart` | 9 | — | Partial | **UNTESTED** |
| `lib/screens/enhancement/enhancement_screen.dart` | 8 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/guild_war_hub_screen.dart` | 8 | — | Partial | **UNTESTED** |
| `lib/screens/character/character_screen.dart` | 7 | claim_alchemist_detox | Partial | **UNTESTED** |
| `lib/screens/mekans/mekan_detail_screen.dart` | 7 | — | Partial | **UNTESTED** |
| `lib/screens/settings/settings_screen.dart` | 7 | delete_account, update_user_profile | No | **UNTESTED** |
| `lib/screens/dungeon/dungeon_battle_screen.dart` | 6 | attack_dungeon, collect_dungeon_rewards | Partial | **UNTESTED** |
| `lib/screens/facilities/facilities_screen.dart` | 6 | — | Partial | **UNTESTED** |
| `lib/screens/reputation/reputation_screen.dart` | 6 | get_reputation | Partial | **UNTESTED** |
| `lib/screens/leaderboard/leaderboard_screen.dart` | 5 | — | Partial | **UNTESTED** |
| `lib/screens/market/widgets/market_my_market_tab.dart` | 5 | — | Partial | **UNTESTED** |
| `lib/screens/mekans/widgets/mekan_design.dart` | 5 | — | Partial | **UNTESTED** |
| `lib/screens/dungeon/widgets/featured_cave_dungeon_card.dart` | 4 | — | Partial | **UNTESTED** |
| `lib/screens/mekans/mekan_arena_screen.dart` | 4 | — | Partial | **UNTESTED** |
| `lib/screens/prison/prison_screen.dart` | 4 | attempt_prison_escape, release_from_prison | Partial | **UNTESTED** |
| `lib/screens/pvp/pvp_screen.dart` | 4 | — | Partial | **UNTESTED** |
| `lib/screens/season/season_screen.dart` | 4 | — | Partial | **UNTESTED** |
| `lib/screens/auth/login_screen.dart` | 3 | — | No | **UNTESTED** |
| `lib/screens/guild/guild_monument_screen.dart` | 3 | upgrade_monument | Partial | **UNTESTED** |
| `lib/screens/guild_war/territory_detail_screen.dart` | 3 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/territory_card.dart` | 3 | — | Partial | **UNTESTED** |
| `lib/screens/loot/loot_chest_widgets.dart` | 3 | — | Partial | **UNTESTED** |
| `lib/screens/market/widgets/market_browse_tab.dart` | 3 | — | Partial | **UNTESTED** |
| `lib/screens/market/widgets/market_quantity_sheet.dart` | 3 | — | Partial | **UNTESTED** |
| `lib/screens/mekans/mekan_create_screen.dart` | 3 | — | Partial | **UNTESTED** |
| `lib/screens/auth/character_select_screen.dart` | 2 | get_character_classes | Partial | **UNTESTED** |
| `lib/screens/auth/register_screen.dart` | 2 | — | No | **UNTESTED** |
| `lib/screens/guild/guild_monument_donate_screen.dart` | 2 | donate_to_monument | Partial | **UNTESTED** |
| `lib/screens/guild_war/battle_result_screen.dart` | 2 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/territory_map_view.dart` | 2 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/tournament_card.dart` | 2 | — | Partial | **UNTESTED** |
| `lib/screens/market/widgets/market_price_edit_sheet.dart` | 2 | — | Partial | **UNTESTED** |
| `lib/screens/market/widgets/market_sell_tab.dart` | 2 | — | Partial | **UNTESTED** |
| `lib/screens/pvp/pvp_history_screen.dart` | 2 | — | Partial | **UNTESTED** |
| `lib/screens/pvp/pvp_tournament_screen.dart` | 2 | get_tournament_bracket, join_pvp_tournament | Partial | **UNTESTED** |
| `lib/screens/guild_war/guild_war_defense_sheet.dart` | 1 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/tournament_detail_screen.dart` | 1 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/war_logs_screen.dart` | 1 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/guild_war_empty_state.dart` | 1 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/guild_war_sub_screen_scaffold.dart` | 1 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/kingdom_election_panel.dart` | 1 | get_current_election, vote_in_election | Partial | **UNTESTED** |
| `lib/screens/home/widgets/sticky_action_bar.dart` | 1 | — | Partial | **UNTESTED** |
| `lib/screens/market/widgets/market_listing_card.dart` | 1 | — | Partial | **UNTESTED** |
| `lib/screens/market/widgets/market_tab_bar.dart` | 1 | — | Partial | **UNTESTED** |
| `lib/screens/mekans/widgets/mekan_scaffold.dart` | 1 | — | Partial | **UNTESTED** |
| `lib/screens/auth/splash_screen.dart` | 0 | — | No | **UNTESTED** |
| `lib/screens/dungeon/dungeon_victory_effects.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/dungeon/widgets/dungeon_cave_palettes.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/enhancement/enhancement_screen_new.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/attack_log_tile.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/defense_power_bar.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/guild_war_season_header.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/guild_war_skeleton.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/guild_war_tab_bar.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/guild_war/widgets/ranking_podium.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/home/widgets/hero_showcase.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/home/widgets/pantheon_board.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/loot/loot_chest_theme.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/market/market_screen.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/market/widgets/market_helpers.dart` | 0 | — | Partial | **UNTESTED** |
| `lib/screens/market/widgets/market_item_icon.dart` | 0 | — | Partial | **UNTESTED** |

## Totals

- Screens inventoried: **76**
- Actions (buttons+taps): **350**
- UI integration tests executed: **0**
- Required next: `integration_test/smoke/screen_matrix_test.dart` + per-action golden path

## Priority UI Test Pack (P0 screens)

1. Login → Character select → Home
2. Dungeon enter → Battle → Reward
3. PvP attack → Result
4. Market browse → Buy → Sell tab
5. Hospital gem skip + wait
6. Prison bail + escape
7. Mekans list → Detail → Arena (1000 rows stress)
8. Guild create/join
9. Craft start → claim
10. Trade initiate → confirm

Each pack = min 5–15 button taps. Full 350 actions ≈ 40–60 integration tests.