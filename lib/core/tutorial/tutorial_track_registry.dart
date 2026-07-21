import 'tutorial_step.dart';
import 'tutorial_track.dart';

/// All modular tutorial tracks (v2).
abstract final class TutorialTrackRegistry {
  static const int version = 2;

  static const List<TutorialTrack> tracks = <TutorialTrack>[
    TutorialTrack(
      id: TutorialTrackId.onboarding,
      triggerRoute: TutorialRoutes.home,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'onboarding_welcome',
          trackId: TutorialTrackId.onboarding,
          title: 'Gölge Krallığı\'na hoş geldin',
          body: 'Kısa rehber seni ilk hedefe götürecek. Devam et.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Devam',
          allowedRoutes: <String>[TutorialRoutes.home],
        ),
        TutorialStepV2(
          id: 'onboarding_hud_energy',
          trackId: TutorialTrackId.onboarding,
          title: 'Enerji',
          body: 'Zindan ve aktiviteler enerji harcar. Dokunarak devam et.',
          anchorId: TutorialAnchorId.hudEnergy,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_welcome'],
        ),
        TutorialStepV2(
          id: 'onboarding_hud_gold',
          trackId: TutorialTrackId.onboarding,
          title: 'Altın',
          body: 'Pazar, craft ve güçlendirme için altın kullanılır.',
          anchorId: TutorialAnchorId.hudGold,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_hud_energy'],
        ),
        TutorialStepV2(
          id: 'onboarding_hud_gems',
          trackId: TutorialTrackId.onboarding,
          title: 'Elmas (Gem)',
          body: 'Premium hızlandırma ve özel eşyalar için.',
          anchorId: TutorialAnchorId.hudGems,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_hud_gold'],
        ),
        TutorialStepV2(
          id: 'onboarding_tap_dungeon_tab',
          trackId: TutorialTrackId.onboarding,
          title: 'İlk hedef: Zindan',
          body: 'Zindan sekmesine dokun.',
          anchorId: TutorialAnchorId.navDungeonTab,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_hud_gems'],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.dungeon,
      triggerRoute: TutorialRoutes.dungeon,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'dungeon_pick_zone',
          trackId: TutorialTrackId.dungeon,
          title: 'Bölge seç',
          body: 'Zone 1 ile başla — düşük risk, iyi loot.',
          anchorId: TutorialAnchorId.dungeonZone0,
          allowedRoutes: <String>[TutorialRoutes.dungeon],
        ),
        TutorialStepV2(
          id: 'dungeon_enter_btn',
          trackId: TutorialTrackId.dungeon,
          title: 'Gir',
          body: 'Seçili zindana girmek için dokun.',
          anchorId: TutorialAnchorId.dungeonEnterBtn,
          requiresPrior: <String>['dungeon_pick_zone'],
          allowedRoutes: <String>[TutorialRoutes.dungeon],
        ),
        TutorialStepV2(
          id: 'dungeon_confirm_enter',
          trackId: TutorialTrackId.dungeon,
          title: 'Onayla',
          body: 'Enerji maliyetini kontrol et, onayla.',
          anchorId: TutorialAnchorId.dungeonConfirmOk,
          requiresPrior: <String>['dungeon_enter_btn'],
        ),
        TutorialStepV2(
          id: 'dungeon_tap_attack',
          trackId: TutorialTrackId.dungeon,
          title: 'Saldır',
          body: 'Saldır butonuna dokun.',
          anchorId: TutorialAnchorId.dungeonAttackBtn,
          requiresPrior: <String>['dungeon_confirm_enter'],
        ),
        TutorialStepV2(
          id: 'dungeon_first_win',
          trackId: TutorialTrackId.dungeon,
          title: 'Zafer!',
          body: 'Loot düştü. Envantere bak.',
          mode: TutorialMode.waitEvent,
          completion: TutorialCompletion.onGameEvent,
          gameEvent: TutorialGameEvent.dungeonWin,
          requiresPrior: <String>['dungeon_tap_attack'],
        ),
        TutorialStepV2(
          id: 'dungeon_to_inventory',
          trackId: TutorialTrackId.dungeon,
          title: 'Envanter',
          body: 'Envanter sekmesine git.',
          anchorId: TutorialAnchorId.navInventoryTab,
          requiresPrior: <String>['dungeon_first_win'],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.inventory,
      triggerRoute: TutorialRoutes.inventory,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'inventory_first_item',
          trackId: TutorialTrackId.inventory,
          title: 'Eşyana dokun',
          body: 'Silahına dokunarak detayı aç.',
          anchorId: TutorialAnchorId.inventoryFirstWeapon,
          allowedRoutes: <String>[TutorialRoutes.inventory],
        ),
        TutorialStepV2(
          id: 'inventory_equip',
          trackId: TutorialTrackId.inventory,
          title: 'Kuşan',
          body: 'Kuşan butonuna bas.',
          anchorId: TutorialAnchorId.inventoryEquipBtn,
          completion: TutorialCompletion.onGameEvent,
          gameEvent: TutorialGameEvent.equipSuccess,
          requiresPrior: <String>['inventory_first_item'],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.character,
      triggerRoute: TutorialRoutes.character,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'character_check_power',
          trackId: TutorialTrackId.character,
          title: 'Güç arttı',
          body: 'Power skorun savaşlarda belirleyici.',
          anchorId: TutorialAnchorId.characterPowerStat,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
        ),
        TutorialStepV2(
          id: 'character_stat_panel',
          trackId: TutorialTrackId.character,
          title: 'Stat puanı',
          body: 'Level atladıkça puan dağıt.',
          anchorId: TutorialAnchorId.characterStatPanel,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          requiresPrior: <String>['character_check_power'],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.enhancement,
      triggerRoute: TutorialRoutes.enhancement,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'enhance_pick_item',
          trackId: TutorialTrackId.enhancement,
          title: 'Eşya seç',
          body: 'Kuşandığın silahı seç.',
          anchorId: TutorialAnchorId.enhanceItemSlot,
        ),
        TutorialStepV2(
          id: 'enhance_tap_forge',
          trackId: TutorialTrackId.enhancement,
          title: 'Geliştir',
          body: '+1 dene — parşömen otomatik seçilir.',
          anchorId: TutorialAnchorId.enhanceForgeBtn,
          requiresPrior: <String>['enhance_pick_item'],
        ),
        TutorialStepV2(
          id: 'enhance_result',
          trackId: TutorialTrackId.enhancement,
          title: 'Sonuç',
          body: 'Başarı veya yanma normal.',
          mode: TutorialMode.waitEvent,
          completion: TutorialCompletion.onGameEvent,
          gameEvent: TutorialGameEvent.enhancementAttempt,
          requiresPrior: <String>['enhance_tap_forge'],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.bank,
      triggerRoute: TutorialRoutes.bank,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'bank_deposit_coach',
          trackId: TutorialTrackId.bank,
          title: 'Bankaya yatır',
          body: 'Eşya seç → Yatır ile aktar.',
          anchorId: TutorialAnchorId.bankDepositBtn,
        ),
        TutorialStepV2(
          id: 'bank_deposit_done',
          trackId: TutorialTrackId.bank,
          title: 'Tamam',
          body: 'İlk yatırma tamamlandı.',
          mode: TutorialMode.waitEvent,
          completion: TutorialCompletion.onGameEvent,
          gameEvent: TutorialGameEvent.bankDeposit,
          requiresPrior: <String>['bank_deposit_coach'],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.market,
      triggerRoute: TutorialRoutes.market,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'market_browse_intro',
          trackId: TutorialTrackId.market,
          title: 'Pazar',
          body: 'Alım-satım ekonominin kalbi.',
          anchorId: TutorialAnchorId.marketBrowseTab,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.shop,
      triggerRoute: TutorialRoutes.shop,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'shop_energy_potion',
          trackId: TutorialTrackId.shop,
          title: 'Enerji iksiri',
          body: 'Enerji bittiğinde iksir al.',
          anchorId: TutorialAnchorId.shopPotionRow,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.season,
      triggerRoute: TutorialRoutes.season,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'season_intro',
          trackId: TutorialTrackId.season,
          title: 'Battle Pass',
          body: 'Her sezon ~14 gün. BPP kazan, ödül claim et.',
          anchorId: TutorialAnchorId.seasonHeader,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
        ),
        TutorialStepV2(
          id: 'season_bpp',
          trackId: TutorialTrackId.season,
          title: 'BPP',
          body: 'Zindan, PvP, görevler BPP verir.',
          anchorId: TutorialAnchorId.seasonBppBar,
          requiresPrior: <String>['season_intro'],
        ),
        TutorialStepV2(
          id: 'season_quests_tab',
          trackId: TutorialTrackId.season,
          title: 'Görevler',
          body: 'Sezon görevlerini buradan takip et.',
          anchorId: TutorialAnchorId.seasonQuestsTab,
          requiresPrior: <String>['season_bpp'],
        ),
        TutorialStepV2(
          id: 'season_l20_badge',
          trackId: TutorialTrackId.season,
          title: 'L20 Rozeti',
          body: 'Free track L20 — claim etmeyi unutma!',
          anchorId: TutorialAnchorId.seasonL20Reward,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          requiresPrior: <String>['season_quests_tab'],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.quests,
      triggerRoute: TutorialRoutes.quests,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'quests_claim_intro',
          trackId: TutorialTrackId.quests,
          title: 'Görevler',
          body: 'Tamamlanan görev ödülünü al.',
          anchorId: TutorialAnchorId.questsClaimBtn,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
        ),
      ],
    ),
  ];

  static TutorialTrack? trackById(String id) {
    for (final TutorialTrack track in tracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  static TutorialStepV2? stepById(String id) {
    for (final TutorialTrack track in tracks) {
      for (final TutorialStepV2 step in track.steps) {
        if (step.id == id) return step;
      }
    }
    return null;
  }

  static List<TutorialStepV2> eligibleSteps({
    required String trackId,
    required Set<String> completedStepIds,
    int playerLevel = 0,
  }) {
    final TutorialTrack? track = trackById(trackId);
    if (track == null) return const <TutorialStepV2>[];
    final List<TutorialStepV2> out = <TutorialStepV2>[];
    for (final TutorialStepV2 step in track.steps) {
      if (completedStepIds.contains(step.id)) continue;
      if (!step.requiresPrior.every(completedStepIds.contains)) continue;
      if (step.id == 'season_l20_badge' && playerLevel < 18) continue;
      out.add(step);
    }
    return out;
  }
}
