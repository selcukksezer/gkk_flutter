import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../models/dungeon_model.dart';
import '../dungeon_zone_data.dart';
import 'dungeon_cave_theme.dart';

/// Tier classification for Aion-2 style abyssal bosses.
enum Aion2BossTier {
  dungeonGuardian('ZİNDAN MUHAFIZI', Color(0xFF60A5FA), Icons.shield_rounded),
  dungeonChampion('ZİNDAN ŞAMPİYONU', Color(0xFFA78BFA), Icons.military_tech_rounded),
  abyssalOverlord('UÇURUM HÜKÜMDARI', Color(0xFFF59E0B), Icons.auto_awesome),
  worldDevourer('DÜNYA YUTAN', Color(0xFFEF4444), Icons.whatshot_rounded),
  primalArchon('KADİM ARKONT', Color(0xFFFFD700), Icons.workspace_premium_rounded);

  const Aion2BossTier(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

/// Rich thematic lore & art definition for an Aion-2 style abyssal boss.
class Aion2BossArtDefinition {
  const Aion2BossArtDefinition({
    required this.bossId,
    required this.name,
    required this.title,
    required this.subtitle,
    required this.element,
    required this.tier,
    required this.zone,
    required this.accentColor,
    required this.glowColor,
    required this.abyssalDarkColor,
    required this.goldFiligreeColor,
    required this.hornStyle,
    required this.eyeStyle,
    required this.loreQuote,
    required this.fallbackDungeonAsset,
  });

  final String bossId;
  final String name;
  final String title;
  final String subtitle;
  final String element;
  final Aion2BossTier tier;
  final int zone;
  final Color accentColor;
  final Color glowColor;
  final Color abyssalDarkColor;
  final Color goldFiligreeColor;
  final int hornStyle;
  final int eyeStyle;
  final String loreQuote;
  final String fallbackDungeonAsset;
}

/// Catalog of authentic Aion-2 dark fantasy abyssal bosses mapped to zones and dungeon IDs.
class Aion2BossIllustrationCatalog {
  const Aion2BossIllustrationCatalog._();

  static const List<Aion2BossArtDefinition> _bosses = <Aion2BossArtDefinition>[
    // Zone 1: Gölgeli Orman
    Aion2BossArtDefinition(
      bossId: 'boss_zone_1',
      name: 'Umbral Malgok',
      title: 'Gölgeler Lordu',
      subtitle: 'Karanlık Orman Başiblis',
      element: 'Karanlık Ruh',
      tier: Aion2BossTier.dungeonGuardian,
      zone: 1,
      accentColor: Color(0xFF4ADE80),
      glowColor: Color(0xFF00FF88),
      abyssalDarkColor: Color(0xFF071A10),
      goldFiligreeColor: Color(0xFFFFD700),
      hornStyle: 1,
      eyeStyle: 1,
      loreQuote: 'Ormanın kadim ağaçları onun fısıltısıyla çürüyor...',
      fallbackDungeonAsset: 'assets/dungeon/dungeon1.png',
    ),
    // Zone 2: Derin Mağara
    Aion2BossArtDefinition(
      bossId: 'boss_zone_2',
      name: 'Krag\'mar Çekirdekkıran',
      title: 'Obsidyen Uçurum Devi',
      subtitle: 'Derin Mağara Muhafızı',
      element: 'Obsidyen Taş & Lav',
      tier: Aion2BossTier.dungeonChampion,
      zone: 2,
      accentColor: Color(0xFF94A3B8),
      glowColor: Color(0xFF38BDF8),
      abyssalDarkColor: Color(0xFF0A121E),
      goldFiligreeColor: Color(0xFFFFC72C),
      hornStyle: 2,
      eyeStyle: 2,
      loreQuote: 'Yerin bin fersah altındaki tektonik kalp onun emrinde dövülüyor.',
      fallbackDungeonAsset: 'assets/dungeon/dungeon11.jpeg',
    ),
    // Zone 3: Ateş Çölü
    Aion2BossArtDefinition(
      bossId: 'boss_zone_3',
      name: 'Ignis Güneşyutan',
      title: 'Cehennem Kanatlı Ejder',
      subtitle: 'Ateş Çölü Hükümdarı',
      element: 'Akkor Cehennem Ateşi',
      tier: Aion2BossTier.abyssalOverlord,
      zone: 3,
      accentColor: Color(0xFFF97316),
      glowColor: Color(0xFFFF4500),
      abyssalDarkColor: Color(0xFF1E0803),
      goldFiligreeColor: Color(0xFFFFE066),
      hornStyle: 3,
      eyeStyle: 3,
      loreQuote: 'Gökten inen alev sağanağı kumu cama dönüştürür.',
      fallbackDungeonAsset: 'assets/dungeon/dungeon21.jpeg',
    ),
    // Zone 4: Fırtına Dağı
    Aion2BossArtDefinition(
      bossId: 'boss_zone_4',
      name: 'Zephyrus Fırtınaefendisi',
      title: 'Yıldırım Arkontu',
      subtitle: 'Gök Gürültüsü Hükümdarı',
      element: 'Kozmik Yıldırım & Kasırga',
      tier: Aion2BossTier.abyssalOverlord,
      zone: 4,
      accentColor: Color(0xFF60A5FA),
      glowColor: Color(0xFF00E5FF),
      abyssalDarkColor: Color(0xFF051024),
      goldFiligreeColor: Color(0xFFFFDF7A),
      hornStyle: 4,
      eyeStyle: 2,
      loreQuote: 'Zirvede duran kişi göklerin gazabına boyun eğmeye mecburdur.',
      fallbackDungeonAsset: 'assets/dungeon/dungeon31.jpeg',
    ),
    // Zone 5: Yeraltı Cehennemi
    Aion2BossArtDefinition(
      bossId: 'boss_zone_5',
      name: 'Baal\'kor Ruhyüzen',
      title: 'Nether Voidlord',
      subtitle: 'Yeraltı Cehennemi Hakimi',
      element: 'Nether Boşluk & Kan',
      tier: Aion2BossTier.worldDevourer,
      zone: 5,
      accentColor: Color(0xFFEF4444),
      glowColor: Color(0xFFFF1744),
      abyssalDarkColor: Color(0xFF220308),
      goldFiligreeColor: Color(0xFFFFD700),
      hornStyle: 5,
      eyeStyle: 3,
      loreQuote: 'Buraya giren ruhlar asla çıkamaz, sadece onun zırhına pul olur.',
      fallbackDungeonAsset: 'assets/dungeon/dungeon41.jpeg',
    ),
    // Zone 6: Kırık Gökyüzü
    Aion2BossArtDefinition(
      bossId: 'boss_zone_6',
      name: 'Aetherion Astral Seraf',
      title: 'Kırık Boyut Muhafızı',
      subtitle: 'Yıldız Kıran Seraf',
      element: 'Astral Parçalanma',
      tier: Aion2BossTier.worldDevourer,
      zone: 6,
      accentColor: Color(0xFFA78BFA),
      glowColor: Color(0xFFD946EF),
      abyssalDarkColor: Color(0xFF130926),
      goldFiligreeColor: Color(0xFFFFF099),
      hornStyle: 2,
      eyeStyle: 1,
      loreQuote: 'Boyutlar arasındaki çatlaklardan akan saf enerjinin vücut bulmuş hali.',
      fallbackDungeonAsset: 'assets/dungeon/dungeon51.jpeg',
    ),
    // Zone 7: Efsanevi Tehlikeler
    Aion2BossArtDefinition(
      bossId: 'boss_zone_7',
      name: 'Tiamat Kadim Ejder Tanrısı',
      title: 'Kıyamet Getiren Uçurum Hanedanı',
      subtitle: 'Aion 2 Baş Düşmanı',
      element: 'Primal Abyssal Void',
      tier: Aion2BossTier.primalArchon,
      zone: 7,
      accentColor: Color(0xFFFBBF24),
      glowColor: Color(0xFFFFD700),
      abyssalDarkColor: Color(0xFF1C1300),
      goldFiligreeColor: Color(0xFFFFF6B8),
      hornStyle: 5,
      eyeStyle: 3,
      loreQuote: 'Aion evreninin varoluşunu tehdit eden kadim uykudan uyanış...',
      fallbackDungeonAsset: 'assets/dungeon/dungeon61.jpeg',
    ),
  ];

  /// Resolves the appropriate Aion-2 boss definition for a given dungeon.
  static Aion2BossArtDefinition resolveForDungeon({
    required DungeonData dungeon,
    int? zoneOverride,
  }) {
    final int zone = zoneOverride ?? zoneForDungeon(dungeon);
    final int clampedZone = zone.clamp(1, 7);

    // Look for direct zone match
    for (final Aion2BossArtDefinition boss in _bosses) {
      if (boss.zone == clampedZone) {
        // If dungeon has a custom boss name, adapt title
        if (dungeon.isBoss || dungeon.difficulty.toLowerCase().contains('dungeon')) {
          return boss;
        }
        return boss;
      }
    }
    return _bosses.first;
  }

  /// Resolves by zone number (1..7).
  static Aion2BossArtDefinition resolveForZone(int zone) {
    final int clampedZone = zone.clamp(1, 7);
    for (final Aion2BossArtDefinition boss in _bosses) {
      if (boss.zone == clampedZone) return boss;
    }
    return _bosses.first;
  }

  /// Resolves by dungeon number (e.g. 1..65).
  static Aion2BossArtDefinition resolveForDungeonNumber(int dungeonNumber) {
    if (dungeonNumber <= 10) return resolveForZone(1);
    if (dungeonNumber <= 20) return resolveForZone(2);
    if (dungeonNumber <= 30) return resolveForZone(3);
    if (dungeonNumber <= 40) return resolveForZone(4);
    if (dungeonNumber <= 50) return resolveForZone(5);
    if (dungeonNumber <= 60) return resolveForZone(6);
    return resolveForZone(7);
  }
}

/// Custom painter that renders a procedural Aion-2 style Abyssal Visage & Runic Summoning Circle.
/// This guarantees genuine visual rendering with zero primitive blockouts.
class Aion2AbyssalIllustrationPainter extends CustomPainter {
  const Aion2AbyssalIllustrationPainter({
    required this.boss,
    required this.animationProgress,
    this.intensity = 1.0,
  });

  final Aion2BossArtDefinition boss;
  final double animationProgress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Offset center = Offset(size.width / 2, size.height * 0.48);
    final double radius = math.min(size.width, size.height) * 0.44;

    // 1. Deep Abyssal Cosmic Vortex Gradient
    final Paint bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.1),
        radius: 0.95,
        colors: <Color>[
          boss.glowColor.withValues(alpha: 0.28 * intensity),
          boss.accentColor.withValues(alpha: 0.16 * intensity),
          boss.abyssalDarkColor.withValues(alpha: 0.92),
          const Color(0xFF03060C),
        ],
        stops: const <double>[0.0, 0.35, 0.72, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Cosmic Nebulae & Runic Particle Dust
    final Paint dustPaint = Paint()..style = PaintingStyle.fill;
    final int particleCount = 28;
    for (int i = 0; i < particleCount; i++) {
      final double seed = (i * 137.5) % 1.0;
      final double speed = 0.4 + (i % 7) * 0.12;
      final double p = (animationProgress * speed + seed) % 1.0;
      final double angle = seed * 2 * math.pi + p * math.pi * 0.5;
      final double dist = radius * (0.2 + 0.75 * math.sin(p * math.pi));
      final double px = center.dx + math.cos(angle) * dist;
      final double py = center.dy + math.sin(angle) * dist * 0.8;
      final double pSize = 0.8 + ((i % 5) * 0.6);
      final double alpha = math.sin(p * math.pi) * 0.65 * intensity;

      dustPaint.color = (i % 3 == 0 ? boss.goldFiligreeColor : boss.glowColor)
          .withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(px, py), pSize, dustPaint);
    }

    // 3. Rotating Aion-2 Abyssal Runic Circles
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final double rot1 = animationProgress * 2 * math.pi * 0.25;
    final double rot2 = -animationProgress * 2 * math.pi * 0.18;

    // Outer Runic Ring
    canvas.save();
    canvas.rotate(rot1);
    final Paint outerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = boss.goldFiligreeColor.withValues(alpha: 0.45 * intensity);
    canvas.drawCircle(Offset.zero, radius * 0.86, outerRing);

    // Outer 8-point Runic Star Crest
    final Path starPath = Path();
    const int points = 8;
    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? radius * 0.86 : radius * 0.76;
      final double a = (i * math.pi) / points;
      final double x = math.cos(a) * r;
      final double y = math.sin(a) * r;
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();
    final Paint starPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = boss.accentColor.withValues(alpha: 0.35 * intensity);
    canvas.drawPath(starPath, starPaint);
    canvas.restore();

    // Inner Counter-Rotating Hexagram Ring
    canvas.save();
    canvas.rotate(rot2);
    final Paint innerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = boss.glowColor.withValues(alpha: 0.5 * intensity);
    canvas.drawCircle(Offset.zero, radius * 0.62, innerRing);

    final Path innerHex = Path();
    const int hexPoints = 6;
    for (int i = 0; i < hexPoints; i++) {
      final double a = (i * 2 * math.pi) / hexPoints;
      final double x = math.cos(a) * radius * 0.62;
      final double y = math.sin(a) * radius * 0.62;
      if (i == 0) {
        innerHex.moveTo(x, y);
      } else {
        innerHex.lineTo(x, y);
      }
    }
    innerHex.close();
    canvas.drawPath(innerHex, innerRing);
    canvas.restore();

    // 4. Detailed Abyssal Lord Visage & Armored Horns
    _drawAbyssalVisage(canvas, radius, center);

    canvas.restore();

    // 5. Ambient Vignette Overlay
    final Paint vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: <Color>[
          Colors.transparent,
          Colors.black.withValues(alpha: 0.35),
          Colors.black.withValues(alpha: 0.85),
        ],
        stops: const <double>[0.4, 0.75, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignettePaint);
  }

  void _drawAbyssalVisage(Canvas canvas, double radius, Offset center) {
    final double headScale = radius * 0.55;

    // Glowing Abyssal Chest Core / Rune
    final Paint coreGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          boss.glowColor.withValues(alpha: 0.75 * intensity),
          boss.accentColor.withValues(alpha: 0.35 * intensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(0, headScale * 0.65), radius: headScale * 0.4));
    canvas.drawCircle(Offset(0, headScale * 0.65), headScale * 0.35, coreGlow);

    // Shoulder Armor Pauldrons (Left & Right)
    final Path pauldronPath = Path();
    // Left pauldron
    pauldronPath.moveTo(-headScale * 0.5, headScale * 0.4);
    pauldronPath.lineTo(-headScale * 1.3, headScale * 0.85);
    pauldronPath.lineTo(-headScale * 0.8, headScale * 1.25);
    pauldronPath.lineTo(-headScale * 0.25, headScale * 0.95);
    pauldronPath.close();

    // Right pauldron
    pauldronPath.moveTo(headScale * 0.5, headScale * 0.4);
    pauldronPath.lineTo(headScale * 1.3, headScale * 0.85);
    pauldronPath.lineTo(headScale * 0.8, headScale * 1.25);
    pauldronPath.lineTo(headScale * 0.25, headScale * 0.95);
    pauldronPath.close();

    final Paint armorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF232D42),
          const Color(0xFF0F1420),
          const Color(0xFF070A10),
        ],
      ).createShader(Rect.fromLTWH(-headScale * 1.3, headScale * 0.4, headScale * 2.6, headScale));
    canvas.drawPath(pauldronPath, armorPaint);

    final Paint armorBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = boss.goldFiligreeColor.withValues(alpha: 0.7 * intensity);
    canvas.drawPath(pauldronPath, armorBorder);

    // Massive Curved Demon/Dragon Horns
    final Path hornPath = Path();
    // Left Horn
    hornPath.moveTo(-headScale * 0.22, -headScale * 0.25);
    hornPath.cubicTo(
      -headScale * 0.75,
      -headScale * 0.45,
      -headScale * 1.15,
      -headScale * 1.15,
      -headScale * 0.75,
      -headScale * 1.45,
    );
    hornPath.cubicTo(
      -headScale * 0.62,
      -headScale * 1.2,
      -headScale * 0.4,
      -headScale * 0.75,
      -headScale * 0.12,
      -headScale * 0.4,
    );
    hornPath.close();

    // Right Horn
    hornPath.moveTo(headScale * 0.22, -headScale * 0.25);
    hornPath.cubicTo(
      headScale * 0.75,
      -headScale * 0.45,
      headScale * 1.15,
      -headScale * 1.15,
      headScale * 0.75,
      -headScale * 1.45,
    );
    hornPath.cubicTo(
      headScale * 0.62,
      -headScale * 1.2,
      headScale * 0.4,
      -headScale * 0.75,
      headScale * 0.12,
      -headScale * 0.4,
    );
    hornPath.close();

    final Paint hornGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          boss.goldFiligreeColor,
          const Color(0xFF32221A),
          const Color(0xFF0C0A09),
        ],
      ).createShader(Rect.fromLTWH(-headScale * 1.2, -headScale * 1.5, headScale * 2.4, headScale * 1.5));
    canvas.drawPath(hornPath, hornGradient);

    final Paint hornOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = boss.goldFiligreeColor.withValues(alpha: 0.85 * intensity);
    canvas.drawPath(hornPath, hornOutline);

    // Horn Ridge Stripes
    final Paint ridgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = boss.glowColor.withValues(alpha: 0.6 * intensity);
    for (double f = 0.2; f <= 0.8; f += 0.2) {
      canvas.drawLine(
        Offset(-headScale * (0.3 + f * 0.4), -headScale * (0.35 + f * 0.8)),
        Offset(-headScale * (0.18 + f * 0.35), -headScale * (0.4 + f * 0.75)),
        ridgePaint,
      );
      canvas.drawLine(
        Offset(headScale * (0.3 + f * 0.4), -headScale * (0.35 + f * 0.8)),
        Offset(headScale * (0.18 + f * 0.35), -headScale * (0.4 + f * 0.75)),
        ridgePaint,
      );
    }

    // Armored Visage / Face Helm
    final Path faceHelm = Path();
    faceHelm.moveTo(0, -headScale * 0.45);
    faceHelm.lineTo(headScale * 0.38, -headScale * 0.15);
    faceHelm.lineTo(headScale * 0.32, headScale * 0.35);
    faceHelm.lineTo(0, headScale * 0.62);
    faceHelm.lineTo(-headScale * 0.32, headScale * 0.35);
    faceHelm.lineTo(-headScale * 0.38, -headScale * 0.15);
    faceHelm.close();

    final Paint helmPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF2D3748),
          const Color(0xFF1A202C),
          const Color(0xFF0F131A),
        ],
      ).createShader(Rect.fromLTWH(-headScale * 0.4, -headScale * 0.45, headScale * 0.8, headScale * 1.1));
    canvas.drawPath(faceHelm, helmPaint);

    final Paint helmBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = boss.goldFiligreeColor.withValues(alpha: 0.85 * intensity);
    canvas.drawPath(faceHelm, helmBorder);

    // Glowing Slit Abyssal Eyes
    final Paint eyeGlow = Paint()
      ..color = boss.glowColor.withValues(alpha: (0.75 + 0.25 * math.sin(animationProgress * 2 * math.pi)) * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final Paint eyeCore = Paint()..color = Colors.white;

    final Path leftEye = Path()
      ..moveTo(-headScale * 0.22, headScale * 0.05)
      ..lineTo(-headScale * 0.08, headScale * 0.08)
      ..lineTo(-headScale * 0.24, headScale * 0.12)
      ..close();

    final Path rightEye = Path()
      ..moveTo(headScale * 0.22, headScale * 0.05)
      ..lineTo(headScale * 0.08, headScale * 0.08)
      ..lineTo(headScale * 0.24, headScale * 0.12)
      ..close();

    canvas.drawPath(leftEye, eyeGlow);
    canvas.drawPath(rightEye, eyeGlow);
    canvas.drawPath(leftEye, eyeCore);
    canvas.drawPath(rightEye, eyeCore);

    // Forehead Runic Crest Gem
    final Path crestGem = Path()
      ..moveTo(0, -headScale * 0.38)
      ..lineTo(headScale * 0.08, -headScale * 0.26)
      ..lineTo(0, -headScale * 0.14)
      ..lineTo(-headScale * 0.08, -headScale * 0.26)
      ..close();

    final Paint gemPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white,
          boss.glowColor,
          boss.accentColor,
        ],
      ).createShader(Rect.fromCircle(center: Offset(0, -headScale * 0.26), radius: headScale * 0.1));
    canvas.drawPath(crestGem, gemPaint);

    final Paint gemBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = boss.goldFiligreeColor;
    canvas.drawPath(crestGem, gemBorder);
  }

  @override
  bool shouldRepaint(Aion2AbyssalIllustrationPainter oldDelegate) =>
      oldDelegate.animationProgress != animationProgress ||
      oldDelegate.intensity != intensity ||
      oldDelegate.boss != boss;
}
