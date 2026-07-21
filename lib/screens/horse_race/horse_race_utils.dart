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
