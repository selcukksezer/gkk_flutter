import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/theme/app_colors.dart';

// =============================================================================
// Mobile Viewport & Golden Test Harness (390x844 Baseline, 2.0 DPR)
//
// Target Specifications:
// - Physical Screen Dimensions: 390 x 844 logical pt (iPhone 14 / modern standard mobile)
// - Device Pixel Ratio: 2.0 (Crisp 780 x 1688 PNG golden output)
// - Realistic SafeArea Insets:
//     * Top: 47.0 pt (Sensor notch / Dynamic Island zone)
//     * Bottom: 34.0 pt (Home swipe indicator bar zone)
//     * Left / Right: 0.0 pt (Portrait orientation)
// - Strict Layout & Overflow Validation:
//     * Zero RenderFlex pixel overflows
//     * Background full-bleed layer rendering with safe foreground content
// =============================================================================

/// Canonical mobile viewport width for AAA mobile gaming.
const double kMobileWidth = 390.0;

/// Canonical mobile viewport height for AAA mobile gaming.
const double kMobileHeight = 844.0;

/// Device pixel ratio generating 780x1688 golden screenshots.
const double kMobileDevicePixelRatio = 2.0;

/// Realistic iOS / Android modern mobile safe area insets.
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

/// Directory path where rendered mobile golden screenshots are persisted.
const String kGoldenOutputDir = 'reports/screenshots/mobile_goldens';

/// PNG header signature (8 magic bytes).
const List<int> kPngMagicHeader = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
];

/// Configures the active test view to authentic mobile 390x844 dimensions.
void setMobileViewDimensions(WidgetTester tester) {
  tester.view.physicalSize = const Size(
    kMobileWidth * kMobileDevicePixelRatio,
    kMobileHeight * kMobileDevicePixelRatio,
  );
  tester.view.devicePixelRatio = kMobileDevicePixelRatio;
  tester.view.padding = const FakeViewPadding(
    top: 47.0 * kMobileDevicePixelRatio,
    bottom: 34.0 * kMobileDevicePixelRatio,
    left: 0.0,
    right: 0.0,
  );
}

/// Resets the test view to standard defaults.
void resetMobileViewDimensions(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.view.resetPadding();
}

/// Builds a mobile test harness wrapping [child] with Dark Aion-2 Theme,
/// and authentic 390x844 MediaQuery with SafeArea insets.
Widget buildMobileTestHarness({
  required Widget child,
  GlobalKey? repaintKey,
  ThemeData? customTheme,
}) {
  final ThemeData theme = customTheme ??
      ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080B12),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.liquidGold,
          secondary: AppColors.accentCyan,
          surface: Color(0xFF121826),
          error: AppColors.danger,
        ),
      );

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(kMobileWidth, kMobileHeight),
        devicePixelRatio: kMobileDevicePixelRatio,
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
  );
}

/// Captures a rendered [RepaintBoundary] identified by [repaintKey] to a PNG file on disk.
Future<File> captureWidgetToMobilePng({
  required WidgetTester tester,
  required GlobalKey repaintKey,
  required String filename,
}) async {
  final Directory dir = Directory(kGoldenOutputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  File? savedFile;
  await tester.runAsync(() async {
    final BuildContext? context = repaintKey.currentContext;
    if (context == null) {
      throw StateError('RepaintBoundary context is null for $filename');
    }
    final RenderRepaintBoundary boundary =
        context.findRenderObject()! as RenderRepaintBoundary;

    final ui.Image image = await boundary.toImage(
      pixelRatio: kMobileDevicePixelRatio,
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw StateError('Failed to encode image to PNG for $filename');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final File file = File('$kGoldenOutputDir/$filename');
    await file.writeAsBytes(pngBytes, flush: true);
    savedFile = file;
  });

  return savedFile!;
}

/// Asserts that a captured PNG file satisfies golden integrity criteria:
/// - File exists on disk
/// - File size is non-trivial (> 10 KB)
/// - File starts with genuine PNG magic header
void verifyMobileGoldenFile(File file, {int minBytes = 10000}) {
  expect(file.existsSync(), isTrue, reason: 'Golden PNG file must exist on disk: ${file.path}');
  expect(
    file.lengthSync(),
    greaterThan(minBytes),
    reason: 'Golden PNG file should contain genuine rendered visual data (> $minBytes bytes)',
  );

  final Uint8List bytes = file.readAsBytesSync();
  expect(bytes.length, greaterThan(8));
  final List<int> header = bytes.sublist(0, 8);
  expect(
    header,
    equals(kPngMagicHeader),
    reason: 'File must begin with valid PNG magic header [89 50 4E 47 0D 0A 1A 0A]',
  );
}
