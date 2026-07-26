import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/app_settings_service.dart';
import '../core/services/local_notification_service.dart';
import '../core/services/music_service.dart';

class SettingsUiState {
  const SettingsUiState({
    required this.ready,
    required this.musicVolume,
    required this.muteAll,
    required this.sfxVolume,
    required this.hapticEnabled,
    required this.reduceMotion,
    required this.notifications,
    required this.notifNightMarket,
    required this.notifNemesis,
  });

  final bool ready;
  final double musicVolume;
  final bool muteAll;
  final double sfxVolume;
  final bool hapticEnabled;
  final bool reduceMotion;
  final bool notifications;
  final bool notifNightMarket;
  final bool notifNemesis;

  static const SettingsUiState loading = SettingsUiState(
    ready: false,
    musicVolume: 0.7,
    muteAll: false,
    sfxVolume: 0.8,
    hapticEnabled: true,
    reduceMotion: false,
    notifications: true,
    notifNightMarket: true,
    notifNemesis: true,
  );

  SettingsUiState copyWith({
    bool? ready,
    double? musicVolume,
    bool? muteAll,
    double? sfxVolume,
    bool? hapticEnabled,
    bool? reduceMotion,
    bool? notifications,
    bool? notifNightMarket,
    bool? notifNemesis,
  }) {
    return SettingsUiState(
      ready: ready ?? this.ready,
      musicVolume: musicVolume ?? this.musicVolume,
      muteAll: muteAll ?? this.muteAll,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      notifications: notifications ?? this.notifications,
      notifNightMarket: notifNightMarket ?? this.notifNightMarket,
      notifNemesis: notifNemesis ?? this.notifNemesis,
    );
  }
}

class AppSettingsNotifier extends Notifier<SettingsUiState> {
  @override
  SettingsUiState build() {
    Future<void>.microtask(reload);
    return SettingsUiState.loading;
  }

  Future<void> reload() async {
    await MusicService.instance.ensureReady();
    if (!AppSettingsService.instance.isLoaded) {
      await AppSettingsService.instance.load();
    }
    await LocalNotificationService.instance.loadEnabledPreference();

    final AppSettingsSnapshot snap = AppSettingsService.instance.snapshot;
    state = SettingsUiState(
      ready: true,
      musicVolume: snap.musicVolume,
      muteAll: snap.musicMuted,
      sfxVolume: snap.sfxVolume,
      hapticEnabled: snap.hapticEnabled,
      reduceMotion: snap.reduceMotion,
      notifications: LocalNotificationService.instance.isEnabled,
      notifNightMarket: LocalNotificationService.instance.isNightMarketEnabled,
      notifNemesis: LocalNotificationService.instance.isNemesisEnabled,
    );
  }

  Future<void> setMusicVolume(double value) async {
    state = state.copyWith(musicVolume: value);
    await MusicService.instance.setVolume(value);
  }

  Future<void> setMuteAll(bool muted) async {
    state = state.copyWith(muteAll: muted);
    await MusicService.instance.setMuted(muted);
  }

  Future<void> setSfxVolume(double value) async {
    state = state.copyWith(sfxVolume: value);
    await AppSettingsService.instance.setSfxVolume(value);
  }

  Future<void> setHapticEnabled(bool enabled) async {
    state = state.copyWith(hapticEnabled: enabled);
    await AppSettingsService.instance.setHapticEnabled(enabled);
  }

  Future<void> setReduceMotion(bool enabled) async {
    state = state.copyWith(reduceMotion: enabled);
    await AppSettingsService.instance.setReduceMotion(enabled);
  }

  Future<void> setNotifications(bool enabled) async {
    state = state.copyWith(notifications: enabled);
    await LocalNotificationService.instance.setEnabled(enabled);
  }

  Future<void> setNotifNightMarket(bool enabled) async {
    state = state.copyWith(notifNightMarket: enabled);
    await LocalNotificationService.instance.setNightMarketEnabled(enabled);
  }

  Future<void> setNotifNemesis(bool enabled) async {
    state = state.copyWith(notifNemesis: enabled);
    await LocalNotificationService.instance.setNemesisEnabled(enabled);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, SettingsUiState>(
  AppSettingsNotifier.new,
);
