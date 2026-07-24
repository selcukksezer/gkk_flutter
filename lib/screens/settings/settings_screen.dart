import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/universal_game_dialog.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/game_notification_scheduler.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/music_service.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import '../../l10n/l10n.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _musicVolume = 0.7;
  bool _muteAll = false;
  bool _notifications = true;
  bool _notifNightMarket = true;
  bool _notifNemesis = true;

  late TextEditingController _nameController;
  bool _savingName = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerProvider).profile;
    final name = profile?.displayName ?? profile?.username ?? '';
    _nameController = TextEditingController(text: name);
    _musicVolume = MusicService.instance.volume;
    _muteAll = MusicService.instance.muted;
    unawaited(_loadNotificationPref());
  }

  Future<void> _loadNotificationPref() async {
    await LocalNotificationService.instance.loadEnabledPreference();
    if (!mounted) return;
    setState(() {
      _notifications = LocalNotificationService.instance.isEnabled;
      _notifNightMarket = LocalNotificationService.instance.isNightMarketEnabled;
      _notifNemesis = LocalNotificationService.instance.isNemesisEnabled;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.length < 3) {
      setState(() => _nameError = context.l10n.settingsNameMinLength);
      return;
    }
    setState(() {
      _nameError = null;
      _savingName = true;
    });
    try {
      await SupabaseService.client.rpc('update_user_profile', params: {'p_display_name': name});
      await ref.read(playerProvider.notifier).loadProfile();
      if (mounted) {
        AppMessenger.show(context, context.l10n.settingsNameUpdated);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(
          context,
          userFacingErrorMessage(e, fallback: 'Profil güncellenemedi.'),
        );
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
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
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await UniversalGameDialog.show(
      context,
      title: context.l10n.settingsDeleteAccountTitle,
      message: context.l10n.settingsDeleteAccountConfirm,
      confirmLabel: context.l10n.settingsDeleteAccountTitle,
      cancelLabel: context.l10n.commonCancel,
      accent: AppColors.mysticRuby,
    );
    if (confirm != true) return;
    try {
      await SupabaseService.client.rpc('delete_account');
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
      if (mounted) context.go(AppRoutes.login);
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(
          context,
          userFacingErrorMessage(e, fallback: 'Hesap silinemedi.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String languageCode = ref.watch(localeProvider).languageCode;

    return Scaffold(
      appBar: GameTopBar(
        title: l10n.routeSettings,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.settings,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      body: GameScreenBackground(
        child: ListView(
          padding: GameScrollLayout.withClearance(context, const EdgeInsets.all(16)),
          children: <Widget>[
            _sectionCard(
              title: context.l10n.ses_ayarlar,
              children: <Widget>[
                _sliderTile(
                  label: '🎵 Müzik ${(_musicVolume * 100).round()}%',
                  value: _muteAll ? 0.0 : _musicVolume,
                  onChanged: _muteAll
                      ? null
                      : (v) {
                          setState(() => _musicVolume = v);
                          MusicService.instance.setVolume(v);
                        },
                ),
                _sliderTile(
                  label: '🔔 Efektler (yakında)',
                  value: 0.0,
                  onChanged: null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.t_m_sesleri_kapat),
                  value: _muteAll,
                  onChanged: (v) {
                    setState(() => _muteAll = v);
                    MusicService.instance.setMuted(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: context.l10n.bildirimler_oyun,
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.bildirimler),
                  value: _notifications,
                  onChanged: (bool v) async {
                    setState(() => _notifications = v);
                    await LocalNotificationService.instance.setEnabled(v);
                    if (v) {
                      final profile = ref.read(playerProvider).profile;
                      await GameNotificationScheduler.instance.syncAll(profile: profile);
                    }
                  },
                ),
                if (_notifications) ...<Widget>[
                  SwitchListTile(
                    contentPadding: const EdgeInsets.only(left: 12),
                    title: const Text('Gece Pazarı'),
                    subtitle: const Text(
                      'Açılış / kapanış hatırlatmaları',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    value: _notifNightMarket,
                    onChanged: (bool v) async {
                      setState(() => _notifNightMarket = v);
                      await LocalNotificationService.instance
                          .setNightMarketEnabled(v);
                      if (v) {
                        await GameNotificationScheduler.instance
                            .syncNightMarketReminder();
                      } else {
                        await GameNotificationScheduler.instance
                            .cancelNightMarketReminders();
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.only(left: 12),
                    title: const Text('Nemesis'),
                    subtitle: const Text(
                      'Çevrimiçi / intikam bildirimleri',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    value: _notifNemesis,
                    onChanged: (bool v) async {
                      setState(() => _notifNemesis = v);
                      await LocalNotificationService.instance
                          .setNemesisEnabled(v);
                    },
                  ),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.otomatik_sava),
                  subtitle: const Text(
                    'PvP ve zindan otomatik savaş henüz bağlı değil',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  leading: const Icon(Icons.smart_toy_outlined, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: l10n.dil_language,
              children: <Widget>[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: <ButtonSegment<String>>[
                      ButtonSegment<String>(value: 'tr', label: Text(l10n.t_rk_e)),
                      ButtonSegment<String>(value: 'en', label: Text(l10n.english)),
                    ],
                    selected: <String>{languageCode},
                    onSelectionChanged: (Set<String> selection) {
                      ref.read(localeProvider.notifier).setLocale(Locale(selection.first));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: context.l10n.profil,
              children: <Widget>[
                const SizedBox(height: 4),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsDisplayNameLabel,
                    errorText: _nameError,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _savingName ? null : _saveName,
                    child: _savingName
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(context.l10n.kaydet),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: context.l10n.hesap,
              children: <Widget>[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(context.l10n.k_yap),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: Text(context.l10n.hesab_sil),
                    style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return DottedPanel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      borderColor: AppColors.liquidGold.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.liquidGold,
              letterSpacing: 0.6,
            ),
          ),
          Divider(
            color: Colors.white.withValues(alpha: 0.08),
            height: 18,
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _sliderTile({required String label, required double value, ValueChanged<double>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        Slider(
          value: value,
          onChanged: onChanged,
          min: 0.0,
          max: 1.0,
        ),
      ],
    );
  }
}
