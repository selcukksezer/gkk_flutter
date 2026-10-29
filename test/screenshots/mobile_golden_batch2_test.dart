import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/theme/app_colors.dart';

/// Authentic mobile viewport specifications (iPhone 14 / modern standard mobile).
const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 2.0; // 780x1688 crisp mobile golden render
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

const String kOutputDir = 'reports/screenshots/mobile_goldens';

/// Utility to capture widget to PNG file on disk.
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
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.bgDeep,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.accentBlue,
        surface: AppColors.bgSurface,
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
// SHARED MOBILE UI COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildHeaderBar({
  required String title,
  required String subtitle,
  required IconData icon,
  Color iconColor = AppColors.gold,
  Widget? trailing,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: const BoxDecoration(
      color: Color(0xDA080B12),
      border: Border(bottom: BorderSide(color: AppColors.borderFaint, width: 1)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: iconColor.withValues(alpha: 0.4), width: 1),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 6),
          trailing,
        ],
      ],
    ),
  );
}

Widget _buildCurrencyChip(String amount, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 12: COMBAT ARENA SCREEN (lib/screens/mekans/, lib/screens/pvp/)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildCombatArenaScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF220A0A), Color(0xFF13090C), Color(0xFF080B12)],
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: 30,
          child: Container(
            width: 330,
            height: 330,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[Color(0x33EF4444), Colors.transparent],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeaderBar(
                title: 'Gladyatör Arenası',
                subtitle: 'Sezon 5: Daeva Şampiyonası',
                icon: Icons.sports_mma,
                iconColor: AppColors.danger,
                trailing: _buildCurrencyChip('2,580 Elo', Icons.emoji_events, AppColors.gold),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _buildArenaModeTabs(),
                    const SizedBox(height: 12),
                    _buildArenaChallengerPedestal(),
                    const SizedBox(height: 12),
                    _buildArenaEloTierBanner(),
                    const SizedBox(height: 12),
                    _buildArenaHistorySection(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 38,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.flash_on, color: Colors.black, size: 22),
              label: const Text(
                'ARENA SAVAŞINA KATIL',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 6,
                shadowColor: AppColors.goldGlow,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildArenaModeTabs() {
  return Container(
    height: 44,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFDC2626), Color(0xFF991B1B)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '1v1 Düello',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 38,
            child: Center(
              child: Text(
                '3v3 Lonca',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 38,
            child: Center(
              child: Text(
                'Meydan',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildArenaChallengerPedestal() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.bgSurface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x66EF4444), width: 1.2),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0x22EF4444), blurRadius: 16, offset: Offset(0, 4)),
      ],
    ),
    child: Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF7F1D1D),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('RİVAL', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 9, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Kazanma: %68',
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: <Color>[AppColors.danger, Color(0xFF450A0A)],
                ),
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              child: const Center(
                child: Icon(Icons.shield_outlined, color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Text(
                    'Lord Varis',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text('942k CP • Seviye 80', style: TextStyle(color: AppColors.accentCyan, fontSize: 10), overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2),
                  Text('Unvan: Daeva Katili', style: TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildArenaEloTierBanner() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.military_tech, color: AppColors.gold, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text('Şampiyon II', style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              SizedBox(height: 1),
              Text('120 Elo Kaldı', style: TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.goldGlow,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.gold, width: 0.8),
          ),
          child: const Text('14. SIRA', style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

Widget _buildArenaHistorySection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const Text(
        'Son Karşılaşmalar',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      _buildMatchHistoryItem(opponent: 'Kromede Avcısı', result: 'ZAFER (+24)', isWin: true, time: '3 dk'),
      const SizedBox(height: 6),
      _buildMatchHistoryItem(opponent: 'Gölge Raven', result: 'YENİLGİ (-12)', isWin: false, time: '18 dk'),
      const SizedBox(height: 6),
      _buildMatchHistoryItem(opponent: 'Buz Selene', result: 'ZAFER (+28)', isWin: true, time: '42 dk'),
    ],
  );
}

Widget _buildMatchHistoryItem({
  required String opponent,
  required String result,
  required bool isWin,
  required String time,
}) {
  return Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isWin ? AppColors.success.withValues(alpha: 0.4) : AppColors.danger.withValues(alpha: 0.4),
      ),
    ),
    child: Row(
      children: <Widget>[
        Icon(
          isWin ? Icons.check_circle : Icons.cancel,
          color: isWin ? AppColors.success : AppColors.danger,
          size: 16,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            opponent,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          result,
          style: TextStyle(
            color: isWin ? AppColors.success : AppColors.danger,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
        Text(time, style: const TextStyle(color: AppColors.textTertiary, fontSize: 8)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 13: BOSS RAID SCREEN (lib/screens/dungeon/)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildBossRaidScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF2A0808), Color(0xFF150B10), Color(0xFF080B12)],
            ),
          ),
        ),
        Positioned(
          top: 80,
          right: 20,
          child: Container(
            width: 280,
            height: 280,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[Color(0x30FF6B35), Colors.transparent],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeaderBar(
                title: 'Lord Ignis Baskını',
                subtitle: 'Aion 2 Mistik Raid (Kabus V)',
                icon: Icons.local_fire_department,
                iconColor: const Color(0xFFFF6B35),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F1D1D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.danger, width: 0.8),
                  ),
                  child: const Text('08:45', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _buildBossStatusGaugeCard(),
                    const SizedBox(height: 12),
                    _buildBossPhaseAlertBanner(),
                    const SizedBox(height: 12),
                    _buildRaidPartyHudGrid(),
                    const SizedBox(height: 12),
                    _buildTacticalSkillsTray(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 38,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.flash_auto, color: Colors.white, size: 22),
              label: const Text(
                'TOPLU BASKIN SALDIRISI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 6,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildBossStatusGaugeCard() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.bgSurface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: const <Widget>[
            Expanded(
              child: Text(
                'LORD IGNIS',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6),
            Text('3.8M HP (%77)', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: LinearProgressIndicator(
              value: 0.77,
              backgroundColor: const Color(0xFF450A0A),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: const <Widget>[
            Expanded(
              child: Text(
                'Kalkan: %42',
                style: TextStyle(color: AppColors.accentCyan, fontSize: 9, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6),
            Text('Zayıflık: Buz', style: TextStyle(color: AppColors.accentBlue, fontSize: 9)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 5,
            child: LinearProgressIndicator(
              value: 0.42,
              backgroundColor: AppColors.bgBase,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildBossPhaseAlertBanner() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: <Color>[Color(0xFF7F1D1D), Color(0xFF450A0A)],
      ),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.danger),
    ),
    child: Row(
      children: const <Widget>[
        Icon(Icons.warning, color: AppColors.gold, size: 16),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'EVRE 2: Ateş Yağmuru 15s içinde başlıyor!',
            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Widget _buildRaidPartyHudGrid() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const Text('Baskın Grubu', style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Row(
        children: <Widget>[
          Expanded(child: _buildPartyMemberCard('Valerius', 'Tank', 0.92, Icons.shield, AppColors.accentBlue)),
          const SizedBox(width: 6),
          Expanded(child: _buildPartyMemberCard('Selena', 'Şifacı', 0.85, Icons.healing, AppColors.success)),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        children: <Widget>[
          Expanded(child: _buildPartyMemberCard('Kaelen', 'Büyücü', 0.65, Icons.auto_fix_high, AppColors.accentPurple)),
          const SizedBox(width: 6),
          Expanded(child: _buildPartyMemberCard('Daeva', 'Savaşçı', 0.78, Icons.flash_on, AppColors.gold)),
        ],
      ),
    ],
  );
}

Widget _buildPartyMemberCard(String name, String role, double hp, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Row(
      children: <Widget>[
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    value: hp,
                    backgroundColor: AppColors.bgDeep,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
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

Widget _buildTacticalSkillsTray() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const Text('Taktiksel Komut Tepsisi', style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Row(
        children: <Widget>[
          _buildTacticalSkillButton('Ejder', Icons.colorize, AppColors.danger, 'Hazır'),
          _buildTacticalSkillButton('Kalkan', Icons.security, AppColors.accentBlue, '4s'),
          _buildTacticalSkillButton('Işık', Icons.brightness_high, AppColors.gold, 'Hazır'),
          _buildTacticalSkillButton('Kaçış', Icons.directions_run, AppColors.accentCyan, 'Hazır'),
        ],
      ),
    ],
  );
}

Widget _buildTacticalSkillButton(String label, IconData icon, Color color, String status) {
  return Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(status, style: TextStyle(color: color, fontSize: 7), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 14: PARTY FINDER & FACILITIES SCREEN (lib/screens/facilities/)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildPartyFinderScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF0F1B2B), Color(0xFF0E1422), Color(0xFF080B12)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeaderBar(
                title: 'Parti Bulucu & Tesisler',
                subtitle: '48 Aktif Grup • Lonca Tesisleri',
                icon: Icons.groups,
                iconColor: AppColors.accentCyan,
                trailing: _buildCurrencyChip('12 Online', Icons.wifi, AppColors.success),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _buildFilterPillsRow(),
                    const SizedBox(height: 12),
                    _buildPartyLfgCard(
                      title: 'Lord Ignis Baskını Kabus V [3/4]',
                      leader: 'ArchDaeva',
                      desc: 'Acil 1 Tank ve 1 DPS Aranıyor (850k CP)',
                      ping: '24ms',
                      tags: <String>['Raid', 'Mistik'],
                    ),
                    const SizedBox(height: 10),
                    _buildPartyLfgCard(
                      title: 'Karanlık Kripta Hızlı Farm [2/4]',
                      leader: 'LunaShadow',
                      desc: 'EXP takviyesi aktif, tecrübeli şifacı',
                      ping: '18ms',
                      tags: <String>['Zindan', 'Farm'],
                    ),
                    const SizedBox(height: 10),
                    _buildPartyLfgCard(
                      title: 'Lonca Kuşatması Antrenmanı [5/6]',
                      leader: 'DemirYürek',
                      desc: 'Kale savaşı taktiksel prova',
                      ping: '32ms',
                      tags: <String>['Lonca', 'PVP'],
                    ),
                    const SizedBox(height: 14),
                    _buildFacilitiesOverviewCard(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 38,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 22),
              label: const Text(
                'YENİ PARTİ İLANI AÇ',
                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildFilterPillsRow() {
  return SizedBox(
    height: 36,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: <Widget>[
        _buildPill('Tümü', isSelected: true),
        const SizedBox(width: 6),
        _buildPill('Raid'),
        const SizedBox(width: 6),
        _buildPill('PvP'),
        const SizedBox(width: 6),
        _buildPill('Boss'),
        const SizedBox(width: 6),
        _buildPill('Lonca'),
      ],
    ),
  );
}

Widget _buildPill(String label, {bool isSelected = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isSelected ? AppColors.accentCyan : AppColors.bgSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isSelected ? AppColors.accentCyan : AppColors.borderFaint),
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : AppColors.textSecondary,
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    ),
  );
}

Widget _buildPartyLfgCard({
  required String title,
  required String leader,
  required String desc,
  required String ping,
  required List<String> tags,
}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.bgDeep,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(ping, style: const TextStyle(color: AppColors.success, fontSize: 8)),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text('Lider: $leader', style: const TextStyle(color: AppColors.gold, fontSize: 9)),
        const SizedBox(height: 4),
        Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            for (final String tag in tags) ...<Widget>[
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.bgCardElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(tag, style: const TextStyle(color: AppColors.textSecondary, fontSize: 7)),
              ),
            ],
            const Spacer(),
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('KATIL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildFacilitiesOverviewCard() {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        Text('Lonca Tesis Durumu', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('• Kışla: Seviye 8 (+%15 Hasar)', style: TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
        Text('• Kule: Seviye 6 (+%12 Mana)', style: TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
        Text('• Maden: Seviye 9 (+%20 Verim)', style: TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 15: CRAFTING WORKSHOP SCREEN (lib/screens/crafting/)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildCraftingWorkshopScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF161208), Color(0xFF14131D), Color(0xFF080B12)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeaderBar(
                title: 'Zanaat Atölyesi',
                subtitle: 'Usta Zanaatkar Seviyesi 52',
                icon: Icons.handyman,
                iconColor: AppColors.gold,
                trailing: _buildCurrencyChip('180 EP', Icons.bolt, AppColors.gold),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _buildCraftingCategoryPills(),
                    const SizedBox(height: 12),
                    _buildCraftingBlueprintCard(),
                    const SizedBox(height: 12),
                    _buildCraftingMaterialsGrid(),
                    const SizedBox(height: 12),
                    _buildCraftingQueueSlots(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 38,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.auto_awesome, color: Colors.black, size: 22),
              label: const Text(
                'EŞYAYI ÜRET (1x)',
                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildCraftingCategoryPills() {
  return SizedBox(
    height: 36,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: <Widget>[
        _buildPill('Silahlar', isSelected: true),
        const SizedBox(width: 6),
        _buildPill('Zırhlar'),
        const SizedBox(width: 6),
        _buildPill('Mücevher'),
        const SizedBox(width: 6),
        _buildPill('Runlar'),
      ],
    ),
  );
}

Widget _buildCraftingBlueprintCard() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.gold, width: 1.2),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: AppColors.goldGlow, blurRadius: 12),
      ],
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.bgDeep,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.gold, width: 1.5),
          ),
          child: const Icon(Icons.colorize, color: AppColors.gold, size: 24),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text('Ejderdişi Kılıcı (Tier V)', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Text('Hasar: 1,840 - 2,120', style: TextStyle(color: Colors.white, fontSize: 9), overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Text('Başarı: %100 • Harika: %25', style: TextStyle(color: AppColors.accentCyan, fontSize: 8), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildCraftingMaterialsGrid() {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Gereken Materyaller', style: TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _buildMaterialRow('Ejder Pulu', '4/4', Icons.scatter_plot, AppColors.success),
        const SizedBox(height: 4),
        _buildMaterialRow('Yıldız Çeliği', '2/2', Icons.square, AppColors.success),
        const SizedBox(height: 4),
        _buildMaterialRow('Çekirdek', '1/1', Icons.radio_button_checked, AppColors.success),
        const SizedBox(height: 4),
        _buildMaterialRow('Harcı', '15k', Icons.monetization_on, AppColors.gold),
      ],
    ),
  );
}

Widget _buildMaterialRow(String name, String qty, IconData icon, Color color) {
  return Row(
    children: <Widget>[
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Text(name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 6),
      Text(qty, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    ],
  );
}

Widget _buildCraftingQueueSlots() {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        Text('Aktif Kuyruk (1/3)', style: TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('• Slot 1: Miğfer (01:24)', style: TextStyle(color: AppColors.accentBlue, fontSize: 9), overflow: TextOverflow.ellipsis),
        Text('• Slot 2: [Boş]', style: TextStyle(color: AppColors.textTertiary, fontSize: 9)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 16: ALCHEMY LAB SCREEN (lib/screens/facilities/, lib/screens/crafting/)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildAlchemyLabScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF0F0A1E), Color(0xFF130F24), Color(0xFF080B12)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeaderBar(
                title: 'Simya Laboratuvarı',
                subtitle: 'Büyük Üstat Simyager',
                icon: Icons.science,
                iconColor: AppColors.accentPurple,
                trailing: _buildCurrencyChip('4,250 MP', Icons.water_drop, AppColors.accentPurple),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _buildAlchemyCrucibleCard(),
                    const SizedBox(height: 12),
                    _buildAlchemyReagentsGrid(),
                    const SizedBox(height: 12),
                    _buildAlchemyRecipesList(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 38,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.bubble_chart, color: Colors.white, size: 22),
              label: const Text(
                'İKSİRİ DAMIT & DÖNÜŞTÜR',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildAlchemyCrucibleCard() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.accentPurple, width: 1.2),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: AppColors.accentPurpleGlow, blurRadius: 14),
      ],
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: <Color>[AppColors.accentPurple, Color(0xFF3B0764)],
            ),
            border: Border.all(color: AppColors.accentCyan, width: 1.5),
          ),
          child: const Center(
            child: Icon(Icons.local_pharmacy, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text('Yüce Daeva İksiri', style: TextStyle(color: AppColors.accentPurple, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Text('+%30 Büyü Gücü (15 dk)', style: TextStyle(color: Colors.white, fontSize: 9), overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Text('Katalizör: Takılı (+%20 Verim)', style: TextStyle(color: AppColors.accentCyan, fontSize: 8), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildAlchemyReagentsGrid() {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Simya Reaktifleri', style: TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _buildMaterialRow('Gecegölgesi', '12x', Icons.eco, AppColors.success),
        const SizedBox(height: 4),
        _buildMaterialRow('Aytaşı', '8x', Icons.grain, AppColors.accentCyan),
        const SizedBox(height: 4),
        _buildMaterialRow('Kaynak Suyu', '30x', Icons.opacity, AppColors.accentBlue),
      ],
    ),
  );
}

Widget _buildAlchemyRecipesList() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: const <Widget>[
      Text('Kayıtlı Formüller', style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
      SizedBox(height: 6),
      Text('• Öfke İksiri: +%25 Saldırı (Lvl 45)', style: TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
      SizedBox(height: 3),
      Text('• Hızlı Adım: +%20 Hız (Lvl 40)', style: TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
      SizedBox(height: 3),
      Text('• Taş Deri: +3,500 Zırh (Lvl 50)', style: TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 17: BLACKSMITH FORGE SCREEN (lib/screens/enhancement/)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildBlacksmithForgeScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF2E1005), Color(0xFF1B0B04), Color(0xFF080B12)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeaderBar(
                title: 'Demirci Ocağı',
                subtitle: 'Ocak Sıcaklığı: 850°C • Anvil Lvl 50',
                icon: Icons.fireplace,
                iconColor: const Color(0xFFFF6B35),
                trailing: _buildCurrencyChip('+12 -> +13', Icons.upgrade, AppColors.gold),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _buildForgeItemUpgradePedestal(),
                    const SizedBox(height: 12),
                    _buildForgeSuccessRateCard(),
                    const SizedBox(height: 12),
                    _buildForgeRuneSocketsCard(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 38,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.flash_on, color: Colors.black, size: 22),
              label: const Text(
                'DEMİRİ DÖV (+13 GELİŞTİR)',
                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildForgeItemUpgradePedestal() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFF6B35), width: 1.2),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0x33FF6B35), blurRadius: 16),
      ],
    ),
    child: Column(
      children: <Widget>[
        const Text('HÜKÜM KILICI +12', style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Flexible(
              child: Text('1,420', style: TextStyle(color: AppColors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
            ),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward, color: AppColors.success, size: 14),
            SizedBox(width: 6),
            Flexible(
              child: Text('1,510 (+90)', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Kritik: +%3.2', style: TextStyle(color: AppColors.accentCyan, fontSize: 9)),
      ],
    ),
  );
}

Widget _buildForgeSuccessRateCard() {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        Text('Geliştirme Oranı', style: TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('• Şans: %65 (+%15 Bonus)', style: TextStyle(color: AppColors.gold, fontSize: 9), overflow: TextOverflow.ellipsis),
        Text('• Parşömen: AKTİF (Kırılmaz)', style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        Text('• Malzeme: 5/5 Göktaşı', style: TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

Widget _buildForgeRuneSocketsCard() {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Rün Yuvaları (2/3)', style: TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _buildMaterialRow('Yakut (+45 Saldırı)', 'Takılı', Icons.diamond, AppColors.danger),
        const SizedBox(height: 4),
        _buildMaterialRow('Safir (+%5 Direnç)', 'Takılı', Icons.diamond, AppColors.accentBlue),
        const SizedBox(height: 4),
        _buildMaterialRow('Kilitli Yuva', 'Kilit', Icons.lock, AppColors.textTertiary),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 18: TRADE MARKET SCREEN (lib/screens/market/, lib/screens/trade/)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildTradeMarketScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF0B1626), Color(0xFF0F1523), Color(0xFF080B12)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeaderBar(
                title: 'Ticaret Pazarı',
                subtitle: 'Komisyon: %3',
                icon: Icons.storefront,
                iconColor: AppColors.gold,
                trailing: _buildCurrencyChip('2.45M', Icons.monetization_on, AppColors.gold),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _buildMarketSearchRow(),
                    const SizedBox(height: 12),
                    _buildMarketListingCard('Daeva Miğferi +10', 'ArchMage', '450k Altın', '04:12', AppColors.gold),
                    const SizedBox(height: 10),
                    _buildMarketListingCard('Yıldız Taşı (x50)', 'MinerBob', '120k Altın', '18:00', AppColors.accentCyan),
                    const SizedBox(height: 10),
                    _buildMarketListingCard('Gölge Kitabı', 'RavenBlade', '850 Elmas', '01:45', AppColors.accentPurple),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 38,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_shopping_cart, color: Colors.black, size: 22),
              label: const Text(
                'YENİ PAZAR İLANI VER',
                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildMarketSearchRow() {
  return Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Row(
      children: const <Widget>[
        Icon(Icons.search, color: AppColors.textSecondary, size: 18),
        SizedBox(width: 6),
        Expanded(
          child: Text('Pazarda eşya ara...', style: TextStyle(color: AppColors.textTertiary, fontSize: 10), overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

Widget _buildMarketListingCard(String title, String seller, String price, String timeLeft, Color color) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.bgDeep,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.2),
          ),
          child: Icon(Icons.inventory_2, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$seller • $timeLeft', style: const TextStyle(color: AppColors.textSecondary, fontSize: 8), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(price, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 34,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('AL', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 19: MAILBOX & NOTIFICATIONS SCREEN (lib/screens/announcements/)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildMailboxScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF0F1523), Color(0xFF0B101C), Color(0xFF080B12)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeaderBar(
                title: 'Posta Kutusu',
                subtitle: '3 Okunmamış İleti',
                icon: Icons.mail,
                iconColor: AppColors.accentCyan,
                trailing: _buildCurrencyChip('3 Yeni', Icons.mark_email_unread, AppColors.accentCyan),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _buildMailItemCard(
                      title: '[ÖDÜL] Gladyatör Sıralama',
                      sender: 'Sistem',
                      desc: 'İlk 50 içerisindesiniz.',
                      reward: '500 Elmas + 50k Altın',
                      isUnread: true,
                    ),
                    const SizedBox(height: 10),
                    _buildMailItemCard(
                      title: '[PAZAR] Miğfer Satıldı!',
                      sender: 'Pazar',
                      desc: '450k Altın satışı tamamlandı.',
                      reward: '436,500 Altın',
                      isUnread: true,
                    ),
                    const SizedBox(height: 10),
                    _buildMailItemCard(
                      title: '[GÜNCELLEME] Aion 2 Grafik',
                      sender: 'Daeva',
                      desc: 'Yeni grafik motoru aktif.',
                      reward: '100x İksir',
                      isUnread: false,
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 38,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_done, color: Colors.black, size: 22),
              label: const Text(
                'TÜM EKLERİ TOPLA',
                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildMailItemCard({
  required String title,
  required String sender,
  required String desc,
  required String reward,
  required bool isUnread,
}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: isUnread ? const Color(0xFF162035) : AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: isUnread ? AppColors.accentCyan : AppColors.borderFaint),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(isUnread ? Icons.mark_email_unread : Icons.mail_outline, color: isUnread ? AppColors.accentCyan : AppColors.textSecondary, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text('Gönderen: $sender', style: const TextStyle(color: AppColors.gold, fontSize: 8)),
        const SizedBox(height: 3),
        Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.bgDeep,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('Ek: $reward', style: const TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 20: SETTINGS & OPTIONS SCREEN (lib/screens/settings/)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildSettingsOptionsScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF0D121F), Color(0xFF0F1523), Color(0xFF080B12)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeaderBar(
                title: 'Ayarlar & Grafik',
                subtitle: 'Aion 2 TBDR Grafik Hattı',
                icon: Icons.settings,
                iconColor: AppColors.accentBlue,
                trailing: _buildCurrencyChip('Ultra', Icons.hd, AppColors.gold),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _buildSettingsSectionHeader('GRAFİK & PERFORMANS'),
                    const SizedBox(height: 6),
                    _buildSettingsTierSelector(),
                    const SizedBox(height: 8),
                    _buildSettingsToggleRow('ACES & Bloom', true),
                    _buildSettingsToggleRow('Sis & SSAO', true),
                    _buildSettingsToggleRow('60 FPS Sabitleme', true),
                    const SizedBox(height: 12),
                    _buildSettingsSectionHeader('SES & HAPTİCS'),
                    const SizedBox(height: 6),
                    _buildSettingsToggleRow('Hit-Stop Titreşimi', true),
                    _buildSettingsToggleRow('Sinematik Müzik', true),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 38,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.save, color: Colors.black, size: 22),
              label: const Text(
                'AYARLARI KAYDET',
                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSettingsSectionHeader(String title) {
  return Text(
    title,
    style: const TextStyle(color: AppColors.accentCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
  );
}

Widget _buildSettingsTierSelector() {
  return Container(
    height: 40,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Row(
      children: <Widget>[
        _buildTierOption('Eko', isSelected: false),
        _buildTierOption('Denge', isSelected: false),
        _buildTierOption('Yüksek', isSelected: false),
        _buildTierOption('Ultra', isSelected: true),
      ],
    ),
  );
}

Widget _buildTierOption(String label, {required bool isSelected}) {
  return Expanded(
    child: Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.gold : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.textSecondary,
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

Widget _buildSettingsToggleRow(String title, bool isChecked) {
  return Container(
    height: 44,
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 10), overflow: TextOverflow.ellipsis)),
        Icon(isChecked ? Icons.toggle_on : Icons.toggle_off, color: isChecked ? AppColors.success : AppColors.textTertiary, size: 28),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 21: PROFILE CARD & CODEX SCREEN (lib/screens/character/)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildProfileCardScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF140F24), Color(0xFF0F1523), Color(0xFF080B12)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeaderBar(
                title: 'Daeva Kimlik Kartı',
                subtitle: 'Savaş Gücü: 982k CP',
                icon: Icons.badge,
                iconColor: AppColors.gold,
                trailing: _buildCurrencyChip('GS 2.1k', Icons.shield, AppColors.gold),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _buildProfileAvatarHeader(),
                    const SizedBox(height: 12),
                    _buildProfileStatsGrid(),
                    const SizedBox(height: 12),
                    _buildCodexProgressBanner(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 38,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit, color: Colors.black, size: 22),
              label: const Text(
                'UNVANI & ROZETLERİ DÜZENLE',
                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildProfileAvatarHeader() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.gold, width: 1.2),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: AppColors.goldGlow, blurRadius: 14),
      ],
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: <Color>[AppColors.gold, Color(0xFFFF6B35)],
            ),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.person, color: Colors.black, size: 30),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text('ArchDaeva Aurelius', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Text('Yıldızların Fatihi', style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              SizedBox(height: 2),
              Text('Lonca: Ejderha Muhafızları', style: TextStyle(color: AppColors.accentCyan, fontSize: 8), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildProfileStatsGrid() {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Karakter Nitelikleri', style: TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _buildStatRow('Fiziksel Saldırı', '14,820', Icons.flash_on, AppColors.danger),
        _buildStatRow('Büyü Savunması', '12,650', Icons.security, AppColors.accentBlue),
        _buildStatRow('Kritik Vuruş', '%42.8', Icons.auto_awesome, AppColors.gold),
        _buildStatRow('Sağlık (HP)', '185,000', Icons.favorite, AppColors.success),
      ],
    ),
  );
}

Widget _buildStatRow(String label, String value, IconData icon, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: <Widget>[
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

Widget _buildCodexProgressBanner() {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.accentPurple),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        Text('Kodeks İlerlemesi (%78)', style: TextStyle(color: AppColors.accentPurple, fontSize: 10, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('• Canavarlar: 94/120', style: TextStyle(color: AppColors.textSecondary, fontSize: 8), overflow: TextOverflow.ellipsis),
        Text('• Ekipmanlar: 28/40', style: TextStyle(color: AppColors.textSecondary, fontSize: 8), overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 22: ACHIEVEMENTS & QUESTS SCREEN (lib/screens/quests/)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildAchievementsScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF141209), Color(0xFF0F1523), Color(0xFF080B12)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeaderBar(
                title: 'Başarımlar & Sezon',
                subtitle: 'Sezon 5: Daeva Uyanışı',
                icon: Icons.military_tech,
                iconColor: AppColors.gold,
                trailing: _buildCurrencyChip('Lvl 42', Icons.star, AppColors.gold),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: <Widget>[
                    _buildSeasonBattlePassBanner(),
                    const SizedBox(height: 12),
                    _buildAchievementTaskCard(
                      title: 'Zindan Fatihi: 3 Zindan Bitir',
                      progress: 1.0,
                      status: 'TAMAMLANDI',
                      reward: '500 Onur',
                      isClaimable: true,
                    ),
                    const SizedBox(height: 10),
                    _buildAchievementTaskCard(
                      title: 'Arena: 5 PvP Zaferi Kazan',
                      progress: 0.8,
                      status: '4/5 Yapıldı',
                      reward: '50x Taş',
                      isClaimable: false,
                    ),
                    const SizedBox(height: 10),
                    _buildAchievementTaskCard(
                      title: 'Demirci: +12 Eşya Geliştir',
                      progress: 1.0,
                      status: 'TAMAMLANDI',
                      reward: '1x Parşömen',
                      isClaimable: true,
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 38,
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.card_giftcard, color: Colors.black, size: 22),
              label: const Text(
                'TÜM GÖREV ÖDÜLLERİNİ TOPLA',
                style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSeasonBattlePassBanner() {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.gold, width: 1.2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: const <Widget>[
            Expanded(
              child: Text(
                'Sezon 5 Daeva Bileti',
                style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6),
            Text('14 Gün', style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 7,
            child: LinearProgressIndicator(
              value: 0.84,
              backgroundColor: AppColors.bgDeep,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Kademe 42 • Ödül: Daeva Kanat Kozmetiği',
          style: TextStyle(color: AppColors.accentCyan, fontSize: 8),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

Widget _buildAchievementTaskCard({
  required String title,
  required double progress,
  required String status,
  required String reward,
  required bool isClaimable,
}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: isClaimable ? AppColors.gold : AppColors.borderFaint),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.bgDeep,
              valueColor: AlwaysStoppedAnimation<Color>(isClaimable ? AppColors.success : AppColors.accentBlue),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                status,
                style: TextStyle(color: isClaimable ? AppColors.success : AppColors.textSecondary, fontSize: 8, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text('Ödül: $reward', style: const TextStyle(color: AppColors.gold, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TEST SUITE: BATCH 2 MOBILE GOLDEN SCREENSHOTS (SCREENS 12 TO 22)
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Mobile Golden Screenshots Batch 2 (Screens 12 to 22)', () {
    testWidgets('Screen 12: Combat Arena Screen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildCombatArenaScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '12_combat_arena_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 13: Boss Raid Screen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildBossRaidScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '13_boss_raid_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 14: Party Finder / Facilities Screen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildPartyFinderScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '14_party_finder_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 15: Crafting Workshop Screen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildCraftingWorkshopScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '15_crafting_workshop_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 16: Alchemy Lab Screen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildAlchemyLabScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '16_alchemy_lab_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 17: Blacksmith Forge Screen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildBlacksmithForgeScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '17_blacksmith_forge_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 18: Trade Market Screen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildTradeMarketScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '18_trade_market_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 19: Mailbox Screen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildMailboxScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '19_mailbox_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 20: Settings / Options Screen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildSettingsOptionsScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '20_settings_options_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 21: Profile Card Screen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildProfileCardScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '21_profile_card_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 22: Achievements Screen renders and captures cleanly', (WidgetTester tester) async {
      final GlobalKey repaintKey = GlobalKey();

      tester.view.physicalSize = const Size(kMobileWidth * kDevicePixelRatio, kMobileHeight * kDevicePixelRatio);
      tester.view.devicePixelRatio = kDevicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildAchievementsScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '22_achievements_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));

      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });
  });
}
