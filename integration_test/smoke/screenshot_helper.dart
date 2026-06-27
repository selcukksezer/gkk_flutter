import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// Route path → filesystem-safe screenshot basename.
String screenshotSlug(String path) {
  if (path == '/' || path.isEmpty) return 'splash';
  return path
      .replaceFirst(RegExp(r'^/'), '')
      .replaceAll('/', '_')
      .replaceAll('-', '_')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
}

/// Output directory from `--dart-define=AUDIT_SCREENSHOT_DIR=...`.
String? screenshotOutputDir() {
  const String fromDefine = String.fromEnvironment('AUDIT_SCREENSHOT_DIR');
  if (fromDefine.isNotEmpty) return fromDefine;
  return null;
}

class ScreenshotEntry {
  ScreenshotEntry({
    required this.route,
    required this.slug,
    this.file,
    this.bytes,
    this.error,
    this.screenFile,
  });

  final String route;
  final String slug;
  final String? file;
  final int? bytes;
  final String? error;
  final String? screenFile;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'route': route,
        'slug': slug,
        'file': file,
        'bytes': bytes,
        'error': error,
        'screen_file': screenFile,
        'status': error == null ? 'captured' : 'failed',
      };
}

class ScreenshotAuditManifest {
  ScreenshotAuditManifest({
    required this.runId,
    required this.outputDir,
    required this.device,
  });

  final String runId;
  final String outputDir;
  final String device;
  final List<ScreenshotEntry> entries = <ScreenshotEntry>[];
  final List<String> failures = <String>[];

  void addEntry(ScreenshotEntry entry) => entries.add(entry);

  void addFailure(String message) => failures.add(message);

  int get capturedCount =>
      entries.where((ScreenshotEntry e) => e.error == null).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'run_id': runId,
        'output_dir': outputDir,
        'device': device,
        'captured': capturedCount,
        'failed': entries.length - capturedCount,
        'failures': failures,
        'screenshots': entries.map((ScreenshotEntry e) => e.toJson()).toList(),
      };

  Future<void> writeToDisk() async {
    if (!writesScreenshotsOnHost) return;
    final File manifest = File('$outputDir/manifest.json');
    await manifest.parent.create(recursive: true);
    await manifest.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
  }
}

/// Known route → lib screen file mapping for audit reports.
const Map<String, String> routeScreenFiles = <String, String>{
  '/': 'lib/screens/auth/splash_screen.dart',
  '/login': 'lib/screens/auth/login_screen.dart',
  '/register': 'lib/screens/auth/register_screen.dart',
  '/onboarding/character-select': 'lib/screens/auth/character_select_screen.dart',
  '/home': 'lib/screens/home/home_screen.dart',
  '/inventory': 'lib/screens/inventory/inventory_screen.dart',
  '/dungeon': 'lib/screens/dungeon/dungeon_screen.dart',
  '/dungeon/battle': 'lib/screens/dungeon/dungeon_battle_screen.dart',
  '/character': 'lib/screens/character/character_screen.dart',
  '/horse-race': 'lib/screens/horse_race/horse_race_screen.dart',
  '/hospital': 'lib/screens/hospital/hospital_screen.dart',
  '/market': 'lib/screens/market/market_screen.dart',
  '/facilities': 'lib/screens/facilities/facilities_screen.dart',
  '/bank': 'lib/screens/bank/bank_screen.dart',
  '/chat': 'lib/screens/chat/chat_screen.dart',
  '/crafting': 'lib/screens/crafting/crafting_screen.dart',
  '/enhancement': 'lib/screens/enhancement/enhancement_screen.dart',
  '/guild': 'lib/screens/guild/guild_screen.dart',
  '/guild-war': 'lib/screens/guild_war/guild_war_hub_screen.dart',
  '/guild-war/logs': 'lib/screens/guild_war/war_logs_screen.dart',
  '/guild-war/battle-result': 'lib/screens/guild_war/battle_result_screen.dart',
  '/guild/monument': 'lib/screens/guild/guild_monument_screen.dart',
  '/guild/monument/donate': 'lib/screens/guild/guild_monument_donate_screen.dart',
  '/leaderboard': 'lib/screens/leaderboard/leaderboard_screen.dart',
  '/loot': 'lib/screens/loot/loot_hub_screen.dart',
  '/mekans': 'lib/screens/mekans/mekans_screen.dart',
  '/mekans/create': 'lib/screens/mekans/mekan_create_screen.dart',
  '/my-mekan': 'lib/screens/mekans/my_mekan_screen.dart',
  '/prison': 'lib/screens/prison/prison_screen.dart',
  '/pvp': 'lib/screens/pvp/pvp_screen.dart',
  '/pvp/history': 'lib/screens/pvp/pvp_history_screen.dart',
  '/pvp/tournament': 'lib/screens/pvp/pvp_tournament_screen.dart',
  '/quests': 'lib/screens/quests/quests_screen.dart',
  '/reputation': 'lib/screens/reputation/reputation_screen.dart',
  '/season': 'lib/screens/season/season_screen.dart',
  '/settings': 'lib/screens/settings/settings_screen.dart',
  '/shop': 'lib/screens/shop/shop_screen.dart',
  '/trade': 'lib/screens/trade/trade_screen.dart',
};

String? screenFileForRoute(String route) {
  if (routeScreenFiles.containsKey(route)) {
    return routeScreenFiles[route];
  }
  if (route.startsWith('/facilities/')) {
    return 'lib/screens/facilities/facility_detail_screen.dart';
  }
  if (route.contains('/guild-war/tournament/')) {
    return 'lib/screens/guild_war/tournament_detail_screen.dart';
  }
  if (route.contains('/guild-war/territory/')) {
    return 'lib/screens/guild_war/territory_detail_screen.dart';
  }
  if (route.contains('/mekans/') && route.endsWith('/arena')) {
    return 'lib/screens/mekans/mekan_arena_screen.dart';
  }
  if (route.startsWith('/mekans/')) {
    return 'lib/screens/mekans/mekan_detail_screen.dart';
  }
  return null;
}

/// Host-side flutter test can write PNGs directly; device runs rely on
/// [test_driver/screenshot_audit_driver.dart] to pull bytes to disk.
bool get writesScreenshotsOnHost {
  if (kIsWeb) return false;
  return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
}

/// Closes the daily reward modal if it is blocking the route under test.
/// Prefers non-destructive dismiss (Kapat / barrier tap) over claiming rewards.
Future<void> dismissBlockingOverlays(WidgetTester tester) async {
  await smokePump(tester, duration: const Duration(milliseconds: 600));

  final Finder dialogTitle = find.text('20 Günlük Ödül Yolu');
  if (dialogTitle.evaluate().isEmpty) {
    return;
  }

  final Finder kapat = find.text('Kapat');
  if (kapat.evaluate().isNotEmpty) {
    await tester.tap(kapat.first);
    await smokePump(tester, duration: const Duration(milliseconds: 500));
    return;
  }

  // Barrier tap — top-left, away from centered panel; does not claim rewards.
  await tester.tapAt(const Offset(12, 80));
  await smokePump(tester, duration: const Duration(milliseconds: 500));

  if (find.text('20 Günlük Ödül Yolu').evaluate().isNotEmpty) {
    final Finder outlined = find.byType(OutlinedButton);
    if (outlined.evaluate().isNotEmpty) {
      await tester.tap(outlined.first);
      await smokePump(tester, duration: const Duration(milliseconds: 500));
    }
  }
}

Future<void> captureRouteScreenshot({
  required IntegrationTestWidgetsFlutterBinding binding,
  required WidgetTester tester,
  required String routePath,
  required ScreenshotAuditManifest manifest,
}) async {
  final String slug = screenshotSlug(routePath);

  try {
    if (!kIsWeb && Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }

    await dismissBlockingOverlays(tester);
    await smokePump(tester, duration: const Duration(milliseconds: 900));

    final List<int> bytes = await binding.takeScreenshot(slug);

    if (bytes.isEmpty) {
      manifest.addEntry(
        ScreenshotEntry(
          route: routePath,
          slug: slug,
          error: 'empty screenshot bytes',
          screenFile: screenFileForRoute(routePath),
        ),
      );
      return;
    }

    String? savedPath;
    if (writesScreenshotsOnHost) {
      final String dir = screenshotOutputDir() ?? manifest.outputDir;
      final String filePath = '$dir/$slug.png';
      final File file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      savedPath = file.path;
    } else {
      savedPath = '${manifest.outputDir}/$slug.png';
    }

    manifest.addEntry(
      ScreenshotEntry(
        route: routePath,
        slug: slug,
        file: savedPath,
        bytes: bytes.length,
        screenFile: screenFileForRoute(routePath),
      ),
    );
  } catch (e) {
    manifest.addFailure('$routePath → $e');
    manifest.addEntry(
      ScreenshotEntry(
        route: routePath,
        slug: slug,
        error: e.toString(),
        screenFile: screenFileForRoute(routePath),
      ),
    );
  }
}
