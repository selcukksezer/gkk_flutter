import 'package:flutter/material.dart';

/// Category of faction in the Aion 2 Mobile realm.
enum FactionCategory {
  order,
  craft,
  council;

  String get label {
    switch (this) {
      case FactionCategory.order:
        return 'Hanedan & Tarikat';
      case FactionCategory.craft:
        return 'Zanaat Birlikleri';
      case FactionCategory.council:
        return 'Bölge Konseyleri';
    }
  }

  IconData get icon {
    switch (this) {
      case FactionCategory.order:
        return Icons.military_tech_rounded;
      case FactionCategory.craft:
        return Icons.hardware_rounded;
      case FactionCategory.council:
        return Icons.account_balance_rounded;
    }
  }
}

/// Color theme palette for faction emblem shaders and cards.
enum FactionPaletteType {
  deepAzure,
  abyssalCrimson,
  emeraldAura;

  Color get primary {
    switch (this) {
      case FactionPaletteType.deepAzure:
        return const Color(0xFF00E5FF);
      case FactionPaletteType.abyssalCrimson:
        return const Color(0xFFFF1744);
      case FactionPaletteType.emeraldAura:
        return const Color(0xFF00E676);
    }
  }

  Color get secondary {
    switch (this) {
      case FactionPaletteType.deepAzure:
        return const Color(0xFF0D47A1);
      case FactionPaletteType.abyssalCrimson:
        return const Color(0xFF7C4DFF);
      case FactionPaletteType.emeraldAura:
        return const Color(0xFF00BFA5);
    }
  }

  Color get accent {
    switch (this) {
      case FactionPaletteType.deepAzure:
        return const Color(0xFFFFD54F);
      case FactionPaletteType.abyssalCrimson:
        return const Color(0xFFFF5252);
      case FactionPaletteType.emeraldAura:
        return const Color(0xFFFFD700);
    }
  }

  Color get glow {
    switch (this) {
      case FactionPaletteType.deepAzure:
        return const Color(0xFF80D8FF);
      case FactionPaletteType.abyssalCrimson:
        return const Color(0xFFFF8A80);
      case FactionPaletteType.emeraldAura:
        return const Color(0xFFA7F3D0);
    }
  }

  List<Color> get cardGradient {
    switch (this) {
      case FactionPaletteType.deepAzure:
        return <Color>[
          const Color(0xFF081B38).withValues(alpha: 0.92),
          const Color(0xFF030A17).withValues(alpha: 0.98),
        ];
      case FactionPaletteType.abyssalCrimson:
        return <Color>[
          const Color(0xFF280710).withValues(alpha: 0.92),
          const Color(0xFF0B0104).withValues(alpha: 0.98),
        ];
      case FactionPaletteType.emeraldAura:
        return <Color>[
          const Color(0xFF042416).withValues(alpha: 0.92),
          const Color(0xFF020D08).withValues(alpha: 0.98),
        ];
    }
  }
}

/// Standard Aion 2 Standing Tiers (Neutral -> Friendly -> Honored -> Revered -> Exalted)
enum FactionStandingTier {
  neutral,
  friendly,
  honored,
  revered,
  exalted;

  String get title {
    switch (this) {
      case FactionStandingTier.neutral:
        return 'Nötr';
      case FactionStandingTier.friendly:
        return 'Dost';
      case FactionStandingTier.honored:
        return 'Saygıdeğer';
      case FactionStandingTier.revered:
        return 'Hürmetli';
      case FactionStandingTier.exalted:
        return 'Yüce';
    }
  }

  String get romanBadge {
    switch (this) {
      case FactionStandingTier.neutral:
        return 'I';
      case FactionStandingTier.friendly:
        return 'II';
      case FactionStandingTier.honored:
        return 'III';
      case FactionStandingTier.revered:
        return 'IV';
      case FactionStandingTier.exalted:
        return 'V';
    }
  }

  int get minPoints {
    switch (this) {
      case FactionStandingTier.neutral:
        return 0;
      case FactionStandingTier.friendly:
        return 3000;
      case FactionStandingTier.honored:
        return 9000;
      case FactionStandingTier.revered:
        return 25000;
      case FactionStandingTier.exalted:
        return 50000;
    }
  }

  int get maxPoints {
    switch (this) {
      case FactionStandingTier.neutral:
        return 3000;
      case FactionStandingTier.friendly:
        return 9000;
      case FactionStandingTier.honored:
        return 25000;
      case FactionStandingTier.revered:
        return 50000;
      case FactionStandingTier.exalted:
        return 100000;
    }
  }

  int get vendorDiscountPct {
    switch (this) {
      case FactionStandingTier.neutral:
        return 0;
      case FactionStandingTier.friendly:
        return 5;
      case FactionStandingTier.honored:
        return 10;
      case FactionStandingTier.revered:
        return 15;
      case FactionStandingTier.exalted:
        return 20;
    }
  }

  Color colorForPalette(FactionPaletteType palette) {
    switch (this) {
      case FactionStandingTier.neutral:
        return const Color(0xFF94A3B8);
      case FactionStandingTier.friendly:
        return palette == FactionPaletteType.deepAzure
            ? const Color(0xFF38BDF8)
            : (palette == FactionPaletteType.abyssalCrimson
                ? const Color(0xFFFF8A80)
                : const Color(0xFF34D399));
      case FactionStandingTier.honored:
        return palette == FactionPaletteType.deepAzure
            ? const Color(0xFF818CF8)
            : (palette == FactionPaletteType.abyssalCrimson
                ? const Color(0xFFE040FB)
                : const Color(0xFF10B981));
      case FactionStandingTier.revered:
        return const Color(0xFFFBBF24);
      case FactionStandingTier.exalted:
        return const Color(0xFFFFD700);
    }
  }
}


/// Specific perk unlocked through faction standing.
class FactionPerk {
  const FactionPerk({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredTier,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final FactionStandingTier requiredTier;
  final IconData icon;

  bool isUnlockedFor(FactionStandingTier currentTier) =>
      currentTier.index >= requiredTier.index;
}

/// Milestone reward claimable at standing tiers.
class FactionMilestoneReward {
  const FactionMilestoneReward({
    required this.id,
    required this.title,
    required this.requiredTier,
    required this.rewardText,
    required this.icon,
    this.isClaimed = false,
  });

  final String id;
  final String title;
  final FactionStandingTier requiredTier;
  final String rewardText;
  final IconData icon;
  final bool isClaimed;

  FactionMilestoneReward copyWith({bool? isClaimed}) {
    return FactionMilestoneReward(
      id: id,
      title: title,
      requiredTier: requiredTier,
      rewardText: rewardText,
      icon: icon,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }

  bool isEligible(FactionStandingTier currentTier) =>
      currentTier.index >= requiredTier.index && !isClaimed;
}

/// Complete representation of an Aion 2 faction's standing state.
class FactionStandingData {
  FactionStandingData({
    required this.id,
    required this.name,
    required this.alignment,
    required this.category,
    required this.paletteType,
    required this.points,
    required this.headquarters,
    required this.loreDescription,
    required this.perks,
    required this.milestones,
  });

  final String id;
  final String name;
  final String alignment;
  final FactionCategory category;
  final FactionPaletteType paletteType;
  final int points;
  final String headquarters;
  final String loreDescription;
  final List<FactionPerk> perks;
  final List<FactionMilestoneReward> milestones;

  FactionStandingTier get currentTier {
    if (points >= FactionStandingTier.exalted.minPoints) {
      return FactionStandingTier.exalted;
    }
    if (points >= FactionStandingTier.revered.minPoints) {
      return FactionStandingTier.revered;
    }
    if (points >= FactionStandingTier.honored.minPoints) {
      return FactionStandingTier.honored;
    }
    if (points >= FactionStandingTier.friendly.minPoints) {
      return FactionStandingTier.friendly;
    }
    return FactionStandingTier.neutral;
  }

  int get vendorDiscountPct => currentTier.vendorDiscountPct;

  FactionStandingTier? get nextTier {
    final int nextIdx = currentTier.index + 1;
    if (nextIdx < FactionStandingTier.values.length) {
      return FactionStandingTier.values[nextIdx];
    }
    return null;
  }

  double get tierProgress {
    if (currentTier == FactionStandingTier.exalted) return 1.0;
    final int min = currentTier.minPoints;
    final int max = currentTier.maxPoints;
    final double p = (points - min) / (max - min);
    return p.clamp(0.0, 1.0);
  }

  int get remainingPointsToNext {
    if (currentTier == FactionStandingTier.exalted) return 0;
    return (currentTier.maxPoints - points).clamp(0, 100000);
  }

  int get unlockedPerksCount {
    final FactionStandingTier tier = currentTier;
    return perks.where((FactionPerk p) => p.isUnlockedFor(tier)).length;
  }

  int get claimableRewardsCount {
    final FactionStandingTier tier = currentTier;
    return milestones.where((FactionMilestoneReward m) => m.isEligible(tier)).length;
  }

  FactionStandingData claimReward(String rewardId) {
    final List<FactionMilestoneReward> updated = milestones.map((FactionMilestoneReward m) {
      if (m.id == rewardId) {
        return m.copyWith(isClaimed: true);
      }
      return m;
    }).toList();

    return copyWith(milestones: updated);
  }

  FactionStandingData copyWith({
    String? id,
    String? name,
    String? alignment,
    FactionCategory? category,
    FactionPaletteType? paletteType,
    int? points,
    String? headquarters,
    String? loreDescription,
    List<FactionPerk>? perks,
    List<FactionMilestoneReward>? milestones,
  }) {
    return FactionStandingData(
      id: id ?? this.id,
      name: name ?? this.name,
      alignment: alignment ?? this.alignment,
      category: category ?? this.category,
      paletteType: paletteType ?? this.paletteType,
      points: points ?? this.points,
      headquarters: headquarters ?? this.headquarters,
      loreDescription: loreDescription ?? this.loreDescription,
      perks: perks ?? this.perks,
      milestones: milestones ?? this.milestones,
    );
  }
}


/// Preset authentic factions for Aion 2 Mobile Social Progression.
List<FactionStandingData> defaultFactionStandings() {
  return <FactionStandingData>[
    // 1. Miragent Holy Templars (Elyos Order) - Deep Azure
    FactionStandingData(
      id: 'miragent_templars',
      name: 'Miragent Kutsal Tapınakçıları',
      alignment: 'Elyos / Işık Muhafızları',
      category: FactionCategory.order,
      paletteType: FactionPaletteType.deepAzure,
      points: 34200,
      headquarters: 'Sanctum Baş Tapınağı',
      loreDescription:
          'Aion\'un ışığını korumaya adanmış, Sanctum\'un en seçkin ilahi savaşçı tarikatı.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'mir_1',
          title: 'Sanctum Işınlanma İndirimi (%50)',
          description: 'Sanctum kapılarına teleport maliyeti yarıya düşer.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.flight_takeoff_rounded,
        ),
        FactionPerk(
          id: 'mir_2',
          title: 'İlahi Koruma (+4% Zırh & Savunma)',
          description: 'Tüm zindanlarda ilahi ışık zırh takviyesi.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.shield_rounded,
        ),
        FactionPerk(
          id: 'mir_3',
          title: 'Miragent Kutsal Zırh Seti',
          description: 'Özel Miragent fraksiyon satıcısı vitrini açılır.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.auto_awesome_rounded,
        ),
        FactionPerk(
          id: 'mir_4',
          title: 'Yüce Baş Melek Kanatları',
          description: 'Uçuş süresi +30 sn ve ilahi parlama aurası.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.star_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 'm_rew_1',
          title: 'Kutsal Aether Özütü x100',
          requiredTier: FactionStandingTier.friendly,
          rewardText: '100x Kutsal Aether',
          icon: Icons.science_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 'm_rew_2',
          title: 'Miragent Nişanı & Unvanı',
          requiredTier: FactionStandingTier.honored,
          rewardText: 'Miragent Şövalyesi Unvanı',
          icon: Icons.military_tech_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 'm_rew_3',
          title: 'Miragent Hürmetli Sandığı',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'Efsanevi Miragent Miğferi & 25,000 Altın',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'm_rew_4',
          title: 'Yüce Miragent Kanat Kristali',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'Mitik Kanat Süslemesi & 100,000 Altın',
          icon: Icons.diamond_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 2. Fenris's Fang Legion (Asmodian Order) - Abyssal Crimson
    FactionStandingData(
      id: 'fenris_fangs',
      name: 'Fenris Pençesi Lejyonu',
      alignment: 'Asmodian / Gölge Lejyonu',
      category: FactionCategory.order,
      paletteType: FactionPaletteType.abyssalCrimson,
      points: 28900,
      headquarters: 'Pandaemonium Gölge Kalesi',
      loreDescription:
          'Karanlık uçurumun dehşetini kucaklayan, Asmodae\'nin en vahşi lejyon birliği.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'fen_1',
          title: 'Gölge Geçidi Ücretsiz Geçiş',
          description: 'Pandaemonium gölge kapılarında serbest geçiş.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.vpn_key_rounded,
        ),
        FactionPerk(
          id: 'fen_2',
          title: 'Abyssal Hiddet (+5% PvP Hasarı)',
          description: 'Uçurum ve savaş alanlarında ekstra hasar çarpanı.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.flash_on_rounded,
        ),
        FactionPerk(
          id: 'fen_3',
          title: 'Fenris Gölge Teçhizatı Erişimi',
          description: 'Lejyon zırh ustasından destansı silah alımı.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.colorize_rounded,
        ),
        FactionPerk(
          id: 'fen_4',
          title: 'Abyssal Ejder Gözü Aurası',
          description: 'Göz kamaştırıcı kırmızı gölge ejder aurası.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.visibility_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 'f_rew_1',
          title: 'Fenris Lejyoner Pelerini',
          requiredTier: FactionStandingTier.friendly,
          rewardText: 'Nadir Fenris Pelerini',
          icon: Icons.shield_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 'f_rew_2',
          title: 'Karanlık Aether Kristali x50',
          requiredTier: FactionStandingTier.honored,
          rewardText: '50x Saf Karanlık Aether',
          icon: Icons.blur_on_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 'f_rew_3',
          title: 'Fenris Hürmetli Sandığı',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'Efsanevi Fenris Pençesi Hançeri',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'f_rew_4',
          title: 'Yüce Gölge Silah Kaplaması',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'Mitik Abyssal Silah Parıltısı',
          icon: Icons.flare_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 3. Tigraki Workshop (Craft Guild) - Emerald Aura
    FactionStandingData(
      id: 'tigraki_workshop',
      name: 'Tigraki Atölyesi',
      alignment: 'Shugo / Usta Zanaatkarlar',
      category: FactionCategory.craft,
      paletteType: FactionPaletteType.emeraldAura,
      points: 16500,
      headquarters: 'Tigraki Uçan Adası',
      loreDescription:
          'Aion evreninin en kurnaz ve hünerli Shugo demir ustaları ve mucitleri.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'tig_1',
          title: 'Demircilik Başarı Åansı +4%',
          description: 'Ekipman üretiminde kritik başarı şansı artar.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.build_rounded,
        ),
        FactionPerk(
          id: 'tig_2',
          title: 'Ham Madde Maliyeti -15%',
          description: 'Atölye zanaat malzemelerinde kalıcı Shugo indirimi.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.price_check_rounded,
        ),
        FactionPerk(
          id: 'tig_3',
          title: 'Efsanevi Taslak Kitaplığı',
          description: 'Gizli Shugo silah ve zırh şemalarına erişim.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.menu_book_rounded,
        ),
        FactionPerk(
          id: 'tig_4',
          title: 'Tigraki Usta Çekici',
          description: 'Zanaat üretim süresi %35 kısalır.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.hardware_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 't_rew_1',
          title: 'Tigraki Zanaat Çantası',
          requiredTier: FactionStandingTier.friendly,
          rewardText: '+12 Envanter Yuvası',
          icon: Icons.backpack_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 't_rew_2',
          title: 'Ender Zanaat Taslak Paketi',
          requiredTier: FactionStandingTier.honored,
          rewardText: '3x Nadir Demircilik Taslağı',
          icon: Icons.history_edu_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 't_rew_3',
          title: 'Tigraki Hürmetli Sandığı',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'Efsanevi Shugo Çekici & 50x Aether Cevheri',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 't_rew_4',
          title: 'Yüce Zanaatkar Üniforması',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'Kozmetik Usta Zanaatkar Kostümü',
          icon: Icons.checkroom_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 4. Aetheric Artificers Guild (Craft Guild) - Deep Azure
    FactionStandingData(
      id: 'aetheric_artificers',
      name: 'Aether Simyacıları Loncası',
      alignment: 'Aether Mühendisleri & Simyacılar',
      category: FactionCategory.craft,
      paletteType: FactionPaletteType.deepAzure,
      points: 7400,
      headquarters: 'Göksel Aether Laboratuvarı',
      loreDescription:
          'Göksel aether akışlarını şişeleyip kudretli iksirlere dönüştüren kadim lonca.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'aeth_1',
          title: 'İksir Üretim Verimi +15%',
          description: 'Her iksir üretiminde çift doz çıkma şansı.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.local_drink_rounded,
        ),
        FactionPerk(
          id: 'aeth_2',
          title: 'Aether Çıkarma Hızı +25%',
          description: 'Havadaki aether kaynaklarını daha hızlı toplama.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.cloud_download_rounded,
        ),
        FactionPerk(
          id: 'aeth_3',
          title: 'Uçurum Taşı Dönüştürücü',
          description: 'Basit taşları Abyssal cevherlere çevirme tezgahı.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.change_circle_rounded,
        ),
        FactionPerk(
          id: 'aeth_4',
          title: 'Sonsuz Aether Matarası',
          description: 'Günde 1 kez tam mana & can yenileyen iksir.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.whatshot_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 'ae_rew_1',
          title: 'Aether Simyacı Cübbesi',
          requiredTier: FactionStandingTier.friendly,
          rewardText: 'Özel Kozmetik Lonca Cübbesi',
          icon: Icons.accessibility_new_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'ae_rew_2',
          title: 'Saf Aether Özütü x100',
          requiredTier: FactionStandingTier.honored,
          rewardText: '100x Saf Göksel Aether Damlası',
          icon: Icons.science_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'ae_rew_3',
          title: 'Kadim Simya Tarifi',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'Yenilmezlik İksiri Formülü',
          icon: Icons.menu_book_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'ae_rew_4',
          title: 'Yüce Simyager Unvanı',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'Altın İsimlik & +500 Büyü Gücü',
          icon: Icons.emoji_events_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 5. Reshanta Abyss Council (Regional Council) - Abyssal Crimson
    FactionStandingData(
      id: 'reshanta_council',
      name: 'Reshanta Uçurum Konseyi',
      alignment: 'Reshanta / Egemenlik Meclisi',
      category: FactionCategory.council,
      paletteType: FactionPaletteType.abyssalCrimson,
      points: 22800,
      headquarters: 'Reshanta Merkez Kalesi',
      loreDescription:
          'Uçurumun kalbindeki stratejik hisarları ve antik boyut yarıklarını denetleyen konsey.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'res_1',
          title: 'Uçurum Puanı (AP) Kazanımı +8%',
          description: 'Tüm PvP ve kuşatma etkinliklerinde ekstra AP kazanımı.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.military_tech_rounded,
        ),
        FactionPerk(
          id: 'res_2',
          title: 'Kuşatma Makinesi Hasarı +12%',
          description: 'Kale kuşatmalarında kapı ve savunma taşlarına ek hasar.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.fireplace_rounded,
        ),
        FactionPerk(
          id: 'res_3',
          title: 'Reshanta Garnizon Satıcı İndirimi',
          description: 'Uçurum teçhizatlarında kalıcı %15 indirim.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.storefront_rounded,
        ),
        FactionPerk(
          id: 'res_4',
          title: 'Reshanta Fatihi Savaş Sancağı',
          description: 'Grup üyelerine +%10 saldırı hızı aurası.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.flag_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 'r_rew_1',
          title: '5,000 Uçurum Puanı (AP)',
          requiredTier: FactionStandingTier.friendly,
          rewardText: '5,000 AP Anında Yükleme',
          icon: Icons.star_half_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 'r_rew_2',
          title: 'Reshanta Muhafız Mührü',
          requiredTier: FactionStandingTier.honored,
          rewardText: 'Kuşatma Madalyonu & 35,000 Altın',
          icon: Icons.verified_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'r_rew_3',
          title: 'Abyssal Savaş Sandığı',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'Seçmeli Uçurum Aksesuarı',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'r_rew_4',
          title: 'Reshanta Fatihi Unvanı',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'Kırmızı Parıldayan Unvan & +120 PvP Gücü',
          icon: Icons.stars_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 6. Sanctum High Synod (Regional Council) - Deep Azure
    FactionStandingData(
      id: 'sanctum_synod',
      name: 'Sanctum Yüce Meclisi',
      alignment: 'Sanctum / Başkent Senatosu',
      category: FactionCategory.council,
      paletteType: FactionPaletteType.deepAzure,
      points: 46200,
      headquarters: 'Sanctum Meclis Salonu',
      loreDescription:
          'Elysea\'nın başkentini yöneten, kanunları ve ilahi vergileri düzenleyen yüce kurul.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'san_1',
          title: 'Başkent Satıcı İndirimi (%5)',
          description: 'Sanctum çarşısındaki tüm NPC mağazalarında geçerli.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.shopping_bag_rounded,
        ),
        FactionPerk(
          id: 'san_2',
          title: 'Şehir İçi Hareket Hızı +15%',
          description: 'Sanctum sokaklarında hafiflik ve hızlı adımlar.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.directions_run_rounded,
        ),
        FactionPerk(
          id: 'san_3',
          title: 'Yüksek Senatör Muhafız Çağrısı',
          description: 'Zorlu durumlarda elit Sanctum muhafızı çağırma.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.groups_rounded,
        ),
        FactionPerk(
          id: 'san_4',
          title: 'Sanctum Yüce Temsilcisi Diploması',
          description: 'Tüm vergilerden muafiyet & özel altın heykel.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.workspace_premium_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 's_rew_1',
          title: 'Sanctum Onur Madalyası',
          requiredTier: FactionStandingTier.friendly,
          rewardText: 'Altın Onur Rozeti',
          icon: Icons.badge_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 's_rew_2',
          title: 'Altın Güvercin Postası İzni',
          requiredTier: FactionStandingTier.honored,
          rewardText: 'Anında Ücretsiz Posta Erişimi',
          icon: Icons.mail_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 's_rew_3',
          title: 'Sanctum Yüksek Sandığı',
          requiredTier: FactionStandingTier.revered,
          rewardText: '50,000 Altın & 2x Mitik Güç Taşı',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 's_rew_4',
          title: 'Yüce Meclis Şeref Asası',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'Kozmetik Åeref Asası & Altın Işık',
          icon: Icons.auto_awesome_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 7. Inggison Frontier Wardens (Regional Council) - Emerald Aura
    FactionStandingData(
      id: 'inggison_wardens',
      name: 'Inggison Sınır Muhafızları',
      alignment: 'Balaurea / Sınır Gözlemcileri',
      category: FactionCategory.council,
      paletteType: FactionPaletteType.emeraldAura,
      points: 2100,
      headquarters: 'Inggison İleri Karakolu',
      loreDescription:
          'Balaurea\'nın yabani topraklarında Balaur ejder lejyonlarına karşı sınır hattını tutan cesur muhafızlar.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'ing_1',
          title: 'Sınır Karakolu Satıcı İndirimi (%5)',
          description: 'Inggison erzak ve tamir maliyetlerinde indirim.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.healing_rounded,
        ),
        FactionPerk(
          id: 'ing_2',
          title: 'Yaban Can Yenilenmesi +8%',
          description: 'Savaş dışındayken yüksek hızda can ve mana dolumu.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.favorite_rounded,
        ),
        FactionPerk(
          id: 'ing_3',
          title: 'Rüzgar Akımı Geçiş İzni',
          description: 'Balaurea rüzgar koridorlarında ultra hızlı süzülme.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.air_rounded,
        ),
        FactionPerk(
          id: 'ing_4',
          title: 'Kadim Balaur Avcısı Nişanı',
          description: 'Balaur canavarlarına karşı +15% Kritik Hasar.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.pets_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 'i_rew_1',
          title: 'Sınır Keşif Pelerini',
          requiredTier: FactionStandingTier.friendly,
          rewardText: 'Yeşil Kamufle Sınır Pelerini',
          icon: Icons.shield_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'i_rew_2',
          title: 'Inggison Muhafız Zırhı',
          requiredTier: FactionStandingTier.honored,
          rewardText: 'Nadir Sınır Zırhı Parçası',
          icon: Icons.security_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'i_rew_3',
          title: 'Kadim Eser Sandığı',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'Balaurea Antik Eseri & 30,000 Altın',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'i_rew_4',
          title: 'Sınır Muhafızı Efsanesi Unvanı',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'Zümrüt Yeşili Unvan & +80 Canlılık',
          icon: Icons.military_tech_rounded,
          isClaimed: false,
        ),
      ],
    ),
  ];
}
