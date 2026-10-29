import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'horse_race_provider.dart';

const List<Color> horseRaceLaneFallbacks = <Color>[
  AppColors.gold,
  AppColors.accentCyan,
  AppColors.accentPurple,
  AppColors.success,
  AppColors.danger,
  AppColors.accentBlue,
];

Color parseHorseLaneColor(String raw, {required String horseId}) {
  final String hex = raw.replaceAll('#', '').trim();
  if (hex.length == 6) {
    final int? value = int.tryParse('FF$hex', radix: 16);
    if (value != null) return Color(value);
  }
  if (hex.length == 8) {
    final int? value = int.tryParse(hex, radix: 16);
    if (value != null) return Color(value);
  }

  if (kDebugMode && hex.isNotEmpty) {
    debugPrint('horse_race: invalid lane_color "$raw" for $horseId');
  }

  final int bucket = horseId.hashCode.abs() % horseRaceLaneFallbacks.length;
  return horseRaceLaneFallbacks[bucket];
}

String compactHorseAmount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String formatHorseGems(num value) {
  final double v = value.toDouble();
  final double abs = v.abs();
  if (abs >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (abs >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

String formatHorsePayout(HorseRaceBet bet) {
  if (bet.currencyType == 'gems') {
    return formatHorseGems(bet.payoutAmount);
  }
  return compactHorseAmount(bet.payoutAmount.round());
}

String horseCurrencyLabel(String currencyType) {
  return currencyType == 'gems' ? 'Elmas' : 'Altın';
}

String formatHorseCountdown(int seconds) {
  final int m = seconds ~/ 60;
  final int s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String horsePhaseLabel(HorseRacePhase phase) {
  return switch (phase) {
    HorseRacePhase.betting => 'Bahis açık',
    HorseRacePhase.locked => 'Kilit',
    HorseRacePhase.racing => 'Canlı',
    HorseRacePhase.finished => 'Sonuç',
    HorseRacePhase.unknown => '',
  };
}

double horseGridMainAxisExtent({
  required double viewportWidth,
  required int crossAxisCount,
  required double spacing,
  required double aspectRatio,
  double minCellHeight = 0,
}) {
  if (crossAxisCount <= 0) return minCellHeight;
  final double cellWidth =
      (viewportWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
  return math.max(cellWidth / aspectRatio, minCellHeight);
}

/// Strict digits-only bet amount validation.
class HorseBetAmountValidation {
  const HorseBetAmountValidation._({
    required this.isValid,
    this.amount,
    this.message,
  });

  const HorseBetAmountValidation.valid(int amount)
    : this._(isValid: true, amount: amount);

  const HorseBetAmountValidation.invalid(String message)
    : this._(isValid: false, message: message);

  final bool isValid;
  final int? amount;
  final String? message;
}

String sanitizeHorseBetDigits(String raw) =>
    raw.replaceAll(RegExp(r'[^0-9]'), '');

HorseBetAmountValidation validateHorseBetAmount(
  String raw, {
  required int min,
  required int max,
}) {
  final String digits = sanitizeHorseBetDigits(raw);
  if (digits.isEmpty) {
    return const HorseBetAmountValidation.invalid('Bahis miktarı gir');
  }
  final int? parsed = int.tryParse(digits);
  if (parsed == null || parsed <= 0) {
    return const HorseBetAmountValidation.invalid('Sadece rakam kullan');
  }
  if (parsed < min) {
    return HorseBetAmountValidation.invalid('En az $min olmalı');
  }
  if (parsed > max) {
    return HorseBetAmountValidation.invalid('En fazla $max olabilir');
  }
  return HorseBetAmountValidation.valid(parsed);
}

int horseBetMaxInputLength(int maxBet) => math.max(maxBet.toString().length, 1);

/// Data point representing a historical position for motion trail rendering.
class HorseSprintTrailPoint {
  const HorseSprintTrailPoint({
    required this.position,
    required this.progress,
    required this.color,
    this.speed = 1.0,
    this.opacity = 1.0,
    this.width = 4.0,
  });

  final Offset position;
  final double progress;
  final Color color;
  final double speed;
  final double opacity;
  final double width;
}

/// Motion trail and path math utilities for horse race sprites.
abstract final class HorseMotionTrailUtils {
  /// Builds a smooth ribbon path from a series of trailing points.
  static Path createRibbonPath({
    required List<Offset> points,
    required double startWidth,
    required double endWidth,
  }) {
    final Path path = Path();
    if (points.length < 2) return path;

    final List<Offset> leftPoints = <Offset>[];
    final List<Offset> rightPoints = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final double fraction = i / (points.length - 1);
      final double w = startWidth + (endWidth - startWidth) * fraction;

      // Normal vector based on adjacent points
      Offset tangent;
      if (i == 0) {
        tangent = points[1] - points[0];
      } else if (i == points.length - 1) {
        tangent = points[points.length - 1] - points[points.length - 2];
      } else {
        tangent = points[i + 1] - points[i - 1];
      }

      final double len = tangent.distance;
      final Offset normal = len > 0.0001
          ? Offset(-tangent.dy / len, tangent.dx / len)
          : const Offset(1, 0);

      leftPoints.add(points[i] + normal * (w * 0.5));
      rightPoints.add(points[i] - normal * (w * 0.5));
    }

    path.moveTo(leftPoints.first.dx, leftPoints.first.dy);
    for (int i = 1; i < leftPoints.length; i++) {
      path.lineTo(leftPoints[i].dx, leftPoints[i].dy);
    }
    for (int i = rightPoints.length - 1; i >= 0; i--) {
      path.lineTo(rightPoints[i].dx, rightPoints[i].dy);
    }
    path.close();
    return path;
  }
}

/// Computes instantaneous forward speed (dPos / dt) of [horseId] at [progress].
double computeHorseVelocity({
  required HorseRaceScript script,
  required String horseId,
  required double progress,
  double sampleDelta = 0.02,
}) {
  return script.velocityAt(horseId, progress, sampleDelta: sampleDelta);
}

/// Computes instantaneous acceleration of [horseId] at [progress].
double computeHorseAcceleration({
  required HorseRaceScript script,
  required String horseId,
  required double progress,
  double sampleDelta = 0.03,
}) {
  return script.accelerationAt(horseId, progress, sampleDelta: sampleDelta);
}

/// Computes the climax surge factor (0.0 to 1.0) along the final stretch (>= 0.72).
double computeClimaxSurgeFactor(double progress) {
  if (progress < 0.72) return 0.0;
  final double t = ((progress - 0.72) / 0.28).clamp(0.0, 1.0);
  return math.pow(t, 2.0).toDouble();
}

/// Computes high-frequency directional camera shake for race climax.
Offset computeCameraShakeOffset({
  required double progress,
  required double timeSeconds,
  double maxIntensity = 6.0,
  bool isClimax = false,
}) {
  final double surge = computeClimaxSurgeFactor(progress);
  final double intensity = (isClimax ? 1.0 : surge) * maxIntensity;
  if (intensity <= 0.01) return Offset.zero;

  // Multi-frequency harmonic perturbation
  const double f1 = 31.0;
  const double f2 = 53.0;
  const double f3 = 23.0;

  final double dx =
      (math.sin(timeSeconds * f1) * 0.65 + math.cos(timeSeconds * f2) * 0.35) *
      intensity;
  final double dy =
      (math.cos(timeSeconds * f1 * 1.25) * 0.7 +
          math.sin(timeSeconds * f3) * 0.3) *
      (intensity * 0.6);

  return Offset(dx, dy);
}

/// Computes the dynamic camera surge scale on race climax (e.g. 1.0 -> 1.04).
double computeClimaxCameraSurgeScale({
  required double progress,
  double baseScale = 1.0,
  double peakSurge = 1.04,
}) {
  final double surge = computeClimaxSurgeFactor(progress);
  return baseScale + (peakSurge - baseScale) * math.sin(surge * math.pi * 0.5);
}

/// Sprint acceleration tier classification for dynamic HUD indicators.
enum HorseSprintAccelerationTier {
  cruising('SÜRÜŞ', AppColors.mutedTitanium, 1),
  accelerating('HIZLANMA', AppColors.accentCyan, 2),
  sprinting('SPRİNT', AppColors.liquidGold, 3),
  climaxSurge('SON SURGE', AppColors.cyberFuchsia, 4);

  const HorseSprintAccelerationTier(this.label, this.color, this.chevrons);

  final String label;
  final Color color;
  final int chevrons;

  static HorseSprintAccelerationTier fromSpeedAndProgress({
    required double speed,
    required double progress,
    bool isLeader = false,
  }) {
    if (progress >= 0.85 && (speed >= 1.15 || isLeader)) {
      return HorseSprintAccelerationTier.climaxSurge;
    }
    if (speed >= 1.20) {
      return HorseSprintAccelerationTier.sprinting;
    }
    if (speed >= 1.05) {
      return HorseSprintAccelerationTier.accelerating;
    }
    return HorseSprintAccelerationTier.cruising;
  }
}
