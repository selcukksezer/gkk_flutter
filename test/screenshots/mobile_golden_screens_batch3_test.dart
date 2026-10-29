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

const Color kBorderGold = Color(0x80F5C842);
const Color kAccentGreen = AppColors.success;


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
// REUSABLE MOBILE UI SHELLS & ATOMS
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildAtmosphere({required Widget child}) {
  return Stack(
    children: <Widget>[
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF060913), Color(0xFF0F1523), Color(0xFF080B12)],
          ),
        ),
      ),
      Positioned(
        top: -60,
        left: -30,
        child: Container(
          width: 260,
          height: 260,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[Color(0x28F5C842), Colors.transparent],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 80,
        right: -40,
        child: Container(
          width: 240,
          height: 240,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[Color(0x225B8FFF), Colors.transparent],
            ),
          ),
        ),
      ),
      SafeArea(child: child),
    ],
  );
}

Widget _buildScreenHeader(String title, String subtitle, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: const BoxDecoration(
      color: Color(0xDD0B101D),
      border: Border(bottom: BorderSide(color: AppColors.borderFaint, width: 1)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderFaint),
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withOpacity(0.12),
            border: Border.all(color: AppColors.gold.withOpacity(0.4)),
          ),
          child: Icon(icon, size: 16, color: AppColors.gold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderGold),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              Icon(Icons.monetization_on, size: 12, color: AppColors.gold),
              SizedBox(width: 3),
              Text(
                '1.4M',
                style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildGlassBox({
  required Widget child,
  EdgeInsetsGeometry? padding,
  Color borderColor = AppColors.borderDefault,
  Color bgColor = const Color(0xB2111827),
}) {
  return Container(
    padding: padding ?? const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2)),
      ],
    ),
    child: child,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 23: LEADERBOARDS (Pantheon of Immortals)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildLeaderboardsScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: _buildAtmosphere(
      child: Column(
        children: <Widget>[
          _buildScreenHeader('PANTHEON OF IMMORTALS', 'Realm Season VII Leaderboard', Icons.emoji_events),
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                _buildFilterTab('Power Rating', isActive: true),
                const SizedBox(width: 6),
                _buildFilterTab('PvP Gladiators', isActive: false),
                const SizedBox(width: 6),
                _buildFilterTab('Dungeons', isActive: false),
                const SizedBox(width: 6),
                _buildFilterTab('Guilds', isActive: false),
              ],
            ),
          ),
          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: <Widget>[
                // Top 3 Podium
                _buildTopThreePodium(),
                const SizedBox(height: 12),
                // Current User Sticky Standing Card
                _buildGlassBox(
                  borderColor: AppColors.gold.withOpacity(0.6),
                  bgColor: const Color(0xDD182236),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '#42',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accentBlue,
                        child: Icon(Icons.person, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            Text('You (Kael)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Top 3.2% • Rising +4 Today', style: TextStyle(color: AppColors.accentCyan, fontSize: 10)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const <Widget>[
                          Text('98,420 CP', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Lvl 72 Templar', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Other Rankings
                _buildRankRow(4, 'Morrigan', 'Shadow Assassin', '128,450 CP', 'Eclipse [ECL]', Icons.security),
                _buildRankRow(5, 'Thorin_Oak', 'Iron Berserker', '124,190 CP', 'Valhalla [VAL]', Icons.shield),
                _buildRankRow(6, 'Lyanna_Star', 'Celestial Cleric', '119,820 CP', 'Solaris [SOL]', Icons.flare),
                _buildRankRow(7, 'Azazel_Void', 'Void Sorcerer', '116,500 CP', 'Nether [NTH]', Icons.auto_awesome),
                _buildRankRow(8, 'Balthazar', 'Dragon Knight', '112,300 CP', 'Draconis [DRC]', Icons.whatshot),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildFilterTab(String label, {required bool isActive}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? AppColors.gold.withOpacity(0.2) : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppColors.gold : AppColors.borderFaint,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.gold : AppColors.textSecondary,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}

Widget _buildTopThreePodium() {
  return _buildGlassBox(
    borderColor: kBorderGold,
    child: Column(
      children: <Widget>[
        const Text(
          'SEASON TITANS',
          style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            // #2 Silver
            _buildPodiumColumn(
              rank: 2,
              name: 'Valkyrie_X',
              power: '138,200',
              height: 70,
              medalColor: const Color(0xFFC0C0C0),
              crownIcon: Icons.military_tech,
            ),
            // #1 Gold
            _buildPodiumColumn(
              rank: 1,
              name: 'Aethelgard',
              power: '142,850',
              height: 95,
              medalColor: AppColors.gold,
              crownIcon: Icons.workspace_premium,
              isFirst: true,
            ),
            // #3 Bronze
            _buildPodiumColumn(
              rank: 3,
              name: 'ShadowFang',
              power: '135,400',
              height: 55,
              medalColor: const Color(0xFFCD7F32),
              crownIcon: Icons.military_tech,
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildPodiumColumn({
  required int rank,
  required String name,
  required String power,
  required double height,
  required Color medalColor,
  required IconData crownIcon,
  bool isFirst = false,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(crownIcon, color: medalColor, size: isFirst ? 26 : 20),
      const SizedBox(height: 2),
      Text(
        name,
        style: TextStyle(
          color: Colors.white,
          fontSize: isFirst ? 12 : 10,
          fontWeight: isFirst ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      Text(
        '$power CP',
        style: TextStyle(color: medalColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Container(
        width: 76,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              medalColor.withOpacity(0.35),
              medalColor.withOpacity(0.08),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: Border.all(color: medalColor.withOpacity(0.6)),
        ),
        child: Center(
          child: Text(
            '#$rank',
            style: TextStyle(color: medalColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ],
  );
}

Widget _buildRankRow(int rank, String name, String subtitle, String cp, String guild, IconData icon) {
  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x99111827),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.borderFaint),
    ),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 24,
          child: Text('#$rank', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        Icon(icon, size: 16, color: AppColors.accentCyan),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('$subtitle • $guild', style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
            ],
          ),
        ),
        Text(cp, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 24: PVP LEAGUE (Ranked Arena Division)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildPvpLeagueScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: _buildAtmosphere(
      child: Column(
        children: <Widget>[
          _buildScreenHeader('PVP GLADIATOR LEAGUE', 'Competitive 1v1 & 3v3 Arena', Icons.shield),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: <Widget>[
                // Season Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF3B121A), Color(0xFF1F0D15)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.coralFlare.withOpacity(0.6)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.local_fire_department, color: AppColors.coralFlare, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            Text('SEASON VII: BLOOD ASCENSION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('Ends in: 4d 18h 32m • Tier Rewards Primed', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.coralFlare.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.coralFlare),
                        ),
                        child: const Text('ACTIVE', style: TextStyle(color: AppColors.coralFlare, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Gladiator Division Card
                _buildGlassBox(
                  borderColor: AppColors.gold,
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: <Color>[AppColors.gold, Color(0xFF8B4513)],
                              ),
                              border: Border.all(color: AppColors.gold, width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.military_tech, color: Colors.white, size: 34),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const <Widget>[
                                Text('GRANDMASTER III', style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                SizedBox(height: 2),
                                Text('Rating: 2,845 MMR (Top 1.5%)', style: TextStyle(color: Colors.white, fontSize: 12)),
                                SizedBox(height: 4),
                                Text('Season Record: 84W - 18L (82.3% Win Rate)', style: TextStyle(color: AppColors.accentCyan, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          _buildStatChip('Win Streak', '5x Streak', Icons.bolt, AppColors.gold),
                          const SizedBox(width: 8),
                          _buildStatChip('Honor Rank', 'Legatus', Icons.star, AppColors.accentPurple),
                          const SizedBox(width: 8),
                          _buildStatChip('Glory Points', '3,450', Icons.military_tech, AppColors.accentCyan),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Game Mode Selector
                const Text('SELECT COMBAT DIVISION', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _buildModeCard('1v1 DUEL OF KINGS', 'Solo Ranked Ladder', Icons.person, 'Est. 14s', isSelected: true),
                    const SizedBox(width: 10),
                    _buildModeCard('3v3 ARENA SQUAD', 'Tri-Team Clashes', Icons.groups, 'Est. 28s', isSelected: false),
                  ],
                ),
                const SizedBox(height: 14),
                // Recent Match Log
                const Text('RECENT COMBAT HISTORY', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _buildMatchLogItem(isWin: true, opponent: 'IronClad_99', classType: 'Warrior', delta: '+24 MMR', duration: '48s'),
                _buildMatchLogItem(isWin: true, opponent: 'NightShade', classType: 'Rogue', delta: '+21 MMR', duration: '1m 12s'),
                _buildMatchLogItem(isWin: false, opponent: 'ArchMage_Zero', classType: 'Mage', delta: '-16 MMR', duration: '2m 04s'),
                const SizedBox(height: 14),
                // Large Queue Button
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[AppColors.gold, Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Color(0x60F5C842), blurRadius: 12, offset: Offset(0, 3)),
                    ],
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.sports_kabaddi, color: Colors.black, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'ENTER GLADIATOR QUEUE',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildStatChip(String title, String val, IconData icon, Color color) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0x66080B12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 8)),
          Text(val, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}

Widget _buildModeCard(String title, String sub, IconData icon, String wait, {required bool isSelected}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0x40F5C842) : const Color(0xB2111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.gold : AppColors.borderFaint,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: isSelected ? AppColors.gold : Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              const Icon(Icons.timer, size: 10, color: AppColors.accentCyan),
              const SizedBox(width: 3),
              Text(wait, style: const TextStyle(color: AppColors.accentCyan, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildMatchLogItem({
  required bool isWin,
  required String opponent,
  required String classType,
  required String delta,
  required String duration,
}) {
  final Color statusColor = isWin ? kAccentGreen : AppColors.coralFlare;
  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x99111827),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: statusColor.withOpacity(0.3)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isWin ? 'VICTORY' : 'DEFEAT',
            style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('vs $opponent', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              Text('$classType • $duration', style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
            ],
          ),
        ),
        Text(delta, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 25: AUCTION HOUSE (Grand Trading Post)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildAuctionHouseScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: _buildAtmosphere(
      child: Column(
        children: <Widget>[
          _buildScreenHeader('GRAND AUCTION EXCHANGE', 'Player-Driven Real-Time Market', Icons.storefront),
          // Search & Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xB2111827),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderFaint),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(Icons.search, size: 14, color: AppColors.textSecondary),
                        SizedBox(width: 6),
                        Expanded(child: Text('Search weapons, armor, runes...', style: TextStyle(color: AppColors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorderGold),
                  ),
                  child: const Icon(Icons.tune, size: 16, color: AppColors.gold),
                ),
              ],
            ),
          ),
          // Category Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: <Widget>[
                _buildCategoryPill('All Items', isSelected: true),
                _buildCategoryPill('Mythic Weapons', isSelected: false),
                _buildCategoryPill('Celestial Armor', isSelected: false),
                _buildCategoryPill('Ancient Runes', isSelected: false),
                _buildCategoryPill('Catalysts', isSelected: false),
              ],
            ),
          ),
          // Listings List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: <Widget>[
                _buildAuctionItemCard(
                  name: "Dragonfire Cleaver +15",
                  tier: 'Mythic Two-Handed Sword',
                  rarityColor: AppColors.coralFlare,
                  seller: 'LordAstaroth',
                  timeLeft: '42m',
                  currentBid: '450,000',
                  buyout: '680,000',
                  icon: Icons.gavel,
                ),
                _buildAuctionItemCard(
                  name: 'Celestial Aegis Robes',
                  tier: 'Legendary Robes (DEF +1,890)',
                  rarityColor: AppColors.gold,
                  seller: 'Seraphina',
                  timeLeft: '1h 15m',
                  currentBid: '280,000',
                  buyout: '350,000',
                  icon: Icons.shield,
                ),
                _buildAuctionItemCard(
                  name: 'Prismatic Void Crystal x50',
                  tier: 'Epic Crafting Catalyst',
                  rarityColor: AppColors.accentPurple,
                  seller: 'VoidMerchant',
                  timeLeft: '2h 40m',
                  currentBid: '95,000',
                  buyout: '120,000',
                  icon: Icons.diamond,
                ),
                _buildAuctionItemCard(
                  name: 'Ascendant Griffin Saddle',
                  tier: 'Mythic Mount Barding (+15% SPD)',
                  rarityColor: AppColors.accentCyan,
                  seller: 'SkyStrider',
                  timeLeft: '5h 10m',
                  currentBid: '310,000',
                  buyout: '420,000',
                  icon: Icons.flight,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCategoryPill(String label, {required bool isSelected}) {
  return Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: isSelected ? AppColors.gold.withOpacity(0.2) : AppColors.bgSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isSelected ? AppColors.gold : AppColors.borderFaint),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: isSelected ? AppColors.gold : AppColors.textSecondary,
        fontSize: 10,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    ),
  );
}

Widget _buildAuctionItemCard({
  required String name,
  required String tier,
  required Color rarityColor,
  required String seller,
  required String timeLeft,
  required String currentBid,
  required String buyout,
  required IconData icon,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xB2111827),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: rarityColor.withOpacity(0.5)),
    ),
    child: Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: rarityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: rarityColor),
              ),
              child: Icon(icon, color: rarityColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(tier, style: TextStyle(color: rarityColor, fontSize: 9, fontWeight: FontWeight.w600)),
                  Text('Seller: $seller • $timeLeft left', style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x66080B12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Current Bid', style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
                    Text('\ G', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Buyout Price', style: TextStyle(color: AppColors.gold, fontSize: 8, fontWeight: FontWeight.bold)),
                    Text('\ G', style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Buyout', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 26: PET SYSTEM (Familiar Sanctuary)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildPetSystemScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: _buildAtmosphere(
      child: Column(
        children: <Widget>[
          _buildScreenHeader('FAMILIAR SANCTUARY', 'Companion Beasts & Celestial Guardians', Icons.pets),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: <Widget>[
                // Active Pet Showcase Hero Card
                _buildGlassBox(
                  borderColor: AppColors.gold,
                  child: Column(
                    children: <Widget>[
                      // Pedestal & 3D Avatar
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const RadialGradient(
                            colors: <Color>[Color(0x55F5C842), Colors.transparent],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            // Glow halo
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 1.5),
                              ),
                            ),
                            // Pet Icon
                            const Icon(Icons.whatshot, size: 54, color: AppColors.coralFlare),
                            // Level & Star Badge
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('MAX 5★', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Active Battle Companion', style: TextStyle(color: AppColors.gold, fontSize: 9)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'CRIMSON DRAGONKIN (EMBER)',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const Text('Level 50 / 50 • Fire Elemental Affinity', style: TextStyle(color: AppColors.coralFlare, fontSize: 10)),
                      const SizedBox(height: 10),
                      // Pet Stats Bar
                      Row(
                        children: <Widget>[
                          _buildPetStat('Master ATK Bonus', '+15% DMG', AppColors.gold),
                          _buildPetStat('Crit Rate Aura', '+8% Rate', AppColors.coralFlare),
                          _buildPetStat('Companion Loyalty', '100% Max', kAccentGreen),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Active Skill Card
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0x66080B12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.coralFlare.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: <Widget>[
                            Icon(Icons.local_fire_department, color: AppColors.coralFlare, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('Active Skill: Inferno Nova (Cd: 20s)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  Text('Deals 480% AoE Fire damage to all surrounding enemies.', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('COMPANION ROSTER (4/12)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _buildPetRosterTile('Ember', 'Lvl 50', Icons.whatshot, AppColors.coralFlare, isActive: true),
                    const SizedBox(width: 8),
                    _buildPetRosterTile('Frost Drake', 'Lvl 42', Icons.ac_unit, AppColors.accentCyan, isActive: false),
                    const SizedBox(width: 8),
                    _buildPetRosterTile('Jade Sprite', 'Lvl 35', Icons.spa, kAccentGreen, isActive: false),
                    const SizedBox(width: 8),
                    _buildPetRosterTile('Void Stalker', 'Lvl 28', Icons.nights_stay, AppColors.accentPurple, isActive: false),
                  ],
                ),
                const SizedBox(height: 14),
                // Pet Action Controls
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorderGold),
                        ),
                        child: const Center(
                          child: Text('Feed Ambrosia (98%)', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('Ascend Stars', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildPetStat(String title, String val, Color color) {
  return Expanded(
    child: Column(
      children: <Widget>[
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 8)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

Widget _buildPetRosterTile(String name, String lvl, IconData icon, Color color, {required bool isActive}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.2) : const Color(0xB2111827),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? color : AppColors.borderFaint, width: isActive ? 1.5 : 1),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          Text(lvl, style: TextStyle(color: color, fontSize: 8)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 27: MOUNT SYSTEM (Celestial Stables)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildMountSystemScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: _buildAtmosphere(
      child: Column(
        children: <Widget>[
          _buildScreenHeader('CELESTIAL STABLES', 'War Mounts & Aerial Gliders', Icons.cruelty_free),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: <Widget>[
                // Active Mount Showcase
                _buildGlassBox(
                  borderColor: AppColors.accentCyan,
                  child: Column(
                    children: <Widget>[
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const RadialGradient(
                            colors: <Color>[Color(0x4406B6D4), Colors.transparent],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Icon(Icons.flight_takeoff, size: 64, color: AppColors.accentCyan),
                            Positioned(
                              bottom: 8,
                              child: Text(
                                'AERIAL SPEED: +120% MOUNTED SPEED',
                                style: TextStyle(color: AppColors.accentCyan, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'CELESTIAL ARMORED GRYPHON',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Text('Mythic Aerial Mount • Rank V Barding', style: TextStyle(color: AppColors.accentCyan, fontSize: 10)),
                      const SizedBox(height: 10),
                      // Stamina & Dash Gauge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: const <Widget>[
                              Expanded(
                                child: Text('Mount Stamina', style: TextStyle(color: AppColors.textSecondary, fontSize: 9), overflow: TextOverflow.ellipsis),
                              ),
                              Text('1,500 / 1,500 (3 Dashes)', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: 1.0,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Barding Slots
                      Row(
                        children: <Widget>[
                          _buildBardingSlot('Helm', 'Silver Crown', Icons.security),
                          const SizedBox(width: 8),
                          _buildBardingSlot('Saddle', 'Dragonhide', Icons.chair),
                          const SizedBox(width: 8),
                          _buildBardingSlot('Talismans', 'Swiftwind IV', Icons.auto_awesome),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('STABLE REPERTOIRE (3/8)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildStableItem('Armored Gryphon', 'Mythic Aerial • Active Mount', '+120% SPD', AppColors.accentCyan, true),
                _buildStableItem('Shadowfang Saber', 'Legendary Terrestrial Mount', '+85% SPD', AppColors.accentPurple, false),
                _buildStableItem('Solar Warhorse', 'Epic Steed', '+60% SPD', AppColors.gold, false),
                const SizedBox(height: 14),
                // Action Bar
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: <Color>[AppColors.accentCyan, Color(0xFF0284C7)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('MOUNT UP (DOUBLE-TAP ON FIELD)', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildBardingSlot(String slot, String name, IconData icon) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0x66080B12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accentCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.accentCyan),
          const SizedBox(height: 2),
          Text(slot, style: const TextStyle(color: AppColors.textSecondary, fontSize: 8)),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

Widget _buildStableItem(String name, String sub, String spd, Color color, bool isEquipped) {
  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xB2111827),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: isEquipped ? color : AppColors.borderFaint),
    ),
    child: Row(
      children: <Widget>[
        Icon(Icons.stars, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 8)),
            ],
          ),
        ),
        Text(spd, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 28: ARTIFACT SHRINE (Ancient Relics Altar)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildArtifactShrineScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: _buildAtmosphere(
      child: Column(
        children: <Widget>[
          _buildScreenHeader('ARTIFACT SHRINE', 'Sacred Altar of Divine Relics', Icons.auto_awesome),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: <Widget>[
                // Sacred Altar Centerpiece
                _buildGlassBox(
                  borderColor: AppColors.gold,
                  child: Column(
                    children: <Widget>[
                      // Circular Runic Altar
                      Container(
                        height: 130,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const RadialGradient(
                            colors: <Color>[Color(0x55F5C842), Colors.transparent],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.gold, width: 2),
                              ),
                              child: Center(
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.accentCyan.withOpacity(0.6), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                            const Icon(Icons.flare, size: 48, color: AppColors.gold),
                            Positioned(
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Resonance: 38,900 DPR', style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('HEART OF THE SUN GOD', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const Text('Tier V Divine Relic • Solar Infusion Complete', style: TextStyle(color: AppColors.gold, fontSize: 10)),
                      const SizedBox(height: 8),
                      // Passive Blessing
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0x66080B12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: <Widget>[
                            Icon(Icons.shield, color: AppColors.gold, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('Solar Dominion: +20% Fire Damage, +12% Spell Vamp to entire party.', style: TextStyle(color: Colors.white70, fontSize: 9)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('4 SACRED RELIC SOCKETS', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _buildRelicSlot('Sun Heart', 'Equipped', Icons.wb_sunny, AppColors.gold, true),
                    const SizedBox(width: 8),
                    _buildRelicSlot('Lunar Shard', 'Equipped', Icons.nightlight_round, AppColors.accentCyan, true),
                    const SizedBox(width: 8),
                    _buildRelicSlot('Void Eye', 'Equipped', Icons.remove_red_eye, AppColors.accentPurple, true),
                    const SizedBox(width: 8),
                    _buildRelicSlot('Yggdrasil', 'Unlocked', Icons.park, kAccentGreen, false),
                  ],
                ),
                const SizedBox(height: 14),
                // Infusion Progress
                _buildGlassBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: const <Widget>[
                          Expanded(
                            child: Text('Divine Essence Infusion', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          Text('340 / 500 Essence', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: 340 / 500,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: <Color>[AppColors.gold, Color(0xFFD97706)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('COMMENCE DIVINE INFUSION', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildRelicSlot(String name, String status, IconData icon, Color color, bool isEquipped) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isEquipped ? color.withOpacity(0.18) : const Color(0xB2111827),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isEquipped ? color : AppColors.borderFaint),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          Text(status, style: TextStyle(color: color, fontSize: 8)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 29: RUNE ENGRAVING (Runic Anvil & Sockets)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildRuneEngravingScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: _buildAtmosphere(
      child: Column(
        children: <Widget>[
          _buildScreenHeader('RUNIC ENGRAVING ANVIL', 'Socket Ancient Runes & Power Inscriptions', Icons.hardware),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: <Widget>[
                // Target Equipment Card
                _buildGlassBox(
                  borderColor: AppColors.coralFlare,
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.coralFlare.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.coralFlare),
                        ),
                        child: const Center(child: Icon(Icons.flash_on, color: AppColors.coralFlare, size: 28)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text("Oathkeeper's Blade +12", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('Mythic Grade Greatsword • 3 Rune Sockets', style: TextStyle(color: AppColors.coralFlare, fontSize: 10)),
                            Text('Base ATK: 3,420 • Crit Rate +14%', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 3 Sockets Status
                const Text('RUNE SOCKETS (2/3 ACTIVE)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildRuneSocketRow(1, 'Rune of Berserk VI', '+180 Physical Damage', AppColors.coralFlare, Icons.whatshot),
                _buildRuneSocketRow(2, 'Rune of Swiftness V', '+12% Attack Speed', AppColors.accentCyan, Icons.bolt),
                _buildRuneSocketRow(3, 'Empty Socket', 'Selected for Inscription', AppColors.gold, Icons.add_circle_outline, isEmpty: true),
                const SizedBox(height: 12),
                // Vault Runes
                const Text('SELECT INVENTORY RUNE', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildVaultRuneItem('Rune of Havoc VI', '+24% Critical Damage', 'Success: 100%', AppColors.gold, isSelected: true),
                _buildVaultRuneItem('Rune of Aegis VI', '+320 Physical Defense', 'Success: 85%', AppColors.accentBlue, isSelected: false),
                _buildVaultRuneItem('Rune of Leech V', '+6% Life Steal', 'Success: 90%', kAccentGreen, isSelected: false),
                const SizedBox(height: 14),
                // Charm Protection Check
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x66080B12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.check_circle, color: kAccentGreen, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Dragon Protection Charm Active: Weapon cannot shatter on failure.', style: TextStyle(color: Colors.white70, fontSize: 9)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Action Button
                Container(
                  width: double.infinity,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: <Color>[AppColors.gold, Color(0xFFB45309)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('ENGRAVE RUNE (15,000 GOLD)', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildRuneSocketRow(int num, String name, String effect, Color color, IconData icon, {bool isEmpty = false}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: isEmpty ? color.withOpacity(0.12) : const Color(0xB2111827),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.6), width: isEmpty ? 1.5 : 1),
    ),
    child: Row(
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Socket #$num: $name', style: TextStyle(color: isEmpty ? color : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(effect, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildVaultRuneItem(String name, String stat, String rate, Color color, {required bool isSelected}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: isSelected ? color.withOpacity(0.2) : const Color(0x66080B12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: isSelected ? color : AppColors.borderFaint),
    ),
    child: Row(
      children: <Widget>[
        Icon(Icons.diamond, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(stat, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
            ],
          ),
        ),
        Text(rate, style: const TextStyle(color: kAccentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 30: EVENT BATTLE PASS (Ascension Pass)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildEventBattlePassScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: _buildAtmosphere(
      child: Column(
        children: <Widget>[
          _buildScreenHeader('ASCENSION SEASON PASS', 'Season of the Celestial Phoenix', Icons.card_giftcard),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: <Widget>[
                // Header Banner
                _buildGlassBox(
                  borderColor: AppColors.gold,
                  bgColor: const Color(0xDD231508),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text('TIER 48 / 60', style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('ELITE PASS ACTIVE', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: const <Widget>[
                          Expanded(
                            child: Text('8,450 / 10,000 XP to Tier 49', style: TextStyle(color: Colors.white70, fontSize: 10), overflow: TextOverflow.ellipsis),
                          ),
                          Text('14d 8h Remaining', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: 0.845,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Rewards Track Preview (Horizontal)
                const Text('PASS REWARDS CORRIDOR', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _buildTierRewardCard(47, '100k Gold', 'Phoenix Wings Glider', isClaimed: true),
                      _buildTierRewardCard(48, '10x Potions', 'Celestial Pet Egg', isClaimed: true),
                      _buildTierRewardCard(49, '50 Diamonds', '500 Relic Essence', isClaimed: false, isCurrent: true),
                      _buildTierRewardCard(50, '150k Gold', 'MYTHIC HERO SKIN', isClaimed: false, isMilestone: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Weekly Quests
                const Text('WEEKLY CHALLENGES (2/3 COMPLETE)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildPassQuestItem('Slay 50 Dungeon Bosses', '48 / 50 Defeated', 0.96, '500 XP', false),
                _buildPassQuestItem('Win 10 PvP Arena Matches', '10 / 10 Completed', 1.0, '600 XP', true),
                _buildPassQuestItem('Infuse 5 Relics in Shrine', '3 / 5 Infused', 0.6, '450 XP', false),
                const SizedBox(height: 14),
                // Claim All Button
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: <Color>[AppColors.gold, Color(0xFFD97706)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('CLAIM ALL COMPLETED REWARDS', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTierRewardCard(int tier, String freeReward, String eliteReward, {bool isClaimed = false, bool isCurrent = false, bool isMilestone = false}) {
  return Container(
    width: 130,
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: isMilestone ? const Color(0xCC301B05) : const Color(0xB2111827),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isMilestone ? AppColors.gold : (isCurrent ? AppColors.accentCyan : AppColors.borderFaint),
        width: isMilestone || isCurrent ? 1.5 : 1,
      ),
    ),
    child: Column(
      children: <Widget>[
        Text('TIER $tier', style: TextStyle(color: isMilestone ? AppColors.gold : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        // Free
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
          child: Column(
            children: <Widget>[
              const Text('FREE', style: TextStyle(color: AppColors.textSecondary, fontSize: 7)),
              Text(freeReward, style: const TextStyle(color: Colors.white, fontSize: 9), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Elite
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
          child: Column(
            children: <Widget>[
              const Text('ELITE', style: TextStyle(color: AppColors.gold, fontSize: 7, fontWeight: FontWeight.bold)),
              Text(eliteReward, style: TextStyle(color: isMilestone ? AppColors.gold : Colors.white, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isClaimed ? 'CLAIMED' : (isCurrent ? 'NEXT' : 'LOCKED'),
          style: TextStyle(
            color: isClaimed ? kAccentGreen : (isCurrent ? AppColors.accentCyan : AppColors.textSecondary),
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget _buildPassQuestItem(String name, String progress, double frac, String xp, bool isDone) {
  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xB2111827),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: isDone ? kAccentGreen.withOpacity(0.4) : AppColors.borderFaint),
    ),
    child: Row(
      children: <Widget>[
        Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? kAccentGreen : AppColors.textSecondary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(progress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(xp, style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 31: DAILY LOGIN REWARDS (Celestial 28-Day Calendar)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildDailyLoginRewardsScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: _buildAtmosphere(
      child: Column(
        children: <Widget>[
          _buildScreenHeader('CELESTIAL ATTENDANCE', '28-Day Cycle • Cycle 4', Icons.calendar_today),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: <Widget>[
                // VIP Multiplier Banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: <Color>[Color(0xFF28183C), Color(0xFF140D22)]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accentPurple),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.workspace_premium, color: AppColors.gold, size: 24),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('VIP 6 PRIVILEGE ACTIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            Text('2x Multiplier applied on Days 7, 14, 21, and 28!', style: TextStyle(color: AppColors.accentPurple, fontSize: 9)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Today Highlight Card
                _buildGlassBox(
                  borderColor: AppColors.gold,
                  bgColor: const Color(0xDD1B2214),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.diamond, color: Colors.black, size: 26),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('DAY 19 (TODAY)', style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('200 Celestial Diamonds + 5x Summon Scroll', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('CLAIM', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Calendar Week View (Days 15 to 21)
                const Text('CURRENT WEEK ATTENDANCE (DAYS 15 - 21)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _buildDayTile(15, 'Claimed', Icons.check, isClaimed: true),
                    const SizedBox(width: 6),
                    _buildDayTile(16, 'Claimed', Icons.check, isClaimed: true),
                    const SizedBox(width: 6),
                    _buildDayTile(17, 'Claimed', Icons.check, isClaimed: true),
                    const SizedBox(width: 6),
                    _buildDayTile(18, 'Claimed', Icons.check, isClaimed: true),
                    const SizedBox(width: 6),
                    _buildDayTile(19, 'Ready', Icons.diamond, isToday: true),
                    const SizedBox(width: 6),
                    _buildDayTile(20, 'Locked', Icons.lock),
                    const SizedBox(width: 6),
                    _buildDayTile(21, 'Milestone', Icons.stars, isMilestone: true),
                  ],
                ),
                const SizedBox(height: 14),
                // Grand Final Prize Card
                _buildGlassBox(
                  borderColor: AppColors.gold,
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.military_tech, color: AppColors.gold, size: 36),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('DAY 28 GRAND CULMINATION', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Mythic Celestial Phoenix Armor Set + Title', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('9 Days Left', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDayTile(int day, String label, IconData icon, {bool isClaimed = false, bool isToday = false, bool isMilestone = false}) {
  final Color borderColor = isToday
      ? AppColors.gold
      : (isMilestone ? AppColors.accentPurple : (isClaimed ? kAccentGreen : AppColors.borderFaint));
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: isToday ? AppColors.gold.withOpacity(0.2) : const Color(0xB2111827),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: isToday || isMilestone ? 1.5 : 1),
      ),
      child: Column(
        children: <Widget>[
          Text('D$day', style: TextStyle(color: isToday ? AppColors.gold : Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Icon(icon, size: 14, color: borderColor),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: borderColor, fontSize: 7), overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 32: PUSH NOTIFICATIONS MODAL (Mobile Alert Center)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildPushNotificationsModalScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: _buildAtmosphere(
      child: Stack(
        children: <Widget>[
          // Background Dim with Blurred Game Behind
          Container(
            color: Colors.black.withOpacity(0.4),
          ),
          // Centered Glass Modal Sheet
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xF20F1626),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorderGold, width: 1.5),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Modal Header
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withOpacity(0.15),
                        ),
                        child: const Icon(Icons.notifications_active, color: AppColors.gold, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('REALM ALERTS & NOTIFICATIONS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('Mobile Background Notifications (Android & iOS)', style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                          ],
                        ),
                      ),
                      const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Mockup Dynamic Island Notification Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withOpacity(0.6)),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(Icons.bolt, color: AppColors.gold, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('⚔️ GKK Realm: Energy Fully Recharged!', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text('Your stamina has reached 120/120. Enter the Dungeon!', style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
                            ],
                          ),
                        ),
                        Text('now', style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Toggle Options
                  _buildPushToggle('Energy & Stamina Full', 'Instant alert when 120/120 energy restored', isEnabled: true),
                  _buildPushToggle('Auction House Sales & Bids', 'Get notified upon winning bids or item sales', isEnabled: true),
                  _buildPushToggle('World Boss & Guild War Incursions', '15-minute advance alert before siege battles', isEnabled: true),
                  _buildPushToggle('Daily Login Streak Reminders', 'Never lose your 28-day attendance streak', isEnabled: true),
                  _buildPushToggle('Promotional & Event News', 'Limited time diamond bundles & cosmetics', isEnabled: false),
                  const SizedBox(height: 14),
                  // Buttons
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderFaint),
                          ),
                          child: const Center(
                            child: Text('Dismiss', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('SAVE PREFERENCES', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
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
    ),
  );
}

Widget _buildPushToggle(String title, String sub, {required bool isEnabled}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 8)),
            ],
          ),
        ),
        Container(
          width: 36,
          height: 20,
          decoration: BoxDecoration(
            color: isEnabled ? AppColors.gold : Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Align(
            alignment: isEnabled ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 33: LOADING & SHADER WARM-UP (Impeller Pipeline Compilation)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildLoadingShaderWarmupScreen() {
  return Scaffold(
    backgroundColor: AppColors.bgDeep,
    body: Stack(
      children: <Widget>[
        // High Fantasy Atmospheric Sky
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF03050C), Color(0xFF0B1120), Color(0xFF060911)],
            ),
          ),
        ),
        // Nebulae / God-ray Halos
        Positioned(
          top: 100,
          left: 50,
          right: 50,
          child: Container(
            height: 240,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[Color(0x33F5C842), Color(0x2238BDF8), Colors.transparent],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // Game Logo / Title
                Column(
                  children: <Widget>[
                    const SizedBox(height: 20),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: <Color>[AppColors.gold, AppColors.coralFlare]),
                        border: Border.all(color: AppColors.gold, width: 2),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: Color(0x60F5C842), blurRadius: 16),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.shield, color: Colors.black, size: 36),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'GKK: REALM OF ASCENSION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const Text(
                      'AION-GRADE NEXT-GEN MOBILE MMORPG',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Center Spinner & Arcane Seal
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
                  ),
                  child: Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accentCyan.withOpacity(0.6), width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.auto_awesome, color: AppColors.gold, size: 36),
                      ),
                    ),
                  ),
                ),
                // Pipeline Compilation Details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Pipeline Progress
                    Row(
                      children: const <Widget>[
                        Expanded(
                          child: Text(
                            'Compiling Shader Pipelines (Metal / Vulkan TBDR)...',
                            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '88%',
                          style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0.88,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 12),
                    // Checkmarks
                    _buildShaderCheck('ACES Tonemapping & Bloom PSO: Compiled'),
                    _buildShaderCheck('Volumetric Fog & SSAO Compute Pipeline: Ready'),
                    _buildShaderCheck('10,000 Entity VAT Mesh Crowd Instancer: Primed'),
                    _buildShaderCheck('Preloading Texture Atlas & Audio Buffers (42/48)...', isPending: true),
                    const SizedBox(height: 14),
                    // Adaptive Quality Scaler Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x66080B12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorderGold),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.bolt, size: 14, color: kAccentGreen),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text('Adaptive Scaler: Ultra 60FPS Tier Verified', style: TextStyle(color: kAccentGreen, fontSize: 9, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Lore Tip
                    const Text(
                      'Tip: Aligning matching elemental runes unlocks latent divine resonance inside the Artifact Shrine.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
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

Widget _buildShaderCheck(String text, {bool isPending = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: <Widget>[
        Icon(
          isPending ? Icons.sync : Icons.check,
          size: 11,
          color: isPending ? AppColors.accentCyan : kAccentGreen,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isPending ? AppColors.accentCyan : AppColors.textSecondary,
              fontSize: 9,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTOMATED TEST SUITE: SCREENS 23 TO 33
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Automated Flutter Golden & Mobile Screenshot Capture Suite (Batch 3: Screens 23-33)', () {
    testWidgets('Screen 23: Leaderboards (Pantheon of Immortals) renders and captures cleanly', (WidgetTester tester) async {
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
          child: buildLeaderboardsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '23_leaderboard_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 24: PvP League renders and captures cleanly', (WidgetTester tester) async {
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
          child: buildPvpLeagueScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '24_pvp_league_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 25: Auction House renders and captures cleanly', (WidgetTester tester) async {
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
          child: buildAuctionHouseScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '25_auction_house_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 26: Pet System renders and captures cleanly', (WidgetTester tester) async {
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
          child: buildPetSystemScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '26_pet_system_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 27: Mount System renders and captures cleanly', (WidgetTester tester) async {
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
          child: buildMountSystemScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '27_mount_system_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 28: Artifact Shrine renders and captures cleanly', (WidgetTester tester) async {
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
          child: buildArtifactShrineScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '28_artifact_shrine_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 29: Rune Engraving renders and captures cleanly', (WidgetTester tester) async {
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
          child: buildRuneEngravingScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '29_rune_engraving_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 30: Event Battle Pass renders and captures cleanly', (WidgetTester tester) async {
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
          child: buildEventBattlePassScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '30_event_battle_pass_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 31: Daily Login Rewards renders and captures cleanly', (WidgetTester tester) async {
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
          child: buildDailyLoginRewardsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '31_daily_login_rewards_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 32: Push Notifications Modal renders and captures cleanly', (WidgetTester tester) async {
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
          child: buildPushNotificationsModalScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '32_push_notifications_modal_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    testWidgets('Screen 33: Loading & Shader Warm-up Screen renders and captures cleanly', (WidgetTester tester) async {
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
          child: buildLoadingShaderWarmupScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final File screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '33_loading_shader_warmup_mobile.png',
      );

      expect(screenshot.existsSync(), isTrue);
      expect(screenshot.lengthSync(), greaterThan(15000));
      final Uint8List header = screenshot.readAsBytesSync().sublist(0, 8);
      expect(header, equals(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });
  });
}
