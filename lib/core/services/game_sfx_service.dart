import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'app_foreground_service.dart';
import 'app_haptics.dart';
import 'app_settings_service.dart';
import 'game_sfx_temp_stub.dart'
    if (dart.library.io) 'game_sfx_temp_io.dart';
import 'graphics_quality_service.dart';

/// Procedural zero-asset-bloat 16-bit PCM WAV sound effects catalog.
enum GameSfx {
  swordSlash,
  criticalSlash,
  anvilStrike,
  anvilSuccess,
  anvilFail,
  legendaryDrop,
  coinMagnet,
  siegeHorn,
  gallopBoost,
}

/// Zero-MB Procedural SFX + Haptic Choreography Engine (`1 GB RAM` friendly).
///
/// Synthesizes compact mono `22050 Hz` 16-bit PCM WAV buffers lazily in memory
/// (`< 180 KB` total across all 9 effects, `0 MB` GPU VRAM, `0 KB` APK bloat)
/// and plays them through a small round-robin [AudioPlayer] pool while honoring
/// [AppSettingsService.sfxVolume] and [AppForegroundService].
class GameSfxService {
  GameSfxService._();

  static final GameSfxService instance = GameSfxService._();

  static const int sampleRate = 22050;

  final Map<GameSfx, Uint8List> _wavCache = <GameSfx, Uint8List>{};
  final Map<GameSfx, int> _lastPlayEpochMs = <GameSfx, int>{};
  final List<AudioPlayer> _pool = <AudioPlayer>[];
  int _poolCursor = 0;

  int _debugPlayCount = 0;
  GameSfx? _debugLastSfx;

  @visibleForTesting
  int get debugPlayCount => _debugPlayCount;

  @visibleForTesting
  GameSfx? get debugLastSfx => _debugLastSfx;

  static bool get _isTestBinding {
    try {
      final String name = WidgetsBinding.instance.runtimeType.toString();
      return name.contains('Test');
    } catch (_) {
      return true;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _lastPlayEpochMs.clear();
    _debugPlayCount = 0;
    _debugLastSfx = null;
  }

  /// Builds or returns the cached RIFF/WAVE PCM bytes for [sfx].
  Uint8List wavBytesFor(GameSfx sfx) {
    return _wavCache.putIfAbsent(sfx, () => _synthesizeWav(sfx));
  }

  int _cooldownMsFor(GameSfx sfx) {
    return switch (sfx) {
      GameSfx.coinMagnet => 48,
      GameSfx.swordSlash => 75,
      GameSfx.criticalSlash => 90,
      GameSfx.anvilStrike => 110,
      GameSfx.gallopBoost => 120,
      GameSfx.anvilSuccess ||
      GameSfx.anvilFail ||
      GameSfx.legendaryDrop ||
      GameSfx.siegeHorn => 180,
    };
  }

  /// Plays [sfx] (with optional paired [withHaptics]) if SFX volume > 0 and app
  /// is foregrounded. Never throws on Web autoplay restrictions or test hosts.
  Future<void> play(
    GameSfx sfx, {
    double volumeScale = 1.0,
    bool withHaptics = true,
  }) async {
    if (!AppForegroundService.instance.isForeground) return;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int lastMs = _lastPlayEpochMs[sfx] ?? 0;
    if (nowMs - lastMs < _cooldownMsFor(sfx)) return;
    _lastPlayEpochMs[sfx] = nowMs;

    if (withHaptics && !_isTestBinding) {
      _triggerPairedHaptic(sfx);
    }

    final double baseVol = AppSettingsService.instance.sfxVolume;
    final double effectiveVol = (baseVol * volumeScale).clamp(0.0, 1.0);
    if (effectiveVol <= 0.01) return;

    final Uint8List bytes = wavBytesFor(sfx);
    _debugPlayCount += 1;
    _debugLastSfx = sfx;

    if (_isTestBinding) return;

    try {
      final int desiredPoolSize =
          GraphicsQualityService.instance.profile.isLow ? 2 : 4;
      while (_pool.length < desiredPoolSize) {
        final AudioPlayer p = AudioPlayer();
        await p
            .setAudioContext(
              AudioContext(
                iOS: AudioContextIOS(
                  category: AVAudioSessionCategory.ambient,
                ),
                android: const AudioContextAndroid(
                  contentType: AndroidContentType.sonification,
                  usageType: AndroidUsageType.assistanceSonification,
                  audioFocus: AndroidAudioFocus.none,
                ),
              ),
            )
            .timeout(const Duration(milliseconds: 500));
        await p
            .setPlayerMode(PlayerMode.lowLatency)
            .timeout(const Duration(milliseconds: 500));
        await p
            .setReleaseMode(ReleaseMode.stop)
            .timeout(const Duration(milliseconds: 500));
        _pool.add(p);
      }
      final AudioPlayer player = _pool[_poolCursor % _pool.length];
      _poolCursor = (_poolCursor + 1) % _pool.length;

      final String? tempPath = await cacheGameSfxWavFile(sfx.name, bytes);
      final Source source = tempPath != null
          ? DeviceFileSource(tempPath)
          : BytesSource(bytes);

      await player
          .play(
            source,
            volume: effectiveVol,
            mode: PlayerMode.lowLatency,
          )
          .timeout(const Duration(milliseconds: 800));
    } catch (_) {
      // Ignore audio backend / web autoplay errors cleanly.
    }
  }

  void _triggerPairedHaptic(GameSfx sfx) {
    switch (sfx) {
      case GameSfx.swordSlash:
        unawaited(AppHaptics.light());
      case GameSfx.criticalSlash:
        unawaited(AppHaptics.criticalImpact());
      case GameSfx.anvilStrike:
        unawaited(AppHaptics.anvilStrikePulse());
      case GameSfx.anvilSuccess:
        unawaited(AppHaptics.anvilSuccessFanfare());
      case GameSfx.anvilFail:
        unawaited(AppHaptics.anvilShatter());
      case GameSfx.legendaryDrop:
        unawaited(AppHaptics.legendaryDropPulse());
      case GameSfx.coinMagnet:
        unawaited(AppHaptics.selection());
      case GameSfx.siegeHorn:
        unawaited(AppHaptics.heavy());
      case GameSfx.gallopBoost:
        unawaited(AppHaptics.medium());
    }
  }

  static Uint8List _synthesizeWav(GameSfx sfx) {
    final double durationSec = switch (sfx) {
      GameSfx.coinMagnet => 0.095,
      GameSfx.swordSlash => 0.165,
      GameSfx.gallopBoost => 0.210,
      GameSfx.criticalSlash => 0.245,
      GameSfx.anvilStrike => 0.310,
      GameSfx.anvilFail => 0.370,
      GameSfx.siegeHorn => 0.490,
      GameSfx.anvilSuccess => 0.510,
      GameSfx.legendaryDrop => 0.540,
    };

    final int numSamples = (sampleRate * durationSec).round();
    final ByteData data = ByteData(44 + numSamples * 2);

    // RIFF/WAVE header (44 bytes)
    _writeAscii(data, 0, 'RIFF');
    data.setUint32(4, 36 + numSamples * 2, Endian.little);
    _writeAscii(data, 8, 'WAVE');
    _writeAscii(data, 12, 'fmt ');
    data.setUint32(16, 16, Endian.little); // PCM chunk size
    data.setUint16(20, 1, Endian.little); // format = 1 (PCM)
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    data.setUint16(32, 2, Endian.little); // block align
    data.setUint16(34, 16, Endian.little); // bits per sample
    _writeAscii(data, 36, 'data');
    data.setUint32(40, numSamples * 2, Endian.little);

    final math.Random rng = math.Random(sfx.index * 7919 + 1337);
    double phase1 = 0.0;
    double phase2 = 0.0;
    double prevNoise = 0.0;

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double progress = i / numSamples;
      final double white = rng.nextDouble() * 2.0 - 1.0;
      final double hiPassNoise = white - prevNoise * 0.72;
      prevNoise = white;

      double sample = 0.0;

      switch (sfx) {
        case GameSfx.swordSlash:
          final double env = math.sin(progress * math.pi) *
              math.exp(-progress * 3.1);
          final double sweepFreq = 980.0 - 620.0 * progress;
          phase1 += (2.0 * math.pi * sweepFreq) / sampleRate;
          sample = (hiPassNoise * 0.62 + math.sin(phase1) * 0.38) * env * 0.78;

        case GameSfx.criticalSlash:
          final double subEnv = math.exp(-t * 18.0);
          final double bladeEnv = math.exp(-t * 9.5);
          final double subFreq = 115.0 - 68.0 * progress;
          phase1 += (2.0 * math.pi * subFreq) / sampleRate;
          phase2 += (2.0 * math.pi * (1240.0 - 380.0 * progress)) / sampleRate;
          final double twin = math.sin(2.0 * math.pi * 1860.0 * t);
          sample = math.sin(phase1) * subEnv * 0.58 +
              (math.sin(phase2) * 0.52 + twin * 0.28 + hiPassNoise * 0.42) *
                  bladeEnv *
                  0.68;

        case GameSfx.anvilStrike:
          // Authentic Knight-Online blacksmith hammer CLANG: sharp transient +
          // inharmonic steel bell partials!
          final double transient = math.exp(-t * 65.0) * hiPassNoise * 0.65;
          final double bellEnv = math.exp(-t * 11.2);
          final double p1 = math.sin(2.0 * math.pi * 760.0 * t);
          final double p2 = math.sin(2.0 * math.pi * 1218.0 * t) * 0.75;
          final double p3 = math.sin(2.0 * math.pi * 2045.0 * t) * 0.52;
          final double p4 = math.sin(2.0 * math.pi * 2910.0 * t) *
              math.exp(-t * 22.0) *
              0.40;
          sample = (transient + (p1 + p2 + p3 + p4) * 0.34 * bellEnv) * 0.88;

        case GameSfx.anvilSuccess:
          // Ascending C5 -> E5 -> G5 -> C6 celestial chord arpeggio
          const List<double> notes = <double>[523.25, 659.25, 783.99, 1046.50];
          final int step = (progress * notes.length)
              .floor()
              .clamp(0, notes.length - 1);
          final double localT = (progress * notes.length) - step;
          final double f = notes[step];
          final double noteEnv =
              (1.0 - math.exp(-localT * 28.0)) * math.exp(-localT * 2.4);
          final double tailFade = (1.0 - progress * 0.35);
          sample = (math.sin(2.0 * math.pi * f * t) * 0.60 +
                  math.sin(2.0 * math.pi * f * 2.0 * t) * 0.25 +
                  math.sin(2.0 * math.pi * f * 1.5 * t) * 0.15) *
              noteEnv *
              tailFade *
              0.82;

        case GameSfx.anvilFail:
          final double crack = (t < 0.08)
              ? hiPassNoise * math.exp(-t * 26.0) * 0.85
              : 0.0;
          final double dropFreq = 290.0 * math.exp(-progress * 1.35);
          phase1 += (2.0 * math.pi * dropFreq) / sampleRate;
          phase2 += (2.0 * math.pi * (dropFreq * 1.19)) / sampleRate; // minor 3rd
          final double env = math.exp(-progress * 3.6);
          sample = crack +
              (math.sin(phase1) * 0.55 + math.sin(phase2) * 0.38) * env * 0.72;

        case GameSfx.legendaryDrop:
          // Radiant D5 -> F#5 -> A5 -> D6 crystalline loot beam bell!
          const List<double> beamNotes = <double>[
            587.33,
            739.99,
            880.00,
            1174.66,
          ];
          double chordSum = 0.0;
          for (int n = 0; n < beamNotes.length; n++) {
            final double onset = n * 0.085;
            if (t >= onset) {
              final double dt = t - onset;
              final double env = math.exp(-dt * 4.8);
              final double freq = beamNotes[n];
              chordSum += (math.sin(2.0 * math.pi * freq * dt) * 0.68 +
                      math.sin(2.0 * math.pi * freq * 2.0 * dt) * 0.32) *
                  env;
            }
          }
          sample = chordSum * 0.36;

        case GameSfx.coinMagnet:
          final double env = math.exp(-t * 36.0);
          final double f = t < 0.032 ? 1975.5 : 2637.0; // B6 -> E7 coin ping!
          sample = (math.sin(2.0 * math.pi * f * t) * 0.72 +
                  math.sin(2.0 * math.pi * f * 2.0 * t) * 0.28) *
              env *
              0.68;

        case GameSfx.siegeHorn:
          final double swell = math.sin(progress * math.pi);
          const double f0 = 130.81; // C3 war horn
          sample = (math.sin(2.0 * math.pi * f0 * t) * 0.50 +
                  math.sin(2.0 * math.pi * f0 * 1.5 * t) * 0.28 +
                  math.sin(2.0 * math.pi * f0 * 2.0 * t) * 0.16 +
                  math.sin(2.0 * math.pi * f0 * 3.0 * t) * 0.09) *
              swell *
              0.82;

        case GameSfx.gallopBoost:
          final double thump =
              math.sin(2.0 * math.pi * 88.0 * t) * math.exp(-t * 22.0) * 0.58;
          final double rush =
              hiPassNoise * math.sin(progress * math.pi) * 0.44;
          sample = (thump + rush) * 0.80;
      }

      final int pcm16 = (sample.clamp(-1.0, 1.0) * 32767.0).round();
      data.setInt16(44 + i * 2, pcm16, Endian.little);
    }

    return data.buffer.asUint8List();
  }

  static void _writeAscii(ByteData data, int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }
}
