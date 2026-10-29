import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/daily_reward_model.dart';
import '../../theme/app_colors.dart';

/// Animation phases for the chest unlock cinematic.
enum ChestUnlockPhase {
  idle,
  anticipating,
  bursting,
  opened,
  presented,
}

/// Rarity tiers for daily reward items and grants.
enum DailyRewardRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary;

  String get label => switch (this) {
    DailyRewardRarity.common => 'SIRADAN',
    DailyRewardRarity.uncommon => 'SEÇKİN',
    DailyRewardRarity.rare => 'NADİR',
    DailyRewardRarity.epic => 'DESTANSI',
    DailyRewardRarity.legendary => 'EFSANEVİ',
  };

  Color get primaryColor => switch (this) {
    DailyRewardRarity.common => const Color(0xFFB0BEC5),
    DailyRewardRarity.uncommon => const Color(0xFF4CAF50),
    DailyRewardRarity.rare => const Color(0xFF29B6F6),
    DailyRewardRarity.epic => const Color(0xFFAB47BC),
    DailyRewardRarity.legendary => const Color(0xFFFFB300),
  };

  Color get glowColor => switch (this) {
    DailyRewardRarity.common => const Color(0x66B0BEC5),
    DailyRewardRarity.uncommon => const Color(0x804CAF50),
    DailyRewardRarity.rare => const Color(0x9929B6F6),
    DailyRewardRarity.epic => const Color(0xB3AB47BC),
    DailyRewardRarity.legendary => const Color(0xCCFFD54F),
  };

  List<BoxShadow> get auraShadow => <BoxShadow>[
    BoxShadow(
      color: glowColor,
      blurRadius: switch (this) {
        DailyRewardRarity.legendary => 36,
        DailyRewardRarity.epic => 28,
        DailyRewardRarity.rare => 20,
        _ => 12,
      },
      spreadRadius: switch (this) {
        DailyRewardRarity.legendary => 4,
        DailyRewardRarity.epic => 3,
        DailyRewardRarity.rare => 2,
        _ => 1,
      },
    ),
  ];

  static DailyRewardRarity fromGrant(DailyRewardGrant grant) {
    if (grant.cycleDay == 28 || grant.cycleDay == 20 || (grant.gems >= 50)) {
      return DailyRewardRarity.legendary;
    }
    if (grant.isMilestone || grant.cycleDay % 7 == 0 || grant.gems >= 20) {
      return DailyRewardRarity.epic;
    }
    if (grant.hasItem || grant.gems > 0 || grant.gold >= 10000) {
      return DailyRewardRarity.rare;
    }
    if (grant.gold >= 5000 || grant.energy >= 15) {
      return DailyRewardRarity.uncommon;
    }
    return DailyRewardRarity.common;
  }
}

/// Particle model for radial burst VFX and floating sparkle motes.
class DailyParticle {
  DailyParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.maxLife,
    this.life = 0.0,
    this.rotation = 0.0,
    this.rotationSpeed = 0.0,
    this.gravity = 0.08,
    this.drag = 0.98,
  });

  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double life;
  double maxLife;
  double rotation;
  double rotationSpeed;
  double gravity;
  double drag;

  bool get isDead => life >= maxLife;
  double get progress => (life / maxLife).clamp(0.0, 1.0);
  double get alpha => (1.0 - progress).clamp(0.0, 1.0);

  void update(double dt) {
    life += dt;
    vx *= drag;
    vy = (vy * drag) + gravity;
    x += vx;
    y += vy;
    rotation += rotationSpeed * dt;
  }

  static DailyParticle spawnBurst({
    required double originX,
    required double originY,
    required math.Random random,
    Color? baseColor,
  }) {
    final double angle = random.nextDouble() * 2 * math.pi;
    final double speed = 2.5 + random.nextDouble() * 7.5;
    final double size = 3.0 + random.nextDouble() * 5.0;
    final double maxLife = 0.6 + random.nextDouble() * 0.9;
    
    final List<Color> colors = <Color>[
      const Color(0xFFFFD54F), // Gold
      const Color(0xFFFFE082), // Amber glow
      const Color(0xFFFFF9C4), // White gold
      const Color(0xFFBA68C8), // Arcane amethyst
      const Color(0xFF4FC3F7), // Celestial cyan
      Colors.white,
    ];
    final Color chosenColor = baseColor ?? colors[random.nextInt(colors.length)];

    return DailyParticle(
      x: originX,
      y: originY,
      vx: math.cos(angle) * speed,
      vy: math.sin(angle) * speed,
      size: size,
      color: chosenColor,
      maxLife: maxLife,
      rotation: random.nextDouble() * math.pi,
      rotationSpeed: (random.nextDouble() - 0.5) * 8.0,
      gravity: 0.12,
      drag: 0.96,
    );
  }
}
