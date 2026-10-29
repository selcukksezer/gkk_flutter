import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Rarity tier for comeback rewards following Aion 2 cosmetic hierarchy.
enum ComebackRarity {
  common,
  rare,
  epic,
  legendary,
}

extension ComebackRarityX on ComebackRarity {
  Color get color => switch (this) {
        ComebackRarity.common => AppColors.mutedTitanium,
        ComebackRarity.rare => AppColors.accentCyan,
        ComebackRarity.epic => AppColors.cyberFuchsia,
        ComebackRarity.legendary => AppColors.liquidGold,
      };

  String get label => switch (this) {
        ComebackRarity.common => 'Sıradan',
        ComebackRarity.rare => 'Nadir',
        ComebackRarity.epic => 'Destansı',
        ComebackRarity.legendary => 'Efsanevi',
      };

  List<Color> get gradientColors => switch (this) {
        ComebackRarity.common => <Color>[
            const Color(0xFF6B7280),
            const Color(0xFF4B5563),
          ],
        ComebackRarity.rare => <Color>[
            AppColors.accentCyan,
            const Color(0xFF0077B6),
          ],
        ComebackRarity.epic => <Color>[
            AppColors.cyberFuchsia,
            AppColors.accentPurple,
          ],
        ComebackRarity.legendary => <Color>[
            AppColors.liquidGold,
            AppColors.warningSolar,
          ],
      };
}

/// Item inside a gift card or milestone chest.
class ComebackRewardItem {
  const ComebackRewardItem({
    required this.name,
    required this.quantity,
    required this.icon,
    this.rarity = ComebackRarity.rare,
    this.description,
  });

  final String name;
  final String quantity;
  final IconData icon;
  final ComebackRarity rarity;
  final String? description;
}

/// Exclusive Comeback Buff applied to returning players.
/// e.g. +20% EXP, +15% Gold, +10% Drop Rate for 7 days.
class ComebackBuffInfo {
  const ComebackBuffInfo({
    this.name = 'Geri Dönen Savaşçı Kutsaması',
    this.subtitle = 'Kadim Aion Işığıyla Güçlendin',
    this.expBoostPercent = 20,
    this.goldBoostPercent = 15,
    this.dropRateBoostPercent = 10,
    required this.activatedAt,
    required this.expiresAt,
    this.isActive = true,
  });

  final String name;
  final String subtitle;
  final int expBoostPercent;
  final int goldBoostPercent;
  final int dropRateBoostPercent;
  final DateTime activatedAt;
  final DateTime expiresAt;
  final bool isActive;

  Duration get remainingDuration {
    final DateTime now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(now);
  }

  bool get isExpired => remainingDuration == Duration.zero;

  String get remainingFormatted {
    final Duration rem = remainingDuration;
    if (rem.inDays > 0) {
      final int hours = rem.inHours % 24;
      return '${rem.inDays}g ${hours}s kaldı';
    }
    if (rem.inHours > 0) {
      final int minutes = rem.inMinutes % 60;
      return '${rem.inHours}s ${minutes}d kaldı';
    }
    if (rem.inMinutes > 0) {
      return '${rem.inMinutes} dk kaldı';
    }
    return 'Süresi doldu';
  }

  factory ComebackBuffInfo.defaultBuff({DateTime? now, int durationDays = 7}) {
    final DateTime start = now ?? DateTime.now();
    return ComebackBuffInfo(
      activatedAt: start,
      expiresAt: start.add(Duration(days: durationDays)),
      isActive: true,
    );
  }
}

/// Tiered 7-day returning player milestone login reward.
class ComebackMilestoneTier {
  const ComebackMilestoneTier({
    required this.day,
    required this.title,
    required this.rewardDescription,
    required this.rewardIcon,
    required this.rewardAmount,
    this.rarity = ComebackRarity.rare,
    this.isClaimed = false,
    this.isReady = false,
    this.isLocked = true,
  });

  final int day;
  final String title;
  final String rewardDescription;
  final IconData rewardIcon;
  final String rewardAmount;
  final ComebackRarity rarity;
  final bool isClaimed;
  final bool isReady;
  final bool isLocked;

  ComebackMilestoneTier copyWith({
    bool? isClaimed,
    bool? isReady,
    bool? isLocked,
  }) {
    return ComebackMilestoneTier(
      day: day,
      title: title,
      rewardDescription: rewardDescription,
      rewardIcon: rewardIcon,
      rewardAmount: rewardAmount,
      rarity: rarity,
      isClaimed: isClaimed ?? this.isClaimed,
      isReady: isReady ?? this.isReady,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  static List<ComebackMilestoneTier> generateDefaultTrack({int currentProgressDay = 1}) {
    const List<({String title, String desc, IconData icon, String amount, ComebackRarity rarity})> defs =
        <({String title, String desc, IconData icon, String amount, ComebackRarity rarity})>[
      (
        title: 'Hoş Geldin Paketi',
        desc: 'Temel Macera İksirleri',
        icon: Icons.card_giftcard_rounded,
        amount: '10x İksir',
        rarity: ComebackRarity.common,
      ),
      (
        title: 'Çifte EXP Parşömeni',
        desc: '+100% 2 Saatlik EXP Takviyesi',
        icon: Icons.auto_awesome_rounded,
        amount: '5x Parşömen',
        rarity: ComebackRarity.rare,
      ),
      (
        title: 'Kadim Zindan Bileti',
        desc: 'Özel Zindan Giriş Hakkı',
        icon: Icons.vpn_key_rounded,
        amount: '3x Bilet',
        rarity: ComebackRarity.rare,
      ),
      (
        title: 'Enerji Kristali',
        desc: 'Tam Enerji Yenileme',
        icon: Icons.bolt_rounded,
        amount: '500 Enerji',
        rarity: ComebackRarity.epic,
      ),
      (
        title: 'Seçkin Ekipman Sandığı',
        desc: 'Kahraman Seviye Zırh Parçası',
        icon: Icons.shield_rounded,
        amount: '1x Sandık',
        rarity: ComebackRarity.epic,
      ),
      (
        title: 'Hazine Kesesi',
        desc: 'Geliştirme Altını',
        icon: Icons.monetization_on_rounded,
        amount: '250.000 Altın',
        rarity: ComebackRarity.legendary,
      ),
      (
        title: 'Efsanevi Kanat: Fırtına',
        desc: 'Özel Geri Dönüş Kanat Kozmetiği',
        icon: Icons.flight_takeoff_rounded,
        amount: '1x Kanat',
        rarity: ComebackRarity.legendary,
      ),
    ];

    return List<ComebackMilestoneTier>.generate(defs.length, (int index) {
      final int day = index + 1;
      final ({String amount, String desc, IconData icon, ComebackRarity rarity, String title}) def = defs[index];
      final bool isClaimed = day < currentProgressDay;
      final bool isReady = day == currentProgressDay;
      final bool isLocked = day > currentProgressDay;

      return ComebackMilestoneTier(
        day: day,
        title: def.title,
        rewardDescription: def.desc,
        rewardIcon: def.icon,
        rewardAmount: def.amount,
        rarity: def.rarity,
        isClaimed: isClaimed,
        isReady: isReady,
        isLocked: isLocked,
      );
    });
  }
}

/// Welcome-back gift card payload.
class ComebackGiftCardData {
  const ComebackGiftCardData({
    required this.title,
    required this.subtitle,
    required this.offlineHours,
    required this.rewards,
    required this.eligibilityExpiry,
    this.isClaimed = false,
    this.claimedAt,
  });

  final String title;
  final String subtitle;
  final double offlineHours;
  final List<ComebackRewardItem> rewards;
  final DateTime eligibilityExpiry;
  final bool isClaimed;
  final DateTime? claimedAt;

  ComebackGiftCardData copyWith({
    bool? isClaimed,
    DateTime? claimedAt,
  }) {
    return ComebackGiftCardData(
      title: title,
      subtitle: subtitle,
      offlineHours: offlineHours,
      rewards: rewards,
      eligibilityExpiry: eligibilityExpiry,
      isClaimed: isClaimed ?? this.isClaimed,
      claimedAt: claimedAt ?? this.claimedAt,
    );
  }

  factory ComebackGiftCardData.defaultForOffline({
    required double offlineHours,
    DateTime? now,
  }) {
    final DateTime base = now ?? DateTime.now();
    return ComebackGiftCardData(
      title: 'Efsanevi Geri Dönüş Paketi',
      subtitle: 'Yokluğunda Atreia seni özledi. Gücünü geri topla!',
      offlineHours: offlineHours,
      eligibilityExpiry: base.add(const Duration(days: 14)),
      rewards: const <ComebackRewardItem>[
        ComebackRewardItem(
          name: 'Elmas Kesesi',
          quantity: '5.000',
          icon: Icons.diamond_rounded,
          rarity: ComebackRarity.legendary,
          description: 'Premium alışveriş birimi',
        ),
        ComebackRewardItem(
          name: 'Kadim Altın',
          quantity: '500.000',
          icon: Icons.paid_rounded,
          rarity: ComebackRarity.epic,
          description: 'Geliştirme ve tamir altını',
        ),
        ComebackRewardItem(
          name: 'Canlandırma İksiri',
          quantity: '20x',
          icon: Icons.local_pharmacy_rounded,
          rarity: ComebackRarity.rare,
          description: 'Anında can yenileme',
        ),
        ComebackRewardItem(
          name: 'Özel Ünvan: Dönen Fırtına',
          quantity: '1x',
          icon: Icons.military_tech_rounded,
          rarity: ComebackRarity.legendary,
          description: 'Geri dönen savaşçılara özel prestij unvanı',
        ),
      ],
      isClaimed: false,
    );
  }
}
