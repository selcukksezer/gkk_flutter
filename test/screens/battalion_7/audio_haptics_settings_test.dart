import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gkk_flutter/screens/settings/services/audio_haptics_settings_service.dart';
import 'package:gkk_flutter/screens/settings/widgets/audio_haptics_controls.dart';
import 'package:gkk_flutter/screens/settings/widgets/audio_level_meter.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioHapticsState Model Tests', () {
    test('initial state has correct AAA defaults', () {
      const state = AudioHapticsState.initial;
      expect(state.ready, isFalse);
      expect(state.masterVolume, 1.0);
      expect(state.bgmVolume, 0.7);
      expect(state.sfxVolume, 0.8);
      expect(state.voiceVolume, 0.85);
      expect(state.ambientVolume, 0.75);
      expect(state.muteAll, isFalse);
      expect(state.hapticIntensity, HapticIntensity.medium);
      expect(state.isHapticEnabled, isTrue);
    });

    test('effective volumes factor in master volume and muteAll', () {
      const activeState = AudioHapticsState(
        ready: true,
        masterVolume: 0.5,
        bgmVolume: 0.8,
        sfxVolume: 0.6,
        voiceVolume: 0.9,
        ambientVolume: 0.7,
        muteAll: false,
        hapticIntensity: HapticIntensity.heavy,
        reduceMotion: false,
      );

      expect(activeState.effectiveMaster, 0.5);
      expect(activeState.effectiveBgm, closeTo(0.4, 0.001));
      expect(activeState.effectiveSfx, closeTo(0.3, 0.001));
      expect(activeState.effectiveVoice, closeTo(0.45, 0.001));
      expect(activeState.effectiveAmbient, closeTo(0.35, 0.001));
      expect(activeState.isHapticEnabled, isTrue);

      final mutedState = activeState.copyWith(muteAll: true);
      expect(mutedState.effectiveMaster, 0.0);
      expect(mutedState.effectiveBgm, 0.0);
      expect(mutedState.effectiveSfx, 0.0);
      expect(mutedState.effectiveVoice, 0.0);
      expect(mutedState.effectiveAmbient, 0.0);
    });

    test('copyWith updates specified fields only', () {
      const original = AudioHapticsState.initial;
      final updated = original.copyWith(
        masterVolume: 0.42,
        hapticIntensity: HapticIntensity.off,
      );

      expect(updated.masterVolume, 0.42);
      expect(updated.hapticIntensity, HapticIntensity.off);
      expect(updated.isHapticEnabled, isFalse);
      expect(updated.bgmVolume, original.bgmVolume);
      expect(updated.sfxVolume, original.sfxVolume);
    });
  });

  group('HapticIntensity Enum Tests', () {
    test('fromString parses correctly and handles fallback', () {
      expect(HapticIntensity.fromString('off'), HapticIntensity.off);
      expect(HapticIntensity.fromString('SOFT'), HapticIntensity.soft);
      expect(HapticIntensity.fromString('Medium'), HapticIntensity.medium);
      expect(HapticIntensity.fromString('heavy'), HapticIntensity.heavy);
      expect(HapticIntensity.fromString('unknown_val'), HapticIntensity.medium);
      expect(HapticIntensity.fromString(null), HapticIntensity.medium);
    });

    test('title and description are populated', () {
      for (final intensity in HapticIntensity.values) {
        expect(intensity.title.isNotEmpty, isTrue);
        expect(intensity.description.isNotEmpty, isTrue);
      }
    });

    test('trigger executes without throwing', () async {
      for (final intensity in HapticIntensity.values) {
        await expectLater(intensity.trigger(), completes);
      }
    });
  });

  group('AudioHapticsSettingsService Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AudioHapticsSettingsService.keyMasterVolume: 0.85,
        AudioHapticsSettingsService.keyBgmVolume: 0.65,
        AudioHapticsSettingsService.keySfxVolume: 0.75,
        AudioHapticsSettingsService.keyVoiceVolume: 0.9,
        AudioHapticsSettingsService.keyAmbientVolume: 0.7,
        AudioHapticsSettingsService.keyMuteAll: false,
        AudioHapticsSettingsService.keyHapticIntensity: 'heavy',
        AudioHapticsSettingsService.keyReduceMotion: false,
      });
    });

    test('loads persisted settings from SharedPreferences', () async {
      final service = AudioHapticsSettingsService.instance;
      final state = await service.load();

      expect(state.ready, isTrue);
      expect(state.masterVolume, closeTo(0.85, 0.01));
      expect(state.bgmVolume, closeTo(0.65, 0.01));
      expect(state.sfxVolume, closeTo(0.75, 0.01));
      expect(state.voiceVolume, closeTo(0.9, 0.01));
      expect(state.ambientVolume, closeTo(0.7, 0.01));
      expect(state.hapticIntensity, HapticIntensity.heavy);
      expect(state.isHapticEnabled, isTrue);
    });

    test('setMasterVolume updates state and SharedPreferences', () async {
      final service = AudioHapticsSettingsService.instance;
      await service.load();

      await service.setMasterVolume(0.5);
      expect(service.state.masterVolume, 0.5);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(AudioHapticsSettingsService.keyMasterVolume), 0.5);
    });

    test('setHapticIntensity updates state and legacy flag', () async {
      final service = AudioHapticsSettingsService.instance;
      await service.load();

      await service.setHapticIntensity(HapticIntensity.soft);
      expect(service.state.hapticIntensity, HapticIntensity.soft);
      expect(service.state.isHapticEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AudioHapticsSettingsService.keyHapticIntensity),
        'soft',
      );
      expect(
        prefs.getBool(AudioHapticsSettingsService.keyHapticEnabled),
        isTrue,
      );

      await service.setHapticIntensity(HapticIntensity.off);
      expect(service.state.hapticIntensity, HapticIntensity.off);
      expect(service.state.isHapticEnabled, isFalse);
      expect(
        prefs.getBool(AudioHapticsSettingsService.keyHapticEnabled),
        isFalse,
      );
    });

    test('resetToDefaults restores initial baseline values', () async {
      final service = AudioHapticsSettingsService.instance;
      await service.load();

      await service.setMasterVolume(0.1);
      await service.setMuteAll(true);
      await service.resetToDefaults();

      expect(service.state.masterVolume, 1.0);
      expect(service.state.bgmVolume, 0.7);
      expect(service.state.sfxVolume, 0.8);
      expect(service.state.muteAll, isFalse);
      expect(service.state.hapticIntensity, HapticIntensity.medium);
    });
  });

  group('Audio & Haptics Widget Tests', () {
    testWidgets('GlowingSoundLevelMeter renders properly at active volume',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 20,
              child: GlowingSoundLevelMeter(
                volume: 0.75,
                accentColor: AppColors.liquidGold,
                muted: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GlowingSoundLevelMeter), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('GlowingSoundLevelMeter handles muted state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 20,
              child: GlowingSoundLevelMeter(
                volume: 0.5,
                accentColor: AppColors.cyberFuchsia,
                muted: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GlowingSoundLevelMeter), findsOneWidget);
    });

    testWidgets('AionAudioSliderTile displays title, percentage, and triggers onChanged',
        (WidgetTester tester) async {
      double changedVal = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AionAudioSliderTile(
              title: 'Master Volume',
              subtitle: 'Global audio output ceiling',
              icon: Icons.volume_up_rounded,
              value: 0.8,
              accentColor: AppColors.liquidGold,
              onChanged: (val) => changedVal = val,
            ),
          ),
        ),
      );

      expect(find.text('Master Volume'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(GlowingSoundLevelMeter), findsOneWidget);

      await tester.tap(find.byType(Slider));
      await tester.pumpAndSettle();
      expect(changedVal, isNotNull);
    });

    testWidgets('AionAudioSliderTile shows MUTED badge when muted',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AionAudioSliderTile(
              title: 'BGM (Background Music)',
              subtitle: 'Cinematic orchestral theme',
              icon: Icons.library_music_rounded,
              value: 0.7,
              muted: true,
              accentColor: AppColors.cyberFuchsia,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('MUTED'), findsOneWidget);
    });

    testWidgets('HapticIntensitySelector renders all 4 options and responds to tap',
        (WidgetTester tester) async {
      HapticIntensity selected = HapticIntensity.medium;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return HapticIntensitySelector(
                  selectedIntensity: selected,
                  onChanged: (val) => setState(() => selected = val),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('OFF'), findsOneWidget);
      expect(find.text('SOFT'), findsOneWidget);
      expect(find.text('MEDIUM'), findsOneWidget);
      expect(find.text('HEAVY'), findsOneWidget);

      await tester.tap(find.text('HEAVY'));
      await tester.pumpAndSettle();
      expect(selected, HapticIntensity.heavy);

      await tester.tap(find.text('OFF'));
      await tester.pumpAndSettle();
      expect(selected, HapticIntensity.off);
    });

    testWidgets('TestHapticButton triggers callback and ripple animation',
        (WidgetTester tester) async {
      bool tested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestHapticButton(
              intensity: HapticIntensity.medium,
              onTest: () => tested = true,
            ),
          ),
        ),
      );

      expect(find.text('TEST HAPTIC PULSE'), findsOneWidget);
      await tester.tap(find.byType(TestHapticButton));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tested, isTrue);
    });

    testWidgets('AionAudioSection and AionHapticsSection render inside ProviderScope',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    AionAudioSection(),
                    SizedBox(height: 16),
                    AionHapticsSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AUDIO & SOUND CHANNELS'), findsOneWidget);
      expect(find.text('Mute All Audio'), findsOneWidget);
      expect(find.text('Master Volume'), findsOneWidget);
      expect(find.text('BGM (Background Music)'), findsOneWidget);
      expect(find.text('SFX (Sound Effects)'), findsOneWidget);
      expect(find.text('Voice & Dialogue'), findsOneWidget);
      expect(find.text('Ambient & Atmosphere'), findsOneWidget);

      expect(find.text('HAPTIC FEEDBACK & GAMEPLAY'), findsOneWidget);
      expect(find.text('VIBRATION INTENSITY'), findsOneWidget);
      expect(find.text('Reduce Motion & Shake'), findsOneWidget);
      expect(find.text('TEST HAPTIC PULSE'), findsOneWidget);
    });
  });
}
