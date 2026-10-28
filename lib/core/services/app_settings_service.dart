import 'package:shared_preferences/shared_preferences.dart';

import 'graphics_quality_service.dart';
import 'music_service.dart';

/// Yerel oyun ayarları — SharedPreferences.
///
/// `flutter run` prefs silmez (uygulama uninstall / sim reset eder).
/// Race: [load] `main` içinde `runApp` öncesi await edilmeli.
class AppSettingsService {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  static const String sfxVolumeKey = 'sfx_volume';
  static const String hapticKey = 'haptic_enabled';
  static const String reduceMotionKey = 'reduce_motion';

  bool _loaded = false;
  double _sfxVolume = 0.8;
  bool _hapticEnabled = true;
  bool _reduceMotion = false;

  bool get isLoaded => _loaded;
  double get sfxVolume => _sfxVolume;
  bool get hapticEnabled => _hapticEnabled;
  bool get reduceMotion => _reduceMotion;

  AppSettingsSnapshot get snapshot => AppSettingsSnapshot(
        musicVolume: MusicService.instance.volume,
        musicMuted: MusicService.instance.muted,
        sfxVolume: _sfxVolume,
        hapticEnabled: _hapticEnabled,
        reduceMotion: _reduceMotion,
      );

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _sfxVolume = (prefs.getDouble(sfxVolumeKey) ?? 0.8).clamp(0.0, 1.0);
    _hapticEnabled = prefs.getBool(hapticKey) ?? true;
    _reduceMotion = prefs.getBool(reduceMotionKey) ?? false;
    GraphicsQualityService.instance.syncAppReduceMotion(_reduceMotion);
    _loaded = true;
  }

  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume.clamp(0.0, 1.0);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(sfxVolumeKey, _sfxVolume);
  }

  Future<void> setHapticEnabled(bool enabled) async {
    _hapticEnabled = enabled;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hapticKey, enabled);
  }

  Future<void> setReduceMotion(bool enabled) async {
    _reduceMotion = enabled;
    GraphicsQualityService.instance.syncAppReduceMotion(enabled);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(reduceMotionKey, enabled);
  }
}

class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    required this.musicVolume,
    required this.musicMuted,
    required this.sfxVolume,
    required this.hapticEnabled,
    required this.reduceMotion,
  });

  final double musicVolume;
  final bool musicMuted;
  final double sfxVolume;
  final bool hapticEnabled;
  final bool reduceMotion;

  AppSettingsSnapshot copyWith({
    double? musicVolume,
    bool? musicMuted,
    double? sfxVolume,
    bool? hapticEnabled,
    bool? reduceMotion,
  }) {
    return AppSettingsSnapshot(
      musicVolume: musicVolume ?? this.musicVolume,
      musicMuted: musicMuted ?? this.musicMuted,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }
}
