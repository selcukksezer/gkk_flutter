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
import '../../core/services/local_notification_service.dart';
import '../../core/services/supabase_service.dart';
import '../../l10n/l10n.dart';
import '../../models/player_model.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/policy_provider.dart';
import '../../providers/staff_provider.dart';
import '../support/widgets/bug_report_reward.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/logout_helper.dart';
import '../../theme/app_text_styles.dart';
import 'services/audio_haptics_settings_service.dart';
import 'widgets/audio_haptics_controls.dart';
import 'widgets/delete_account_confirm_dialog.dart';
import 'widgets/preloader_cache_diagnostics_card.dart';
import 'widgets/settings_design.dart';
import 'graphics_quality_section.dart';
import 'graphics_settings_provider.dart';
import 'graphics_settings_screen.dart';
import 'graphics_settings_service.dart';
import '../../core/engine/adaptive_quality_scaler.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _graphicsKey = GlobalKey();
  final GlobalKey _audioKey = GlobalKey();
  final GlobalKey _hapticsKey = GlobalKey();
  final GlobalKey _diagnosticsKey = GlobalKey();
  final GlobalKey _notifKey = GlobalKey();
  final GlobalKey _accountKey = GlobalKey();

  int _selectedCategory = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(appSettingsProvider.notifier).reload());
      unawaited(ref.read(audioHapticsSettingsProvider.notifier).reload());
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    AppHaptics.selection();
    final BuildContext? targetContext = key.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.06,
      );
    }
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

    // Modern SwitchThemeData enforcing AAA luxury token styling with NO deprecated activeThumbColor
    final SwitchThemeData modernSwitchTheme = SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return SettingsPalette.titanium.withValues(alpha: 0.5);
        }
        if (states.contains(WidgetState.selected)) {
          return SettingsPalette.textHi;
        }
        return SettingsPalette.titanium;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) {
          return SettingsPalette.obsidian.withValues(alpha: 0.4);
        }
        if (states.contains(WidgetState.selected)) {
          return SettingsPalette.neon.withValues(alpha: 0.85);
        }
        return SettingsPalette.obsidian;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return SettingsPalette.neon.withValues(alpha: 0.9);
        }
        return SettingsPalette.titanium.withValues(alpha: 0.35);
      }),
      overlayColor: WidgetStateProperty.all(
        SettingsPalette.neon.withValues(alpha: 0.15),
      ),
    );

    return Scaffold(
      appBar: GameTopBar(title: l10n.routeSettings, onLogout: _logoutChrome),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.settings,
        onLogout: _logoutChrome,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(switchTheme: modernSwitchTheme),
        child: GameScreenBackground(
          child: !settings.ready
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: _scrollController,
                  padding: GameScrollLayout.withClearance(
                    context,
                    const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  ),
                  children: <Widget>[
                    // 0. Player Profile Hero Card
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
                    const SizedBox(height: 12),

                    // 1. Runic Category Quick Navigation Bar
                    SettingsStagger(
                      index: 1,
                      reduceMotion: settings.reduceMotion,
                      child: _RunicCategoryNav(
                        selectedIndex: _selectedCategory,
                        onSelect: (int idx) {
                          setState(() => _selectedCategory = idx);
                          switch (idx) {
                            case 0:
                              _scrollToKey(_graphicsKey);
                            case 1:
                              _scrollToKey(_audioKey);
                            case 2:
                              _scrollToKey(_hapticsKey);
                            case 3:
                              _scrollToKey(_diagnosticsKey);
                            case 4:
                              _scrollToKey(_notifKey);
                            case 5:
                              _scrollToKey(_accountKey);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Aion-2 Graphics Settings Router Card
                    KeyedSubtree(
                      key: _graphicsKey,
                      child: SettingsStagger(
                        index: 2,
                        reduceMotion: settings.reduceMotion,
                        child: const _GraphicsRouterHeroCard(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. In-Line Graphics Quality & Scaler Controls
                    SettingsStagger(
                      index: 3,
                      reduceMotion: settings.reduceMotion,
                      child: const GraphicsQualitySection(),
                    ),
                    const SizedBox(height: 14),

                    // 4. Runic Audio & Sound Stage Quick Presets
                    KeyedSubtree(
                      key: _audioKey,
                      child: SettingsStagger(
                        index: 4,
                        reduceMotion: settings.reduceMotion,
                        child: const _RunicAudioPresetsCard(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 5. In-Line Detailed Audio Sliders & Channels
                    SettingsStagger(
                      index: 5,
                      reduceMotion: settings.reduceMotion,
                      child: const AionAudioSection(),
                    ),
                    const SizedBox(height: 14),

                    // 6. In-Line Haptics & Gameplay Response
                    KeyedSubtree(
                      key: _hapticsKey,
                      child: SettingsStagger(
                        index: 6,
                        reduceMotion: settings.reduceMotion,
                        child: const AionHapticsSection(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 7. ZeroJank Preloader & 3D Cache Diagnostics Card
                    KeyedSubtree(
                      key: _diagnosticsKey,
                      child: SettingsStagger(
                        index: 7,
                        reduceMotion: settings.reduceMotion,
                        child: const PreloaderCacheDiagnosticsCard(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 8. Notifications Settings Section
                    KeyedSubtree(
                      key: _notifKey,
                      child: SettingsStagger(
                        index: 8,
                        reduceMotion: settings.reduceMotion,
                        child: _NotificationsSection(settings: settings),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 9. Language Selection Section
                    SettingsStagger(
                      index: 9,
                      reduceMotion: settings.reduceMotion,
                      child: _LanguageSection(languageCode: languageCode),
                    ),
                    const SizedBox(height: 14),

                    // 10. Support & Bug Report Section
                    SettingsStagger(
                      index: 10,
                      reduceMotion: settings.reduceMotion,
                      child: const _SupportSection(),
                    ),
                    const SizedBox(height: 14),

                    // 11. Legal Documents Section
                    SettingsStagger(
                      index: 11,
                      reduceMotion: settings.reduceMotion,
                      child: const _LegalSection(),
                    ),
                    const SizedBox(height: 14),

                    // 12. Display Name Info Section
                    SettingsStagger(
                      index: 12,
                      reduceMotion: settings.reduceMotion,
                      child: _DisplayNameInfoSection(profile: profile),
                    ),
                    const SizedBox(height: 14),

                    // 13. Account Management Section
                    KeyedSubtree(
                      key: _accountKey,
                      child: SettingsStagger(
                        index: 13,
                        reduceMotion: settings.reduceMotion,
                        child: _AccountSection(
                          onLogout: _logout,
                          onDelete: _deleteAccount,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 14. About & Version Info Section
                    SettingsStagger(
                      index: 14,
                      reduceMotion: settings.reduceMotion,
                      child: const _AboutSection(),
                    ),
                  ],
                ),
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

/// Frosted glass horizontal category quick navigation bar.
class _RunicCategoryNav extends StatelessWidget {
  const _RunicCategoryNav({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const List<_CategoryItem> _categories = <_CategoryItem>[
    _CategoryItem(rune: 'ᚩ', label: 'Grafik', icon: Icons.auto_awesome_rounded, color: Color(0xFF00E5FF)),
    _CategoryItem(rune: 'ᛟ', label: 'Ses', icon: Icons.music_note_rounded, color: SettingsPalette.gold),
    _CategoryItem(rune: 'ᚱ', label: 'Dokunma', icon: Icons.vibration_rounded, color: SettingsPalette.fuchsia),
    _CategoryItem(rune: 'ᛃ', label: 'Teşhis', icon: Icons.memory_rounded, color: SettingsPalette.neon),
    _CategoryItem(rune: 'ᛊ', label: 'Bildirim', icon: Icons.notifications_rounded, color: SettingsPalette.coral),
    _CategoryItem(rune: 'ᛏ', label: 'Hesap', icon: Icons.manage_accounts_rounded, color: SettingsPalette.ruby),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categories.asMap().entries.map((MapEntry<int, _CategoryItem> entry) {
          final int idx = entry.key;
          final _CategoryItem item = entry.value;
          final bool isSelected = idx == selectedIndex;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SettingsPressable(
              onTap: () => onSelect(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected
                      ? item.color.withValues(alpha: 0.22)
                      : SettingsPalette.obsidian.withValues(alpha: 0.7),
                  border: Border.all(
                    color: isSelected
                        ? item.color.withValues(alpha: 0.8)
                        : SettingsPalette.titanium.withValues(alpha: 0.25),
                  ),
                  boxShadow: isSelected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.rune,
                      style: TextStyle(
                        color: isSelected ? item.color : SettingsPalette.titanium,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      item.icon,
                      size: 13,
                      color: isSelected ? item.color : SettingsPalette.titanium,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.label,
                      style: AppTextStyles.captionBold.copyWith(
                        color: isSelected ? SettingsPalette.textHi : SettingsPalette.textMid,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.rune,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String rune;
  final String label;
  final IconData icon;
  final Color color;
}

/// Aion-2 Graphics Settings Router Card with real-time telemetry status.
class _GraphicsRouterHeroCard extends ConsumerWidget {
  const _GraphicsRouterHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GraphicsConfigData config = ref.watch(graphicsSettingsProvider);
    const Color cyan = GraphicsQualitySection.cyanAion;

    final int resPct = (config.resolutionScale * 100).round();
    final String fpsLabel = '${config.targetFps.round()} FPS';

    return SettingsGlassCard(
      accent: cyan,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: <Color>[
                      cyan.withValues(alpha: 0.35),
                      SettingsPalette.navy,
                    ],
                  ),
                  border: Border.all(color: cyan.withValues(alpha: 0.6)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: cyan.withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  size: 20,
                  color: cyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'AION-2 GRAFİK & SCALER MOTORU',
                          style: AppTextStyles.captionBold.copyWith(
                            color: SettingsPalette.textHi,
                            letterSpacing: 0.8,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: cyan.withValues(alpha: 0.15),
                            border: Border.all(color: cyan.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'ROUTER',
                            style: AppTextStyles.captionBold.copyWith(
                              color: cyan,
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Impeller 60/120 FPS · Termal Histerezis Koruması',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.titanium,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bento quick telemetry status row
          Row(
            children: <Widget>[
              Expanded(
                child: _TelemetryPill(
                  label: 'KALİTE',
                  value: config.tier.displayName.toUpperCase(),
                  color: cyan,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TelemetryPill(
                  label: 'HEDEF KARE',
                  value: fpsLabel,
                  color: SettingsPalette.neon,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TelemetryPill(
                  label: 'ÇÖZÜNÜRLÜK',
                  value: '$resPct%',
                  color: SettingsPalette.gold,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TelemetryPill(
                  label: 'SCALER',
                  value: config.autoScalerEnabled ? 'AKTİF' : 'KAPALI',
                  color: config.autoScalerEnabled
                      ? SettingsPalette.neon
                      : SettingsPalette.titanium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsPressable(
            onTap: () {
              AppHaptics.selection();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GraphicsSettingsScreen(),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: <Color>[
                    cyan.withValues(alpha: 0.25),
                    SettingsPalette.obsidian,
                  ],
                ),
                border: Border.all(color: cyan.withValues(alpha: 0.65)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: cyan.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.tune_rounded, size: 16, color: cyan),
                  const SizedBox(width: 8),
                  Text(
                    'GELİŞMİŞ GRAFİK & SCALER TEST BENCH\'İ AÇ',
                    style: AppTextStyles.captionBold.copyWith(
                      color: SettingsPalette.textHi,
                      fontSize: 11.5,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: cyan),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryPill extends StatelessWidget {
  const _TelemetryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: SettingsPalette.obsidian.withValues(alpha: 0.7),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: SettingsPalette.titanium,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.captionBold.copyWith(
              color: color,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Runic Audio & Sound Stage Quick Presets Card.
class _RunicAudioPresetsCard extends ConsumerWidget {
  const _RunicAudioPresetsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AudioHapticsNotifier notifier =
        ref.read(audioHapticsSettingsProvider.notifier);

    return SettingsGlassCard(
      accent: SettingsPalette.gold,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: <Color>[
                      SettingsPalette.gold.withValues(alpha: 0.35),
                      SettingsPalette.obsidian,
                    ],
                  ),
                  border: Border.all(
                    color: SettingsPalette.gold.withValues(alpha: 0.5),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: SettingsPalette.gold.withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'ᛟ',
                    style: TextStyle(
                      color: SettingsPalette.gold,
                      fontSize: 18,
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
                      'RÜNİK AKUSTİK & DOKUNSAL PROFİLLER',
                      style: AppTextStyles.captionBold.copyWith(
                        color: SettingsPalette.textHi,
                        letterSpacing: 0.8,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Anında Aion ses evreni & dokunsal geribildirim önayarları',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.titanium,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _RunicPresetButton(
                  rune: 'ᛟ',
                  title: 'SİNEMATİK',
                  subtitle: 'Dengeli Atmosfer',
                  accent: SettingsPalette.gold,
                  onTap: () async {
                    await notifier.setMasterVolume(1.0);
                    await notifier.setBgmVolume(0.85);
                    await notifier.setSfxVolume(0.75);
                    await notifier.setVoiceVolume(0.95);
                    await notifier.setAmbientVolume(0.80);
                    await notifier.setMuteAll(false);
                    await notifier.setHapticIntensity(HapticIntensity.medium);
                    await AppHaptics.medium();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RunicPresetButton(
                  rune: 'ᚱ',
                  title: 'SAVAŞ',
                  subtitle: 'Ağır Vuruş Hissi',
                  accent: SettingsPalette.coral,
                  onTap: () async {
                    await notifier.setMasterVolume(1.0);
                    await notifier.setBgmVolume(0.50);
                    await notifier.setSfxVolume(1.0);
                    await notifier.setVoiceVolume(0.85);
                    await notifier.setAmbientVolume(0.60);
                    await notifier.setMuteAll(false);
                    await notifier.setHapticIntensity(HapticIntensity.heavy);
                    await AppHaptics.heavy();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RunicPresetButton(
                  rune: 'ᚨ',
                  title: 'SESSİZ',
                  subtitle: 'Gece Fısıltısı',
                  accent: AppColors.accentCyan,
                  onTap: () async {
                    await notifier.setMasterVolume(0.35);
                    await notifier.setBgmVolume(0.25);
                    await notifier.setSfxVolume(0.30);
                    await notifier.setVoiceVolume(0.40);
                    await notifier.setAmbientVolume(0.20);
                    await notifier.setMuteAll(false);
                    await notifier.setHapticIntensity(HapticIntensity.soft);
                    await AppHaptics.light();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RunicPresetButton extends StatelessWidget {
  const _RunicPresetButton({
    required this.rune,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final String rune;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accent.withValues(alpha: 0.18),
              SettingsPalette.obsidian,
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: <Widget>[
            Text(
              rune,
              style: TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: AppTextStyles.captionBold.copyWith(
                color: SettingsPalette.textHi,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: SettingsPalette.titanium,
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

