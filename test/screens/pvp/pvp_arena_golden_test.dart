import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/components/pvp/pvp_gladiator_3d_view.dart';
import 'package:gkk_flutter/models/nemesis_model.dart';
import 'package:gkk_flutter/screens/pvp/widgets/arena_map_viewport.dart';
import 'package:gkk_flutter/screens/pvp/widgets/gladiator_tier_emblem.dart';
import 'package:gkk_flutter/screens/pvp/widgets/nemesis_rival_panel.dart';
import 'package:gkk_flutter/screens/pvp/widgets/pvp_colosseum_backdrop.dart';
import 'package:gkk_flutter/screens/pvp/widgets/pvp_thumb_action_deck.dart';
import 'package:gkk_flutter/screens/pvp/widgets/pvp_versus_splash_banner.dart';
import 'package:gkk_flutter/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Authentic mobile viewport specifications (iPhone 14 / modern Android flagship).
const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 1.0; // 390x844 authentic mobile logical pixels
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

const String kOutputDir = 'reports/screenshots/mobile_goldens/pvp';

/// Utility to capture widget to PNG file on disk for visual inspection.
Future<File> captureWidgetToPng({
  required WidgetTester tester,
  required GlobalKey repaintKey,
  required String filename,
}) async {
  final Directory dir = Directory(kOutputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  File? savedFile;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: kDevicePixelRatio);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode image to PNG for $filename');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final File file = File('$kOutputDir/$filename');
    await file.writeAsBytes(pngBytes, flush: true);
    savedFile = file;
  });

  return savedFile!;
}

/// Helper wrapper that enforces authentic mobile viewport, devicePixelRatio, and safe area.
Widget buildMobileTestHarness({
  required GlobalKey repaintKey,
  required Widget child,
  Size size = const Size(kMobileWidth, kMobileHeight),
  EdgeInsets safeArea = kMobileSafeArea,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF070910),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: Color(0xFF00E5FF),
        surface: Color(0xFF101322),
      ),
    ),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        devicePixelRatio: kDevicePixelRatio,
        padding: safeArea,
        viewPadding: safeArea,
      ),
      child: RepaintBoundary(
        key: repaintKey,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT 1: DUAL COMBAT HEALTH BARS & VITALS HUD
// ─────────────────────────────────────────────────────────────────────────────

class PvpArenaCombatVitalsHud extends StatelessWidget {
  const PvpArenaCombatVitalsHud({
    super.key,
    required this.playerName,
    required this.playerLevel,
    required this.playerHp,
    required this.playerMaxHp,
    required this.playerEnergy,
    required this.playerMaxEnergy,
    required this.playerShield,
    required this.playerRating,
    required this.opponentName,
    required this.opponentLevel,
    required this.opponentHp,
    required this.opponentMaxHp,
    required this.opponentEnergy,
    required this.opponentMaxEnergy,
    required this.opponentRating,
    required this.roundText,
    required this.timerText,
  });

  final String playerName;
  final int playerLevel;
  final int playerHp;
  final int playerMaxHp;
  final int playerEnergy;
  final int playerMaxEnergy;
  final int playerShield;
  final int playerRating;

  final String opponentName;
  final int opponentLevel;
  final int opponentHp;
  final int opponentMaxHp;
  final int opponentEnergy;
  final int opponentMaxEnergy;
  final int opponentRating;

  final String roundText;
  final String timerText;

  @override
  Widget build(BuildContext context) {
    final double playerHpRatio = (playerHp / playerMaxHp).clamp(0.0, 1.0);
    final double opponentHpRatio = (opponentHp / opponentMaxHp).clamp(0.0, 1.0);
    final double playerEnergyRatio = (playerEnergy / playerMaxEnergy).clamp(0.0, 1.0);
    final double opponentEnergyRatio = (opponentEnergy / opponentMaxEnergy).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xEE090C16),
            const Color(0xBB0F1424),
            Colors.transparent,
          ],
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0x22F5C842), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Top Row: Timer & Round Framing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Player Rating Badge
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161F36),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.6), width: 0.8),
                  ),
                  child: Text(
                    '⚔️ $playerRating MM',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Match Center Emblem & Clock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF2A1C10), Color(0xFF3D2810), Color(0xFF2A1C10)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.8), width: 1.2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      roundText,
                      style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 6),
                    Container(width: 1, height: 10, color: AppColors.gold.withValues(alpha: 0.5)),
                    const SizedBox(width: 6),
                    Text(
                      timerText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              // Opponent Rating Badge
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF33161C),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6), width: 0.8),
                  ),
                  child: Text(
                    '⚔️ $opponentRating MM',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Combatants Name & Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Player Label
              Expanded(
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF60A5FA), width: 1.5),
                        color: const Color(0xFF1E3A8A),
                      ),
                      child: const Center(
                        child: Text('🛡️', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            playerName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Lv. $playerLevel Elyos',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // VS Divider
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              // Opponent Label
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            opponentName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Lv. $opponentLevel Asmodian',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFF87171), fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF87171), width: 1.5),
                        color: const Color(0xFF7F1D1D),
                      ),
                      child: const Center(
                        child: Text('⚔️', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Dual Mirrored Health Bars Row
          Row(
            children: <Widget>[
              // Player Health Bar (Left to Right)
              Expanded(
                child: _buildHealthBar(
                  hp: playerHp,
                  maxHp: playerMaxHp,
                  ratio: playerHpRatio,
                  isPlayer: true,
                  shield: playerShield,
                ),
              ),

              const SizedBox(width: 10),

              // Opponent Health Bar (Right to Left)
              Expanded(
                child: _buildHealthBar(
                  hp: opponentHp,
                  maxHp: opponentMaxHp,
                  ratio: opponentHpRatio,
                  isPlayer: false,
                  shield: 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Dual Energy / Mana Bars Row
          Row(
            children: <Widget>[
              // Player Energy
              Expanded(
                child: _buildEnergyBar(
                  current: playerEnergy,
                  max: playerMaxEnergy,
                  ratio: playerEnergyRatio,
                  color: const Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(width: 10),
              // Opponent Energy
              Expanded(
                child: _buildEnergyBar(
                  current: opponentEnergy,
                  max: opponentMaxEnergy,
                  ratio: opponentEnergyRatio,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBar({
    required int hp,
    required int maxHp,
    required double ratio,
    required bool isPlayer,
    required int shield,
  }) {
    final bool isCritical = ratio < 0.30;
    final List<Color> colors = isPlayer
        ? (isCritical
            ? <Color>[const Color(0xFFEF4444), const Color(0xFFB91C1C)]
            : <Color>[const Color(0xFF10B981), const Color(0xFF059669)])
        : (isCritical
            ? <Color>[const Color(0xFFFF1744), const Color(0xFF990000)]
            : <Color>[const Color(0xFFF59E0B), const Color(0xFFD97706)]);

    return Column(
      crossAxisAlignment: isPlayer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: <Widget>[
        // Numerical HP Readout
        Row(
          mainAxisAlignment: isPlayer ? MainAxisAlignment.spaceBetween : MainAxisAlignment.spaceBetween,
          children: <Widget>[
            if (isPlayer && shield > 0)
              Text(
                '+$shield Kalkan',
                style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 9, fontWeight: FontWeight.bold),
              )
            else
              const SizedBox.shrink(),
            Text(
              '$hp / $maxHp HP',
              style: TextStyle(
                color: isCritical ? const Color(0xFFFCA5A5) : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Bar Container
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF151926),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isCritical
                  ? const Color(0xFFEF4444)
                  : (isPlayer ? const Color(0xFF34D399) : const Color(0xFFFBBF24)).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Stack(
            children: <Widget>[
              // Health Fill
              FractionallySizedBox(
                alignment: isPlayer ? Alignment.centerLeft : Alignment.centerRight,
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(colors: colors),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: colors.first.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              // Shield Overlay (Player only)
              if (isPlayer && shield > 0)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (shield / maxHp).clamp(0.0, 0.4),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: const Color(0x6660A5FA),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 0.8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnergyBar({
    required int current,
    required int max,
    required double ratio,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 4,
            color: const Color(0xFF111420),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT 2: COMBO COUNTERS & COMBAT JUICE HUD
// ─────────────────────────────────────────────────────────────────────────────

class PvpComboFeedbackHud extends StatelessWidget {
  const PvpComboFeedbackHud({
    super.key,
    required this.comboCount,
    required this.comboTierTitle,
    required this.damageMultiplier,
    required this.lastDamageText,
    required this.isCritical,
    required this.comboProgress,
  });

  final int comboCount;
  final String comboTierTitle;
  final double damageMultiplier;
  final String lastDamageText;
  final bool isCritical;
  final double comboProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Combo Counter Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Glowing Combo Emblem
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF3B1E08), Color(0xFF78350F), Color(0xFF3B1E08)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'COMBO x$comboCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${(damageMultiplier * 100).toInt()}% Hasar',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Combo Tier Title & Decay Timer Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                comboTierTitle,
                style: const TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: comboProgress,
                    backgroundColor: const Color(0xFF261D15),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Floating Critical Strike Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCritical ? const Color(0xDD7F1D1D) : const Color(0xDD1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCritical ? const Color(0xFFEF4444) : const Color(0xFF00E5FF),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (isCritical ? const Color(0xFFEF4444) : const Color(0xFF00E5FF)).withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isCritical ? Icons.flash_on_rounded : Icons.shield_outlined,
                      color: isCritical ? AppColors.gold : const Color(0xFF00E5FF),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCritical ? 'KRİTİK DARBE!' : 'STANDART VURUŞ',
                      style: TextStyle(
                        color: isCritical ? AppColors.gold : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lastDamageText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT 3: MATCH RESULTS MODAL & VICTORY / DEFEAT BANNER
// ─────────────────────────────────────────────────────────────────────────────

class PvpMatchResultCard extends StatelessWidget {
  const PvpMatchResultCard({
    super.key,
    required this.isVictory,
    required this.playerRatingBefore,
    required this.playerRatingAfter,
    required this.goldReward,
    required this.honorReward,
    required this.lootTitle,
    required this.totalDamageDealt,
    required this.maxCombo,
    required this.battleDurationText,
    required this.onRematch,
    required this.onReturn,
  });

  final bool isVictory;
  final int playerRatingBefore;
  final int playerRatingAfter;
  final int goldReward;
  final int honorReward;
  final String lootTitle;
  final int totalDamageDealt;
  final int maxCombo;
  final String battleDurationText;
  final VoidCallback onRematch;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final int ratingDelta = playerRatingAfter - playerRatingBefore;
    final Color mainColor = isVictory ? AppColors.gold : const Color(0xFFEF4444);
    final Color accentGlow = isVictory ? const Color(0xFFF59E0B) : const Color(0xFF990000);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xF50D111D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mainColor.withValues(alpha: 0.8), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accentGlow.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header Laurel / Skull Icon
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  mainColor.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
              border: Border.all(color: mainColor, width: 2),
            ),
            child: Center(
              child: Icon(
                isVictory ? Icons.military_tech_rounded : Icons.shield_rounded,
                color: mainColor,
                size: 34,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Victory / Defeat Title
          Text(
            isVictory ? 'ŞANLI ZAFER' : 'ACIKLI YENİLGİ',
            style: TextStyle(
              color: mainColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),

          Text(
            isVictory ? 'Gladyatör Arenasında Egemenlik Kuruldu' : 'Kumlar Kanına Bulandı, İntikam Vakti Gelecek',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Rating Shift Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF161B2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262E4A), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'PvP Arenası Rating:',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Row(
                  children: <Widget>[
                    Text(
                      '$playerRatingBefore → ',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$playerRatingAfter ',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ratingDelta >= 0 ? const Color(0xFF065F46) : const Color(0xFF7F1D1D),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ratingDelta >= 0 ? '+$ratingDelta' : '$ratingDelta',
                        style: TextStyle(
                          color: ratingDelta >= 0 ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Combat Statistics Grid
          Row(
            children: <Widget>[
              Expanded(
                child: _buildStatTile('Hasar', '$totalDamageDealt', Icons.bolt_rounded, AppColors.gold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatTile('Maks Combo', 'x$maxCombo', Icons.local_fire_department_rounded, const Color(0xFFFF5722)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatTile('Süre', battleDurationText, Icons.timer_outlined, const Color(0xFF00E5FF)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Rewards Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF131826),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text('🪙 ', style: TextStyle(fontSize: 12)),
                      Flexible(
                        child: Text(
                          '+$goldReward Altın',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.goldLight, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text('🎖️ ', style: TextStyle(fontSize: 12)),
                      Flexible(
                        child: Text(
                          '+$honorReward Onur',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text('📦 ', style: TextStyle(fontSize: 12)),
                      Flexible(
                        child: Text(
                          lootTitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Action Buttons
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onReturn,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Arenaya Dön',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onRematch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isVictory ? AppColors.gold : const Color(0xFFDC2626),
                    foregroundColor: isVictory ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isVictory ? 'Tekrar Savaş' : '⚡ İntikam Al',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131826),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSITE SCREEN: INTEGRATED MOBILE PVP ARENA SCREEN
// ─────────────────────────────────────────────────────────────────────────────

Widget buildIntegratedPvpArenaScreen({
  required VoidCallback onEnterArena,
  required Future<void> Function(int wager) onQuickDuel,
}) {
  return Scaffold(
    backgroundColor: const Color(0xFF070910),
    body: SafeArea(
      child: Column(
        children: <Widget>[
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1424),
              border: Border(bottom: BorderSide(color: Color(0x33F5C842), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.shield_rounded, color: AppColors.gold, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            Text(
                              'PVP ARENA KOLOSEUMU',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                            Text(
                              'Sezon 4 · Gladyatör Kademesi',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.gold, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38BDF8), width: 0.8),
                  ),
                  child: const Text(
                    '1420 Rating',
                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Arena Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: <Widget>[
                // 3D Arena Colosseum Viewport
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    height: 320,
                    child: ArenaMapViewport(
                      currentRating: 1420,
                      onEnterArena: onEnterArena,
                    ),
                  ),
                ),

                // Matchmaking Status & Queue Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101526),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Row(
                          children: const <Widget>[
                            Icon(Icons.wifi_tethering_rounded, color: Color(0xFF34D399), size: 16),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Canlı Eşleşme Havuzu:',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '148 Gladyatör Çevrimiçi',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF065F46),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AKTİF',
                          style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Thumb Action Deck for Quick Wagering
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: PvpThumbActionDeck(
                    initialWager: 500,
                    maxGold: 10000,
                    onQuickDuel: onQuickDuel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT 4: MOCK COMBATANT OFFER TILE (FOR MATCHMAKING LADDER)
// ─────────────────────────────────────────────────────────────────────────────

class _MockCombatantOfferTile extends StatelessWidget {
  const _MockCombatantOfferTile({
    required this.username,
    required this.level,
    required this.power,
    required this.rating,
    required this.onChallenge,
  });

  final String username;
  final int level;
  final int power;
  final int rating;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101626),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E293B),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                ),
                child: const Center(
                  child: Text('⚔️', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    username,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Lv. $level · Güç $power',
                    style: const TextStyle(color: Colors.white60, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F36),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$rating MMR',
                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Meydan Oku', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTS EXECUTION
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Battalion 2: PvP Arena Mobile Golden Tests (390x844 SafeArea)', () {
    testWidgets('Golden 01: Arena Colosseum Map Viewport Framing (Portrait 390x844 SafeArea)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      bool enteredArena = false;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: SizedBox(
                height: 480,
                child: ArenaMapViewport(
                  currentRating: 1420,
                  onEnterArena: () => enteredArena = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions: Text and structure correctly framed
      expect(find.text('1420'), findsOneWidget);
      expect(find.text('Uçurum Gladyatör Arenası'), findsOneWidget);
      expect(find.text('Arenaya Gir'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);

      // Tap trigger test
      await tester.tap(find.text('Arenaya Gir'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(enteredArena, isTrue);

      // Capture Golden Screenshot
      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '01_pvp_colosseum_framing_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 02: Arena Colosseum Map Viewport Framing (Landscape 844x390)', (
      WidgetTester tester,
    ) async {
      const Size landscapeSize = Size(kMobileHeight, kMobileWidth);
      tester.view.physicalSize = landscapeSize;
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      bool enteredArena = false;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          size: landscapeSize,
          safeArea: const EdgeInsets.only(left: 47, right: 47, bottom: 21),
          child: Scaffold(
            body: SafeArea(
              child: ArenaMapViewport(
                currentRating: 1580,
                onEnterArena: () => enteredArena = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions
      expect(find.text('1580'), findsOneWidget);
      expect(find.text('ARENA MODU'), findsOneWidget);
      expect(find.text('Arenaya Gir'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap trigger test
      await tester.tap(find.text('Arenaya Gir'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(enteredArena, isTrue);

      // Capture Golden Screenshot
      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '02_pvp_colosseum_landscape_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 03: Dual Combat Health Bars & Vitals HUD (Notch SafeArea)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: const <Widget>[
                  PvpArenaCombatVitalsHud(
                    playerName: 'AionKahramanı',
                    playerLevel: 65,
                    playerHp: 24500,
                    playerMaxHp: 28000,
                    playerEnergy: 120,
                    playerMaxEnergy: 120,
                    playerShield: 3500,
                    playerRating: 1420,
                    opponentName: 'GölgeCellat',
                    opponentLevel: 68,
                    opponentHp: 7800, // Critical low HP state
                    opponentMaxHp: 30000,
                    opponentEnergy: 45,
                    opponentMaxEnergy: 120,
                    opponentRating: 1580,
                    roundText: 'RAUND 2/3',
                    timerText: '01:42',
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions: Both combatants and metrics verified
      expect(find.text('AionKahramanı'), findsOneWidget);
      expect(find.text('GölgeCellat'), findsOneWidget);
      expect(find.text('Lv. 65 Elyos'), findsOneWidget);
      expect(find.text('Lv. 68 Asmodian'), findsOneWidget);
      expect(find.text('RAUND 2/3'), findsOneWidget);
      expect(find.text('01:42'), findsOneWidget);
      expect(find.text('24500 / 28000 HP'), findsOneWidget);
      expect(find.text('7800 / 30000 HP'), findsOneWidget);
      expect(find.text('+3500 Kalkan'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Capture Golden Screenshot
      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '03_pvp_combat_health_bars_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 04: Combo Counters & Hit Feedback VFX HUD', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: PvpComboFeedbackHud(
                  comboCount: 7,
                  comboTierTitle: '⚔️ KESİNTİSİZ ASİL SALDIRI',
                  damageMultiplier: 0.25,
                  lastDamageText: '4,890 💥',
                  isCritical: true,
                  comboProgress: 0.72,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions
      expect(find.text('COMBO x7'), findsOneWidget);
      expect(find.text('+25% Hasar'), findsOneWidget);
      expect(find.text('⚔️ KESİNTİSİZ ASİL SALDIRI'), findsOneWidget);
      expect(find.text('KRİTİK DARBE!'), findsOneWidget);
      expect(find.text('4,890 💥'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Capture Golden Screenshot
      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '04_pvp_combo_counter_vfx_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 05: Match Result Screen — Glorious Victory State', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      bool rematchTapped = false;
      bool returnTapped = false;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: PvpMatchResultCard(
                  isVictory: true,
                  playerRatingBefore: 1420,
                  playerRatingAfter: 1452,
                  goldReward: 1500,
                  honorReward: 250,
                  lootTitle: 'Antik Sandık',
                  totalDamageDealt: 68420,
                  maxCombo: 9,
                  battleDurationText: '01:18',
                  onRematch: () => rematchTapped = true,
                  onReturn: () => returnTapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions
      expect(find.text('ŞANLI ZAFER'), findsOneWidget);
      expect(find.text('1420 → '), findsOneWidget);
      expect(find.text('1452 '), findsOneWidget);
      expect(find.text('+32'), findsOneWidget);
      expect(find.text('+1500 Altın'), findsOneWidget);
      expect(find.text('+250 Onur'), findsOneWidget);
      expect(find.text('68420'), findsOneWidget);
      expect(find.text('x9'), findsOneWidget);
      expect(find.text('Tekrar Savaş'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap buttons
      await tester.tap(find.text('Tekrar Savaş'));
      await tester.pump(const Duration(milliseconds: 30));
      expect(rematchTapped, isTrue);

      await tester.tap(find.text('Arenaya Dön'));
      await tester.pump(const Duration(milliseconds: 30));
      expect(returnTapped, isTrue);

      // Capture Golden Screenshot
      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '05_pvp_match_result_victory_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 06: Match Result Screen — Defeat & Revenge State', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      bool revengeTapped = false;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: PvpMatchResultCard(
                  isVictory: false,
                  playerRatingBefore: 1420,
                  playerRatingAfter: 1404,
                  goldReward: 300,
                  honorReward: 50,
                  lootTitle: 'Teselli Sandığı',
                  totalDamageDealt: 42100,
                  maxCombo: 4,
                  battleDurationText: '01:52',
                  onRematch: () => revengeTapped = true,
                  onReturn: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions
      expect(find.text('ACIKLI YENİLGİ'), findsOneWidget);
      expect(find.text('1420 → '), findsOneWidget);
      expect(find.text('1404 '), findsOneWidget);
      expect(find.text('-16'), findsOneWidget);
      expect(find.text('⚡ İntikam Al'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap revenge
      await tester.tap(find.text('⚡ İntikam Al'));
      await tester.pump(const Duration(milliseconds: 30));
      expect(revengeTapped, isTrue);

      // Capture Golden Screenshot
      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '06_pvp_match_result_defeat_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 07: PvpThumbActionDeck Mobile Wagering & Control Dock', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      int selectedWager = 0;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  PvpThumbActionDeck(
                    initialWager: 500,
                    maxGold: 5000,
                    onQuickDuel: (int wager) async {
                      selectedWager = wager;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions
      expect(find.text('BAHİS MİKTARI'), findsOneWidget);
      expect(find.text('500 🪙 Altın'), findsOneWidget);

      // Change wager to +1000 chip preset
      await tester.tap(find.text('+1000'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('1000 🪙 Altın'), findsOneWidget);

      // Trigger duel
      await tester.tap(find.text('⚡ BAHİSLİ DÜELLO BAŞLAT'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(selectedWager, 1000);
      expect(tester.takeException(), isNull);

      // Capture Golden Screenshot
      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '07_pvp_thumb_action_deck_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 08: Integrated Mobile PvP Arena Screen (390x844 Full Flow)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      bool enteredArena = false;
      int quickDuelWager = 0;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildIntegratedPvpArenaScreen(
            onEnterArena: () => enteredArena = true,
            onQuickDuel: (int w) async {
              quickDuelWager = w;
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions: Header, Colosseum, Queue card, Thumb deck all render without overflow
      expect(find.text('PVP ARENA KOLOSEUMU'), findsOneWidget);
      expect(find.text('1420 Rating'), findsOneWidget);
      expect(find.text('1420'), findsOneWidget);
      expect(find.text('148 Gladyatör Çevrimiçi'), findsOneWidget);
      expect(find.text('Arenaya Gir'), findsOneWidget);
      expect(find.text('⚡ BAHİSLİ DÜELLO BAŞLAT'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap Arenaya Gir
      await tester.tap(find.text('Arenaya Gir'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(enteredArena, isTrue);

      // Tap Duel
      await tester.tap(find.text('⚡ BAHİSLİ DÜELLO BAŞLAT'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(quickDuelWager, 500);

      // Capture Golden Screenshot
      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '08_pvp_arena_composite_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 09: Mock Combatants — Clashing Versus Splash Banner (Challenger vs Defender)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      bool clashTriggered = false;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: PvpVersusSplashBanner(
                  challengerName: 'Kahraman Elyos',
                  challengerRating: 1420,
                  challengerPower: 12500,
                  challengerLevel: 65,
                  defenderName: 'Gölge Cellat',
                  defenderRating: 1580,
                  defenderPower: 13200,
                  defenderLevel: 68,
                  arenaTitle: 'Uçurum Gladyatör Koloseumu',
                  wager: 500,
                  compact: false,
                  enableShake: false,
                  enableImpactFlash: false,
                  onClashImpact: () => clashTriggered = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions: Combatants framing, names, stats, levels, and arena title
      expect(find.text('Kahraman Elyos'), findsOneWidget);
      expect(find.text('Gölge Cellat'), findsOneWidget);
      expect(find.text('Lv. 65'), findsWidgets);
      expect(find.text('Lv. 68'), findsWidgets);
      expect(find.text('1420'), findsWidgets);
      expect(find.text('1580'), findsWidgets);
      expect(find.text('Uçurum Gladyatör Koloseumu'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '09_pvp_combatants_versus_banner_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 10: Mock Combatants — Nemesis Rival Tracking & Revenge Action', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      String? challengedRivalId;
      bool dismissed = false;

      const NemesisRival mockRival = NemesisRival(
        hasRival: true,
        rivalId: 'rival_asmodian_42',
        rivalUsername: 'GölgeHükümdar',
        losses: 4,
        wins: 1,
        online: true,
        level: 68,
        power: 13500,
        pvpRating: 1610,
        leaderboardGap: 190,
      );

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: NemesisRivalPanel(
                  rival: mockRival,
                  onRevenge: (String rivalId) => challengedRivalId = rivalId,
                  onDismiss: () => dismissed = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions: Nemesis badge, online indicator, rival username, battle record
      expect(find.text('NEMESIS'), findsOneWidget);
      expect(find.text('Çevrimiçi'), findsOneWidget);
      expect(find.text('GölgeHükümdar'), findsOneWidget);
      expect(find.text('4 yenilgi · 1 galibiyet · Lv 68'), findsOneWidget);
      expect(find.text('Sıralama farkı: 190 güç'), findsOneWidget);
      expect(find.text('Düello Gönder'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap Revenge Action
      await tester.tap(find.text('Düello Gönder'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(challengedRivalId, 'rival_asmodian_42');

      // Tap Dismiss Icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(dismissed, isTrue);

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '10_pvp_nemesis_rival_combatant_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 11: Mock Ranking Ladders — Gladiator Tier Progression Card (MMR Ladder & Win Rate)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      bool leaderboardTapped = false;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GladiatorTierProgressCard(
                  rating: 1420,
                  pvpWins: 45,
                  pvpLosses: 15,
                  onViewLeaderboard: () => leaderboardTapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions: Tier short code, tier title, MMR readout, win rate record, progress bar
      expect(find.text('GOLD'), findsOneWidget);
      expect(find.text('Altın Gladyatör'), findsOneWidget);
      expect(find.text('1420 MMR'), findsOneWidget);
      expect(find.text('· Kazanma: %75.0 (45 G / 15 M)'), findsOneWidget);
      expect(find.text('Sonraki Aşama: +80 MMR'), findsOneWidget);
      expect(find.byType(GladiatorTierEmblem), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap Leaderboard Button
      await tester.tap(find.byIcon(Icons.leaderboard_rounded));
      await tester.pump(const Duration(milliseconds: 50));
      expect(leaderboardTapped, isTrue);

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '11_pvp_ranking_ladder_tier_progress_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 12: Mock Ranking Ladders — Full 7-Tier Ranking Ladder Grid (Bronze to Grandmaster)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: <Widget>[
                    const Text(
                      'PVP RÜTBE VE KADEME MERDİVENİ',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 1.35,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: const <Widget>[
                          GladiatorTierEmblem(
                            tier: GladiatorTier.bronze,
                            size: 48,
                            showLabel: true,
                            showGlow: true,
                            animated: false,
                          ),
                          GladiatorTierEmblem(
                            tier: GladiatorTier.silver,
                            size: 48,
                            showLabel: true,
                            showGlow: true,
                            animated: false,
                          ),
                          GladiatorTierEmblem(
                            tier: GladiatorTier.gold,
                            size: 48,
                            showLabel: true,
                            showGlow: true,
                            animated: false,
                          ),
                          GladiatorTierEmblem(
                            tier: GladiatorTier.platinum,
                            size: 48,
                            showLabel: true,
                            showGlow: true,
                            animated: false,
                          ),
                          GladiatorTierEmblem(
                            tier: GladiatorTier.diamond,
                            size: 48,
                            showLabel: true,
                            showGlow: true,
                            animated: false,
                          ),
                          GladiatorTierEmblem(
                            tier: GladiatorTier.master,
                            size: 48,
                            showLabel: true,
                            showGlow: true,
                            animated: false,
                          ),
                          GladiatorTierEmblem(
                            tier: GladiatorTier.grandmaster,
                            size: 48,
                            showLabel: true,
                            showGlow: true,
                            animated: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions: All 7 tier shortcodes and titles present on the ladder
      expect(find.text('BRONZE'), findsOneWidget);
      expect(find.text('SILVER'), findsOneWidget);
      expect(find.text('GOLD'), findsOneWidget);
      expect(find.text('PLATINUM'), findsOneWidget);
      expect(find.text('DIAMOND'), findsOneWidget);
      expect(find.text('MASTER'), findsOneWidget);
      expect(find.text('GRANDMASTER'), findsOneWidget);
      expect(find.text('PVP RÜTBE VE KADEME MERDİVENİ'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '12_pvp_ranking_ladder_emblems_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 13: Mock Battle Scene — Colosseum Atmospheric Backdrops across Mood Themes', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: PvpColosseumBackdrop(
                mood: ColosseumThemeMood.abyssCrimson,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: const <Widget>[
                      ColosseumCardIllustration(
                        title: 'Uçurum Gladyatör Koloseumu',
                        subtitle: 'Kaos ve kan arenasının alevi · Abis Çöküşü',
                        mood: ColosseumThemeMood.abyssCrimson,
                        height: 90,
                      ),
                      SizedBox(height: 10),
                      ColosseumCardIllustration(
                        title: 'Sanctum Göksel Mabedi',
                        subtitle: 'Kutsal ışık süzmeleri ve altın kemerler',
                        mood: ColosseumThemeMood.sanctumGold,
                        height: 90,
                      ),
                      SizedBox(height: 10),
                      ColosseumCardIllustration(
                        title: 'Obsidiyen Çukur',
                        subtitle: 'Mavi plazma ve aether çatlakları',
                        mood: ColosseumThemeMood.obsidianCyan,
                        height: 90,
                      ),
                      SizedBox(height: 10),
                      ColosseumCardIllustration(
                        title: 'Tutulma Koloseumu',
                        subtitle: 'Mor efsun dumanları ve antik sütunlar',
                        mood: ColosseumThemeMood.eclipseViolet,
                        height: 90,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions: Colosseum illustration cards and mood architectures
      expect(find.text('Uçurum Gladyatör Koloseumu'), findsOneWidget);
      expect(find.text('Sanctum Göksel Mabedi'), findsOneWidget);
      expect(find.text('Obsidiyen Çukur'), findsOneWidget);
      expect(find.text('Tutulma Koloseumu'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '13_pvp_colosseum_battle_scene_backdrop_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 14: Mock Battle Scene — Multi-Arena Environmental Hazards & Gladiator Stances', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 380,
                  child: ArenaMapViewport(
                    currentRating: 1750,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions: 1750 Rating, hazard title, stance touch control
      expect(find.text('1750'), findsOneWidget);
      expect(find.text('Abis Çöküşü: +15% Kaos & Gölge Hasarı'), findsOneWidget);
      expect(find.text('Duruş'), findsOneWidget);

      // Tap on stance to cycle stance
      await tester.tap(find.text('Duruş'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Saldırı!'), findsOneWidget);

      // Tap on canvas center to spawn shockwave & ground decal strike
      await tester.tapAt(const Offset(kMobileWidth * 0.5, 180));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '14_pvp_arena_battle_scene_hazards_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });

    testWidgets('Golden 15: Mock Combatants & Matchmaking Ladder Full Screen (Authentic Multi-Combatant Layout)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      String? challengedCombatant;

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: Scaffold(
            backgroundColor: const Color(0xFF070910),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                children: <Widget>[
                  // 1. Header with Arena rating
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1424),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x33F5C842), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const <Widget>[
                        Text(
                          'PVP ARENA MEYDAN OKUMALARI',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '1420 MMR',
                          style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 2. Gladiator Tier Ladder Card
                  GladiatorTierProgressCard(
                    rating: 1420,
                    pvpWins: 45,
                    pvpLosses: 15,
                  ),

                  const SizedBox(height: 10),

                  // 3. Mock Online Combatants Ladder List
                  const Text(
                    'Çevrimiçi Gladyatörler (Meydan Okuma Merdiveni)',
                    style: TextStyle(color: AppColors.goldLight, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),

                  _MockCombatantOfferTile(
                    username: 'GölgeAvcısı',
                    level: 62,
                    power: 11800,
                    rating: 1380,
                    onChallenge: () => challengedCombatant = 'GölgeAvcısı',
                  ),
                  _MockCombatantOfferTile(
                    username: 'Astraeus',
                    level: 65,
                    power: 12500,
                    rating: 1420,
                    onChallenge: () => challengedCombatant = 'Astraeus',
                  ),
                  _MockCombatantOfferTile(
                    username: 'KaranlıkLord',
                    level: 70,
                    power: 14200,
                    rating: 1640,
                    onChallenge: () => challengedCombatant = 'KaranlıkLord',
                  ),

                  const SizedBox(height: 10),

                  // 4. Thumb Action Deck
                  PvpThumbActionDeck(
                    initialWager: 500,
                    maxGold: 10000,
                    onQuickDuel: (int wager) async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Assertions: Multi-combatant ladder items
      expect(find.text('PVP ARENA MEYDAN OKUMALARI'), findsOneWidget);
      expect(find.text('GölgeAvcısı'), findsOneWidget);
      expect(find.text('Astraeus'), findsOneWidget);
      expect(find.text('KaranlıkLord'), findsOneWidget);
      expect(find.text('1380 MMR'), findsOneWidget);
      expect(find.text('1420 MMR'), findsWidgets);
      expect(find.text('1640 MMR'), findsOneWidget);
      expect(find.text('Meydan Oku'), findsNWidgets(3));
      expect(tester.takeException(), isNull);

      // Tap challenge Astraeus
      await tester.tap(find.text('Meydan Oku').at(1));
      await tester.pump(const Duration(milliseconds: 50));
      expect(challengedCombatant, 'Astraeus');

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '15_pvp_combatants_matchmaking_ladder_mobile.png',
      );
      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(1000));
    });
  });
}
