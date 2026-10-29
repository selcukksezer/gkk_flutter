import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_haptics.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../services/audio_haptics_settings_service.dart';
import 'audio_level_meter.dart';
import 'settings_design.dart';

/// Aion-2 luxury audio slider tile with integrated glowing sound level meter.
class AionAudioSliderTile extends StatelessWidget {
  const AionAudioSliderTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.accentColor,
    this.enabled = true,
    this.muted = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  final Color accentColor;
  final bool enabled;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final double displayVal = (enabled && !muted) ? value : 0.0;
    final int pct = (displayVal * 100).round();
    final bool isEffectivelyMuted = muted || !enabled || displayVal <= 0.001;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: SettingsPalette.obsidian.withValues(alpha: 0.55),
        border: Border.all(
          color: enabled
              ? accentColor.withValues(alpha: 0.22)
              : SettingsPalette.titanium.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: <Color>[
                      accentColor.withValues(alpha: enabled ? 0.35 : 0.1),
                      SettingsPalette.obsidian,
                    ],
                  ),
                  border: Border.all(
                    color: accentColor.withValues(alpha: enabled ? 0.5 : 0.2),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: enabled ? accentColor : SettingsPalette.titanium,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: enabled
                            ? SettingsPalette.textHi
                            : SettingsPalette.titanium,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.titanium,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: isEffectivelyMuted
                      ? SettingsPalette.obsidian
                      : accentColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: isEffectivelyMuted
                        ? SettingsPalette.titanium.withValues(alpha: 0.25)
                        : accentColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isEffectivelyMuted ? 'MUTED' : '$pct%',
                  style: AppTextStyles.captionBold.copyWith(
                    color: isEffectivelyMuted
                        ? SettingsPalette.titanium
                        : accentColor,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GlowingSoundLevelMeter(
            volume: displayVal,
            accentColor: accentColor,
            muted: isEffectivelyMuted,
            barCount: 14,
            height: 16,
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8,
                pressedElevation: 6,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: accentColor,
              inactiveTrackColor: SettingsPalette.obsidian,
              thumbColor: enabled ? accentColor : SettingsPalette.titanium,
              overlayColor: accentColor.withValues(alpha: 0.2),
              disabledActiveTrackColor:
                  SettingsPalette.titanium.withValues(alpha: 0.25),
              disabledInactiveTrackColor: SettingsPalette.obsidian,
              disabledThumbColor: SettingsPalette.titanium,
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: enabled
                  ? (double v) {
                      AppHaptics.selection();
                      onChanged(v);
                    }
                  : null,
              min: 0,
              max: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aion-2 luxury Haptic intensity selector (Off, Soft, Medium, Heavy)
/// with instant tactile feedback and test pulse button.
class HapticIntensitySelector extends StatelessWidget {
  const HapticIntensitySelector({
    super.key,
    required this.selectedIntensity,
    required this.onChanged,
  });

  final HapticIntensity selectedIntensity;
  final ValueChanged<HapticIntensity> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: HapticIntensity.values.map((HapticIntensity tier) {
            final bool isSelected = tier == selectedIntensity;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _IntensityChip(
                  tier: tier,
                  isSelected: isSelected,
                  onTap: () => onChanged(tier),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: SettingsPalette.obsidian.withValues(alpha: 0.6),
            border: Border.all(
              color: SettingsPalette.gold.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selectedIntensity == HapticIntensity.off
                    ? Icons.vibration_rounded
                    : Icons.sensors_rounded,
                size: 14,
                color: selectedIntensity == HapticIntensity.off
                    ? SettingsPalette.titanium
                    : SettingsPalette.neon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedIntensity.description,
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.textMid,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntensityChip extends StatelessWidget {
  const _IntensityChip({
    required this.tier,
    required this.isSelected,
    required this.onTap,
  });

  final HapticIntensity tier;
  final bool isSelected;
  final VoidCallback onTap;

  Color get _accentColor => switch (tier) {
    HapticIntensity.off => SettingsPalette.titanium,
    HapticIntensity.soft => AppColors.accentCyan,
    HapticIntensity.medium => SettingsPalette.gold,
    HapticIntensity.heavy => SettingsPalette.ruby,
  };

  IconData get _icon => switch (tier) {
    HapticIntensity.off => Icons.phonelink_erase_rounded,
    HapticIntensity.soft => Icons.touch_app_rounded,
    HapticIntensity.medium => Icons.vibration_rounded,
    HapticIntensity.heavy => Icons.bolt_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    _accentColor.withValues(alpha: 0.35),
                    SettingsPalette.navy.withValues(alpha: 0.9),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : SettingsPalette.obsidian.withValues(alpha: 0.7),
          border: Border.all(
            color: isSelected
                ? _accentColor.withValues(alpha: 0.85)
                : SettingsPalette.titanium.withValues(alpha: 0.25),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: _accentColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              _icon,
              size: 18,
              color: isSelected ? _accentColor : SettingsPalette.titanium,
            ),
            const SizedBox(height: 5),
            Text(
              tier.title.toUpperCase(),
              style: AppTextStyles.captionBold.copyWith(
                color: isSelected
                    ? SettingsPalette.textHi
                    : SettingsPalette.titanium,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Test Vibration button with animated tactile feedback ripple.
class TestHapticButton extends StatefulWidget {
  const TestHapticButton({
    super.key,
    required this.intensity,
    required this.onTest,
  });

  final HapticIntensity intensity;
  final VoidCallback onTest;

  @override
  State<TestHapticButton> createState() => _TestHapticButtonState();
}

class _TestHapticButtonState extends State<TestHapticButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  void _triggerTest() {
    _rippleController.forward(from: 0.0);
    widget.onTest();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOff = widget.intensity == HapticIntensity.off;
    final Color buttonAccent =
        isOff ? SettingsPalette.titanium : SettingsPalette.neon;

    return SettingsPressable(
      onTap: _triggerTest,
      child: AnimatedBuilder(
        animation: _rippleController,
        builder: (BuildContext context, Widget? child) {
          final double t = _rippleController.value;
          return Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: <Color>[
                  buttonAccent.withValues(
                    alpha: isOff ? 0.15 : 0.28 + (1 - t) * 0.15,
                  ),
                  SettingsPalette.obsidian,
                ],
              ),
              border: Border.all(
                color: buttonAccent.withValues(alpha: 0.45 + (1 - t) * 0.35),
              ),
              boxShadow: !isOff && t > 0 && t < 1
                  ? <BoxShadow>[
                      BoxShadow(
                        color: buttonAccent.withValues(alpha: (1 - t) * 0.4),
                        blurRadius: 14 * t,
                        spreadRadius: 2 * t,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.vibration_rounded,
                  size: 16,
                  color: buttonAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  isOff ? 'TEST VIBRATION (OFF)' : 'TEST HAPTIC PULSE',
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Aion-2 Complete Audio Settings Section with Master, BGM, SFX, Voice, Ambient
/// volume sliders, glowing VU level meters, and Master Mute.
class AionAudioSection extends ConsumerWidget {
  const AionAudioSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AudioHapticsState state = ref.watch(audioHapticsSettingsProvider);
    final AudioHapticsNotifier notifier =
        ref.read(audioHapticsSettingsProvider.notifier);

    return SettingsGlassCard(
      accent: SettingsPalette.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SettingsSectionHeader(
            icon: Icons.music_note_rounded,
            title: 'AUDIO & SOUND CHANNELS',
            subtitle: 'Aion-2 dynamic sound stage & volume control',
            accent: SettingsPalette.gold,
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),

          // Master Mute All toggle
          SettingsToggleRow(
            title: 'Mute All Audio',
            subtitle:
                'Instantly silence all background music, sound effects and voices',
            icon: Icons.volume_off_rounded,
            value: state.muteAll,
            onChanged: (bool v) => notifier.setMuteAll(v),
          ),
          const SizedBox(height: 8),

          // 1. Master Volume (Liquid Gold)
          AionAudioSliderTile(
            title: 'Master Volume',
            subtitle: 'Global audio output ceiling for all channels',
            icon: Icons.volume_up_rounded,
            value: state.masterVolume,
            accentColor: SettingsPalette.gold,
            muted: state.muteAll,
            onChanged: (double v) => notifier.setMasterVolume(v),
          ),

          // 2. BGM / Background Music (Cyber Fuchsia)
          AionAudioSliderTile(
            title: 'BGM (Background Music)',
            subtitle: 'Cinematic orchestral theme & atmospheric battle tracks',
            icon: Icons.library_music_rounded,
            value: state.bgmVolume,
            accentColor: SettingsPalette.fuchsia,
            muted: state.muteAll,
            onChanged: (double v) => notifier.setBgmVolume(v),
          ),

          // 3. Sound Effects / SFX (Electric Coral)
          AionAudioSliderTile(
            title: 'SFX (Sound Effects)',
            subtitle: 'Weapon impacts, spells, UI clicks & hit-stop sounds',
            icon: Icons.graphic_eq_rounded,
            value: state.sfxVolume,
            accentColor: SettingsPalette.coral,
            muted: state.muteAll,
            onChanged: (double v) => notifier.setSfxVolume(v),
          ),

          // 4. Voice / Dialogue (Arcane Cyan)
          AionAudioSliderTile(
            title: 'Voice & Dialogue',
            subtitle: 'Hero voice lines, NPC dialogue & battle shouts',
            icon: Icons.record_voice_over_rounded,
            value: state.voiceVolume,
            accentColor: AppColors.accentCyan,
            muted: state.muteAll,
            onChanged: (double v) => notifier.setVoiceVolume(v),
          ),

          // 5. Ambient / Atmosphere (Toxic Neon)
          AionAudioSliderTile(
            title: 'Ambient & Atmosphere',
            subtitle:
                'Wind rustling, dungeon echoes, rain & environmental cues',
            icon: Icons.air_rounded,
            value: state.ambientVolume,
            accentColor: SettingsPalette.neon,
            muted: state.muteAll,
            onChanged: (double v) => notifier.setAmbientVolume(v),
          ),

          const SizedBox(height: 8),
          // Reset button
          Align(
            alignment: Alignment.centerRight,
            child: SettingsPressable(
              onTap: () => notifier.resetToDefaults(),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.restore_rounded,
                      size: 13,
                      color: SettingsPalette.titanium,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reset Audio Defaults',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.titanium,
                        fontSize: 11,
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
}

/// Aion-2 Complete Haptics & Gameplay Section with 4-tier intensity selector,
/// interactive test vibration button, and motion reduction toggle.
class AionHapticsSection extends ConsumerWidget {
  const AionHapticsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AudioHapticsState state = ref.watch(audioHapticsSettingsProvider);
    final AudioHapticsNotifier notifier =
        ref.read(audioHapticsSettingsProvider.notifier);

    return SettingsGlassCard(
      accent: SettingsPalette.fuchsia,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SettingsSectionHeader(
            icon: Icons.vibration_rounded,
            title: 'HAPTIC FEEDBACK & GAMEPLAY',
            subtitle: 'Tactile vibration response & combat hit sensation',
            accent: SettingsPalette.fuchsia,
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),

          Text(
            'VIBRATION INTENSITY',
            style: AppTextStyles.captionBold.copyWith(
              color: SettingsPalette.textHi,
              fontSize: 11.5,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          HapticIntensitySelector(
            selectedIntensity: state.hapticIntensity,
            onChanged: (HapticIntensity tier) =>
                notifier.setHapticIntensity(tier),
          ),
          const SizedBox(height: 12),

          TestHapticButton(
            intensity: state.hapticIntensity,
            onTest: () => notifier.testHapticPulse(),
          ),
          const SizedBox(height: 12),

          SettingsToggleRow(
            title: 'Reduce Motion & Shake',
            subtitle:
                'Softens screen shake in combat and limits rapid animations',
            icon: Icons.animation_rounded,
            value: state.reduceMotion,
            onChanged: (bool v) => notifier.setReduceMotion(v),
          ),
        ],
      ),
    );
  }
}
