import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Named typography scale for the GKK design system.
///
/// All inline `TextStyle(fontSize: ..., fontWeight: ...)` literals should be
/// replaced with references from this class (optionally `.copyWith(color: ...)`).
abstract final class AppTextStyles {
  static TextStyle _urbanist({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.urbanist(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: TextDecoration.none,
      decorationThickness: 0,
    );
  }

  // ──────────────────────────── Display ────────────────────────────────────

  static final TextStyle display = _urbanist(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  // ──────────────────────────── Headlines ──────────────────────────────────

  static final TextStyle h1 = _urbanist(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static final TextStyle h2 = _urbanist(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static final TextStyle h3 = _urbanist(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ──────────────────────────── Titles ─────────────────────────────────────

  static final TextStyle title = _urbanist(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static final TextStyle titleBold = _urbanist(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ──────────────────────────── Body ───────────────────────────────────────

  static final TextStyle body = _urbanist(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static final TextStyle bodyBold = _urbanist(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // ──────────────────────────── Captions ───────────────────────────────────

  static final TextStyle caption = _urbanist(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static final TextStyle captionBold = _urbanist(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ──────────────────────────── Labels / Micro ─────────────────────────────

  /// Navigation labels, micro badges
  static final TextStyle label = _urbanist(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.textSecondary,
    height: 1.2,
  );

  /// Smallest text — chip labels, section headers
  static final TextStyle micro = _urbanist(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: AppColors.textTertiary,
    height: 1.2,
  );

  // ──────────────────────────── Dialogs ────────────────────────────────────

  static final TextStyle dialogTitle = _urbanist(
    fontSize: 17,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static final TextStyle dialogBody = _urbanist(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedTitanium,
    height: 1.45,
  );

  static final TextStyle dialogButton = _urbanist(
    fontSize: 13,
    fontWeight: FontWeight.w900,
    color: AppColors.carbonVoid,
    height: 1.2,
  );

  static final TextStyle dialogButtonMuted = _urbanist(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: AppColors.mutedTitanium,
    height: 1.2,
  );
}
