import 'tutorial_step.dart';
import 'tutorial_track.dart';

/// All modular tutorial tracks (v2).
///
/// Copy strings are TR fallbacks; runtime UI resolves via [TutorialL10n].
abstract final class TutorialTrackRegistry {
  static const int version = 3;

  static const List<TutorialTrack> tracks = <TutorialTrack>[
    TutorialTrack(
      id: TutorialTrackId.onboarding,
      triggerRoute: TutorialRoutes.home,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'onboarding_welcome',
          trackId: TutorialTrackId.onboarding,
          title: 'Gölge Krallığı\'na hoş geldin',
          body:
              'Bu rehber seni sıfırdan oyuna alıştırır: enerji, zindan, envanter, '
              'kuşanma, güçlendirme ve günlük hedefler. Adım adım ilerle — atlama yok.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Rehbere Başla',
          allowedRoutes: <String>[TutorialRoutes.home],
        ),
        TutorialStepV2(
          id: 'onboarding_game_loop',
          trackId: TutorialTrackId.onboarding,
          title: 'Temel oyun döngüsü',
          body:
              '1) Zindanda savaş → loot düşer.\n'
              '2) Envanterden eşya kuşan → güç artar.\n'
              '3) Güçlendirme / craft ile büyü.\n'
              '4) Pazar, lonca ve sezon ödülleri ile ilerle.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Anladım',
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_welcome'],
        ),
        TutorialStepV2(
          id: 'onboarding_home_promo',
          trackId: TutorialTrackId.onboarding,
          title: 'Kamp duyuruları',
          body:
              'Burada Gece Pazarı, Nemesis, sezon etkinlikleri ve canlı duyurular döner. '
              'Önemli fırsatları kaçırma.',
          anchorId: TutorialAnchorId.homePromo,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_game_loop'],
        ),
        TutorialStepV2(
          id: 'onboarding_home_hero',
          trackId: TutorialTrackId.onboarding,
          title: 'Kahraman vitrini',
          body:
              'Kuşandığın ekipman, toplam güç ve itibar burada. Slotlara dokunarak '
              'detay görebilirsin.',
          anchorId: TutorialAnchorId.homeHero,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_home_promo'],
        ),
        TutorialStepV2(
          id: 'onboarding_hud_energy',
          trackId: TutorialTrackId.onboarding,
          title: 'Enerji',
          body:
              'Zindan, PvP ve birçok aktivite enerji harcar. Enerji zamanla yenilenir; '
              'bittiğinde mağazadan iksir alabilirsin.',
          anchorId: TutorialAnchorId.hudEnergy,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_home_hero'],
        ),
        TutorialStepV2(
          id: 'onboarding_hud_gold',
          trackId: TutorialTrackId.onboarding,
          title: 'Altın',
          body: 'Pazar alım-satım, craft ve güçlendirme için ana para birimi.',
          anchorId: TutorialAnchorId.hudGold,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_hud_energy'],
        ),
        TutorialStepV2(
          id: 'onboarding_hud_gems',
          trackId: TutorialTrackId.onboarding,
          title: 'Elmas',
          body: 'Premium hızlandırma, özel paketler ve nadir fırsatlar için.',
          anchorId: TutorialAnchorId.hudGems,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_hud_gold'],
        ),
        TutorialStepV2(
          id: 'onboarding_nav_intro',
          trackId: TutorialTrackId.onboarding,
          title: 'Alt menü',
          body:
              'Alttaki sekmeler: Envanter, Zindan, Karakter ve Menü. '
              'İlk görevin zindana girmek — bir sonraki adımda Zindan sekmesine dokun.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Hazırım',
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_hud_gems'],
        ),
        TutorialStepV2(
          id: 'onboarding_tap_dungeon_tab',
          trackId: TutorialTrackId.onboarding,
          title: 'İlk hedef: Zindan',
          body: 'Zindan sekmesine dokun — ilk savaşını orada yapacaksın.',
          anchorId: TutorialAnchorId.navDungeonTab,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.home],
          requiresPrior: <String>['onboarding_nav_intro'],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.dungeon,
      triggerRoute: TutorialRoutes.dungeon,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'dungeon_intro',
          trackId: TutorialTrackId.dungeon,
          title: 'Zindan rehberi',
          body:
              'Her bölgede canavarlar loot düşürür. Zone 1 ile başla; enerji yetmezse '
              'sonra mağazadan iksir alırsın.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Başla',
          allowedRoutes: <String>[TutorialRoutes.dungeon],
        ),
        TutorialStepV2(
          id: 'dungeon_pick_zone',
          trackId: TutorialTrackId.dungeon,
          title: 'Bölge seç',
          body: 'Zone 1 ile başla — düşük risk, iyi loot.',
          anchorId: TutorialAnchorId.dungeonZone0,
          allowedRoutes: <String>[TutorialRoutes.dungeon],
          requiresPrior: <String>['dungeon_intro'],
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
          body: 'Loot envanterine gitti. Envanter sekmesine dokun.',
          anchorId: TutorialAnchorId.navInventoryTab,
          requiresPrior: <String>['dungeon_first_win'],
          navigateToRoute: TutorialRoutes.inventory,
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
        TutorialStepV2(
          id: 'inventory_to_character',
          trackId: TutorialTrackId.inventory,
          title: 'Karakter',
          body: 'Gücünü görmek için Karakter sekmesine dokun.',
          anchorId: TutorialAnchorId.navCharacterTab,
          requiresPrior: <String>['inventory_equip'],
          navigateToRoute: TutorialRoutes.character,
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
          allowedRoutes: <String>[TutorialRoutes.character],
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
          allowedRoutes: <String>[TutorialRoutes.character],
        ),
        TutorialStepV2(
          id: 'character_to_enhance',
          trackId: TutorialTrackId.character,
          title: 'Geliştirme ocağı',
          body: 'Menü → Geliştirme ile eşyanı +1 yükselt.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Devam',
          requiresPrior: <String>['character_stat_panel'],
          allowedRoutes: <String>[
            TutorialRoutes.character,
            TutorialRoutes.enhancement,
            TutorialRoutes.home,
          ],
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
          allowedRoutes: <String>[TutorialRoutes.enhancement],
        ),
        TutorialStepV2(
          id: 'enhance_tap_forge',
          trackId: TutorialTrackId.enhancement,
          title: 'Geliştir',
          body: '+1 dene — parşömen otomatik seçilir.',
          anchorId: TutorialAnchorId.enhanceForgeBtn,
          requiresPrior: <String>['enhance_pick_item'],
          allowedRoutes: <String>[TutorialRoutes.enhancement],
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
        TutorialStepV2(
          id: 'enhance_season_cta',
          trackId: TutorialTrackId.enhancement,
          title: 'Sezon ve görevler',
          body: 'Battle Pass ve günlük görevler seni bekliyor — Sezon / Görevler menüsünden aç.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Tamam',
          requiresPrior: <String>['enhance_result'],
          allowedRoutes: <String>[
            TutorialRoutes.enhancement,
            TutorialRoutes.season,
            TutorialRoutes.quests,
            TutorialRoutes.home,
            TutorialRoutes.character,
          ],
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
          allowedRoutes: <String>[TutorialRoutes.bank],
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
          allowedRoutes: <String>[TutorialRoutes.market],
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
          allowedRoutes: <String>[TutorialRoutes.shop],
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
          allowedRoutes: <String>[TutorialRoutes.season],
        ),
        TutorialStepV2(
          id: 'season_bpp',
          trackId: TutorialTrackId.season,
          title: 'BPP',
          body: 'Zindan, PvP, görevler BPP verir.',
          anchorId: TutorialAnchorId.seasonBppBar,
          requiresPrior: <String>['season_intro'],
          allowedRoutes: <String>[TutorialRoutes.season],
        ),
        TutorialStepV2(
          id: 'season_quests_tab',
          trackId: TutorialTrackId.season,
          title: 'Görevler',
          body: 'Sezon görevlerini buradan takip et.',
          anchorId: TutorialAnchorId.seasonQuestsTab,
          requiresPrior: <String>['season_bpp'],
          allowedRoutes: <String>[TutorialRoutes.season],
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
          allowedRoutes: <String>[TutorialRoutes.season],
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
          allowedRoutes: <String>[TutorialRoutes.quests],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.craft,
      triggerRoute: TutorialRoutes.crafting,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'craft_browse_recipes',
          trackId: TutorialTrackId.craft,
          title: 'Tarifler',
          body: 'Üretebileceğin eşyalar burada listelenir.',
          anchorId: TutorialAnchorId.craftRecipeList,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          allowedRoutes: <String>[TutorialRoutes.crafting],
        ),
        TutorialStepV2(
          id: 'craft_start_hint',
          trackId: TutorialTrackId.craft,
          title: 'Üret',
          body: 'Malzeme + altın yeterliyse üretimi başlat.',
          anchorId: TutorialAnchorId.craftStartBtn,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          requiresPrior: <String>['craft_browse_recipes'],
          allowedRoutes: <String>[TutorialRoutes.crafting],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.guild,
      triggerRoute: TutorialRoutes.guild,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'guild_intro',
          trackId: TutorialTrackId.guild,
          title: 'Lonca',
          body: 'Lonca bonusları ve savaşlar takım gücü verir.',
          anchorId: TutorialAnchorId.guildHeader,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          allowedRoutes: <String>[TutorialRoutes.guild],
        ),
        TutorialStepV2(
          id: 'guild_join_or_panel',
          trackId: TutorialTrackId.guild,
          title: 'Katıl / panel',
          body: 'Önerilen loncaya katıl veya kendi loncanı yönet.',
          anchorId: TutorialAnchorId.guildJoinBtn,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          requiresPrior: <String>['guild_intro'],
          allowedRoutes: <String>[TutorialRoutes.guild],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.pvp,
      triggerRoute: TutorialRoutes.pvp,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'pvp_find_match',
          trackId: TutorialTrackId.pvp,
          title: 'Arena',
          body: 'Benzer güçte rakiplere meydan oku.',
          anchorId: TutorialAnchorId.pvpFindMatch,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          allowedRoutes: <String>[TutorialRoutes.pvp],
        ),
        TutorialStepV2(
          id: 'pvp_nemesis_hint',
          trackId: TutorialTrackId.pvp,
          title: 'Nemesis',
          body: 'Rakibini izle — intikam düellosu ve bonus.',
          anchorId: TutorialAnchorId.pvpNemesisPanel,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          requiresPrior: <String>['pvp_find_match'],
          allowedRoutes: <String>[TutorialRoutes.pvp],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.siege,
      triggerRoute: TutorialRoutes.dungeonSiegeHub,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'siege_hub_intro',
          trackId: TutorialTrackId.siege,
          title: 'Kuşatma',
          body: 'Slot tut veya lonca savaşına katıl. Prime saatlerde bonus.',
          anchorId: TutorialAnchorId.siegeHubPanel,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          allowedRoutes: <String>[
            TutorialRoutes.dungeonSiegeHub,
            TutorialRoutes.guildWar,
          ],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.dailyChain,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'daily_d1_dungeon',
          trackId: TutorialTrackId.dailyChain,
          title: 'Gün 1 — Zindan',
          body: 'Günlük hedef: zindana gir, loot topla.',
          anchorId: TutorialAnchorId.dungeonEnterBtn,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.dungeon],
        ),
        TutorialStepV2(
          id: 'daily_d2_inventory',
          trackId: TutorialTrackId.dailyChain,
          title: 'Gün 2 — Envanter',
          body: 'Eşyalarını düzenle, silahını kuşan.',
          anchorId: TutorialAnchorId.inventoryFirstWeapon,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.inventory],
          requiresPrior: <String>['daily_d1_dungeon'],
        ),
        TutorialStepV2(
          id: 'daily_d3_craft',
          trackId: TutorialTrackId.dailyChain,
          title: 'Gün 3 — Craft',
          body: 'Bir tarif seçip üretimi dene.',
          anchorId: TutorialAnchorId.craftRecipeList,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.crafting],
          requiresPrior: <String>['daily_d2_inventory'],
        ),
        TutorialStepV2(
          id: 'daily_d4_guild',
          trackId: TutorialTrackId.dailyChain,
          title: 'Gün 4 — Lonca',
          body: 'Lonca panelini aç veya katıl.',
          anchorId: TutorialAnchorId.guildHeader,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.guild],
          requiresPrior: <String>['daily_d3_craft'],
        ),
        TutorialStepV2(
          id: 'daily_d5_pvp',
          trackId: TutorialTrackId.dailyChain,
          title: 'Gün 5 — PvP',
          body: 'Arena\'da eşleşmeye bak.',
          anchorId: TutorialAnchorId.pvpFindMatch,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.pvp],
          requiresPrior: <String>['daily_d4_guild'],
        ),
        TutorialStepV2(
          id: 'daily_d6_market',
          trackId: TutorialTrackId.dailyChain,
          title: 'Gün 6 — Pazar',
          body: 'Pazarı gez — alım satım burada.',
          anchorId: TutorialAnchorId.marketBrowseTab,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[TutorialRoutes.market],
          requiresPrior: <String>['daily_d5_pvp'],
        ),
        TutorialStepV2(
          id: 'daily_d7_siege',
          trackId: TutorialTrackId.dailyChain,
          title: 'Gün 7 — Kuşatma',
          body: 'Kuşatma hub veya lonca savaşını incele.',
          anchorId: TutorialAnchorId.siegeHubPanel,
          mode: TutorialMode.spotlightTap,
          allowedRoutes: <String>[
            TutorialRoutes.dungeonSiegeHub,
            TutorialRoutes.guildWar,
          ],
          requiresPrior: <String>['daily_d6_market'],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.retentionIntro,
      triggerRoute: TutorialRoutes.character,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'retention_codex',
          trackId: TutorialTrackId.retentionIntro,
          title: 'Kodex',
          body: 'Keşifleri Kodex’te topla. Kilometre taşı ödülleri seni bekliyor.',
          anchorId: TutorialAnchorId.characterCodexTile,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          allowedRoutes: <String>[TutorialRoutes.character, TutorialRoutes.home],
        ),
        TutorialStepV2(
          id: 'retention_nemesis',
          trackId: TutorialTrackId.retentionIntro,
          title: 'Nemesis',
          body: 'PvP’de rakibini izle — intikam düellosu ve bonus altın.',
          anchorId: TutorialAnchorId.pvpNemesisPanel,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          allowedRoutes: <String>[
            TutorialRoutes.pvp,
            TutorialRoutes.character,
            TutorialRoutes.home,
          ],
          requiresPrior: <String>['retention_codex'],
        ),
        TutorialStepV2(
          id: 'retention_night',
          trackId: TutorialTrackId.retentionIntro,
          title: 'Gece Pazarı',
          body: 'Her gün 20:00–22:00 TR — sınırlı gem teklifleri.',
          anchorId: TutorialAnchorId.shopNightTab,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          allowedRoutes: <String>[
            TutorialRoutes.shop,
            TutorialRoutes.character,
            TutorialRoutes.home,
          ],
          requiresPrior: <String>['retention_nemesis'],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.horseRace,
      triggerRoute: TutorialRoutes.horseRace,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'horse_intro',
          trackId: TutorialTrackId.horseRace,
          title: 'At yarışı',
          body: 'Bahis paneli: para birimi ve miktar seç.',
          anchorId: TutorialAnchorId.horseBetPanel,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          allowedRoutes: <String>[TutorialRoutes.horseRace],
        ),
        TutorialStepV2(
          id: 'horse_pick_horse',
          trackId: TutorialTrackId.horseRace,
          title: 'At seç',
          body: 'Çarpanı yüksek veya güvendiğin ata dokun.',
          anchorId: TutorialAnchorId.horseHorseGrid,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          requiresPrior: <String>['horse_intro'],
          allowedRoutes: <String>[TutorialRoutes.horseRace],
        ),
        TutorialStepV2(
          id: 'horse_place_bet',
          trackId: TutorialTrackId.horseRace,
          title: 'Bahis koy',
          body: 'Bahisini onayla — canlı yarış otomatik başlar.',
          anchorId: TutorialAnchorId.horsePlaceBetBtn,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          requiresPrior: <String>['horse_pick_horse'],
          allowedRoutes: <String>[TutorialRoutes.horseRace],
        ),
        TutorialStepV2(
          id: 'horse_result_tip',
          trackId: TutorialTrackId.horseRace,
          title: 'Sonuç',
          body: 'Kazanç/kayıp bilette görünür. Sonraki turda tekrar bahis açılır.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Tamam',
          requiresPrior: <String>['horse_place_bet'],
          allowedRoutes: <String>[TutorialRoutes.horseRace],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.mekans,
      triggerRoute: TutorialRoutes.mekans,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'mekans_browse',
          trackId: TutorialTrackId.mekans,
          title: 'Mekanlar',
          body: 'Han ve arena mekanlarını keşfet — vitrin ve şöhret burada.',
          anchorId: TutorialAnchorId.mekansList,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          allowedRoutes: <String>[TutorialRoutes.mekans],
        ),
        TutorialStepV2(
          id: 'mekans_my_cta',
          trackId: TutorialTrackId.mekans,
          title: 'Benim mekanım',
          body: 'Kendi mekanını yönet veya yeni aç.',
          anchorId: TutorialAnchorId.mekansMyCta,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          requiresPrior: <String>['mekans_browse'],
          allowedRoutes: <String>[TutorialRoutes.mekans],
        ),
        TutorialStepV2(
          id: 'mekans_arena_hint',
          trackId: TutorialTrackId.mekans,
          title: 'Arena düellosu',
          body: 'PvP destekli mekan detayından Arena’ya gir — yerel rakiplerle kapış.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Devam',
          requiresPrior: <String>['mekans_my_cta'],
          allowedRoutes: <String>[
            TutorialRoutes.mekans,
            TutorialRoutes.myMekan,
          ],
        ),
        TutorialStepV2(
          id: 'mekans_fame_tip',
          trackId: TutorialTrackId.mekans,
          title: 'Şöhret',
          body: 'Satış ve arena şöhret kazandırır — liderlikte yüksel.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Tamam',
          requiresPrior: <String>['mekans_arena_hint'],
          allowedRoutes: <String>[
            TutorialRoutes.mekans,
            TutorialRoutes.myMekan,
          ],
        ),
      ],
    ),
    TutorialTrack(
      id: TutorialTrackId.nightMarket,
      triggerRoute: TutorialRoutes.shop,
      steps: <TutorialStepV2>[
        TutorialStepV2(
          id: 'night_tab_open',
          trackId: TutorialTrackId.nightMarket,
          title: 'Gece Pazarı',
          body: 'Mağazada 🌙 Gece sekmesine geç.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Devam',
          allowedRoutes: <String>[TutorialRoutes.shop],
        ),
        TutorialStepV2(
          id: 'night_window',
          trackId: TutorialTrackId.nightMarket,
          title: 'Saat penceresi',
          body: 'Her gün 20:00–22:00 TR açık. Dışında teklifler kilitli.',
          mode: TutorialMode.narrative,
          completion: TutorialCompletion.onManualDismiss,
          primaryLabel: 'Devam',
          requiresPrior: <String>['night_tab_open'],
          allowedRoutes: <String>[TutorialRoutes.shop],
        ),
        TutorialStepV2(
          id: 'night_offer_browse',
          trackId: TutorialTrackId.nightMarket,
          title: 'Sınırlı teklifler',
          body: 'Gem ile özel paketler — stok bitince gider.',
          anchorId: TutorialAnchorId.shopNightOffer,
          mode: TutorialMode.highlightOnly,
          completion: TutorialCompletion.onTapAnchor,
          requiresPrior: <String>['night_window'],
          allowedRoutes: <String>[TutorialRoutes.shop],
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
    bool homeLive = false,
  }) {
    final TutorialTrack? track = trackById(trackId);
    if (track == null) return const <TutorialStepV2>[];
    final List<TutorialStepV2> out = <TutorialStepV2>[];
    for (final TutorialStepV2 step in track.steps) {
      if (completedStepIds.contains(step.id)) continue;
      if (!_priorsMet(step, completedStepIds, homeLive: homeLive)) continue;
      if (step.id == 'season_l20_badge' && playerLevel < 18) continue;
      if (!homeLive && _isHomeLiveOnlyStep(step.id)) continue;
      out.add(step);
    }
    return out;
  }

  static bool isHomeLiveOnlyStep(String stepId) => false;

  static bool _isHomeLiveOnlyStep(String stepId) => isHomeLiveOnlyStep(stepId);

  static bool _priorsMet(
    TutorialStepV2 step,
    Set<String> completed, {
    required bool homeLive,
  }) {
    if (step.requiresPrior.isEmpty) return true;
    return step.requiresPrior.every(completed.contains);
  }

  /// Next D1–D7 step if daily chain is in progress.
  static TutorialStepV2? nextDailyChainStep(Set<String> completedStepIds) {
    final List<TutorialStepV2> eligible = eligibleSteps(
      trackId: TutorialTrackId.dailyChain,
      completedStepIds: completedStepIds,
    );
    return eligible.isEmpty ? null : eligible.first;
  }
}
