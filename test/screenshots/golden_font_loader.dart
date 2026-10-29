import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Production-grade Golden Font Loader for Authentic Aion-2 Golden Screenshots.
///
/// In Flutter test environments, standard fonts are replaced by "Ahem" (a 16x16
/// square font), rendering text as solid black blocks and icons as hollow boxes.
/// This loader mounts real TrueType/OpenType font glyphs into Flutter's engine
/// for all font families and variants used across the application.
abstract final class GoldenFontLoader {
  static bool _isLoaded = false;
  static Future<void>? _activeLoadFuture;

  /// Returns whether fonts have been successfully loaded into the Flutter engine.
  static bool get isLoaded => _isLoaded;

  /// Loads all required fonts (MaterialIcons, Roboto, Urbanist, Cinzel, Outfit,
  /// Plus Jakarta Sans, JetBrains Mono, Roboto Mono, Trajan Pro, and variants)
  /// into the Flutter engine.
  ///
  /// Safe to call multiple times across test files and suites (no-op after first run).
  static Future<void> loadAll() {
    if (_isLoaded) {
      return Future<void>.value();
    }
    return _activeLoadFuture ??= _performLoadAll().then((_) {
      _isLoaded = true;
    });
  }

  /// Resets the loader state (primarily intended for unit testing the loader itself).
  @visibleForTesting
  static void resetForTest() {
    _isLoaded = false;
    _activeLoadFuture = null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PRIVATE EXECUTION PIPELINE
  // ───────────────────────────────────────────────────────────────────────────

  static Future<void> _performLoadAll() async {
    // 1. Disable GoogleFonts runtime network fetching during tests
    GoogleFonts.config.allowRuntimeFetching = false;

    // 2. Resolve and load MaterialIcons font
    await _loadMaterialIcons();

    // 3. Resolve and load typography font bytes
    await _loadTypographyFonts();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MATERIAL ICONS RESOLUTION & LOADING
  // ───────────────────────────────────────────────────────────────────────────

  static Future<void> _loadMaterialIcons() async {
    final File? file = findMaterialIconsFile();
    if (file == null || !file.existsSync()) {
      debugPrint('[GoldenFontLoader] Warning: MaterialIcons font file not found on disk.');
      return;
    }

    try {
      final Uint8List bytes = file.readAsBytesSync();
      final ByteData byteData = ByteData.sublistView(bytes);

      final FontLoader loader = FontLoader('MaterialIcons');
      loader.addFont(Future<ByteData>.value(byteData));
      await loader.load();
    } catch (e) {
      debugPrint('[GoldenFontLoader] Error loading MaterialIcons: $e');
    }
  }

  /// Locates the authentic Flutter SDK MaterialIcons font file on disk.
  static File? findMaterialIconsFile() {
    // 1. Try FLUTTER_ROOT env var
    final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null && flutterRoot.trim().isNotEmpty) {
      final String cleanRoot = flutterRoot.trim().replaceAll(r'\', '/');
      final List<String> candidates = <String>[
        '$cleanRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        '$cleanRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ];
      for (final String path in candidates) {
        final File f = File(path);
        if (f.existsSync()) return f;
      }
    }

    // 2. Try android/local.properties flutter.sdk
    final String? sdkFromProps = _readFlutterSdkFromLocalProperties();
    if (sdkFromProps != null && sdkFromProps.isNotEmpty) {
      final List<String> candidates = <String>[
        '$sdkFromProps/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        '$sdkFromProps/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ];
      for (final String path in candidates) {
        final File f = File(path);
        if (f.existsSync()) return f;
      }
    }

    // 3. Well-known local paths on Windows development machines
    const List<String> fallbackPaths = <String>[
      r'F:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
      r'F:\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
      r'C:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
      r'C:\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
      r'C:\src\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
      r'C:\tools\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
      r'D:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
      r'D:\src\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
      r'E:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
    ];
    for (final String path in fallbackPaths) {
      final File f = File(path);
      if (f.existsSync()) return f;
    }

    return null;
  }

  static String? _readFlutterSdkFromLocalProperties() {
    final File localProps = File('android/local.properties');
    if (!localProps.existsSync()) return null;

    try {
      final List<String> lines = localProps.readAsLinesSync();
      for (final String line in lines) {
        final String trimmed = line.trim();
        if (trimmed.startsWith('flutter.sdk=')) {
          return trimmed
              .substring('flutter.sdk='.length)
              .replaceAll(r'\\', '/')
              .replaceAll(r'\', '/')
              .trim();
        }
      }
    } catch (_) {}
    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TYPOGRAPHY FONTS RESOLUTION & LOADING
  // ───────────────────────────────────────────────────────────────────────────

  static Future<void> _loadTypographyFonts() async {
    final ByteData? regularData = _resolveRegularFont();
    final ByteData? boldData = _resolveBoldFont() ?? regularData;
    final ByteData? monoData = _resolveMonoFont() ?? regularData;
    final ByteData? serifData = _resolveSerifFont() ?? regularData;

    if (regularData == null) {
      debugPrint('[GoldenFontLoader] Warning: No TTF/OTF font found for typography.');
      return;
    }

    // 1. Regular & Medium font families
    final List<String> regularFamilies = <String>[
      'Roboto',
      'Segoe UI',
      'Arial',
      'sans-serif',
      'Urbanist',
      'Urbanist_regular',
      'Urbanist_100',
      'Urbanist_200',
      'Urbanist_300',
      'Urbanist_400',
      'Urbanist_500',
      'Urbanist_600',
      'Outfit',
      'Outfit_regular',
      'Outfit_100',
      'Outfit_200',
      'Outfit_300',
      'Outfit_400',
      'Outfit_500',
      'Outfit_600',
      'Cinzel',
      'CinzelDecorative',
      'Cinzel Decorative',
      'Cinzel_regular',
      'Cinzel_400',
      'Cinzel_500',
      'Cinzel_600',
      'CinzelDecorative_regular',
      'CinzelDecorative_400',
      'PlusJakartaSans',
      'Plus Jakarta Sans',
      'PlusJakartaSans_regular',
      'PlusJakartaSans_300',
      'PlusJakartaSans_400',
      'PlusJakartaSans_500',
      'PlusJakartaSans_600',
    ];

    // 2. Bold & Extra-Bold font families
    final List<String> boldFamilies = <String>[
      'Urbanist_700',
      'Urbanist_800',
      'Urbanist_900',
      'Urbanist_bold',
      'Outfit_700',
      'Outfit_800',
      'Outfit_900',
      'Outfit_bold',
      'Cinzel_700',
      'Cinzel_800',
      'Cinzel_900',
      'Cinzel_bold',
      'CinzelDecorative_700',
      'CinzelDecorative_800',
      'CinzelDecorative_900',
      'CinzelDecorative_bold',
      'PlusJakartaSans_700',
      'PlusJakartaSans_800',
      'PlusJakartaSans_bold',
      'Roboto_700',
      'Roboto_bold',
      'Arial_bold',
    ];

    // 3. Monospace font families
    final List<String> monoFamilies = <String>[
      'monospace',
      'Courier',
      'Courier New',
      'Consolas',
      'JetBrainsMono',
      'JetBrains Mono',
      'JetBrainsMono_regular',
      'JetBrainsMono_300',
      'JetBrainsMono_400',
      'JetBrainsMono_500',
      'JetBrainsMono_600',
      'JetBrainsMono_700',
      'JetBrainsMono_800',
      'JetBrainsMono_bold',
      'RobotoMono',
      'Roboto Mono',
      'RobotoMono_regular',
      'RobotoMono_400',
      'RobotoMono_500',
      'RobotoMono_600',
      'RobotoMono_700',
      'RobotoMono_bold',
    ];

    // 4. Serif font families
    final List<String> serifFamilies = <String>[
      'Trajan Pro',
      'TrajanPro',
      'Trajan',
      'serif',
      'Times New Roman',
    ];

    // Register regular typography families
    for (final String family in regularFamilies) {
      await _loadFamily(family, regularData);
    }

    // Register bold typography families
    for (final String family in boldFamilies) {
      await _loadFamily(family, boldData!);
    }

    // Register monospace typography families
    for (final String family in monoFamilies) {
      await _loadFamily(family, monoData!);
    }

    // Register serif typography families
    for (final String family in serifFamilies) {
      await _loadFamily(family, serifData!);
    }
  }

  static Future<void> _loadFamily(String family, ByteData data) async {
    try {
      final FontLoader loader = FontLoader(family);
      loader.addFont(Future<ByteData>.value(data));
      await loader.load();
    } catch (e) {
      // Font might already be registered in this process; ignore safely.
      debugPrint('[GoldenFontLoader] Notice: loading family "$family": $e');
    }
  }

  static ByteData? _resolveRegularFont() {
    final String? sdk = _readFlutterSdkFromLocalProperties() ?? Platform.environment['FLUTTER_ROOT'];
    final List<String> candidates = <String>[
      r'C:\Windows\Fonts\segoeui.ttf',
      if (sdk != null) '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
      if (sdk != null) '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      r'F:\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf',
      r'C:\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf',
      r'C:\Windows\Fonts\arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
      '/usr/share/fonts/truetype/roboto/Roboto-Regular.ttf',
      '/System/Library/Fonts/SFNS.ttf',
      '/Library/Fonts/Arial.ttf',
    ];

    return _readFirstValidByteData(candidates);
  }

  static ByteData? _resolveBoldFont() {
    final String? sdk = _readFlutterSdkFromLocalProperties() ?? Platform.environment['FLUTTER_ROOT'];
    final List<String> candidates = <String>[
      r'C:\Windows\Fonts\segoeuib.ttf',
      if (sdk != null) '$sdk/bin/cache/artifacts/material_fonts/roboto-bold.ttf',
      if (sdk != null) '$sdk/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf',
      r'F:\flutter\bin\cache\artifacts\material_fonts\roboto-bold.ttf',
      r'C:\flutter\bin\cache\artifacts\material_fonts\roboto-bold.ttf',
      r'C:\Windows\Fonts\arialbd.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
      '/Library/Fonts/Arial Bold.ttf',
    ];

    return _readFirstValidByteData(candidates);
  }

  static ByteData? _resolveMonoFont() {
    final List<String> candidates = <String>[
      r'C:\Windows\Fonts\consola.ttf',
      r'C:\Windows\Fonts\cour.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf',
      '/Library/Fonts/Courier New.ttf',
    ];

    return _readFirstValidByteData(candidates);
  }

  static ByteData? _resolveSerifFont() {
    final List<String> candidates = <String>[
      r'C:\Windows\Fonts\times.ttf',
      r'C:\Windows\Fonts\georgia.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf',
      '/Library/Fonts/Times New Roman.ttf',
    ];

    return _readFirstValidByteData(candidates);
  }

  static ByteData? _readFirstValidByteData(List<String> paths) {
    for (final String path in paths) {
      try {
        final File f = File(path);
        if (f.existsSync()) {
          final Uint8List bytes = f.readAsBytesSync();
          if (bytes.isNotEmpty) {
            return ByteData.sublistView(bytes);
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
