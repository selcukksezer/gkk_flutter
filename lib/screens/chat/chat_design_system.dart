import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Chat-specific colors, spacing, shadows, and gradients.
class ChatDesignSystem {
  ChatDesignSystem._();

  static const Color colorGlobalAccent = Color(0xFF38BDF8);
  static const Color colorGuildAccent = Color(0xFFF97316);
  static const Color colorTradeAccent = Color(0xFFFCCC15);
  static const Color colorDmAccent = AppColors.cyberFuchsia;

  static const Color colorSuccess = Color(0xFF10B981);
  static const Color colorError = Color(0xFFF87171);
  static const Color colorWarning = Color(0xFFFB923C);
  static const Color colorInfo = Color(0xFF0EA5E9);

  static const Color colorOnline = Color(0xFF00FF66);
  static const Color colorOffline = Color(0xFF8E9CAE);

  static const Color colorBgSecondary = Color(0xFF090D15);

  static const Color colorTextPrimary = Colors.white;
  static const Color colorTextSecondary = Color(0xFFE2E8F0);
  static const Color colorTextTertiary = Color(0xFF94A3B8);

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusRound = 999;

  static const Duration durationBase = Duration(milliseconds: 200);
  static const Curve curveEaseInOut = Curves.easeInOutCubic;

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const LinearGradient gradientBgPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF141B26), Color(0xFF090D15)],
  );

  static const LinearGradient gradientGlobal = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0x1F38BDF8), Color(0x0638BDF8)],
  );

  static const LinearGradient gradientGuild = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0x1FF97316), Color(0x06F97316)],
  );

  static const LinearGradient gradientTrade = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0x1FFCCC15), Color(0x06FCCC15)],
  );

  static const LinearGradient gradientDm = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0x1EE01E5A), Color(0x06E01E5A)],
  );
}
