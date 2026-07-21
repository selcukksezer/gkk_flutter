import 'tutorial_step.dart';

/// Legacy v1 flat step registry.
///
/// Runtime tutorial uses [TutorialTrackRegistry] (v2). Kept for reference /
/// migration helpers only — do not wire new UI to this class.
@Deprecated('Use TutorialTrackRegistry (v2 track-based tutorial)')
abstract final class TutorialRegistry {
  static const int version = 1;

  static const List<String> coreStepIds = <String>[
    'onboard_welcome',
    'onboard_nav_dungeon',
    'dungeon_first_win',
    'inventory_equip',
    'enhance_result',
  ];

  static const List<TutorialStep> steps = <TutorialStep>[
    TutorialStep(
      id: 'onboard_welcome',
      title: 'Gölge Krallığı\'na hoş geldin',
      body:
          'Bu kısa rehber seni ilk savaşa hazırlayacak. İstersen "Sonra" ile atlayabilirsin.',
      primaryLabel: 'Devam',
      route: TutorialRoutes.home,
      isCore: true,
    ),
    TutorialStep(
      id: 'onboard_hud_energy',
      title: 'Enerji',
      body:
          'Zindan ve birçok aktivite enerji harcar. Enerji iksiri veya mağaza ile doldurabilirsin.',
      route: TutorialRoutes.home,
      requiresPrior: <String>['onboard_welcome'],
    ),
    TutorialStep(
      id: 'onboard_hud_gold_gems',
      title: 'Altın ve Gem',
      body: 'Altın: pazar ve craft. Gem: premium hızlandırma ve VIP.',
      route: TutorialRoutes.home,
      requiresPrior: <String>['onboard_hud_energy'],
    ),
    TutorialStep(
      id: 'onboard_nav_dungeon',
      title: 'İlk hedef: Zindan',
      body: 'Düşmanları yen, loot topla, güçlen.',
      primaryLabel: 'Zindana Git',
      route: TutorialRoutes.home,
      requiresPrior: <String>['onboard_hud_gold_gems'],
      isCore: true,
    ),
    TutorialStep(
      id: 'dungeon_pick_zone',
      title: 'Bölge seç',
      body: 'Zone 1 ile başla — düşük risk, iyi öğretici loot.',
      route: TutorialRoutes.dungeon,
      requiresPrior: <String>['onboard_nav_dungeon'],
    ),
    TutorialStep(
      id: 'dungeon_enter_cost',
      title: 'Giriş maliyeti',
      body: 'Her koşu enerji harcar. Yeterli enerjin olduğundan emin ol.',
      requiresPrior: <String>['dungeon_pick_zone'],
    ),
    TutorialStep(
      id: 'dungeon_first_win',
      title: 'Loot düştü!',
      body: 'Envanterine yeni eşyalar geldi. Kuşanıp gücünü artır.',
      primaryLabel: 'Envantere Git',
      route: TutorialRoutes.inventory,
      requiresPrior: <String>['dungeon_enter_cost'],
      isCore: true,
    ),
    TutorialStep(
      id: 'inventory_first_item',
      title: 'Eşyana dokun',
      body: 'Detay panelinden kuşan, kullan veya sat.',
      route: TutorialRoutes.inventory,
      requiresPrior: <String>['dungeon_first_win'],
    ),
    TutorialStep(
      id: 'inventory_equip',
      title: 'Kuşan',
      body: 'Silahını kuşandığında güç (power) artar.',
      primaryLabel: 'Karaktere Bak',
      route: TutorialRoutes.character,
      requiresPrior: <String>['inventory_first_item'],
      isCore: true,
    ),
    TutorialStep(
      id: 'character_check_power',
      title: 'Güç arttı',
      body: 'Power skorun zindan ve PvP\'de belirleyici.',
      route: TutorialRoutes.character,
      requiresPrior: <String>['inventory_equip'],
    ),
    TutorialStep(
      id: 'enhance_intro',
      title: 'Parşömen = Geliştirme',
      body: 'İlk zindan loot\'unda parşömen var. +1 dene.',
      primaryLabel: 'Geliştirme',
      route: TutorialRoutes.enhancement,
      requiresPrior: <String>['character_check_power'],
    ),
    TutorialStep(
      id: 'enhance_pick_item',
      title: 'Eşya seç',
      body: 'Kuşandığın silahı seç — parşömen otomatik önerilir.',
      route: TutorialRoutes.enhancement,
      requiresPrior: <String>['enhance_intro'],
    ),
    TutorialStep(
      id: 'enhance_pick_scroll',
      title: 'Parşömen',
      body: 'Lesser Upgrade Scroll ile +1 dene. Başarısızlık normal.',
      requiresPrior: <String>['enhance_pick_item'],
    ),
    TutorialStep(
      id: 'enhance_result',
      title: 'Geliştirme tamam',
      body: 'Başarı veya yanma — her ikisi de oyunun parçası.',
      requiresPrior: <String>['enhance_pick_scroll'],
      isCore: true,
    ),
    TutorialStep(
      id: 'bank_full_intro',
      title: 'Envanterin dolu',
      body:
          'Kullanmadığın eşyaları bankaya koy. Güvende kalır, istediğin zaman geri al.',
      primaryLabel: 'Bankaya Git',
      route: TutorialRoutes.bank,
    ),
    TutorialStep(
      id: 'bank_deposit_coach',
      title: 'Bankaya yatır',
      body: 'Uzun bas: sürükle · Dokun: seç · Yatır butonu ile aktar.',
      route: TutorialRoutes.bank,
      requiresPrior: <String>['bank_full_intro'],
    ),
    TutorialStep(
      id: 'bank_withdraw_hint',
      title: 'Geri çek',
      body: 'Bankadan envantere taşıyarak tekrar kullanabilirsin.',
      requiresPrior: <String>['bank_deposit_coach'],
    ),
    TutorialStep(
      id: 'market_sell_intro',
      title: 'Fazla eşya',
      body: 'Pazarda satarak altın kazan ve yer aç.',
      primaryLabel: 'Pazara Git',
      route: TutorialRoutes.market,
    ),
    TutorialStep(
      id: 'energy_low_warning',
      title: 'Kritik enerji',
      body: 'Enerjin azalıyor. Zindana girmeden önce iksir düşün.',
    ),
    TutorialStep(
      id: 'energy_depleted',
      title: 'Enerji bitti',
      body:
          'Zindana giremezsin. Çözüm: enerji iksiri (envanter/mağaza), gem ile iksir, veya dinlen.',
      primaryLabel: 'Mağazaya Git',
      route: TutorialRoutes.shop,
    ),
    TutorialStep(
      id: 'energy_shop_potion',
      title: 'Enerji iksiri',
      body: 'Mağazadan enerji iksiri al ve envanterden kullan.',
      route: TutorialRoutes.shop,
      requiresPrior: <String>['energy_depleted'],
    ),
    TutorialStep(
      id: 'energy_use_potion',
      title: 'İksir kullan',
      body: 'Envanterden iksire dokun → Kullan.',
      route: TutorialRoutes.inventory,
      requiresPrior: <String>['energy_shop_potion'],
    ),
    TutorialStep(
      id: 'hospital_first',
      title: 'Hastanedesin',
      body: 'Savaş veya overdose sonrası iyileşme süresi. Gem ile hızlandırabilirsin.',
      primaryLabel: 'Hastane',
      route: TutorialRoutes.hospital,
    ),
    TutorialStep(
      id: 'prison_first',
      title: 'Hapistesin',
      body: 'Suç veya ceza süresi dolana kadar bazı aktiviteler kısıtlı.',
      primaryLabel: 'Hapishane',
      route: TutorialRoutes.prison,
    ),
    TutorialStep(
      id: 'tolerance_intro',
      title: 'Tolerans',
      body: 'Çok iksir → tolerans artar, verim düşer, overdose riski.',
    ),
    TutorialStep(
      id: 'd1_quest_claim',
      title: 'Gün 1 — Görev',
      body: 'Görevlerden BPP ve altın kazan. İlk görev ödülünü al.',
      primaryLabel: 'Görevler',
      route: TutorialRoutes.quests,
      isDaily: true,
      dayNumber: 1,
    ),
    TutorialStep(
      id: 'd2_enhance_plus3',
      title: 'Gün 2 — +3 hedef',
      body: 'Eşyana +3 geliştirme dene. Parşömen biriktir.',
      route: TutorialRoutes.enhancement,
      isDaily: true,
      dayNumber: 2,
    ),
    TutorialStep(
      id: 'd3_bank_use',
      title: 'Gün 3 — Banka',
      body: 'En az bir eşyayı bankaya yatır.',
      route: TutorialRoutes.bank,
      isDaily: true,
      dayNumber: 3,
    ),
    TutorialStep(
      id: 'd4_market_browse',
      title: 'Gün 4 — Pazar',
      body: 'Pazarı gez — alım satım ekonominin kalbi.',
      route: TutorialRoutes.market,
      isDaily: true,
      dayNumber: 4,
    ),
    TutorialStep(
      id: 'd5_craft_or_facility',
      title: 'Gün 5 — Üretim',
      body: 'Craft veya tesis ile kaynak üret.',
      primaryLabel: 'Tesisler',
      route: TutorialRoutes.facilities,
      isDaily: true,
      dayNumber: 5,
    ),
    TutorialStep(
      id: 'd6_pvp_or_mekan',
      title: 'Gün 6 — PvP',
      body: 'Arena\'da rakiplerine meydan oku. Benzer güçte eşleşmeye dikkat.',
      route: TutorialRoutes.pvp,
      isDaily: true,
      dayNumber: 6,
    ),
    TutorialStep(
      id: 'd7_season_intro',
      title: 'Gün 7 — Sezon',
      body: 'Battle Pass görevleri ve L20 veteran rozeti seni bekliyor.',
      primaryLabel: 'Sezon',
      route: TutorialRoutes.season,
      isDaily: true,
      dayNumber: 7,
    ),
    TutorialStep(
      id: 'season_intro',
      title: 'Battle Pass Sezonu',
      body: 'Her sezon ~14 gün. BPP kazan, seviye at, ödül claim et.',
      route: TutorialRoutes.season,
    ),
    TutorialStep(
      id: 'season_bpp',
      title: 'BPP nasıl kazanılır',
      body: 'Zindan, PvP, craft, iksir + sezon görevleri BPP verir.',
      route: TutorialRoutes.season,
      requiresPrior: <String>['season_intro'],
    ),
    TutorialStep(
      id: 'season_l20_badge',
      title: 'L20 Veteran Rozeti',
      body:
          'Seviye 20 free track\'te o sezonun veteran rozeti var. Claim etmeyi unutma!',
      route: TutorialRoutes.season,
      requiresPrior: <String>['season_bpp'],
    ),
    TutorialStep(
      id: 'season_reset_warn',
      title: 'Sezon bitiyor',
      body: 'Claim etmediğin ödüller sıfırlanır — L20 rozetini al!',
      route: TutorialRoutes.season,
    ),
  ];

  static TutorialStep? byId(String id) {
    for (final TutorialStep step in steps) {
      if (step.id == id) return step;
    }
    return null;
  }

  static List<TutorialStep> eligibleSteps({
    required Set<String> completed,
    required String? route,
    required bool skippedAll,
  }) {
    if (skippedAll) return const <TutorialStep>[];
    final List<TutorialStep> out = <TutorialStep>[];
    for (final TutorialStep step in steps) {
      if (completed.contains(step.id)) continue;
      if (step.route != null && route != null && step.route != route) continue;
      final bool priorsOk = step.requiresPrior.every(completed.contains);
      if (!priorsOk) continue;
      out.add(step);
    }
    return out;
  }
}
