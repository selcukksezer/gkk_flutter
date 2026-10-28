import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/profile_avatar.dart';
import '../../components/common/universal_game_dialog.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/game_notification_scheduler.dart';
import '../../core/services/graphics_quality_service.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/supabase_service.dart';
import '../../l10n/l10n.dart';
import '../../models/player_model.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/graphics_quality_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/policy_provider.dart';
import '../../providers/staff_provider.dart';
import '../support/widgets/bug_report_reward.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/logout_helper.dart';
import '../../theme/app_text_styles.dart';
import 'widgets/delete_account_confirm_dialog.dart';
import 'widgets/settings_design.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(appSettingsProvider.notifier).reload());
    });
  }

  Future<void> _logout() async {
    final bool? confirm = await UniversalGameDialog.show(
      context,
      title: context.l10n.settingsLogoutTitle,
      message: context.l10n.settingsLogoutConfirm,
      confirmLabel: context.l10n.settingsLogoutTitle,
      cancelLabel: context.l10n.commonCancel,
    );
    if (confirm != true) return;
    await performLogout(ref);
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _deleteAccount() async {
    final String? username = ref.read(playerProvider).profile?.username;
    if (username == null || username.isEmpty) {
      AppMessenger.showError(
        context,
        context.l10n.settingsDeleteUsernameMissing,
      );
      return;
    }

    final bool? confirm = await showDeleteAccountConfirmDialog(
      context,
      username: username,
    );
    if (confirm != true) return;
    try {
      await SupabaseService.client.rpc(
        'delete_account',
        params: <String, dynamic>{'p_username': username},
      );
      await performLogout(ref);
      if (mounted) context.go(AppRoutes.login);
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(
          context,
          userFacingErrorMessage(
            e,
            fallback: context.l10n.settingsDeleteFailed,
          ),
        );
      }
    }
  }

  Future<void> _logoutChrome() async {
    await performLogout(ref);
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  Future<void> _copyReferral(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    AppHaptics.selection();
    if (mounted) {
      AppMessenger.show(context, context.l10n.settingsReferralCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final SettingsUiState settings = ref.watch(appSettingsProvider);
    final PlayerProfile? profile = ref.watch(playerProvider).profile;
    final String languageCode = ref.watch(localeProvider).languageCode;

    return Scaffold(
      appBar: GameTopBar(title: l10n.routeSettings, onLogout: _logoutChrome),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.settings,
        onLogout: _logoutChrome,
      ),
      body: GameScreenBackground(
        child: !settings.ready
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: GameScrollLayout.withClearance(
                  context,
                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
                ),
                children: <Widget>[
                  SettingsStagger(
                    index: 0,
                    reduceMotion: settings.reduceMotion,
                    child: _ProfileHero(
                      profile: profile,
                      onCopyReferral:
                          profile?.referralCode != null &&
                              profile!.referralCode!.isNotEmpty
                          ? () => _copyReferral(profile.referralCode!)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SettingsStagger(
                    index: 1,
                    reduceMotion: settings.reduceMotion,
                    child: const _GraphicsPerformanceSection(),
                  ),
                  const SizedBox(height: 14),
                  SettingsStagger(
                    index: 2,
                    reduceMotion: settings.reduceMotion,
                    child: _AudioSection(settings: settings),
                  ),
                  const SizedBox(height: 14),
                  SettingsStagger(
                    index: 3,
                    reduceMotion: settings.reduceMotion,
                    child: _GameplaySection(settings: settings),
                  ),
                  const SizedBox(height: 14),
                  SettingsStagger(
                    index: 4,
                    reduceMotion: settings.reduceMotion,
                    child: _NotificationsSection(settings: settings),
                  ),
                  const SizedBox(height: 14),
                  SettingsStagger(
                    index: 5,
                    reduceMotion: settings.reduceMotion,
                    child: _LanguageSection(languageCode: languageCode),
                  ),
                  const SizedBox(height: 14),
                  SettingsStagger(
                    index: 6,
                    reduceMotion: settings.reduceMotion,
                    child: const _SupportSection(),
                  ),
                  const SizedBox(height: 14),
                  SettingsStagger(
                    index: 7,
                    reduceMotion: settings.reduceMotion,
                    child: const _LegalSection(),
                  ),
                  const SizedBox(height: 14),
                  SettingsStagger(
                    index: 8,
                    reduceMotion: settings.reduceMotion,
                    child: _DisplayNameInfoSection(profile: profile),
                  ),
                  const SizedBox(height: 14),
                  SettingsStagger(
                    index: 9,
                    reduceMotion: settings.reduceMotion,
                    child: _AccountSection(
                      onLogout: _logout,
                      onDelete: _deleteAccount,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SettingsStagger(
                    index: 10,
                    reduceMotion: settings.reduceMotion,
                    child: const _AboutSection(),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, this.onCopyReferral});

  final PlayerProfile? profile;
  final VoidCallback? onCopyReferral;

  @override
  Widget build(BuildContext context) {
    final String display = profile == null
        ? '—'
        : ((profile!.displayName ?? profile!.username).trim().isEmpty
              ? profile!.username
              : (profile!.displayName ?? profile!.username));
    final String handle = profile == null ? '' : '@${profile!.username}';
    final int level = profile?.level ?? 1;
    final String? frame = profile?.avatarFrame;
    final bool codexFrame = frame == 'codex';

    return SettingsGlassCard(
      accent: SettingsPalette.gold,
      glow: true,
      child: Row(
        children: <Widget>[
          ProfileAvatar(
            size: 64,
            avatarUrl: profile?.avatarUrl,
            glowFrame: true,
            codexFrame: codexFrame,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  handle,
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.titanium,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _Pill(label: 'Lv $level', color: SettingsPalette.gold),
                    if (profile?.characterClass != null) ...<Widget>[
                      const SizedBox(width: 6),
                      _Pill(
                        label: _classLabel(profile!.characterClass!),
                        color: SettingsPalette.fuchsia,
                      ),
                    ],
                  ],
                ),
                if (onCopyReferral != null) ...<Widget>[
                  const SizedBox(height: 10),
                  SettingsPressable(
                    onTap: onCopyReferral,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: SettingsPalette.obsidian.withValues(alpha: 0.7),
                        border: Border.all(
                          color: SettingsPalette.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.card_giftcard_rounded,
                            size: 14,
                            color: SettingsPalette.gold,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.l10n.settingsReferralCode,
                            style: AppTextStyles.caption.copyWith(
                              color: SettingsPalette.titanium,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            profile!.referralCode!,
                            style: AppTextStyles.captionBold.copyWith(
                              color: SettingsPalette.gold,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: SettingsPalette.titanium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _classLabel(CharacterClass c) => switch (c) {
    CharacterClass.warrior => 'Savaşçı',
    CharacterClass.alchemist => 'Simyacı',
    CharacterClass.shadow => 'Gölge',
  };
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionBold.copyWith(
          color: color,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _GraphicsPerformanceSection extends ConsumerWidget {
  const _GraphicsPerformanceSection();

  Color _accentForTier(GraphicsQualityTier tier) => switch (tier) {
        GraphicsQualityTier.low => SettingsPalette.neon,
        GraphicsQualityTier.medium => AppColors.accentCyan,
        GraphicsQualityTier.high => SettingsPalette.gold,
        GraphicsQualityTier.ultra => SettingsPalette.ruby,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GraphicsQualityState gState = ref.watch(graphicsQualityProvider);
    final GraphicsQualityNotifier notifier =
        ref.read(graphicsQualityProvider.notifier);
    final GraphicsProfile prof = gState.profile;
    final DeviceHardwareReport hw = gState.hardwareReport;
    final Color activeAccent = _accentForTier(prof.tier);

    const List<(GraphicsPreference, String, IconData)> presets =
        <(GraphicsPreference, String, IconData)>[
      (GraphicsPreference.auto, 'Otomatik', Icons.auto_awesome_rounded),
      (GraphicsPreference.low, 'Düşük', Icons.bolt_rounded),
      (GraphicsPreference.medium, 'Orta', Icons.speed_rounded),
      (GraphicsPreference.high, 'Yüksek', Icons.high_quality_rounded),
      (GraphicsPreference.ultra, 'Ultra', Icons.diamond_rounded),
    ];

    return SettingsGlassCard(
      key: const Key('settings_graphics_section'),
      accent: activeAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsSectionHeader(
            icon: Icons.tune_rounded,
            title: 'Grafik ve Performans',
            subtitle:
                'Düşük donanımlı telefonlar dahil her cihaza göre otomatik veya manuel kalite ayarı',
            accent: activeAccent,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: SettingsPalette.obsidian.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: activeAccent.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.memory_rounded,
                      size: 14,
                      color: activeAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Aktif Kademe: ${prof.tier.shortLabelTr.toUpperCase()} • ~${prof.estimatedFps} FPS',
                        style: AppTextStyles.captionBold.copyWith(
                          color: SettingsPalette.textHi,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  hw.summaryTr,
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.titanium,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final (
                    GraphicsPreference mode,
                    String label,
                    IconData icon,
                  ) in presets)
                _GraphicsPresetChip(
                  key: Key('settings_graphics_chip_${mode.name}'),
                  label: mode == GraphicsPreference.auto
                      ? '$label (${hw.recommendedTier.shortLabelTr})'
                      : label,
                  icon: icon,
                  selected: prof.preference == mode,
                  accent: activeAccent,
                  onTap: () => notifier.setPreference(mode),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            prof.tier.subtitleTr,
            style: AppTextStyles.caption.copyWith(
              color: SettingsPalette.textMid,
              fontSize: 11,
              height: 1.32,
            ),
          ),
          if (prof.autoDowngraded) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Otomatik koruma: Cihazda kare gecikmesi algılandığı için "${prof.tier.shortLabelTr}" kademesi etkinleştirildi.',
              style: AppTextStyles.captionBold.copyWith(
                color: SettingsPalette.gold,
                fontSize: 10.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 14),
          SettingsToggleRow(
            title: 'Canlı FPS Sayacını Göster',
            subtitle: 'Sol altta anlık FPS ve aktif grafik kademesini göster',
            icon: Icons.monitor_heart_rounded,
            value: prof.showFpsOverlay,
            onChanged: (bool v) => notifier.setShowFpsOverlay(v),
          ),
        ],
      ),
    );
  }
}

class _GraphicsPresetChip extends StatelessWidget {
  const _GraphicsPresetChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: selected
              ? accent.withValues(alpha: 0.20)
              : SettingsPalette.obsidian.withValues(alpha: 0.72),
          border: Border.all(
            color: selected
                ? accent
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.35 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 14,
              color: selected ? accent : SettingsPalette.titanium,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                color: selected
                    ? SettingsPalette.textHi
                    : SettingsPalette.titanium,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioSection extends ConsumerWidget {
  const _AudioSection({required this.settings});

  final SettingsUiState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appSettingsProvider.notifier);
    return SettingsGlassCard(
      accent: SettingsPalette.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsSectionHeader(
            icon: Icons.music_note_rounded,
            title: context.l10n.settingsSectionAudio,
            subtitle: context.l10n.settingsSectionAudioHint,
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),
          SettingsVolumeSlider(
            label: context.l10n.settingsMusic,
            icon: Icons.library_music_rounded,
            value: settings.muteAll ? 0 : settings.musicVolume,
            enabled: !settings.muteAll,
            onChanged: (double v) => notifier.setMusicVolume(v),
          ),
          SettingsVolumeSlider(
            label: context.l10n.settingsSfx,
            icon: Icons.surround_sound_rounded,
            value: settings.muteAll ? 0 : settings.sfxVolume,
            enabled: !settings.muteAll,
            onChanged: (double v) => notifier.setSfxVolume(v),
          ),
          SettingsToggleRow(
            title: context.l10n.t_m_sesleri_kapat,
            subtitle: context.l10n.settingsMuteHint,
            icon: Icons.volume_off_rounded,
            value: settings.muteAll,
            onChanged: (bool v) => notifier.setMuteAll(v),
          ),
        ],
      ),
    );
  }
}

class _GameplaySection extends ConsumerWidget {
  const _GameplaySection({required this.settings});

  final SettingsUiState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appSettingsProvider.notifier);
    return SettingsGlassCard(
      accent: SettingsPalette.fuchsia,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsSectionHeader(
            icon: Icons.sports_esports_rounded,
            title: context.l10n.settingsSectionGameplay,
            subtitle: context.l10n.settingsSectionGameplayHint,
            accent: SettingsPalette.fuchsia,
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),
          SettingsToggleRow(
            title: context.l10n.settingsHaptic,
            subtitle: context.l10n.settingsHapticHint,
            icon: Icons.vibration_rounded,
            value: settings.hapticEnabled,
            onChanged: (bool v) async {
              await notifier.setHapticEnabled(v);
              if (v) await AppHaptics.medium();
            },
          ),
          SettingsToggleRow(
            title: context.l10n.settingsReduceMotion,
            subtitle: context.l10n.settingsReduceMotionHint,
            icon: Icons.animation_rounded,
            value: settings.reduceMotion,
            onChanged: (bool v) => notifier.setReduceMotion(v),
          ),
        ],
      ),
    );
  }
}

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection({required this.settings});

  final SettingsUiState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appSettingsProvider.notifier);
    return SettingsGlassCard(
      accent: SettingsPalette.coral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsSectionHeader(
            icon: Icons.notifications_active_rounded,
            title: context.l10n.settingsSectionNotif,
            subtitle: context.l10n.settingsSectionNotifHint,
            accent: SettingsPalette.coral,
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),
          SettingsToggleRow(
            title: context.l10n.bildirimler,
            subtitle: context.l10n.settingsNotifMasterHint,
            icon: Icons.notifications_rounded,
            value: settings.notifications,
            onChanged: (bool v) async {
              await notifier.setNotifications(v);
              if (v) {
                final bool granted = await LocalNotificationService.instance
                    .requestPermissions();
                if (!granted && context.mounted) {
                  AppMessenger.showError(
                    context,
                    context.l10n.settingsNotifPermissionWarn,
                  );
                }
                final profile = ref.read(playerProvider).profile;
                await GameNotificationScheduler.instance.syncAll(
                  profile: profile,
                );
              }
            },
          ),
          if (settings.notifications) ...<Widget>[
            SettingsToggleRow(
              indent: true,
              title: context.l10n.settingsNotifNightMarket,
              subtitle: context.l10n.settingsNotifNightMarketHint,
              value: settings.notifNightMarket,
              onChanged: (bool v) async {
                await notifier.setNotifNightMarket(v);
                if (v) {
                  await GameNotificationScheduler.instance
                      .syncNightMarketReminder();
                } else {
                  await GameNotificationScheduler.instance
                      .cancelNightMarketReminders();
                }
              },
            ),
            SettingsToggleRow(
              indent: true,
              title: context.l10n.settingsNotifNemesis,
              subtitle: context.l10n.settingsNotifNemesisHint,
              value: settings.notifNemesis,
              onChanged: (bool v) => notifier.setNotifNemesis(v),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageSection extends ConsumerWidget {
  const _LanguageSection({required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SettingsGlassCard(
      accent: AppColors.accentCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsSectionHeader(
            icon: Icons.language_rounded,
            title: l10n.settingsSectionLanguage,
            subtitle: l10n.settingsSectionLanguageHint,
            accent: AppColors.accentCyan,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _LangChip(
                  label: l10n.t_rk_e,
                  selected: languageCode == 'tr',
                  onTap: () => ref
                      .read(localeProvider.notifier)
                      .setLocale(const Locale('tr')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LangChip(
                  label: l10n.english,
                  selected: languageCode == 'en',
                  onTap: () => ref
                      .read(localeProvider.notifier)
                      .setLocale(const Locale('en')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected
              ? LinearGradient(
                  colors: <Color>[
                    AppColors.accentCyan.withValues(alpha: 0.35),
                    SettingsPalette.navy,
                  ],
                )
              : null,
          color: selected
              ? null
              : SettingsPalette.obsidian.withValues(alpha: 0.7),
          border: Border.all(
            color: selected
                ? AppColors.accentCyan.withValues(alpha: 0.8)
                : SettingsPalette.titanium.withValues(alpha: 0.3),
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.accentCyan.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.captionBold.copyWith(
            color: selected ? AppColors.accentCyan : SettingsPalette.textMid,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _DisplayNameInfoSection extends StatelessWidget {
  const _DisplayNameInfoSection({required this.profile});

  final PlayerProfile? profile;

  @override
  Widget build(BuildContext context) {
    final String display = profile == null
        ? '—'
        : ((profile!.displayName ?? profile!.username).trim().isEmpty
              ? profile!.username
              : (profile!.displayName ?? profile!.username));

    return SettingsGlassCard(
      accent: SettingsPalette.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsSectionHeader(
            icon: Icons.badge_rounded,
            title: context.l10n.settingsSectionProfile,
            subtitle: context.l10n.settingsDisplayNameShopHint,
          ),
          const SizedBox(height: 12),
          Text(
            display,
            style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.settingsDisplayNameItemHint,
            style: AppTextStyles.caption.copyWith(color: SettingsPalette.textMid),
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.onLogout, required this.onDelete});

  final VoidCallback onLogout;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsGlassCard(
      accent: SettingsPalette.ruby,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsSectionHeader(
            icon: Icons.manage_accounts_rounded,
            title: l10n.settingsSectionAccount,
            subtitle: l10n.settingsSectionAccountHint,
            accent: SettingsPalette.ruby,
          ),
          const SizedBox(height: 14),
          SettingsOutlineButton(
            label: l10n.k_yap,
            icon: Icons.logout_rounded,
            accent: SettingsPalette.titanium,
            onPressed: onLogout,
          ),
          const SizedBox(height: 10),
          SettingsDangerButton(
            label: l10n.hesab_sil,
            icon: Icons.delete_forever_rounded,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _SupportSection extends ConsumerWidget {
  const _SupportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final StaffState staff = ref.watch(staffProvider);
    return SettingsGlassCard(
      accent: SettingsPalette.neon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsSectionHeader(
            icon: Icons.support_agent_rounded,
            title: l10n.settingsSectionSupport,
            subtitle: l10n.settingsSectionSupportHint,
            accent: SettingsPalette.neon,
          ),
          const SizedBox(height: 12),
          SettingsPressable(
            onTap: () => context.push(AppRoutes.supportTickets),
            child: _SettingsLinkRow(
              icon: Icons.confirmation_number_outlined,
              label: l10n.settingsSupportMyTickets,
            ),
          ),
          SettingsPressable(
            onTap: () => context.push(AppRoutes.createTicket),
            child: _SettingsLinkRow(
              icon: Icons.add_comment_outlined,
              label: l10n.settingsSupportNewTicket,
            ),
          ),
          SettingsPressable(
            onTap: () => context.push(AppRoutes.myBugReports),
            child: _SettingsLinkRow(
              icon: Icons.bug_report_outlined,
              label: l10n.settingsSupportMyBugReports,
            ),
          ),
          const BugReportSettingsRow(),
          if (staff.profile.isStaff)
            SettingsPressable(
              onTap: () => context.push(AppRoutes.staffHub),
              child: const _SettingsLinkRow(icon: Icons.admin_panel_settings, label: 'Staff Hub'),
            ),
          if (staff.profile.hasLiveOpsAccess)
            SettingsPressable(
              onTap: () => context.push(AppRoutes.staffLiveOps),
              child: const _SettingsLinkRow(icon: Icons.tune, label: 'LiveOps'),
            ),
          const SizedBox(height: 8),
          SettingsPressable(
            onTap: () async {
              await Clipboard.setData(const ClipboardData(text: 'support@gkk.game'));
              if (context.mounted) {
                AppMessenger.show(context, l10n.settingsSupportEmailCopied);
              }
            },
            child: const _SettingsLinkRow(icon: Icons.email_outlined, label: 'support@gkk.game'),
          ),
        ],
      ),
    );
  }
}

class _LegalSection extends ConsumerWidget {
  const _LegalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final PolicyState policy = ref.watch(policyProvider);
    return SettingsGlassCard(
      accent: SettingsPalette.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsSectionHeader(
            icon: Icons.gavel_rounded,
            title: l10n.settingsSectionLegal,
            subtitle: l10n.settingsSectionLegalHint,
            accent: SettingsPalette.gold,
          ),
          const SizedBox(height: 12),
          if (policy.isLoading && policy.documents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (policy.documents.isEmpty)
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.settingsLegalLoadFailed,
                    style: AppTextStyles.caption.copyWith(
                      color: SettingsPalette.textMid,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(policyProvider.notifier).refresh(),
                  child: Text(
                    l10n.commonRetry,
                    style: AppTextStyles.captionBold.copyWith(
                      color: SettingsPalette.gold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            )
          else
            for (final doc in policy.documents)
              SettingsPressable(
                onTap: () => context.push('${AppRoutes.legal}/${doc.type}'),
                child: _SettingsLinkRow(icon: Icons.description_outlined, label: doc.title),
              ),
        ],
      ),
    );
  }
}

class _SettingsLinkRow extends StatelessWidget {
  const _SettingsLinkRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: SettingsPalette.textMid),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: SettingsPalette.textHi))),
          const Icon(Icons.chevron_right, color: SettingsPalette.textMid, size: 18),
        ],
      ),
    );
  }
}

class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  String _version = '—';

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      // Platform bilgisi alınamazsa '—' kalır.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsGlassCard(
      accent: SettingsPalette.titanium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsSectionHeader(
            icon: Icons.info_outline_rounded,
            title: l10n.settingsSectionAbout,
            subtitle: l10n.settingsSectionAboutHint,
            accent: SettingsPalette.titanium,
          ),
          const SizedBox(height: 12),
          _AboutRow(label: l10n.settingsAppName, value: 'GKK'),
          _AboutRow(label: l10n.settingsVersion, value: _version),
          _AboutRow(
            label: l10n.settingsPersistNote,
            value: l10n.settingsPersistNoteValue,
            multiline: true,
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: multiline
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.titanium,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.textMid,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: SettingsPalette.titanium,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}
