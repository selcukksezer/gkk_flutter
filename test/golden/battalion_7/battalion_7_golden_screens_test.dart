import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// BATTALION 7: ONBOARDING, HUD, SETTINGS & DAILY REWARDS GOLDEN SUITE
/// Mobile Viewport Specifications (iPhone 14 / Standard Modern Mobile):
/// 390x844, DevicePixelRatio 2.0 (780x1688 High-DPI Output), Authentic SafeArea.
/// ─────────────────────────────────────────────────────────────────────────────

const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 2.0;
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

const String kOutputDir = 'test/golden/battalion_7/goldens';
const String kReportDir = 'reports/screenshots/mobile_goldens/battalion_7';

/// Utility to capture rendered widget to high-resolution PNG file on disk.
Future<File> captureWidgetToPng({
  required WidgetTester tester,
  required GlobalKey repaintKey,
  required String filename,
}) async {
  for (final String path in <String>[kOutputDir, kReportDir]) {
    final Directory dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  File? savedFile;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image =
        await boundary.toImage(pixelRatio: kDevicePixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode image to PNG for $filename');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();

    // Primary test golden output
    final File primary = File('$kOutputDir/$filename');
    await primary.writeAsBytes(pngBytes, flush: true);

    // Secondary report artifact copy
    final File reportCopy = File('$kReportDir/$filename');
    await reportCopy.writeAsBytes(pngBytes, flush: true);

    savedFile = primary;
  });

  return savedFile!;
}

/// Mobile Test Harness enforcing 390x844 viewport, DPR 2.0, and authentic SafeArea.
Widget buildMobileTestHarness({
  required GlobalKey repaintKey,
  required Widget child,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF07090E),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: Color(0xFF00E5FF),
        surface: Color(0xFF0F1523),
      ),
    ),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(kMobileWidth, kMobileHeight),
        devicePixelRatio: kDevicePixelRatio,
        padding: kMobileSafeArea,
        viewPadding: kMobileSafeArea,
      ),
      child: RepaintBoundary(
        key: repaintKey,
        child: SizedBox(
          width: kMobileWidth,
          height: kMobileHeight,
          child: child,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 1: AUTH LOGIN PORTAL SCREEN (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildAuthLoginPortalScreen() {
  return Scaffold(
    backgroundColor: const Color(0xFF07090E),
    body: Stack(
      children: <Widget>[
        // Atmospheric Night Sky Gradient with Celestial Nebulae
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xFF050B16),
                Color(0xFF0A1224),
                Color(0xFF060913),
              ],
            ),
          ),
        ),
        // Radial Celestial Glow Auras
        Positioned(
          top: -60,
          left: -40,
          child: Container(
            width: 320,
            height: 320,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[Color(0x3500E5FF), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          top: 140,
          right: -50,
          child: Container(
            width: 280,
            height: 280,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[Color(0x2EF5C842), Colors.transparent],
              ),
            ),
          ),
        ),
        // Floating Ember / Rune Particles
        Positioned.fill(
          child: CustomPaint(
            painter: _RunicEmbersPainter(),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 16),
                // Game Logo & Cinematic Title
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: <Color>[Color(0xFFF5C842), Color(0xFF8B5CF6)],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFFF5C842).withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFF5C842),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'AION : LEGION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '2027 NEXT-GEN MOBILE MMORPG',
                      style: TextStyle(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.85),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Glassmorphism Portal Auth Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Portal Tabs: [Giriş Yap] [Yeni Kayıt]
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF070B14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0x33FFFFFF),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: <Color>[
                                      Color(0xFFF5C842),
                                      Color(0xFFD97706),
                                    ],
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: const Color(0xFFF5C842)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Giriş Yap',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: const Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Yeni Kayıt',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // E-posta Input Field
                      _buildAuthInputField(
                        label: 'E-POSTA ADRESİ',
                        icon: Icons.alternate_email_rounded,
                        initialText: 'commander@aion2.mobile',
                      ),
                      const SizedBox(height: 12),

                      // Şifre Input Field
                      _buildAuthInputField(
                        label: 'KULLANICI ŞİFRESİ',
                        icon: Icons.lock_outline_rounded,
                        initialText: '••••••••••••',
                        isPassword: true,
                      ),
                      const SizedBox(height: 8),

                      // Forgot password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Şifremi Unuttum?',
                          style: TextStyle(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.85),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Primary Login CTA Button
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFF00E5FF),
                              Color(0xFF2563EB),
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.bolt_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'AION EVRENİNE BAĞLAN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Guest Login CTA
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF131C2E).withValues(alpha: 0.7),
                    border: Border.all(
                      color: const Color(0xFFF5C842).withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.play_circle_fill_rounded,
                                color: Color(0xFFF5C842), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Hızlı Misafir Girişi (Hesapsız)',
                              style: TextStyle(
                                color: Color(0xFFF5C842),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Social SSO Options
                const Row(
                  children: <Widget>[
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'VEYA SOSYAL HESAP İLE',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _buildSocialPill(
                        icon: Icons.apple_rounded,
                        label: 'Apple ID',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSocialPill(
                        icon: Icons.g_mobiledata_rounded,
                        label: 'Google Play',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildAuthInputField({
  required String label,
  required IconData icon,
  required String initialText,
  bool isPassword = false,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF090D18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF1E293B),
            width: 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: const Color(0xFF00E5FF), size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                initialText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isPassword)
              const Icon(
                Icons.visibility_off_rounded,
                color: Colors.white38,
                size: 16,
              ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildSocialPill({required IconData icon, required String label}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFF0F172A).withValues(alpha: 0.6),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 2: CHARACTER SELECTION PREVIEW SCREEN (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildCharacterSelectionPreviewScreen() {
  return Scaffold(
    backgroundColor: const Color(0xFF07080B),
    body: Stack(
      children: <Widget>[
        // Deep Elemental Void Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.2,
              colors: <Color>[
                Color(0x35D97706),
                Color(0xFF120E18),
                Color(0xFF07080B),
              ],
              stops: <double>[0.0, 0.6, 1.0],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              // Header & Slot Indicator
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'KARAKTER SEÇİMİ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Aion-2 Archdaeva Çağı · Slot 1/4',
                              style: TextStyle(
                                color: Color(0xFFF5C842),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x33F5C842),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF5C842)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.shield_outlined,
                              size: 12, color: Color(0xFFF5C842)),
                          SizedBox(width: 4),
                          Text('LVL 45',
                              style: TextStyle(
                                  color: Color(0xFFF5C842),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Class Slot Carousel Bar
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: <Widget>[
                    _buildClassPill(
                      title: 'SAVAŞÇI',
                      icon: Icons.shield_rounded,
                      color: const Color(0xFFF5C842),
                      selected: true,
                    ),
                    const SizedBox(width: 8),
                    _buildClassPill(
                      title: 'SİMYACI',
                      icon: Icons.auto_awesome_rounded,
                      color: const Color(0xFF00E5FF),
                      selected: false,
                    ),
                    const SizedBox(width: 8),
                    _buildClassPill(
                      title: 'GÖLGE',
                      icon: Icons.gps_fixed_rounded,
                      color: const Color(0xFFB388FF),
                      selected: false,
                    ),
                  ],
                ),
              ),

              // 3D Turntable Character Stage & Elemental Aura
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Celestial Rune Circle
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              const Color(0xFFF5C842).withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: CustomPaint(
                        painter: _RunicPedestalPainter(),
                      ),
                    ),
                    // Character Silhouette / 3D Avatar Centerpiece
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 120,
                          height: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0xFFF5C842),
                                Color(0xFFB45309),
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFFF5C842)
                                    .withValues(alpha: 0.4),
                                blurRadius: 24,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person_rounded,
                              size: 100,
                              color: Color(0xFF1E1405),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFF5C842)
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          child: const Text(
                            'ATEŞ & TOPRAK AURA AKTİF',
                            style: TextStyle(
                              color: Color(0xFFF5C842),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Combat Stats & Trait Summary Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF0F1420).withValues(alpha: 0.85),
                  border: Border.all(
                    color: const Color(0xFFF5C842).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Öncü Muhafız (Frontline Dominator)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'STR / DEF / AGG',
                          style: TextStyle(
                            color: Color(0xFFF5C842),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStatBar(
                        label: 'Saldırı Gücü', value: 0.85, color: const Color(0xFFEF4444)),
                    const SizedBox(height: 5),
                    _buildStatBar(
                        label: 'Zırh Savunması',
                        value: 0.92,
                        color: const Color(0xFFF5C842)),
                    const SizedBox(height: 5),
                    _buildStatBar(
                        label: 'Can Havuzu', value: 0.95, color: const Color(0xFF10B981)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Action CTA: Karakteri Seç & Başla
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFFF5C842), Color(0xFFD97706)],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFFF5C842).withValues(alpha: 0.4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'BU KARAKTERLE SAVAŞA BAŞLA',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildClassPill({
  required String title,
  required IconData icon,
  required Color color,
  required bool selected,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: selected ? color.withValues(alpha: 0.22) : const Color(0xFF0F172A),
      border: Border.all(
        color: selected ? color : Colors.white12,
        width: selected ? 1.5 : 0.8,
      ),
    ),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 15, color: selected ? color : Colors.white54),
        const SizedBox(width: 5),
        Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget _buildStatBar({
  required String label,
  required double value,
  required Color color,
}) {
  return Row(
    children: <Widget>[
      SizedBox(
        width: 85,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 6,
            color: Colors.white12,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(color: color),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '${(value * 100).toInt()}%',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 3: GRAPHICS QUALITY SETTINGS SCREEN (ECO/LOW/MED/HIGH/ULTRA) (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildGraphicsQualitySettingsScreen() {
  return Scaffold(
    backgroundColor: const Color(0xFF07090E),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: <Widget>[
          // Screen Title Header
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFF00E5FF)),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFF00E5FF), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'GRAFİK VE GÖRSEL MOTORU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Text(
                      'Aion-2 Impeller · Uyarlamalı Performans Ölçekleyici',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Active Hardware Profile Hero Banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF0E1A2F), Color(0xFF080D1A)],
              ),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.memory_rounded,
                    color: Color(0xFF00E5FF), size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Donanım Profili: Flagship Snapdragon 8 / A17 Pro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Adreno 750 / Vulkan 1.3 · 12 GB RAM · 120Hz ProMotion',
                          style: TextStyle(color: Colors.white60, fontSize: 9.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Real-Time Memory & Performance Indicator Bento Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF0F172A).withValues(alpha: 0.7),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildBentoMetric(
                  label: 'RAM KULLANIMI',
                  value: '1,420 MB',
                  accent: const Color(0xFF00E5FF),
                ),
                Container(width: 1, height: 28, color: Colors.white12),
                _buildBentoMetric(
                  label: 'VRAM KULLANIMI',
                  value: '780 MB',
                  accent: const Color(0xFFB388FF),
                ),
                Container(width: 1, height: 28, color: Colors.white12),
                _buildBentoMetric(
                  label: 'CANLI KARE HIZI',
                  value: '119.8 FPS',
                  accent: const Color(0xFF10B981),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Preset Quality Tier Selector (Eco, Low, Med, High, Ultra)
          const Text(
            'ÖN TANIMLI KALİTE SEVİYESİ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _buildTierButton('Eco', false),
              const SizedBox(width: 5),
              _buildTierButton('Low', false),
              const SizedBox(width: 5),
              _buildTierButton('Med', false),
              const SizedBox(width: 5),
              _buildTierButton('High', false),
              const SizedBox(width: 5),
              _buildTierButton('Ultra', true),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5C842).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFF5C842).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.workspace_premium_rounded,
                    color: Color(0xFFF5C842), size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Seçili: Ultra — Aion-2 AAA Sinematik · 120 FPS · 4K Gölgeler',
                      style: TextStyle(
                        color: Color(0xFFF5C842),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Target FPS Selector
          const Text(
            'HEDEF KARE HIZI (FPS CAP)',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _buildFpsChip('30 FPS (Pil)', false),
              const SizedBox(width: 6),
              _buildFpsChip('60 FPS (Dengeli)', false),
              const SizedBox(width: 6),
              _buildFpsChip('120 FPS (Sinematik)', true),
            ],
          ),
          const SizedBox(height: 14),

          // Resolution Scale Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const <Widget>[
              Text(
                'ÇÖZÜNÜRLÜK ÖLÇEĞİ (DSR)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '1.00x (Tam Doğal)',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF00E5FF),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: 1.0,
              min: 0.5,
              max: 1.0,
              onChanged: (_) {},
            ),
          ),
          const SizedBox(height: 8),

          // Graphics Engine Toggles
          _buildToggleRow(
            title: 'Dinamik Gölgeler & Yumuşatma',
            subtitle: 'Gerçek zamanlı kadim güneş gölgeleri (2048px)',
            value: true,
          ),
          _buildToggleRow(
            title: 'Volumetrik Sis & Işık Hüzmeleri',
            subtitle: '3D atmosferik god-rays ve ışık kırılmaları',
            value: true,
          ),
          _buildToggleRow(
            title: 'SSAO Ortam Karartması & Parıltı',
            subtitle: 'Gerçekçi derinlik gölgelendirmesi ve Bloom VFX',
            value: true,
          ),
          _buildToggleRow(
            title: 'Dinamik Otomatik Ölçekleyici (AQS)',
            subtitle: 'Kare düşüşünde otomatik histerezis koruma',
            value: true,
          ),
        ],
      ),
    ),
  );
}

Widget _buildBentoMetric({
  required String label,
  required String value,
  required Color accent,
}) {
  return Column(
    children: <Widget>[
      Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

Widget _buildTierButton(String label, bool active) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: active
            ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
            : const Color(0xFF0B111E),
        border: Border.all(
          color: active ? const Color(0xFF00E5FF) : Colors.white12,
          width: active ? 1.5 : 0.8,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF00E5FF) : Colors.white60,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildFpsChip(String label, bool active) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: active
            ? const Color(0xFFF5C842).withValues(alpha: 0.2)
            : const Color(0xFF0B111E),
        border: Border.all(
          color: active ? const Color(0xFFF5C842) : Colors.white12,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFFF5C842) : Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildToggleRow({
  required String title,
  required String subtitle,
  required bool value,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: const Color(0xFF00E5FF),
          onChanged: (_) {},
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 4: AUDIO & HAPTICS SETTINGS SCREEN (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildAudioHapticsSettingsScreen() {
  return Scaffold(
    backgroundColor: const Color(0xFF07090E),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFF5C842).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFFF5C842)),
                ),
                child: const Icon(Icons.music_note_rounded,
                    color: Color(0xFFF5C842), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'SES VE DOKUNSAL GERİBİLDİRİM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Text(
                      'Aion-2 Uzamsal Ses & Haptik Tepki Motoru',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Audio Card with VU Meters
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF0F172A).withValues(alpha: 0.75),
              border: Border.all(
                color: const Color(0xFFF5C842).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'SES KANALLARI (3D SPATIAL)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Stereo · 48 kHz',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _buildAudioSliderRow(
                  label: 'Ana Ses (Master)',
                  value: 0.90,
                  accent: const Color(0xFFF5C842),
                ),
                _buildAudioSliderRow(
                  label: 'Müzik (Aion BGM Orkestra)',
                  value: 0.75,
                  accent: const Color(0xFF00E5FF),
                ),
                _buildAudioSliderRow(
                  label: 'Savaş Efektleri (SFX)',
                  value: 0.85,
                  accent: const Color(0xFFEF4444),
                ),
                _buildAudioSliderRow(
                  label: 'Karakter & NPC Sesleri',
                  value: 0.70,
                  accent: const Color(0xFF10B981),
                ),
                _buildAudioSliderRow(
                  label: 'Ortam & Zindan Atmosferi',
                  value: 0.80,
                  accent: const Color(0xFFB388FF),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Haptics Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF0F172A).withValues(alpha: 0.75),
              border: Border.all(
                color: const Color(0xFFB388FF).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'HAPTİK TİTREŞİM YOĞUNLUĞU',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    _buildHapticTierChip('KAPALI', Icons.phonelink_erase_rounded, false),
                    const SizedBox(width: 5),
                    _buildHapticTierChip('HAFİF', Icons.touch_app_rounded, false),
                    const SizedBox(width: 5),
                    _buildHapticTierChip('ORTA', Icons.vibration_rounded, true),
                    const SizedBox(width: 5),
                    _buildHapticTierChip('GÜÇLÜ', Icons.bolt_rounded, false),
                  ],
                ),
                const SizedBox(height: 12),

                // Interactive Test Haptic Pulse Button
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.vibration_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'DOKUNSAL TİTREŞİMİ TEST ET',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                _buildToggleRow(
                  title: 'Ekran Sarsıntısını ve Hızlı Hareketi Azalt',
                  subtitle: 'Kritik vuruşlarda kamera sarsıntısını yumuşatır',
                  value: false,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildAudioSliderRow({
  required String label,
  required double value,
  required Color accent,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: accent,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 7,
            color: Colors.white12,
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: (value * 100).toInt(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          accent.withValues(alpha: 0.6),
                          accent,
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 100 - (value * 100).toInt(),
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildHapticTierChip(String label, IconData icon, bool active) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: active
            ? const Color(0xFFB388FF).withValues(alpha: 0.25)
            : const Color(0xFF070B14),
        border: Border.all(
          color: active ? const Color(0xFFB388FF) : Colors.white12,
          width: active ? 1.5 : 0.8,
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 15, color: active ? const Color(0xFFB388FF) : Colors.white38),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 5: CHAT SCREEN WITH CHANNEL TABS (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildChatScreenWithChannelTabs() {
  return Scaffold(
    backgroundColor: const Color(0xFF07090E),
    body: SafeArea(
      child: Column(
        children: <Widget>[
          // Top Chat Bar with Online Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1523),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'AION SOHBET VE TOPLULUK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Text(
                        '4,821 Oyuncu Çevrimiçi · Sunucu: Atreia-TR',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.tune_rounded, color: Colors.white60, size: 18),
              ],
            ),
          ),

          // Channel Tabs Bar
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: const BoxDecoration(
              color: Color(0xFF090E1A),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: <Widget>[
                _buildChannelTabChip(
                    'Dünya', const Color(0xFF00E5FF), true, null),
                const SizedBox(width: 5),
                _buildChannelTabChip(
                    'Lonca', const Color(0xFFF5C842), false, '3'),
                const SizedBox(width: 5),
                _buildChannelTabChip(
                    'Grup', const Color(0xFF10B981), false, '1'),
                const SizedBox(width: 5),
                _buildChannelTabChip(
                    'Pazar', const Color(0xFFF97316), false, null),
                const SizedBox(width: 5),
                _buildChannelTabChip(
                    'Sistem', const Color(0xFFEF4444), false, null),
                const SizedBox(width: 5),
                _buildChannelTabChip(
                    'Fısıltı', const Color(0xFFB388FF), false, null),
              ],
            ),
          ),

          // System Announcement Banner
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF5C842).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFF5C842).withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.campaign_rounded,
                    color: Color(0xFFF5C842), size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '⚔️ Arthur az önce +15 [Kadim Ejder Kılıcı] dövdü!',
                      style: TextStyle(
                        color: Color(0xFFF5C842),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Message Feed
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              children: <Widget>[
                _buildChatMessageBubble(
                  sender: 'Valerius',
                  role: 'Savaşçı',
                  level: '80',
                  channelTag: '[Dünya]',
                  tagColor: const Color(0xFF00E5FF),
                  message:
                      'Mitolojik Lav Zindanı için 140k+ Şifacı ve DPS aranıyor! (3/4)',
                  time: '12:44',
                ),
                _buildChatMessageBubble(
                  sender: 'Kaelith',
                  role: 'Simyacı',
                  level: '78',
                  channelTag: '[Dünya]',
                  tagColor: const Color(0xFF00E5FF),
                  message:
                      '+12 Işık İksiri ve Dayanıklılık Rünü pazara bırakıldı, kontrol edin.',
                  time: '12:45',
                ),
                _buildChatMessageBubble(
                  sender: 'GölgeAvcı',
                  role: 'Gölge',
                  level: '75',
                  channelTag: '[Lonca]',
                  tagColor: const Color(0xFFF5C842),
                  message:
                      'Akşam saat 20:00\'de kale kuşatması için ses odasında toplanalım.',
                  time: '12:46',
                ),
                _buildChatMessageBubble(
                  sender: 'KorsanLord',
                  role: 'Savaşçı',
                  level: '82',
                  channelTag: '[Dünya]',
                  tagColor: const Color(0xFF00E5FF),
                  message:
                      'Kızıl Ejderha dünya bossu 15 dakika içinde ortaya çıkacak!',
                  time: '12:48',
                ),
              ],
            ),
          ),

          // Quick Emoji / Macro Wheel Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: const Color(0xFF0B101D),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _buildMacroPill('⚔️ Savaşa!'),
                  const SizedBox(width: 5),
                  _buildMacroPill('🛡️ Savunun!'),
                  const SizedBox(width: 5),
                  _buildMacroPill('✨ Şifa Ver'),
                  const SizedBox(width: 5),
                  _buildMacroPill('👍 Hazırım'),
                ],
              ),
            ),
          ),

          // Composer Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00E5FF)),
                  ),
                  child: const Text(
                    '[Dünya]',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Text(
                      'Mesajınızı yazın...',
                      style: TextStyle(color: Colors.white38, fontSize: 11.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF00E5FF), Color(0xFF2563EB)],
                    ),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildChannelTabChip(
    String label, Color color, bool selected, String? badge) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: selected ? color.withValues(alpha: 0.25) : const Color(0xFF131D31),
      border: Border.all(
        color: selected ? color : Colors.white12,
        width: selected ? 1.5 : 0.8,
      ),
    ),
    child: Row(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (badge != null) ...<Widget>[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildChatMessageBubble({
  required String sender,
  required String role,
  required String level,
  required String channelTag,
  required Color tagColor,
  required String message,
  required String time,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 3),
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A).withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              channelTag,
              style: TextStyle(
                color: tagColor,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              sender,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Lv.$level $role',
                style: const TextStyle(color: Colors.white60, fontSize: 8.5),
              ),
            ),
            const Spacer(),
            Text(time,
                style: const TextStyle(color: Colors.white30, fontSize: 9)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
        ),
      ],
    ),
  );
}

Widget _buildMacroPill(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: const Color(0xFF1E293B),
      border: Border.all(color: Colors.white12),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 9.5),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 6: FRIENDS LIST SCREEN (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildFriendsListScreen() {
  return Scaffold(
    backgroundColor: const Color(0xFF07090E),
    body: SafeArea(
      child: Column(
        children: <Widget>[
          // Header & Blacklist CTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'ARKADAŞLAR VE SOSYAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Text(
                        '18 Arkadaş · 6 Çevrimiçi',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF1F2937),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.block_rounded,
                          color: Color(0xFFEF4444), size: 13),
                      SizedBox(width: 4),
                      Text('Kara Liste',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar: [Arkadaşlar] [İstekler (2)] [Ara & Ekle]
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF0B111E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Arkadaşlar (18)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const <Widget>[
                          Text(
                            'İstekler',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                          SizedBox(width: 4),
                          CircleAvatar(
                            radius: 6,
                            backgroundColor: Color(0xFFEF4444),
                            child: Text('2',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Ara & Ekle',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Online Filter Switch Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const <Widget>[
                Text(
                  'YALNIZCA ÇEVRİMİÇİLERİ GÖSTER',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.toggle_on_rounded,
                    color: Color(0xFF10B981), size: 28),
              ],
            ),
          ),

          // Friend Cards List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: <Widget>[
                _buildFriendCard(
                  name: 'AionCommander',
                  role: 'Savaşçı · Lv.85',
                  guild: 'Elyos Krallığı',
                  isOnline: true,
                  statusText: 'Lav Zindanı 4. Katında',
                ),
                _buildFriendCard(
                  name: 'AyIşığıSimya',
                  role: 'Simyacı · Lv.81',
                  guild: 'Simya Loncası',
                  isOnline: true,
                  statusText: 'Şehir Merkezinde Ticaret Yapıyor',
                ),
                _buildFriendCard(
                  name: 'KaranlıkGölge',
                  role: 'Gölge · Lv.78',
                  guild: 'Gölge Tarikatı',
                  isOnline: true,
                  statusText: 'PvP Arenasında Sıra Bekliyor',
                ),
                _buildFriendCard(
                  name: 'DemirYürek',
                  role: 'Savaşçı · Lv.70',
                  guild: 'Kadim Muhafızlar',
                  isOnline: false,
                  statusText: 'Son görülme: 3 saat önce',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildFriendCard({
  required String name,
  required String role,
  required String guild,
  required bool isOnline,
  required String statusText,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A).withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isOnline
            ? const Color(0xFF10B981).withValues(alpha: 0.3)
            : Colors.white10,
      ),
    ),
    child: Row(
      children: <Widget>[
        // Avatar with online presence dot
        Stack(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: <Color>[Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                ),
                border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 24),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6B7280),
                  border: Border.all(color: const Color(0xFF07090E), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '[$guild]',
                    style: const TextStyle(
                      color: Color(0xFFF5C842),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                role,
                style: const TextStyle(color: Colors.white60, fontSize: 9.5),
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: TextStyle(
                  color: isOnline
                      ? const Color(0xFF10B981)
                      : Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        if (isOnline) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF5C842).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF5C842)),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.group_add_rounded,
                    color: Color(0xFFF5C842), size: 13),
                SizedBox(width: 3),
                Text(
                  'Davet Et',
                  style: TextStyle(
                    color: Color(0xFFF5C842),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.chat_bubble_outline_rounded,
              color: Color(0xFF00E5FF), size: 16),
        ],
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 7: ANNOUNCEMENTS & EVENTS CAROUSEL SCREEN (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildAnnouncementsCarouselScreen() {
  return Scaffold(
    backgroundColor: const Color(0xFF07090E),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: <Widget>[
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'DUYURULAR VE ETKİNLİKLER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Text(
                      'Canlı Sezon Güncellemeleri · Aion-2',
                      style: TextStyle(color: Color(0xFFF5C842), fontSize: 10),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.notifications_active_rounded,
                  color: Color(0xFFF5C842), size: 20),
            ],
          ),
          const SizedBox(height: 12),

          // Hero Banner Carousel
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF8B5CF6), Color(0xFF1E1B4B)],
              ),
              border: Border.all(
                color: const Color(0xFFF5C842).withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                // Background fantasy artwork motif
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: <Widget>[
                                Icon(Icons.flash_on_rounded,
                                    color: Colors.white, size: 11),
                                SizedBox(width: 3),
                                Text(
                                  'CANLI SEZON ETKİNLİĞİ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'Kalan: 2g 14s',
                            style: TextStyle(
                              color: Color(0xFFF5C842),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const <Widget>[
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'KADİM EJDERHA UYANIŞI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Tüm zindanlarda %200 EXP ve Efsanevi Eşya Düşürme Şansı!',
                            style: TextStyle(color: Colors.white70, fontSize: 10.5),
                          ),
                        ],
                      ),
                      // Carousel Page Indicator Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: 18,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5C842),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 5,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 5,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // One-Tap "Claim Event Gift" Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFF5C842), Color(0xFFD97706)],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFF5C842).withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.card_giftcard_rounded,
                        color: Colors.black, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'GÜNLÜK ETKİNLİK HEDİYESİNİ AL (100x Elmas & Kadim İksir)',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Category Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _buildAnnouncementFilterTab('Tümü', true),
                const SizedBox(width: 5),
                _buildAnnouncementFilterTab('Etkinlikler', false),
                const SizedBox(width: 5),
                _buildAnnouncementFilterTab('Yama Notları', false),
                const SizedBox(width: 5),
                _buildAnnouncementFilterTab('Sunucu Durumu', false),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Patch Notes Card 1
          _buildPatchNoteCard(
            tag: 'YAMA 2.4.0',
            tagColor: const Color(0xFF00E5FF),
            title: 'Yeni Savaşçı & Simyacı Dengeleme Yaması',
            date: 'Bugün · 10:30',
            description:
                'Savaşçı kalkan savunması güçlendirildi. Simyacı kadim iksir etki süresi 30 saniyeye çıkarıldı.',
          ),
          const SizedBox(height: 8),

          // Patch Notes Card 2
          _buildPatchNoteCard(
            tag: 'SUNUCU',
            tagColor: const Color(0xFF10B981),
            title: 'Haftalık Bakım Tamamlandı & Hata Düzeltmeleri',
            date: 'Dün · 04:00',
            description:
                'Pazar yeri işlem gecikmesi giderildi. Sunucu kene hızı 60 Hz sabitlendi.',
          ),
        ],
      ),
    ),
  );
}

Widget _buildAnnouncementFilterTab(String label, bool active) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: active
          ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
          : const Color(0xFF0F172A),
      border: Border.all(
        color: active ? const Color(0xFF00E5FF) : Colors.white12,
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: active ? const Color(0xFF00E5FF) : Colors.white60,
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _buildPatchNoteCard({
  required String tag,
  required Color tagColor,
  required String title,
  required String date,
  required String description,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: const Color(0xFF0F172A).withValues(alpha: 0.7),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tagColor),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: tagColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(date,
                style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: const TextStyle(color: Colors.white60, fontSize: 10.5, height: 1.3),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 8: NOTIFICATIONS CENTER SCREEN (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildNotificationsCenterScreen() {
  return Scaffold(
    backgroundColor: const Color(0xFF07090E),
    body: SafeArea(
      child: Column(
        children: <Widget>[
          // Header & Mark All Read
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'BİLDİRİM MERKEZİ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Text(
                        '5 Okunmamış Bildirim',
                        style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF1E293B),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.done_all_rounded,
                          color: Color(0xFF00E5FF), size: 13),
                      SizedBox(width: 4),
                      Text('Tümünü Oku',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Category Filter Tabs: [Tümü] [Sistem] [Savaş] [Sosyal] [Ödüller]
          Container(
            height: 38,
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: <Widget>[
                _buildNotifCategoryChip('Tümü (5)', true),
                const SizedBox(width: 5),
                _buildNotifCategoryChip('Sistem', false),
                const SizedBox(width: 5),
                _buildNotifCategoryChip('Savaş & Nemesis', false),
                const SizedBox(width: 5),
                _buildNotifCategoryChip('Sosyal & Lonca', false),
                const SizedBox(width: 5),
                _buildNotifCategoryChip('Ödüller', false),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Notification Cards
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              children: <Widget>[
                _buildNotificationCard(
                  icon: Icons.card_giftcard_rounded,
                  iconColor: const Color(0xFFF5C842),
                  title: 'Günlük Giriş Ödülü Açılabilir!',
                  body:
                      '7. Gün Efsanevi Sandık kilidini açmaya hazırsınız. Hemen ödülünüzü alın!',
                  time: '5dk önce',
                  isUnread: true,
                  ctaLabel: 'Sandığı Aç',
                ),
                _buildNotificationCard(
                  icon: Icons.shield_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'Nemesis Saldırısı Uyarısı!',
                  body:
                      'KaranlıkGölge adlı oyuncu kale maden bölgenize saldırı başlattı.',
                  time: '22dk önce',
                  isUnread: true,
                  ctaLabel: 'Savunmaya Git',
                ),
                _buildNotificationCard(
                  icon: Icons.group_add_rounded,
                  iconColor: const Color(0xFF00E5FF),
                  title: 'Grup Daveti: Lav Zindanı',
                  body:
                      'AionCommander sizi 4 kişilik zindan akınına davet etti.',
                  time: '1 saat önce',
                  isUnread: true,
                  ctaLabel: 'Kabul Et',
                ),
                _buildNotificationCard(
                  icon: Icons.storefront_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Gece Pazarı İndirimi Başladı!',
                  body:
                      'Özel Kadim Zırh parçaları %40 indirimle Gece Pazarında satışta.',
                  time: '3 saat önce',
                  isUnread: false,
                  ctaLabel: 'Pazara Git',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildNotifCategoryChip(String label, bool active) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: active
          ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
          : const Color(0xFF0F172A),
      border: Border.all(
        color: active ? const Color(0xFF00E5FF) : Colors.white12,
        width: active ? 1.5 : 0.8,
      ),
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(
          color: active ? const Color(0xFF00E5FF) : Colors.white60,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

Widget _buildNotificationCard({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String body,
  required String time,
  required bool isUnread,
  required String ctaLabel,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isUnread
          ? const Color(0xFF0F172A).withValues(alpha: 0.9)
          : const Color(0xFF0B101D).withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isUnread
            ? iconColor.withValues(alpha: 0.4)
            : Colors.white10,
        width: isUnread ? 1.2 : 0.8,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: iconColor.withValues(alpha: 0.15),
            border: Border.all(color: iconColor),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight:
                            isUnread ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(time,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 9)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: iconColor.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    ctaLabel,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 9: DAILY REWARD CHEST UNLOCK MODAL (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildDailyRewardChestUnlockModal() {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: Stack(
      children: <Widget>[
        // Dimmed atmospheric background backdrop
        Container(
          color: Colors.black.withValues(alpha: 0.85),
        ),
        // Rotating Celestial Light Rays
        Center(
          child: SizedBox(
            width: 320,
            height: 320,
            child: CustomPaint(
              painter: _ChestLightRaysPainter(),
            ),
          ),
        ),
        // Particle Explosion
        Positioned.fill(
          child: CustomPaint(
            painter: _ChestParticlesPainter(),
          ),
        ),
        SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF1E1735), Color(0xFF0F0C1E)],
                ),
                border: Border.all(
                  color: const Color(0xFFF5C842),
                  width: 1.8,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFFF5C842).withValues(alpha: 0.35),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5C842).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF5C842)),
                    ),
                    child: const Text(
                      '7. GÜN EFSANEVİ ÖDÜLÜ',
                      style: TextStyle(
                        color: Color(0xFFF5C842),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Open 3D Chest Visual Centerpiece
                  Container(
                    width: 110,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const RadialGradient(
                        colors: <Color>[Color(0xFFF5C842), Color(0xFF78350F)],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFFF5C842).withValues(alpha: 0.5),
                          blurRadius: 22,
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFF5C842),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Unlocked Item Presentation Showcase
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'KADİM EJDER KANATLARI [MİTOLOJİK]',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Uçuş Hızı +45% · Maksimum Enerji +250 · Saldırı Gücü +120',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Atreia semalarındaki en kadim ejderhaların ruhundan dövülmüş efsanevi kanat parçası.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Tactile Collect Reward CTA Button
                  Container(
                    height: 44,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFFF5C842), Color(0xFFD97706)],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color:
                              const Color(0xFFF5C842).withValues(alpha: 0.45),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.check_circle_rounded,
                                  color: Colors.black, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'ÖDÜLÜ TOPLA VE KUŞAN',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTERS FOR PROCEDURAL ATMOSPHERIC EMBERS & RUNIC LIGHT RAYS
// ─────────────────────────────────────────────────────────────────────────────

class _RunicEmbersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final math.Random random = math.Random(42);

    for (int i = 0; i < 35; i++) {
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height;
      final double radius = 1.0 + random.nextDouble() * 2.2;
      final double opacity = 0.2 + random.nextDouble() * 0.6;
      final Color color = (i % 2 == 0)
          ? const Color(0xFF00E5FF).withValues(alpha: opacity)
          : const Color(0xFFF5C842).withValues(alpha: opacity);

      paint.color = color;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RunicPedestalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFF5C842).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final Offset center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.42, paint);
    canvas.drawCircle(center, size.width * 0.32, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChestLightRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFFF5C842).withValues(alpha: 0.45),
          const Color(0xFF8B5CF6).withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Offset center = Offset(size.width / 2, size.height / 2);
    const int rayCount = 14;
    const double angleStep = (2 * math.pi) / rayCount;

    for (int i = 0; i < rayCount; i++) {
      final double angle = i * angleStep;
      final Path path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(angle - 0.12) * (size.width * 0.5),
          center.dy + math.sin(angle - 0.12) * (size.height * 0.5),
        )
        ..lineTo(
          center.dx + math.cos(angle + 0.12) * (size.width * 0.5),
          center.dy + math.sin(angle + 0.12) * (size.height * 0.5),
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChestParticlesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final math.Random random = math.Random(107);
    final Offset center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 48; i++) {
      final double angle = random.nextDouble() * 2 * math.pi;
      final double distance = 35 + random.nextDouble() * 120;
      final double radius = 1.2 + random.nextDouble() * 2.8;
      final Color color = (i % 3 == 0)
          ? const Color(0xFFF5C842)
          : (i % 3 == 1)
              ? const Color(0xFFB388FF)
              : const Color(0xFF00E5FF);

      paint.color = color.withValues(alpha: 0.7);
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * distance,
          center.dy + math.sin(angle) * distance,
        ),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// TEST SUITE: 9 MOBILE GOLDEN SCREENSHOT TESTS (390x844 SAFEAREA)
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Battalion 7 Mobile Golden Screenshot Tests (390x844 SafeArea)', () {
    testWidgets('Screen 1: Auth Login Portal Screen (390x844)', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(
        kMobileWidth * kDevicePixelRatio,
        kMobileHeight * kDevicePixelRatio,
      );
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildAuthLoginPortalScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '01_auth_login_portal.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      await expectLater(
        find.byKey(repaintKey),
        matchesGoldenFile('goldens/01_auth_login_portal.png'),
      );
    });

    testWidgets('Screen 2: Character Selection Preview Screen (390x844)', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(
        kMobileWidth * kDevicePixelRatio,
        kMobileHeight * kDevicePixelRatio,
      );
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildCharacterSelectionPreviewScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '02_character_selection_preview.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      await expectLater(
        find.byKey(repaintKey),
        matchesGoldenFile('goldens/02_character_selection_preview.png'),
      );
    });

    testWidgets('Screen 3: Graphics Quality Settings Screen (showing Eco/Low/Med/High/Ultra tiers) (390x844)', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(
        kMobileWidth * kDevicePixelRatio,
        kMobileHeight * kDevicePixelRatio,
      );
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildGraphicsQualitySettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '03_graphics_quality_settings.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      await expectLater(
        find.byKey(repaintKey),
        matchesGoldenFile('goldens/03_graphics_quality_settings.png'),
      );
    });

    testWidgets('Screen 4: Audio & Haptics Settings Screen (390x844)', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(
        kMobileWidth * kDevicePixelRatio,
        kMobileHeight * kDevicePixelRatio,
      );
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildAudioHapticsSettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '04_audio_haptics_settings.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      await expectLater(
        find.byKey(repaintKey),
        matchesGoldenFile('goldens/04_audio_haptics_settings.png'),
      );
    });

    testWidgets('Screen 5: Chat Screen with Channel Tabs (390x844)', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(
        kMobileWidth * kDevicePixelRatio,
        kMobileHeight * kDevicePixelRatio,
      );
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildChatScreenWithChannelTabs(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '05_chat_channel_tabs.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      await expectLater(
        find.byKey(repaintKey),
        matchesGoldenFile('goldens/05_chat_channel_tabs.png'),
      );
    });

    testWidgets('Screen 6: Friends List Screen (390x844)', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(
        kMobileWidth * kDevicePixelRatio,
        kMobileHeight * kDevicePixelRatio,
      );
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildFriendsListScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '06_friends_list_screen.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      await expectLater(
        find.byKey(repaintKey),
        matchesGoldenFile('goldens/06_friends_list_screen.png'),
      );
    });

    testWidgets('Screen 7: Announcements & Events Carousel Screen (390x844)', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(
        kMobileWidth * kDevicePixelRatio,
        kMobileHeight * kDevicePixelRatio,
      );
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildAnnouncementsCarouselScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '07_announcements_carousel_screen.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      await expectLater(
        find.byKey(repaintKey),
        matchesGoldenFile('goldens/07_announcements_carousel_screen.png'),
      );
    });

    testWidgets('Screen 8: Notifications Center Screen (390x844)', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(
        kMobileWidth * kDevicePixelRatio,
        kMobileHeight * kDevicePixelRatio,
      );
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildNotificationsCenterScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '08_notifications_center_screen.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      await expectLater(
        find.byKey(repaintKey),
        matchesGoldenFile('goldens/08_notifications_center_screen.png'),
      );
    });

    testWidgets('Screen 9: Daily Reward Chest Unlock Modal (390x844)', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(
        kMobileWidth * kDevicePixelRatio,
        kMobileHeight * kDevicePixelRatio,
      );
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildDailyRewardChestUnlockModal(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '09_daily_reward_chest_modal.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      await expectLater(
        find.byKey(repaintKey),
        matchesGoldenFile('goldens/09_daily_reward_chest_modal.png'),
      );
    });
  });
}
