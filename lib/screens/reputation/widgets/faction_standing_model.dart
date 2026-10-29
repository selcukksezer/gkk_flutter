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
        return 'BÃ¶lge Konseyleri';
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
        return 'NÃ¶tr';
      case FactionStandingTier.friendly:
        return 'Dost';
      case FactionStandingTier.honored:
        return 'SaygÄ±deÄŸer';
      case FactionStandingTier.revered:
        return 'HÃ¼rmetli';
      case FactionStandingTier.exalted:
        return 'YÃ¼ce';
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
      name: 'Miragent Kutsal TapÄ±nakÃ§Ä±larÄ±',
      alignment: 'Elyos / IÅŸÄ±k MuhafÄ±zlarÄ±',
      category: FactionCategory.order,
      paletteType: FactionPaletteType.deepAzure,
      points: 34200,
      headquarters: 'Sanctum BaÅŸ TapÄ±naÄŸÄ±',
      loreDescription:
          'Aionâ€™un Ä±ÅŸÄ±ÄŸÄ±nÄ± korumaya adanmÄ±ÅŸ, Sanctumâ€™un en seÃ§kin ilahi savaÅŸÃ§Ä± tarikatÄ±.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'mir_1',
          title: 'Sanctum IÅŸÄ±nlanma Ä°ndirimi (%50)',
          description: 'Sanctum kapÄ±larÄ±na teleport maliyeti yarÄ±ya dÃ¼ÅŸer.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.flight_takeoff_rounded,
        ),
        FactionPerk(
          id: 'mir_2',
          title: 'Ä°lahi Koruma (+4% ZÄ±rh & Savunma)',
          description: 'TÃ¼m zindanlarda ilahi Ä±ÅŸÄ±k zÄ±rh takviyesi.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.shield_rounded,
        ),
        FactionPerk(
          id: 'mir_3',
          title: 'Miragent Kutsal ZÄ±rh Seti',
          description: 'Ã–zel Miragent fraksiyon satÄ±cÄ±sÄ± vitrini aÃ§Ä±lÄ±r.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.auto_awesome_rounded,
        ),
        FactionPerk(
          id: 'mir_4',
          title: 'YÃ¼ce BaÅŸ Melek KanatlarÄ±',
          description: 'UÃ§uÅŸ sÃ¼resi +30 sn ve ilahi parlama aurasÄ±.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.star_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 'm_rew_1',
          title: 'Kutsal Aether Ã–zÃ¼tÃ¼ x100',
          requiredTier: FactionStandingTier.friendly,
          rewardText: '100x Kutsal Aether',
          icon: Icons.science_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 'm_rew_2',
          title: 'Miragent NiÅŸanÄ± & UnvanÄ±',
          requiredTier: FactionStandingTier.honored,
          rewardText: 'Miragent ÅÃ¶valyesi UnvanÄ±',
          icon: Icons.military_tech_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 'm_rew_3',
          title: 'Miragent HÃ¼rmetli SandÄ±ÄŸÄ±',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'Efsanevi Miragent MiÄŸferi & 25,000 AltÄ±n',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'm_rew_4',
          title: 'YÃ¼ce Miragent Kanat Kristali',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'Mitik Kanat SÃ¼slemesi & 100,000 AltÄ±n',
          icon: Icons.diamond_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 2. Fenris's Fang Legion (Asmodian Order) - Abyssal Crimson
    FactionStandingData(
      id: 'fenris_fangs',
      name: 'Fenris PenÃ§esi Lejyonu',
      alignment: 'Asmodian / GÃ¶lge Lejyonu',
      category: FactionCategory.order,
      paletteType: FactionPaletteType.abyssalCrimson,
      points: 28900,
      headquarters: 'Pandaemonium GÃ¶lge Kalesi',
      loreDescription:
          'KaranlÄ±k uÃ§urumun dehÅŸetini kucaklayan, Asmodaeâ€™nin en vahÅŸi lejyon birliÄŸi.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'fen_1',
          title: 'GÃ¶lge GeÃ§idi Ãœcretsiz GeÃ§iÅŸ',
          description: 'Pandaemonium gÃ¶lge kapÄ±larÄ±nda serbest geÃ§iÅŸ.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.vpn_key_rounded,
        ),
        FactionPerk(
          id: 'fen_2',
          title: 'Abyssal Hiddet (+5% PvP HasarÄ±)',
          description: 'UÃ§urum ve savaÅŸ alanlarÄ±nda ekstra hasar Ã§arpanÄ±.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.flash_on_rounded,
        ),
        FactionPerk(
          id: 'fen_3',
          title: 'Fenris GÃ¶lge TeÃ§hizatÄ± EriÅŸimi',
          description: 'Lejyon zÄ±rh ustasÄ±ndan destansÄ± silah alÄ±mÄ±.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.colorize_rounded,
        ),
        FactionPerk(
          id: 'fen_4',
          title: 'Abyssal Ejder GÃ¶zÃ¼ AurasÄ±',
          description: 'GÃ¶z kamaÅŸtÄ±rÄ±cÄ± kÄ±rmÄ±zÄ± gÃ¶lge ejder aurasÄ±.',
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
          title: 'KaranlÄ±k Aether Kristali x50',
          requiredTier: FactionStandingTier.honored,
          rewardText: '50x Saf KaranlÄ±k Aether',
          icon: Icons.blur_on_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 'f_rew_3',
          title: 'Fenris HÃ¼rmetli SandÄ±ÄŸÄ±',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'Efsanevi Fenris PenÃ§esi HanÃ§eri',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'f_rew_4',
          title: 'YÃ¼ce GÃ¶lge Silah KaplamasÄ±',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'Mitik Abyssal Silah ParÄ±ltÄ±sÄ±',
          icon: Icons.flare_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 3. Tigraki Workshop (Craft Guild) - Emerald Aura
    FactionStandingData(
      id: 'tigraki_workshop',
      name: 'Tigraki AtÃ¶lyesi',
      alignment: 'Shugo / Usta Zanaatkarlar',
      category: FactionCategory.craft,
      paletteType: FactionPaletteType.emeraldAura,
      points: 16500,
      headquarters: 'Tigraki UÃ§an AdasÄ±',
      loreDescription:
          'Aion evreninin en kurnaz ve hÃ¼nerli Shugo demir ustalarÄ± ve mucitleri.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'tig_1',
          title: 'Demircilik BaÅŸarÄ± ÅansÄ± +4%',
          description: 'Ekipman Ã¼retiminde kritik baÅŸarÄ± ÅŸansÄ± artar.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.build_rounded,
        ),
        FactionPerk(
          id: 'tig_2',
          title: 'Ham Madde Maliyeti -15%',
          description: 'AtÃ¶lye zanaat malzemelerinde kalÄ±cÄ± Shugo indirimi.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.price_check_rounded,
        ),
        FactionPerk(
          id: 'tig_3',
          title: 'Efsanevi Taslak KitaplÄ±ÄŸÄ±',
          description: 'Gizli Shugo silah ve zÄ±rh ÅŸemalarÄ±na eriÅŸim.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.menu_book_rounded,
        ),
        FactionPerk(
          id: 'tig_4',
          title: 'Tigraki Usta Ã‡ekici',
          description: 'Zanaat Ã¼retim sÃ¼resi %35 kÄ±salÄ±r.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.hardware_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 't_rew_1',
          title: 'Tigraki Zanaat Ã‡antasÄ±',
          requiredTier: FactionStandingTier.friendly,
          rewardText: '+12 Envanter YuvasÄ±',
          icon: Icons.backpack_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 't_rew_2',
          title: 'Ender Zanaat Taslak Paketi',
          requiredTier: FactionStandingTier.honored,
          rewardText: '3x Nadir Demircilik TaslaÄŸÄ±',
          icon: Icons.history_edu_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 't_rew_3',
          title: 'Tigraki HÃ¼rmetli SandÄ±ÄŸÄ±',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'Efsanevi Shugo Ã‡ekici & 50x Aether Cevheri',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 't_rew_4',
          title: 'YÃ¼ce Zanaatkar ÃœniformasÄ±',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'Kozmetik Usta Zanaatkar KostÃ¼mÃ¼',
          icon: Icons.checkroom_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 4. Aetheric Artificers Guild (Craft Guild) - Deep Azure
    FactionStandingData(
      id: 'aetheric_artificers',
      name: 'Aether SimyacÄ±larÄ± LoncasÄ±',
      alignment: 'Aether MÃ¼hendisleri & SimyacÄ±lar',
      category: FactionCategory.craft,
      paletteType: FactionPaletteType.deepAzure,
      points: 7400,
      headquarters: 'GÃ¶ksel Aether LaboratuvarÄ±',
      loreDescription:
          'GÃ¶ksel aether akÄ±ÅŸlarÄ±nÄ± ÅŸiÅŸeleyip kudretli iksirlere dÃ¶nÃ¼ÅŸtÃ¼ren kadim lonca.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'aeth_1',
          title: 'Ä°ksir Ãœretim Verimi +15%',
          description: 'Her iksir Ã¼retiminde Ã§ift doz Ã§Ä±kma ÅŸansÄ±.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.local_drink_rounded,
        ),
        FactionPerk(
          id: 'aeth_2',
          title: 'Aether Ã‡Ä±karma HÄ±zÄ± +25%',
          description: 'Havadaki aether kaynaklarÄ±nÄ± daha hÄ±zlÄ± toplama.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.cloud_download_rounded,
        ),
        FactionPerk(
          id: 'aeth_3',
          title: 'UÃ§urum TaÅŸÄ± DÃ¶nÃ¼ÅŸtÃ¼rÃ¼cÃ¼',
          description: 'Basit taÅŸlarÄ± Abyssal cevherlere Ã§evirme tezgahÄ±.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.change_circle_rounded,
        ),
        FactionPerk(
          id: 'aeth_4',
          title: 'Sonsuz Aether MatarasÄ±',
          description: 'GÃ¼nde 1 kez tam mana & can yenileyen iksir.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.whatshot_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 'ae_rew_1',
          title: 'Aether SimyacÄ± CÃ¼bbesi',
          requiredTier: FactionStandingTier.friendly,
          rewardText: 'Ã–zel Kozmetik Lonca CÃ¼bbesi',
          icon: Icons.accessibility_new_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'ae_rew_2',
          title: 'Saf Aether Ã–zÃ¼tÃ¼ x100',
          requiredTier: FactionStandingTier.honored,
          rewardText: '100x Saf GÃ¶ksel Aether DamlasÄ±',
          icon: Icons.science_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'ae_rew_3',
          title: 'Kadim Simya Tarifi',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'Yenilmezlik Ä°ksiri FormÃ¼lÃ¼',
          icon: Icons.menu_book_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'ae_rew_4',
          title: 'YÃ¼ce Simyager UnvanÄ±',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'AltÄ±n Ä°simlik & +500 BÃ¼yÃ¼ GÃ¼cÃ¼',
          icon: Icons.emoji_events_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 5. Reshanta Abyss Council (Regional Council) - Abyssal Crimson
    FactionStandingData(
      id: 'reshanta_council',
      name: 'Reshanta UÃ§urum Konseyi',
      alignment: 'Reshanta / Egemenlik Meclisi',
      category: FactionCategory.council,
      paletteType: FactionPaletteType.abyssalCrimson,
      points: 22800,
      headquarters: 'Reshanta Merkez Kalesi',
      loreDescription:
          'UÃ§urumun kalbindeki stratejik hisarlarÄ± ve antik boyut yarÄ±klarÄ±nÄ± denetleyen konsey.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'res_1',
          title: 'UÃ§urum PuanÄ± (AP) KazanÄ±mÄ± +8%',
          description: 'TÃ¼m PvP ve kuÅŸatma etkinliklerinde ekstra AP kazanÄ±mÄ±.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.military_tech_rounded,
        ),
        FactionPerk(
          id: 'res_2',
          title: 'KuÅŸatma Makinesi HasarÄ± +12%',
          description: 'Kale kuÅŸatmalarÄ±nda kapÄ± ve savunma taÅŸlarÄ±na ek hasar.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.fireplace_rounded,
        ),
        FactionPerk(
          id: 'res_3',
          title: 'Reshanta Garnizon SatÄ±cÄ± Ä°ndirimi',
          description: 'UÃ§urum teÃ§hizatlarÄ±nda kalÄ±cÄ± %15 indirim.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.storefront_rounded,
        ),
        FactionPerk(
          id: 'res_4',
          title: 'Reshanta Fatihi SavaÅŸ SancaÄŸÄ±',
          description: 'Grup Ã¼yelerine +%10 saldÄ±rÄ± hÄ±zÄ± aurasÄ±.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.flag_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 'r_rew_1',
          title: '5,000 UÃ§urum PuanÄ± (AP)',
          requiredTier: FactionStandingTier.friendly,
          rewardText: '5,000 AP AnÄ±nda YÃ¼kleme',
          icon: Icons.star_half_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 'r_rew_2',
          title: 'Reshanta MuhafÄ±z MÃ¼hrÃ¼',
          requiredTier: FactionStandingTier.honored,
          rewardText: 'KuÅŸatma Madalyonu & 35,000 AltÄ±n',
          icon: Icons.verified_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'r_rew_3',
          title: 'Abyssal SavaÅŸ SandÄ±ÄŸÄ±',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'SeÃ§meli UÃ§urum AksesuarÄ±',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'r_rew_4',
          title: 'Reshanta Fatihi UnvanÄ±',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'KÄ±rmÄ±zÄ± ParÄ±ldayan Unvan & +120 PvP GÃ¼cÃ¼',
          icon: Icons.stars_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 6. Sanctum High Synod (Regional Council) - Deep Azure
    FactionStandingData(
      id: 'sanctum_synod',
      name: 'Sanctum YÃ¼ce Meclisi',
      alignment: 'Sanctum / BaÅŸkent Senatosu',
      category: FactionCategory.council,
      paletteType: FactionPaletteType.deepAzure,
      points: 46200,
      headquarters: 'Sanctum Meclis Salonu',
      loreDescription:
          'Elyseaâ€™nÄ±n baÅŸkentini yÃ¶neten, kanunlarÄ± ve ilahi vergileri dÃ¼zenleyen yÃ¼ce kurul.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'san_1',
          title: 'BaÅŸkent SatÄ±cÄ± Ä°ndirimi (%5)',
          description: 'Sanctum Ã§arÅŸÄ±sÄ±ndaki tÃ¼m NPC maÄŸazalarÄ±nda geÃ§erli.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.shopping_bag_rounded,
        ),
        FactionPerk(
          id: 'san_2',
          title: 'Åehir Ä°Ã§i Hareket HÄ±zÄ± +15%',
          description: 'Sanctum sokaklarÄ±nda hafiflik ve hÄ±zlÄ± adÄ±mlar.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.directions_run_rounded,
        ),
        FactionPerk(
          id: 'san_3',
          title: 'YÃ¼ksek SenatÃ¶r MuhafÄ±z Ã‡aÄŸrÄ±sÄ±',
          description: 'Zorlu durumlarda elit Sanctum muhafÄ±zÄ± Ã§aÄŸÄ±rma.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.groups_rounded,
        ),
        FactionPerk(
          id: 'san_4',
          title: 'Sanctum YÃ¼ce Temsilcisi DiplomasÄ±',
          description: 'TÃ¼m vergilerden muafiyet & Ã¶zel altÄ±n heykel.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.workspace_premium_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 's_rew_1',
          title: 'Sanctum Onur MadalyasÄ±',
          requiredTier: FactionStandingTier.friendly,
          rewardText: 'AltÄ±n Onur Rozeti',
          icon: Icons.badge_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 's_rew_2',
          title: 'AltÄ±n GÃ¼vercin PostasÄ± Ä°zni',
          requiredTier: FactionStandingTier.honored,
          rewardText: 'AnÄ±nda Ãœcretsiz Posta EriÅŸimi',
          icon: Icons.mail_rounded,
          isClaimed: true,
        ),
        FactionMilestoneReward(
          id: 's_rew_3',
          title: 'Sanctum YÃ¼ksek SandÄ±ÄŸÄ±',
          requiredTier: FactionStandingTier.revered,
          rewardText: '50,000 AltÄ±n & 2x Mitik GÃ¼Ã§ TaÅŸÄ±',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 's_rew_4',
          title: 'YÃ¼ce Meclis Åeref AsasÄ±',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'Kozmetik Åeref AsasÄ± & AltÄ±n IÅŸÄ±k',
          icon: Icons.auto_awesome_rounded,
          isClaimed: false,
        ),
      ],
    ),

    // 7. Inggison Frontier Wardens (Regional Council) - Emerald Aura
    FactionStandingData(
      id: 'inggison_wardens',
      name: 'Inggison SÄ±nÄ±r MuhafÄ±zlarÄ±',
      alignment: 'Balaurea / SÄ±nÄ±r GÃ¶zlemcileri',
      category: FactionCategory.council,
      paletteType: FactionPaletteType.emeraldAura,
      points: 2100,
      headquarters: 'Inggison Ä°leri Karakolu',
      loreDescription:
          'Balaureaâ€™nÄ±n yabani topraklarÄ±nda Balaur ejder lejyonlarÄ±na karÅŸÄ± sÄ±nÄ±r hattÄ±nÄ± tutan cesur muhafÄ±zlar.',
      perks: const <FactionPerk>[
        FactionPerk(
          id: 'ing_1',
          title: 'SÄ±nÄ±r Karakolu SatÄ±cÄ± Ä°ndirimi (%5)',
          description: 'Inggison erzak ve tamir maliyetlerinde indirim.',
          requiredTier: FactionStandingTier.friendly,
          icon: Icons.healing_rounded,
        ),
        FactionPerk(
          id: 'ing_2',
          title: 'Yaban Can Yenilenmesi +8%',
          description: 'SavaÅŸ dÄ±ÅŸÄ±ndayken yÃ¼ksek hÄ±zda can ve mana dolumu.',
          requiredTier: FactionStandingTier.honored,
          icon: Icons.favorite_rounded,
        ),
        FactionPerk(
          id: 'ing_3',
          title: 'RÃ¼zgar AkÄ±mÄ± GeÃ§iÅŸ Ä°zni',
          description: 'Balaurea rÃ¼zgar koridorlarÄ±nda ultra hÄ±zlÄ± sÃ¼zÃ¼lme.',
          requiredTier: FactionStandingTier.revered,
          icon: Icons.air_rounded,
        ),
        FactionPerk(
          id: 'ing_4',
          title: 'Kadim Balaur AvcÄ±sÄ± NiÅŸanÄ±',
          description: 'Balaur canavarlarÄ±na karÅŸÄ± +15% Kritik Hasar.',
          requiredTier: FactionStandingTier.exalted,
          icon: Icons.pets_rounded,
        ),
      ],
      milestones: const <FactionMilestoneReward>[
        FactionMilestoneReward(
          id: 'i_rew_1',
          title: 'SÄ±nÄ±r KeÅŸif Pelerini',
          requiredTier: FactionStandingTier.friendly,
          rewardText: 'YeÅŸil Kamufle SÄ±nÄ±r Pelerini',
          icon: Icons.shield_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'i_rew_2',
          title: 'Inggison MuhafÄ±z ZÄ±rhÄ±',
          requiredTier: FactionStandingTier.honored,
          rewardText: 'Nadir SÄ±nÄ±r ZÄ±rhÄ± ParÃ§asÄ±',
          icon: Icons.security_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'i_rew_3',
          title: 'Kadim Eser SandÄ±ÄŸÄ±',
          requiredTier: FactionStandingTier.revered,
          rewardText: 'Balaurea Antik Eseri & 30,000 AltÄ±n',
          icon: Icons.inventory_2_rounded,
          isClaimed: false,
        ),
        FactionMilestoneReward(
          id: 'i_rew_4',
          title: 'SÄ±nÄ±r MuhafÄ±zÄ± Efsanesi UnvanÄ±',
          requiredTier: FactionStandingTier.exalted,
          rewardText: 'ZÃ¼mrÃ¼t YeÅŸili Unvan & +80 CanlÄ±lÄ±k',
          icon: Icons.military_tech_rounded,
          isClaimed: false,
        ),
      ],
    ),
  ];
}
