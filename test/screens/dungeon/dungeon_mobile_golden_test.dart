import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/models/dungeon_model.dart';
import 'package:gkk_flutter/screens/dungeon/dungeon_zone_data.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/aion2_boss_illustration_catalog.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/aion2_presentation_frame.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_card.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_cave_theme.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_confirm_entry_dialog.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/dungeon_loot_dialog.dart';
import 'package:gkk_flutter/screens/dungeon/widgets/featured_cave_dungeon_card.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

/// Authentic mobile viewport specifications (390x844, iPhone 14 / modern standard mobile).
const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 2.0; // 780x1688 crisp mobile golden render
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

const String kOutputDirReports = 'reports/screenshots/mobile_goldens';
const String kOutputDirLocal = 'test/screens/dungeon/goldens';

// Standard 8-byte PNG header magic bytes signature
const List<int> kPngMagicSignature = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
];

/// Genuine in-memory asset bundle providing fallback 1x1 transparent PNG data
/// for any texture or image request that does not exist on disk, preventing
/// missing asset errors or crashes in headless test runners.
class DungeonMockAssetBundle extends CachingAssetBundle {
  DungeonMockAssetBundle._();
  static final DungeonMockAssetBundle instance = DungeonMockAssetBundle._();

  static final Uint8List _fallbackPngBytes = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  @override
  Future<ByteData> load(String key) async {
    final File localFile = File(key);
    if (localFile.existsSync()) {
      final Uint8List bytes = await localFile.readAsBytes();
      return ByteData.view(bytes.buffer);
    }
    return ByteData.view(_fallbackPngBytes.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final File localFile = File(key);
    if (localFile.existsSync()) {
      return localFile.readAsString();
    }
    return '';
  }
}

/// Mock HttpOverrides ensuring zero network egress and zero network image crashes.
class DungeonMockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addAuthenticate(Uri url, String realm, HttpClientAuthentication credential) {}
  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _MockHttpClientRequest();
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);
  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) =>
      openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> get(String host, int port, String path) => open('GET', host, port, path);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) => open('POST', host, port, path);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) => open('PUT', host, port, path);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => open('DELETE', host, port, path);
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => open('PATCH', host, port, path);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) => open('HEAD', host, port, path);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => DungeonMockAssetBundle._fallbackPngBytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(DungeonMockAssetBundle._fallbackPngBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Sets authentic mobile 390x844 dimensions with DPR 2.0 and exact SafeArea insets.
void setMobileViewDimensions(WidgetTester tester) {
  tester.view.physicalSize = const Size(
    kMobileWidth * kDevicePixelRatio,
    kMobileHeight * kDevicePixelRatio,
  );
  tester.view.devicePixelRatio = kDevicePixelRatio;
  tester.view.padding = const FakeViewPadding(
    top: 47.0 * kDevicePixelRatio,
    bottom: 34.0 * kDevicePixelRatio,
    left: 0.0,
    right: 0.0,
  );
}

/// Resets view dimensions to testing environment defaults.
void resetMobileViewDimensions(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.view.resetPadding();
}

/// Utility to capture widget to PNG file on disk in both reports and local test folders.
Future<List<File>> captureWidgetToPng({
  required WidgetTester tester,
  required GlobalKey repaintKey,
  required String filename,
}) async {
  for (final String path in <String>[kOutputDirReports, kOutputDirLocal]) {
    final Directory dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  final List<File> savedFiles = <File>[];
  await tester.runAsync(() async {
    final BuildContext? context = repaintKey.currentContext;
    if (context == null) {
      throw StateError('RepaintBoundary context is null for $filename');
    }
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('RenderObject is not a RenderRepaintBoundary for $filename');
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: kDevicePixelRatio);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode image to PNG for $filename');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    for (final String path in <String>[kOutputDirReports, kOutputDirLocal]) {
      final File file = File('$path/$filename');
      await file.writeAsBytes(pngBytes, flush: true);
      savedFiles.add(file);
    }
  });

  return savedFiles;
}

/// Verifies that captured PNG file meets golden integrity requirements:
/// - File exists on disk
/// - Size exceeds minBytes (ensuring non-empty visual rendering)
/// - Starts with valid 8-byte PNG magic header [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
void verifyMobileGoldenFile(File file, {int minBytes = 10000}) {
  expect(file.existsSync(), isTrue, reason: 'Golden PNG must exist on disk: ${file.path}');
  expect(
    file.lengthSync(),
    greaterThan(minBytes),
    reason: 'Golden PNG should contain visual pixel data (> $minBytes bytes)',
  );
  final Uint8List header = file.readAsBytesSync().sublist(0, 8);
  expect(
    header,
    equals(kPngMagicSignature),
    reason: 'File must begin with valid PNG magic header',
  );
}

/// Helper wrapper that enforces authentic 390x844 mobile viewport, devicePixelRatio, safe area, and asset mocking.
Widget buildMobileTestHarness({
  required GlobalKey repaintKey,
  required Widget child,
  AssetBundle? assetBundle,
  ThemeData? customTheme,
}) {
  final AssetBundle bundle = assetBundle ?? DungeonMockAssetBundle.instance;

  final ThemeData theme = customTheme ??
      ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080B12),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          secondary: const Color(0xFF6366F1),
          surface: const Color(0xFF0F1523),
          error: AppColors.danger,
        ),
      );

  return DefaultAssetBundle(
    bundle: bundle,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(kMobileWidth, kMobileHeight),
          devicePixelRatio: kDevicePixelRatio,
          padding: kMobileSafeArea,
          viewPadding: kMobileSafeArea,
          viewInsets: EdgeInsets.zero,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(
            key: repaintKey,
            child: SizedBox(
              width: kMobileWidth,
              height: kMobileHeight,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// 3D ARENA & ATMOSPHERE CUSTOM PAINTER (Mobile TBDR & Impeller Optimized)
// ─────────────────────────────────────────────────────────────────────────────

class DungeonArena3DAtmospherePainter extends CustomPainter {
  const DungeonArena3DAtmospherePainter({
    this.isEnraged = false,
    this.showArena3D = true,
    this.showTorches = true,
    this.showMist = true,
    this.showDecals = true,
    this.showShadows = true,
    this.time = 1.5,
  });

  final bool isEnraged;
  final bool showArena3D;
  final bool showTorches;
  final bool showMist;
  final bool showDecals;
  final bool showShadows;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final double horizonY = size.height * 0.42;

    // 1. Deep Cavern Gradient
    final Rect bgRect = Offset.zero & size;
    final Paint bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.5, 0),
        Offset(size.width * 0.5, size.height),
        <Color>[
          isEnraged ? const Color(0xFF22070A) : const Color(0xFF060912),
          isEnraged ? const Color(0xFF140508) : const Color(0xFF0C101D),
          const Color(0xFF05070D),
        ],
      );
    canvas.drawRect(bgRect, bgPaint);

    // 2. 3D Perspective Ground Plane & Stone Flagstone Grid
    if (showArena3D) {
      final Path groundPath = Path()
        ..moveTo(0, horizonY)
        ..lineTo(size.width, horizonY)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();

      final Paint groundPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, horizonY),
          Offset(size.width * 0.5, size.height),
          <Color>[
            isEnraged ? const Color(0xFF330B10) : const Color(0xFF111827),
            const Color(0xFF070B14),
          ],
        );
      canvas.drawPath(groundPath, groundPaint);

      // Perspective Grid Lines
      final Paint gridPaint = Paint()
        ..color = (isEnraged ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)).withValues(alpha: 0.12)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      const int vLines = 8;
      for (int i = 0; i <= vLines; ++i) {
        final double xBottom = size.width * (i / vLines);
        final double xTop = size.width * 0.5 + (xBottom - size.width * 0.5) * 0.18;
        canvas.drawLine(Offset(xTop, horizonY), Offset(xBottom, size.height), gridPaint);
      }

      const int hLines = 6;
      for (int i = 1; i <= hLines; ++i) {
        final double t = math.pow(i / hLines, 2.0).toDouble();
        final double y = horizonY + (size.height - horizonY) * t;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // 3. Dynamic Soft Shadows
    if (showShadows) {
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

      // Central Boss Occluder Shadow
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.62),
          width: 140,
          height: 36,
        ),
        shadowPaint,
      );

      // Pillar Occluder Shadows
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.18, size.height * 0.52),
          width: 50,
          height: 18,
        ),
        shadowPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.82, size.height * 0.52),
          width: 50,
          height: 18,
        ),
        shadowPaint,
      );
    }

    // 4. Ground Decals (Cracked stone, Scorch marks, Blood splatters)
    if (showDecals) {
      // Scorch Mark
      final Paint scorchPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.52, size.height * 0.64),
          55,
          <Color>[
            isEnraged ? const Color(0xAAFF3300) : const Color(0x77000000),
            Colors.transparent,
          ],
        );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.52, size.height * 0.64),
          width: 110,
          height: 32,
        ),
        scorchPaint,
      );

      // Cracked Earth Fissures
      final Paint crackPaint = Paint()
        ..color = (isEnraged ? const Color(0xFFFF5722) : const Color(0xFF64748B)).withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final Path fissure = Path()
        ..moveTo(size.width * 0.48, size.height * 0.61)
        ..lineTo(size.width * 0.44, size.height * 0.65)
        ..lineTo(size.width * 0.38, size.height * 0.66)
        ..moveTo(size.width * 0.48, size.height * 0.61)
        ..lineTo(size.width * 0.54, size.height * 0.64)
        ..lineTo(size.width * 0.62, size.height * 0.65);
      canvas.drawPath(fissure, crackPaint);

      // Slash Gouge Decal
      final Paint slashPaint = Paint()
        ..color = (isEnraged ? const Color(0xFFFF1744) : const Color(0xFF38BDF8)).withValues(alpha: 0.5)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(size.width * 0.32, size.height * 0.70),
        Offset(size.width * 0.42, size.height * 0.67),
        slashPaint,
      );
    }

    // 5. Dynamic Torch Lights & Radial Emissives
    if (showTorches) {
      final Color leftTorchColor = isEnraged ? const Color(0xFFFF1744) : const Color(0xFFFF8C00);
      final Color rightTorchColor = isEnraged ? const Color(0xFFFF5252) : const Color(0xFF00E5FF);

      // Left Torch Emissive Flare
      final Paint leftFlare = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.12, horizonY * 0.75),
          70,
          <Color>[
            leftTorchColor.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        );
      canvas.drawCircle(Offset(size.width * 0.12, horizonY * 0.75), 70, leftFlare);

      // Right Torch Emissive Flare
      final Paint rightFlare = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.88, horizonY * 0.75),
          70,
          <Color>[
            rightTorchColor.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        );
      canvas.drawCircle(Offset(size.width * 0.88, horizonY * 0.75), 70, rightFlare);
    }

    // 6. Volumetric Mist Wisps
    if (showMist) {
      final Paint mistPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizonY - 20),
          Offset(0, horizonY + 80),
          <Color>[
            Colors.transparent,
            (isEnraged ? const Color(0x33FF1744) : const Color(0x2238BDF8)),
            Colors.transparent,
          ],
        );
      canvas.drawRect(
        Rect.fromLTRB(0, horizonY - 20, size.width, horizonY + 80),
        mistPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DungeonArena3DAtmospherePainter oldDelegate) {
    return oldDelegate.isEnraged != isEnraged ||
        oldDelegate.showTorches != showTorches ||
        oldDelegate.time != time;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 1: DUNGEON HUB / ZONE SELECTION SCREEN (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildDungeonHubScreen() {
  return Scaffold(
    backgroundColor: const Color(0xFF060911),
    body: Stack(
      children: <Widget>[
        // Layer 1: Ambient 3D Cavern Background
        Positioned.fill(
          child: CustomPaint(
            painter: const DungeonArena3DAtmospherePainter(
              isEnraged: false,
              showTorches: false,
              showArena3D: false,
              showMist: true,
              showDecals: false,
              showShadows: false,
            ),
          ),
        ),
        // Layer 2: SafeArea Mobile Layout
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Top Bar
              _buildDungeonHubTopBar(),
              // Zone Tabs
              _buildDungeonZoneTabs(),
              // Zone Banner
              _buildDungeonZoneBanner(),
              // Dungeon Cards List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                  children: <Widget>[
                    _buildFeaturedCaveCard(
                      title: 'GÖLGE UÇURUMU TAPINAĞI',
                      subtitle: 'Bölge 1 — Kadim Boss Tapınağı',
                      levelReq: 35,
                      energyCost: 15,
                      difficulty: 'ZORLU',
                      difficultyColor: const Color(0xFFEF4444),
                      drops: <String>['⚔️ Efsanevi Kılıç', '💎 Ejder Taşı', '🛡️ Zırh'],
                      bgGradient: const <Color>[Color(0xFF2C1014), Color(0xFF160A0D)],
                    ),
                    const SizedBox(height: 12),
                    _buildStandardDungeonCard(
                      title: 'Kristalize Mağara',
                      zone: 'Bölge 1',
                      levelReq: 25,
                      energyCost: 10,
                      powerReq: 1200,
                      isCleared: true,
                      stars: 3,
                    ),
                    const SizedBox(height: 10),
                    _buildStandardDungeonCard(
                      title: 'Kızıl Kükürt Madeni',
                      zone: 'Bölge 1',
                      levelReq: 30,
                      energyCost: 12,
                      powerReq: 1450,
                      isCleared: false,
                      stars: 2,
                    ),
                    const SizedBox(height: 10),
                    _buildStandardDungeonCard(
                      title: 'Obsidiyen Katakompları',
                      zone: 'Bölge 1',
                      levelReq: 38,
                      energyCost: 18,
                      powerReq: 1900,
                      isCleared: false,
                      stars: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Layer 3: Mobile Bottom Navigation Bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildDungeonBottomBar(selectedIndex: 2),
        ),
      ],
    ),
  );
}

Widget _buildDungeonHubTopBar() {
  return Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: const BoxDecoration(
      color: Color(0xDD090C15),
      border: Border(bottom: BorderSide(color: Color(0x33C8AA6E), width: 1)),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.shield_outlined, color: Color(0xFFD4AF37), size: 22),
        const SizedBox(width: 8),
        const Text(
          'ZİNDANLAR & TAPINAKLAR',
          style: TextStyle(
            color: Color(0xFFF3E7C4),
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        // Energy Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x2210B981),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x6610B981), width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.bolt, color: Color(0xFF10B981), size: 14),
              SizedBox(width: 4),
              Text(
                '85 / 100',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildDungeonZoneTabs() {
  final List<String> zones = <String>[
    'Tüm Zindanlar',
    'Bölge 1: Mağaralar',
    'Bölge 2: Katakomp',
    'Bölge 3: Uçurum',
  ];
  return Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    color: const Color(0x9906080F),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: zones.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (BuildContext context, int index) {
        final bool selected = index == 1;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0x33D4AF37) : const Color(0x221A2234),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFFD4AF37) : const Color(0x333A4A66),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              zones[index],
              style: TextStyle(
                color: selected ? const Color(0xFFF5DF9E) : const Color(0xFF8E9BAE),
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildDungeonZoneBanner() {
  return Container(
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: <Color>[Color(0xFF1E2638), Color(0xFF121724)],
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x44D4AF37)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x33D4AF37),
            border: Border.all(color: const Color(0xFFD4AF37)),
          ),
          child: const Center(
            child: Text(
              '1',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'BÖLGE 1: KARANLIK DERİNLİKLER',
                style: TextStyle(
                  color: Color(0xFFF3E7C4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Giriş Şartı: Sv. 20+ • 4 Zindan Mevcut',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x3310B981),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x6610B981)),
          ),
          child: const Text(
            'KİLİT AÇIK',
            style: TextStyle(
              color: Color(0xFF10B981),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildFeaturedCaveCard({
  required String title,
  required String subtitle,
  required int levelReq,
  required int energyCost,
  required String difficulty,
  required Color difficultyColor,
  required List<String> drops,
  required List<Color> bgGradient,
}) {
  return Container(
    height: 180,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x88D4AF37), width: 1.5),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x33D4AF37),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: bgGradient,
      ),
    ),
    child: Stack(
      children: <Widget>[
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, -0.4),
                  radius: 1.2,
                  colors: <Color>[
                    const Color(0x22D4AF37),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header Row
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: difficultyColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: difficultyColor, width: 1),
                    ),
                    child: Text(
                      difficulty,
                      style: TextStyle(
                        color: difficultyColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x33D4AF37),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD4AF37), width: 0.8),
                    ),
                    child: Text(
                      'Sv. $levelReq+',
                      style: const TextStyle(
                        color: Color(0xFFF3E7C4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Energy Cost
                  Row(
                    children: <Widget>[
                      const Icon(Icons.bolt, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 2),
                      Text(
                        '$energyCost Enerji',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              // Title
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF9F5EC),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFB0BAC9),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              // Loot Preview Pills
              Row(
                children: drops.map((String drop) {
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x44FFFFFF)),
                    ),
                    child: Text(
                      drop,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 10,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              // CTA Button
              SizedBox(
                height: 34,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.explore, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'ZİNDANA MEYDAN OKU',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
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

Widget _buildStandardDungeonCard({
  required String title,
  required String zone,
  required int levelReq,
  required int energyCost,
  required int powerReq,
  required bool isCleared,
  required int stars,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF0F1523),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x33475569)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0x226366F1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x556366F1)),
          ),
          child: const Icon(Icons.terrain, color: Color(0xFF818CF8), size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF1F5F9),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: <Widget>[
                  Text(
                    'Sv. $levelReq',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Color(0xFF475569))),
                  const SizedBox(width: 8),
                  Text(
                    'Güç: $powerReq',
                    style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  ...List<Widget>.generate(3, (int s) {
                    return Icon(
                      s < stars ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFBBF24),
                      size: 12,
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: const Color(0xFFF3E7C4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0x66D4AF37)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.bolt, color: Color(0xFF10B981), size: 14),
              Text(
                '$energyCost',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildDungeonBottomBar({required int selectedIndex}) {
  final List<({IconData icon, String label})> tabs = <({IconData icon, String label})>[
    (icon: Icons.shield, label: 'Karakter'),
    (icon: Icons.inventory_2, label: 'Envanter'),
    (icon: Icons.castle, label: 'Zindan'),
    (icon: Icons.sports_mma, label: 'PvP'),
    (icon: Icons.storefront, label: 'Pazar'),
  ];
  return Container(
    height: 56,
    decoration: const BoxDecoration(
      color: Color(0xFA090C15),
      border: Border(top: BorderSide(color: Color(0x33475569), width: 1)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List<Widget>.generate(tabs.length, (int i) {
        final bool isSelected = i == selectedIndex;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              tabs[i].icon,
              color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF64748B),
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              tabs[i].label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF64748B),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 2: ACTIVE DUNGEON BOSS COMBAT SCREEN (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildActiveDungeonBossCombatScreen({
  bool isEnraged = false,
  double bossHpPercent = 0.85,
}) {
  return Scaffold(
    backgroundColor: const Color(0xFF07090E),
    body: Stack(
      children: <Widget>[
        // Layer 1: 3D Arena & Atmosphere
        Positioned.fill(
          child: CustomPaint(
            painter: DungeonArena3DAtmospherePainter(
              isEnraged: isEnraged,
              showTorches: true,
              showArena3D: true,
              showMist: true,
              showDecals: true,
              showShadows: true,
            ),
          ),
        ),
        // Layer 2: Main Combat Interface within SafeArea
        SafeArea(
          child: Column(
            children: <Widget>[
              // Combat Header with Dungeon Name & Escape Button
              _buildCombatHeader(dungeonName: 'Karanlık Uçurum — Kat 12'),
              // Abyssal Boss Health Gauge & Avatar
              _buildAbyssalBossUi(
                bossName: 'İGNİS — KÖZLERİN EFENDİSİ',
                level: 45,
                hpPercent: bossHpPercent,
                isEnraged: isEnraged,
              ),
              // Mid-Screen Combat Arena Visualization
              Expanded(
                child: _buildCombatArenaCenterView(isEnraged: isEnraged),
              ),
              // Player Status HUD (HP, Energy, Class)
              _buildPlayerCombatHud(),
              const SizedBox(height: 6),
              // Mobile Thumb-Friendly Combat Action Deck
              _buildCombatActionDeck(isEnraged: isEnraged),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildCombatHeader({required String dungeonName}) {
  return Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0x33000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 10),
        Text(
          dungeonName,
          style: const TextStyle(
            color: Color(0xFFF3E7C4),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x33EF4444),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x66EF4444)),
          ),
          child: const Row(
            children: <Widget>[
              Icon(Icons.directions_run, color: Color(0xFFEF4444), size: 14),
              SizedBox(width: 4),
              Text(
                'KAÇ',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildAbyssalBossUi({
  required String bossName,
  required int level,
  required double hpPercent,
  required bool isEnraged,
}) {
  final Color barColor = isEnraged ? const Color(0xFFDC2626) : const Color(0xFFF59E0B);
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isEnraged
            ? <Color>[const Color(0xAA450A0A), const Color(0xAA1C0505)]
            : <Color>[const Color(0xAA1E293B), const Color(0xAA0F172A)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isEnraged ? const Color(0xFFEF4444) : const Color(0x66D4AF37),
        width: 1.5,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: isEnraged ? const Color(0x44EF4444) : const Color(0x22D4AF37),
          blurRadius: 12,
        ),
      ],
    ),
    child: Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    isEnraged ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                    Colors.black,
                  ],
                ),
                border: Border.all(
                  color: isEnraged ? const Color(0xFFFCA5A5) : const Color(0xFFD4AF37),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text('👹', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          bossName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isEnraged ? const Color(0xFFFCA5A5) : const Color(0xFFF8FAFC),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      if (isEnraged)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ÖFKE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0x44D4AF37),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Sv. $level BOSS',
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(hpPercent * 100).toInt()}% CAN',
                        style: TextStyle(
                          color: barColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: <Widget>[
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F1D),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x4464748B)),
              ),
            ),
            FractionallySizedBox(
              widthFactor: hpPercent.clamp(0.0, 1.0),
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isEnraged
                        ? <Color>[const Color(0xFFDC2626), const Color(0xFFF87171)]
                        : <Color>[const Color(0xFFD97706), const Color(0xFFFBBF24)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: barColor.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildCombatArenaCenterView({required bool isEnraged}) {
  return Stack(
    alignment: Alignment.center,
    children: <Widget>[
      Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isEnraged
                  ? <Color>[const Color(0x66EF4444), Colors.transparent]
                  : <Color>[const Color(0x44D4AF37), Colors.transparent],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.sports_martial_arts,
              color: isEnraged ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
              size: 80,
            ),
          ),
        ),
      ),
      Positioned(
        top: 60,
        right: 80,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isEnraged ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
            ),
          ),
          child: Text(
            isEnraged ? '-2,450 KRİTİK!' : '-1,120',
            style: TextStyle(
              color: isEnraged ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 10,
        left: 20,
        right: 20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xAA0B0F19),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x33475569)),
          ),
          child: Text(
            isEnraged
                ? 'İgnis alev saçarak öfke durumuna geçti! Hasar +%50!'
                : 'Kılıç savuruşu canavara 1,120 hasar verdi.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildPlayerCombatHud() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 14),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xDD0F172A),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x4464748B)),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E293B),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
          ),
          child: const Center(
            child: Text('⚔️', style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text(
                    'HP',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: 0.72,
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: <Color>[Color(0xFFDC2626), Color(0xFFF87171)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '864 / 1,200',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  const Text(
                    'MP',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: 0.55,
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: <Color>[Color(0xFF2563EB), Color(0xFF60A5FA)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '55 / 100',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildCombatActionDeck({required bool isEnraged}) {
  return Container(
    height: 74,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _buildActionDeckButton(
          icon: Icons.flash_on,
          label: 'Saldır',
          color: const Color(0xFFEF4444),
          badge: '1x',
          onTap: () {},
        ),
        _buildActionDeckButton(
          icon: Icons.auto_awesome,
          label: 'Ejder Darbesi',
          color: const Color(0xFFF59E0B),
          badge: '25 MP',
          onTap: () {},
        ),
        _buildActionDeckButton(
          icon: Icons.local_pharmacy,
          label: 'İksir',
          color: const Color(0xFF10B981),
          badge: 'x4',
          onTap: () {},
        ),
        _buildActionDeckButton(
          icon: Icons.shield,
          label: 'Kalkan',
          color: const Color(0xFF6366F1),
          badge: 'Hazır',
          onTap: () {},
        ),
        _buildActionDeckButton(
          icon: Icons.repeat,
          label: 'Otomatik',
          color: const Color(0xFF8B5CF6),
          badge: 'AÇIK',
          isToggled: true,
          onTap: () {},
        ),
      ],
    ),
  );
}

Widget _buildActionDeckButton({
  required IconData icon,
  required String label,
  required Color color,
  required String badge,
  bool isToggled = false,
  required VoidCallback onTap,
}) {
  return Container(
    width: 66,
    height: 70,
    decoration: BoxDecoration(
      color: isToggled ? color.withValues(alpha: 0.25) : const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isToggled ? color : const Color(0x4464748B),
        width: 1.2,
      ),
      boxShadow: isToggled
          ? <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 8,
              ),
            ]
          : null,
    ),
    child: Stack(
      children: <Widget>[
        Positioned(
          top: 3,
          right: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF1F5F9),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
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
// SCREEN 3: DUNGEON VICTORY & LOOT MODAL (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildDungeonVictoryLootScreen() {
  return Scaffold(
    backgroundColor: const Color(0xFF07090E),
    body: Stack(
      children: <Widget>[
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.2),
                radius: 1.0,
                colors: <Color>[
                  Color(0x33D4AF37),
                  Color(0xFA05070C),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x55D4AF37),
                    blurRadius: 24,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.emoji_events, color: Color(0xFFD4AF37), size: 48),
                  const SizedBox(height: 8),
                  const Text(
                    'ZİNDAN TEMİZLENDİ!',
                    style: TextStyle(
                      color: Color(0xFFF5E3B3),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kadim Közlerin Efendisi mağlup edildi.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x3364748B)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            Text('EXP', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 10, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('+14,500', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        Column(
                          children: <Widget>[
                            Text('ALTIN', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('+8,200', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        Column(
                          children: <Widget>[
                            Text('İTİBAR', style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('+150', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'KAZANILAN GANİMETLER',
                      style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _buildLootItemSlot(
                        icon: '⚔️',
                        name: 'Alev Kılıcı',
                        rarityColor: const Color(0xFFEF4444),
                        rarityLabel: 'Efsanevi',
                      ),
                      _buildLootItemSlot(
                        icon: '💎',
                        name: 'Rün Kristali',
                        rarityColor: const Color(0xFFA855F7),
                        rarityLabel: 'Epik',
                      ),
                      _buildLootItemSlot(
                        icon: '🛡️',
                        name: 'Obsidiyen Kalkan',
                        rarityColor: const Color(0xFF3B82F6),
                        rarityLabel: 'Nadir',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: const Color(0xFF1A1A1A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'ÖDÜLLERİ TOPLA & DÖN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
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

Widget _buildLootItemSlot({
  required String icon,
  required String name,
  required Color rarityColor,
  required String rarityLabel,
}) {
  return Container(
    width: 86,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: rarityColor, width: 1.5),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: rarityColor.withValues(alpha: 0.25),
          blurRadius: 8,
        ),
      ],
    ),
    child: Column(
      children: <Widget>[
        Text(icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          rarityLabel,
          style: TextStyle(
            color: rarityColor,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 4: DUNGEON SIEGE HUB SCREEN (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildDungeonSiegeHubTestScreen() {
  return Scaffold(
    backgroundColor: const Color(0xFF060911),
    body: Stack(
      children: <Widget>[
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF090D18), Color(0xFF121B2F), Color(0xFF070B14)],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: <Widget>[
              // Top Bar
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x33C8AA6E), width: 1)),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.shield_moon, color: Color(0xFFD4AF37), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'ZİNDAN KUŞATMA MERKEZİ',
                      style: TextStyle(
                        color: Color(0xFFF3E7C4),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              // Prime Timer Banner
              Container(
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF31101E), Color(0xFF190B12)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.timer, color: Color(0xFFEF4444), size: 20),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'PRİME-TİME KUŞATMA AKTİF!',
                          style: TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Kalan Süre: 01:42:15 • 2x Haraç Bonusu',
                          style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Fortress Defense Slots
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                  children: <Widget>[
                    _buildFortressSlotCard(
                      slotIndex: 1,
                      isMine: true,
                      guildName: 'Elyos Hanedanı',
                      ownerName: 'AionCommander',
                      power: 2450,
                      tributeCollected: '12,500 Altın',
                    ),
                    const SizedBox(height: 10),
                    _buildFortressSlotCard(
                      slotIndex: 2,
                      isMine: false,
                      guildName: 'Karanlık Muhafızlar',
                      ownerName: 'GölgeSavaşçı',
                      power: 2200,
                      tributeCollected: '9,800 Altın',
                    ),
                    const SizedBox(height: 10),
                    _buildFortressSlotCard(
                      slotIndex: 3,
                      isMine: false,
                      guildName: null,
                      ownerName: null,
                      power: 0,
                      tributeCollected: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildFortressSlotCard({
  required int slotIndex,
  required bool isMine,
  required String? guildName,
  required String? ownerName,
  required int power,
  required String? tributeCollected,
}) {
  final bool isOccupied = ownerName != null;
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF0F1523),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isMine ? const Color(0xFFD4AF37) : const Color(0x33475569),
        width: isMine ? 1.5 : 1.0,
      ),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOccupied ? const Color(0x33D4AF37) : const Color(0x2264748B),
            border: Border.all(
              color: isOccupied ? const Color(0xFFD4AF37) : const Color(0x4464748B),
            ),
          ),
          child: Center(
            child: Text(
              '$slotIndex',
              style: TextStyle(
                color: isOccupied ? const Color(0xFFD4AF37) : const Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                isOccupied ? '$ownerName (${guildName ?? ""})' : 'Boş Savunma Yuvası',
                style: TextStyle(
                  color: isOccupied ? const Color(0xFFF1F5F9) : const Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isOccupied ? 'Güç: $power • Haraç: $tributeCollected' : 'Bu yuvayı ele geçirmek için meydan oku',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: isMine
                ? const Color(0xFF1E293B)
                : isOccupied
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Text(
            isMine ? 'Yönet' : isOccupied ? 'Meydan Oku' : 'Ele Geçir',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 5: DUNGEON CONFIRM ENTRY DIALOG (390x844)
// ─────────────────────────────────────────────────────────────────────────────

Widget buildDungeonConfirmEntryDialogScreen() {
  return Scaffold(
    backgroundColor: const Color(0xEE05070C),
    body: SafeArea(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x88D4AF37), width: 1.5),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.castle, color: Color(0xFFD4AF37), size: 40),
              const SizedBox(height: 10),
              const Text(
                'ZİNDANA GİRİŞ ONAYI',
                style: TextStyle(
                  color: Color(0xFFF3E7C4),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Gölge Uçurumu Tapınağı — Kat 12',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x3364748B)),
                ),
                child: const Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.bolt, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 8),
                        Text('Enerji Bedeli:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        Spacer(),
                        Text('-15 Enerji', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(Icons.local_hospital, color: Color(0xFFEF4444), size: 16),
                        SizedBox(width: 8),
                        Text('Yenilgi / Hastane Riski:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        Spacer(),
                        Text('%12 Risk', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 16),
                        SizedBox(width: 8),
                        Text('Ganimet Çarpanı:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        Spacer(),
                        Text('1.5x Bonus', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: const BorderSide(color: Color(0x6664748B)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: const Color(0xFF1A1A1A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Giriş Yap', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN TEST SUITE
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = DungeonMockHttpOverrides();
  });

  group('Dungeon Mobile Golden Screenshot Tests (390x844 SafeArea)', () {
    testWidgets('Screen 1: Dungeon Hub & Zone Navigation renders cleanly and captures golden PNG', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();

      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildDungeonHubScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('ZİNDANLAR & TAPINAKLAR'), findsOneWidget);
      expect(find.text('GÖLGE UÇURUMU TAPINAĞI'), findsOneWidget);
      expect(find.text('BÖLGE 1: KARANLIK DERİNLİKLER'), findsOneWidget);

      final List<File> files = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '01_dungeon_hub_mobile_390x844.png',
      );

      for (final File f in files) {
        verifyMobileGoldenFile(f, minBytes: 10000);
      }
    });

    testWidgets('Screen 2: Dungeon Boss Encounter Active Combat Deck renders cleanly without overflow', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();

      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildActiveDungeonBossCombatScreen(isEnraged: false, bossHpPercent: 0.85),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('İGNİS — KÖZLERİN EFENDİSİ'), findsOneWidget);
      expect(find.text('85% CAN'), findsOneWidget);
      expect(find.text('Saldır'), findsOneWidget);
      expect(find.text('Ejder Darbesi'), findsOneWidget);
      expect(find.text('İksir'), findsOneWidget);

      final List<File> files = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '02_dungeon_boss_encounter_mobile_390x844.png',
      );

      for (final File f in files) {
        verifyMobileGoldenFile(f, minBytes: 10000);
      }
    });

    testWidgets('Screen 3: Dungeon Boss Enraged Phase & Combat VFX / Juice renders cleanly without overflow', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();

      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildActiveDungeonBossCombatScreen(isEnraged: true, bossHpPercent: 0.25),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('ÖFKE'), findsOneWidget);
      expect(find.text('25% CAN'), findsOneWidget);
      expect(find.text('-2,450 KRİTİK!'), findsOneWidget);

      final List<File> files = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '03_dungeon_boss_enraged_vfx_mobile_390x844.png',
      );

      for (final File f in files) {
        verifyMobileGoldenFile(f, minBytes: 10000);
      }
    });

    testWidgets('Screen 4: Dungeon Victory & Abyssal Loot Modal renders cleanly without overflow', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();

      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildDungeonVictoryLootScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('ZİNDAN TEMİZLENDİ!'), findsOneWidget);
      expect(find.text('KAZANILAN GANİMETLER'), findsOneWidget);
      expect(find.text('Alev Kılıcı'), findsOneWidget);
      expect(find.text('Efsanevi'), findsOneWidget);

      final List<File> files = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '04_dungeon_victory_loot_mobile_390x844.png',
      );

      for (final File f in files) {
        verifyMobileGoldenFile(f, minBytes: 10000);
      }
    });

    testWidgets('Screen 5: Dungeon Siege Hub Screen renders cleanly without overflow', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();

      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildDungeonSiegeHubTestScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('ZİNDAN KUŞATMA MERKEZİ'), findsOneWidget);
      expect(find.text('PRİME-TİME KUŞATMA AKTİF!'), findsOneWidget);
      expect(find.text('Boş Savunma Yuvası'), findsOneWidget);

      final List<File> files = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '05_dungeon_siege_hub_mobile_390x844.png',
      );

      for (final File f in files) {
        verifyMobileGoldenFile(f, minBytes: 10000);
      }
    });

    testWidgets('Screen 6: Dungeon Confirm Entry Dialog renders cleanly without overflow', (
      WidgetTester tester,
    ) async {
      final GlobalKey repaintKey = GlobalKey();

      setMobileViewDimensions(tester);
      addTearDown(() => resetMobileViewDimensions(tester));

      await tester.pumpWidget(
        buildMobileTestHarness(
          repaintKey: repaintKey,
          child: buildDungeonConfirmEntryDialogScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('ZİNDANA GİRİŞ ONAYI'), findsOneWidget);
      expect(find.text('Gölge Uçurumu Tapınağı — Kat 12'), findsOneWidget);
      expect(find.text('Giriş Yap'), findsOneWidget);

      final List<File> files = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '06_dungeon_confirm_entry_mobile_390x844.png',
      );

      for (final File f in files) {
        verifyMobileGoldenFile(f, minBytes: 10000);
      }
    });
  });

  group('Real Dungeon Components Layout & Texture Verification Suite', () {
    testWidgets(
      'Component 1: FeaturedCaveDungeonCard renders with cave theme, textures, and asset mocking without errors',
      (WidgetTester tester) async {
        final GlobalKey repaintKey = GlobalKey();
        setMobileViewDimensions(tester);
        addTearDown(() => resetMobileViewDimensions(tester));

        const DungeonData testDungeon = DungeonData(
          id: 'dng_001',
          dungeonId: 'dungeon_1',
          name: 'Gölge Uçurumu Tapınağı',
          description: 'Kadim Tapınak Bölgesi',
          difficulty: 'hard',
          requiredLevel: 35,
          maxPlayers: 1,
          energyCost: 15,
          minGold: 800,
          maxGold: 3500,
          lootTable: <String>['Efsanevi Kılıç', 'Ejder Taşı'],
          isGroup: false,
          zone: 1,
          isBoss: true,
          powerRequirement: 1450,
        );

        await tester.pumpWidget(
          buildMobileTestHarness(
            repaintKey: repaintKey,
            child: Scaffold(
              backgroundColor: const Color(0xFF080B12),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: FeaturedCaveDungeonCard(
                    dungeon: testDungeon,
                    theme: CaveCardTheme.cyberCave,
                    zoneIcon: Icons.terrain,
                    zoneLabel: 'BÖLGE 1',
                    zoneColor: AppColors.gold,
                    canEnter: true,
                    inHospital: false,
                    inPrison: false,
                    entering: false,
                    successPercent: 82,
                    energyCost: 15,
                    minGold: 800,
                    maxGold: 3500,
                    powerRequirement: 1450,
                    playerPower: 1600,
                    onEnter: () {},
                    onLoot: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('Gölge Uçurumu Tapınağı'), findsOneWidget);
        expect(find.text('BÖLGE 1'), findsOneWidget);
        expect(find.text('KOLAY'), findsOneWidget);
        expect(find.text('Zindana Gir'), findsOneWidget);
        expect(find.byType(FeaturedCaveDungeonCard), findsOneWidget);

        final List<File> files = await captureWidgetToPng(
          tester: tester,
          repaintKey: repaintKey,
          filename: '07_real_featured_cave_card_mobile.png',
        );
        for (final File f in files) {
          verifyMobileGoldenFile(f, minBytes: 10000);
        }
      },
    );

    testWidgets(
      'Component 2: DungeonCard renders with boss definitions and Aion 2 filigree styling',
      (WidgetTester tester) async {
        final GlobalKey repaintKey = GlobalKey();
        setMobileViewDimensions(tester);
        addTearDown(() => resetMobileViewDimensions(tester));

        const DungeonData bossDungeon = DungeonData(
          id: 'dng_025',
          dungeonId: 'dungeon_25',
          name: 'Ateş Tapınağı — İgnis',
          description: 'Akkor alevlerin merkezi',
          difficulty: 'boss',
          requiredLevel: 45,
          maxPlayers: 1,
          energyCost: 20,
          minGold: 1200,
          maxGold: 4500,
          lootTable: <String>['Alev Kılıcı'],
          isGroup: false,
          zone: 3,
          isBoss: true,
          powerRequirement: 2200,
        );

        await tester.pumpWidget(
          buildMobileTestHarness(
            repaintKey: repaintKey,
            child: Scaffold(
              backgroundColor: const Color(0xFF080B12),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: DungeonCard(
                    dungeon: bossDungeon,
                    zone: kDungeonZones[2],
                    canEnter: true,
                    inHospital: false,
                    inPrison: false,
                    entering: false,
                    successPercent: 65,
                    playerPower: 2400,
                    powerRequirement: 2200,
                    onEnter: () {},
                    onLoot: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('Ateş Tapınağı — İgnis'), findsOneWidget);
        expect(find.byType(DungeonCard), findsOneWidget);

        final List<File> files = await captureWidgetToPng(
          tester: tester,
          repaintKey: repaintKey,
          filename: '08_real_dungeon_card_mobile.png',
        );
        for (final File f in files) {
          verifyMobileGoldenFile(f, minBytes: 10000);
        }
      },
    );

    testWidgets(
      'Component 3: DungeonConfirmEntryDialog renders entry risk, loot multiplier, and liquid gold button',
      (WidgetTester tester) async {
        final GlobalKey repaintKey = GlobalKey();
        setMobileViewDimensions(tester);
        addTearDown(() => resetMobileViewDimensions(tester));

        const DungeonData dungeon = DungeonData(
          id: 'dng_012',
          dungeonId: 'dungeon_12',
          name: 'Karanlık Uçurum Kat 12',
          description: 'Kadim Tapınak',
          difficulty: 'hard',
          requiredLevel: 38,
          maxPlayers: 1,
          energyCost: 18,
          minGold: 900,
          maxGold: 3800,
          lootTable: <String>[],
          isGroup: false,
          zone: 1,
          isBoss: true,
        );

        await tester.pumpWidget(
          buildMobileTestHarness(
            repaintKey: repaintKey,
            child: const Scaffold(
              backgroundColor: Color(0xEE05070C),
              body: SafeArea(
                child: Center(
                  child: DungeonConfirmEntryDialog(
                    dungeon: dungeon,
                    hospitalRiskPct: 12.0,
                    rewardMultiplierPreview: 1.5,
                    currentEnergy: 85,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.byType(DungeonConfirmEntryDialog), findsOneWidget);

        final List<File> files = await captureWidgetToPng(
          tester: tester,
          repaintKey: repaintKey,
          filename: '09_real_confirm_entry_dialog_mobile.png',
        );
        for (final File f in files) {
          verifyMobileGoldenFile(f, minBytes: 10000);
        }
      },
    );

    testWidgets(
      'Component 4: DungeonLootDialog renders drop chances and loot rarities',
      (WidgetTester tester) async {
        final GlobalKey repaintKey = GlobalKey();
        setMobileViewDimensions(tester);
        addTearDown(() => resetMobileViewDimensions(tester));

        const DungeonData lootDungeon = DungeonData(
          id: 'dng_001',
          dungeonId: 'dungeon_1',
          name: 'Gölge Uçurumu Tapınağı',
          description: 'Ganimet Dolu Mağara',
          difficulty: 'hard',
          requiredLevel: 35,
          maxPlayers: 1,
          energyCost: 15,
          minGold: 800,
          maxGold: 3500,
          lootTable: <String>['Efsanevi Kılıç', 'Ejder Taşı'],
          isGroup: false,
          zone: 1,
          isBoss: true,
          equipmentDropChance: 0.15,
          resourceDropChance: 0.45,
          scrollDropChance: 0.25,
          catalystDropChance: 0.05,
        );

        await tester.pumpWidget(
          buildMobileTestHarness(
            repaintKey: repaintKey,
            child: Scaffold(
              backgroundColor: const Color(0xFF060911),
              body: SafeArea(
                child: Center(
                  child: DungeonLootDialog(
                    dungeon: lootDungeon,
                    zone: kDungeonZones[0],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.byType(DungeonLootDialog), findsOneWidget);

        final List<File> files = await captureWidgetToPng(
          tester: tester,
          repaintKey: repaintKey,
          filename: '10_real_loot_dialog_mobile.png',
        );
        for (final File f in files) {
          verifyMobileGoldenFile(f, minBytes: 10000);
        }
      },
    );

    testWidgets(
      'Component 5: Aion2GlassmorphicFrame & Aion2GoldFiligreePainter render ornate corner acanthus flourishes',
      (WidgetTester tester) async {
        final GlobalKey repaintKey = GlobalKey();
        setMobileViewDimensions(tester);
        addTearDown(() => resetMobileViewDimensions(tester));

        await tester.pumpWidget(
          buildMobileTestHarness(
            repaintKey: repaintKey,
            child: const Scaffold(
              backgroundColor: Color(0xFF080B12),
              body: Center(
                child: SizedBox(
                  width: 320,
                  height: 180,
                  child: Aion2GlassmorphicFrame(
                    showFiligree: true,
                    child: Center(
                      child: Text(
                        'AION 2 GLASSMORPHIC DUNGEON FRAME',
                        style: TextStyle(
                          color: Color(0xFFF3E7C4),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('AION 2 GLASSMORPHIC DUNGEON FRAME'), findsOneWidget);
        expect(find.byType(Aion2GlassmorphicFrame), findsOneWidget);

        final List<File> files = await captureWidgetToPng(
          tester: tester,
          repaintKey: repaintKey,
          filename: '11_aion2_glassmorphic_frame_mobile.png',
        );
        for (final File f in files) {
          verifyMobileGoldenFile(f, minBytes: 10000);
        }
      },
    );

    testWidgets(
      'Component 6: DungeonArena3DAtmospherePainter renders 3D stone floor, torches, shadows, decals, and mist',
      (WidgetTester tester) async {
        final GlobalKey repaintKey = GlobalKey();
        setMobileViewDimensions(tester);
        addTearDown(() => resetMobileViewDimensions(tester));

        await tester.pumpWidget(
          buildMobileTestHarness(
            repaintKey: repaintKey,
            child: const Scaffold(
              body: SizedBox.expand(
                child: CustomPaint(
                  painter: DungeonArena3DAtmospherePainter(
                    isEnraged: true,
                    showArena3D: true,
                    showTorches: true,
                    showMist: true,
                    showDecals: true,
                    showShadows: true,
                    time: 2.5,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.byType(CustomPaint), findsWidgets);

        final List<File> files = await captureWidgetToPng(
          tester: tester,
          repaintKey: repaintKey,
          filename: '12_dungeon_arena_3d_atmosphere_mobile.png',
        );
        for (final File f in files) {
          verifyMobileGoldenFile(f, minBytes: 10000);
        }
      },
    );

    test(
      'Component 7: DungeonMockAssetBundle gracefully handles missing and disk-backed assets without throwing',
      () async {
        final ByteData missingAsset = await DungeonMockAssetBundle.instance.load(
          'assets/dungeon/non_existent_cave_art.png',
        );
        expect(missingAsset.lengthInBytes, greaterThan(0));
        final Uint8List header = missingAsset.buffer.asUint8List().sublist(0, 8);
        expect(header, equals(kPngMagicSignature));

        final String missingString = await DungeonMockAssetBundle.instance.loadString(
          'assets/missing_file.json',
        );
        expect(missingString, isEmpty);
      },
    );
  });
}
