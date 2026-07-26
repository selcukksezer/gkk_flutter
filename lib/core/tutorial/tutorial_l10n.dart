import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import 'tutorial_track.dart';

/// Resolves tutorial step copy from generated l10n (arb).
abstract final class TutorialL10n {
  static String title(BuildContext context, TutorialStepV2 step) {
    final AppLocalizations l10n = context.l10n;
    return titleFor(l10n, step);
  }

  static String body(BuildContext context, TutorialStepV2 step) {
    final AppLocalizations l10n = context.l10n;
    return bodyFor(l10n, step);
  }

  static String? primaryLabel(BuildContext context, TutorialStepV2 step) {
    final AppLocalizations l10n = context.l10n;
    if (step.primaryLabel == null) return null;
    final String raw = step.primaryLabel!;
    if (raw == 'Devam' || raw == 'Continue') return l10n.tutContinue;
    if (raw == 'Tamam' || raw == 'Done') return l10n.tutDone;
    return raw;
  }

  static String titleFor(AppLocalizations l10n, TutorialStepV2 step) {
    switch (step.id) {
      case 'onboarding_welcome':
        return l10n.tut_onboarding_welcome_title;
      case 'onboarding_home_promo':
        return l10n.tut_onboarding_home_promo_title;
      case 'onboarding_home_hero':
        return l10n.tut_onboarding_home_hero_title;
      case 'onboarding_hud_energy':
        return l10n.tut_onboarding_hud_energy_title;
      case 'onboarding_hud_gold':
        return l10n.tut_onboarding_hud_gold_title;
      case 'onboarding_hud_gems':
        return l10n.tut_onboarding_hud_gems_title;
      case 'onboarding_tap_dungeon_tab':
        return l10n.tut_onboarding_tap_dungeon_tab_title;
      case 'dungeon_pick_zone':
        return l10n.tut_dungeon_pick_zone_title;
      case 'dungeon_enter_btn':
        return l10n.tut_dungeon_enter_btn_title;
      case 'dungeon_confirm_enter':
        return l10n.tut_dungeon_confirm_enter_title;
      case 'dungeon_tap_attack':
        return l10n.tut_dungeon_tap_attack_title;
      case 'dungeon_first_win':
        return l10n.tut_dungeon_first_win_title;
      case 'dungeon_to_inventory':
        return l10n.tut_dungeon_to_inventory_title;
      case 'inventory_first_item':
        return l10n.tut_inventory_first_item_title;
      case 'inventory_equip':
        return l10n.tut_inventory_equip_title;
      case 'inventory_to_character':
        return l10n.tut_inventory_to_character_title;
      case 'character_check_power':
        return l10n.tut_character_check_power_title;
      case 'character_stat_panel':
        return l10n.tut_character_stat_panel_title;
      case 'character_to_enhance':
        return l10n.tut_character_to_enhance_title;
      case 'enhance_pick_item':
        return l10n.tut_enhance_pick_item_title;
      case 'enhance_tap_forge':
        return l10n.tut_enhance_tap_forge_title;
      case 'enhance_result':
        return l10n.tut_enhance_result_title;
      case 'enhance_season_cta':
        return l10n.tut_enhance_season_cta_title;
      case 'bank_deposit_coach':
        return l10n.tut_bank_deposit_coach_title;
      case 'bank_deposit_done':
        return l10n.tut_bank_deposit_done_title;
      case 'market_browse_intro':
        return l10n.tut_market_browse_intro_title;
      case 'shop_energy_potion':
        return l10n.tut_shop_energy_potion_title;
      case 'season_intro':
        return l10n.tut_season_intro_title;
      case 'season_bpp':
        return l10n.tut_season_bpp_title;
      case 'season_quests_tab':
        return l10n.tut_season_quests_tab_title;
      case 'season_l20_badge':
        return l10n.tut_season_l20_badge_title;
      case 'quests_claim_intro':
        return l10n.tut_quests_claim_intro_title;
      case 'craft_browse_recipes':
        return l10n.tut_craft_browse_recipes_title;
      case 'craft_start_hint':
        return l10n.tut_craft_start_hint_title;
      case 'guild_intro':
        return l10n.tut_guild_intro_title;
      case 'guild_join_or_panel':
        return l10n.tut_guild_join_or_panel_title;
      case 'pvp_find_match':
        return l10n.tut_pvp_find_match_title;
      case 'pvp_nemesis_hint':
        return l10n.tut_pvp_nemesis_hint_title;
      case 'siege_hub_intro':
        return l10n.tut_siege_hub_intro_title;
      case 'daily_d1_dungeon':
        return l10n.tut_daily_d1_dungeon_title;
      case 'daily_d2_inventory':
        return l10n.tut_daily_d2_inventory_title;
      case 'daily_d3_craft':
        return l10n.tut_daily_d3_craft_title;
      case 'daily_d4_guild':
        return l10n.tut_daily_d4_guild_title;
      case 'daily_d5_pvp':
        return l10n.tut_daily_d5_pvp_title;
      case 'daily_d6_market':
        return l10n.tut_daily_d6_market_title;
      case 'daily_d7_siege':
        return l10n.tut_daily_d7_siege_title;
      case 'retention_codex':
        return l10n.tut_retention_codex_title;
      case 'retention_nemesis':
        return l10n.tut_retention_nemesis_title;
      case 'retention_night':
        return l10n.tut_retention_night_title;
      case 'horse_intro':
        return l10n.tut_horse_intro_title;
      case 'horse_pick_horse':
        return l10n.tut_horse_pick_horse_title;
      case 'horse_place_bet':
        return l10n.tut_horse_place_bet_title;
      case 'horse_result_tip':
        return l10n.tut_horse_result_tip_title;
      case 'mekans_browse':
        return l10n.tut_mekans_browse_title;
      case 'mekans_my_cta':
        return l10n.tut_mekans_my_cta_title;
      case 'mekans_arena_hint':
        return l10n.tut_mekans_arena_hint_title;
      case 'mekans_fame_tip':
        return l10n.tut_mekans_fame_tip_title;
      case 'night_tab_open':
        return l10n.tut_night_tab_open_title;
      case 'night_window':
        return l10n.tut_night_window_title;
      case 'night_offer_browse':
        return l10n.tut_night_offer_browse_title;
      default:
        return step.title;
    }
  }

  static String bodyFor(AppLocalizations l10n, TutorialStepV2 step) {
    switch (step.id) {
      case 'onboarding_welcome':
        return l10n.tut_onboarding_welcome_body;
      case 'onboarding_home_promo':
        return l10n.tut_onboarding_home_promo_body;
      case 'onboarding_home_hero':
        return l10n.tut_onboarding_home_hero_body;
      case 'onboarding_hud_energy':
        return l10n.tut_onboarding_hud_energy_body;
      case 'onboarding_hud_gold':
        return l10n.tut_onboarding_hud_gold_body;
      case 'onboarding_hud_gems':
        return l10n.tut_onboarding_hud_gems_body;
      case 'onboarding_tap_dungeon_tab':
        return l10n.tut_onboarding_tap_dungeon_tab_body;
      case 'dungeon_pick_zone':
        return l10n.tut_dungeon_pick_zone_body;
      case 'dungeon_enter_btn':
        return l10n.tut_dungeon_enter_btn_body;
      case 'dungeon_confirm_enter':
        return l10n.tut_dungeon_confirm_enter_body;
      case 'dungeon_tap_attack':
        return l10n.tut_dungeon_tap_attack_body;
      case 'dungeon_first_win':
        return l10n.tut_dungeon_first_win_body;
      case 'dungeon_to_inventory':
        return l10n.tut_dungeon_to_inventory_body;
      case 'inventory_first_item':
        return l10n.tut_inventory_first_item_body;
      case 'inventory_equip':
        return l10n.tut_inventory_equip_body;
      case 'inventory_to_character':
        return l10n.tut_inventory_to_character_body;
      case 'character_check_power':
        return l10n.tut_character_check_power_body;
      case 'character_stat_panel':
        return l10n.tut_character_stat_panel_body;
      case 'character_to_enhance':
        return l10n.tut_character_to_enhance_body;
      case 'enhance_pick_item':
        return l10n.tut_enhance_pick_item_body;
      case 'enhance_tap_forge':
        return l10n.tut_enhance_tap_forge_body;
      case 'enhance_result':
        return l10n.tut_enhance_result_body;
      case 'enhance_season_cta':
        return l10n.tut_enhance_season_cta_body;
      case 'bank_deposit_coach':
        return l10n.tut_bank_deposit_coach_body;
      case 'bank_deposit_done':
        return l10n.tut_bank_deposit_done_body;
      case 'market_browse_intro':
        return l10n.tut_market_browse_intro_body;
      case 'shop_energy_potion':
        return l10n.tut_shop_energy_potion_body;
      case 'season_intro':
        return l10n.tut_season_intro_body;
      case 'season_bpp':
        return l10n.tut_season_bpp_body;
      case 'season_quests_tab':
        return l10n.tut_season_quests_tab_body;
      case 'season_l20_badge':
        return l10n.tut_season_l20_badge_body;
      case 'quests_claim_intro':
        return l10n.tut_quests_claim_intro_body;
      case 'craft_browse_recipes':
        return l10n.tut_craft_browse_recipes_body;
      case 'craft_start_hint':
        return l10n.tut_craft_start_hint_body;
      case 'guild_intro':
        return l10n.tut_guild_intro_body;
      case 'guild_join_or_panel':
        return l10n.tut_guild_join_or_panel_body;
      case 'pvp_find_match':
        return l10n.tut_pvp_find_match_body;
      case 'pvp_nemesis_hint':
        return l10n.tut_pvp_nemesis_hint_body;
      case 'siege_hub_intro':
        return l10n.tut_siege_hub_intro_body;
      case 'daily_d1_dungeon':
        return l10n.tut_daily_d1_dungeon_body;
      case 'daily_d2_inventory':
        return l10n.tut_daily_d2_inventory_body;
      case 'daily_d3_craft':
        return l10n.tut_daily_d3_craft_body;
      case 'daily_d4_guild':
        return l10n.tut_daily_d4_guild_body;
      case 'daily_d5_pvp':
        return l10n.tut_daily_d5_pvp_body;
      case 'daily_d6_market':
        return l10n.tut_daily_d6_market_body;
      case 'daily_d7_siege':
        return l10n.tut_daily_d7_siege_body;
      case 'retention_codex':
        return l10n.tut_retention_codex_body;
      case 'retention_nemesis':
        return l10n.tut_retention_nemesis_body;
      case 'retention_night':
        return l10n.tut_retention_night_body;
      case 'horse_intro':
        return l10n.tut_horse_intro_body;
      case 'horse_pick_horse':
        return l10n.tut_horse_pick_horse_body;
      case 'horse_place_bet':
        return l10n.tut_horse_place_bet_body;
      case 'horse_result_tip':
        return l10n.tut_horse_result_tip_body;
      case 'mekans_browse':
        return l10n.tut_mekans_browse_body;
      case 'mekans_my_cta':
        return l10n.tut_mekans_my_cta_body;
      case 'mekans_arena_hint':
        return l10n.tut_mekans_arena_hint_body;
      case 'mekans_fame_tip':
        return l10n.tut_mekans_fame_tip_body;
      case 'night_tab_open':
        return l10n.tut_night_tab_open_body;
      case 'night_window':
        return l10n.tut_night_window_body;
      case 'night_offer_browse':
        return l10n.tut_night_offer_browse_body;
      default:
        return step.body;
    }
  }
}
