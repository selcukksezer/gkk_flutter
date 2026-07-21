import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Login / ana menü loop müziği (assets/audio/main_theme.wav, 48 sn loop).
class MusicService with WidgetsBindingObserver {
  MusicService._();

  static final MusicService instance = MusicService._();

  static const String _volumeKey = 'music_volume';
  static const String _muteKey = 'music_muted';
  static const String _asset = 'audio/main_theme.wav';

  final AudioPlayer _player = AudioPlayer();
  bool _started = false;
  double _volume = 0.7;
  bool _muted = false;

  double get volume => _volume;
  bool get muted => _muted;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble(_volumeKey) ?? 0.7;
    _muted = prefs.getBool(_muteKey) ?? false;

    try {
      // iOS: sessiz anahtar müziği kesmesin (playback kategorisi).
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const <AVAudioSessionOptions>{
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_muted ? 0 : _volume);
      await _player.play(AssetSource(_asset));
    } catch (_) {
      // Ses cihazı yoksa (ör. bazı emülatörler) sessiz devam.
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
    if (!_muted) {
      try {
        await _player.setVolume(_volume);
      } catch (_) {}
    }
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, _muted);
    try {
      await _player.setVolume(_muted ? 0 : _volume);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_started) {
          unawaited(_player.resume());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_player.pause());
    }
  }
}
