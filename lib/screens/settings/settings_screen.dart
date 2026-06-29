import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import '../../l10n/l10n.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _musicVolume = 0.7;
  double _sfxVolume = 0.8;
  bool _muteAll = false;
  bool _notifications = true;
  bool _autoBattle = false;

  late TextEditingController _nameController;
  bool _savingName = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerProvider).profile;
    final name = profile?.displayName ?? profile?.username ?? '';
    _nameController = TextEditingController(text: name);
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
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsLogoutTitle),
        content: Text(context.l10n.settingsLogoutConfirm),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(context.l10n.settingsLogoutTitle)),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsDeleteAccountTitle, style: const TextStyle(color: Colors.redAccent)),
        content: Text(context.l10n.settingsDeleteAccountConfirm),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(context.l10n.settingsDeleteAccountTitle),
          ),
        ],
      ),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
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
                      : (v) => setState(() => _musicVolume = v),
                ),
                _sliderTile(
                  label: '🔔 Efektler ${(_sfxVolume * 100).round()}%',
                  value: _muteAll ? 0.0 : _sfxVolume,
                  onChanged: _muteAll
                      ? null
                      : (v) => setState(() => _sfxVolume = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.t_m_sesleri_kapat),
                  value: _muteAll,
                  onChanged: (v) => setState(() => _muteAll = v),
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
                  onChanged: (v) => setState(() => _notifications = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.otomatik_sava),
                  subtitle: const Text(
                    'PvP ve zindan savaşlarını otomatik yönet',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  value: _autoBattle,
                  onChanged: (v) => setState(() => _autoBattle = v),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        color: Colors.black26,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5),
          ),
          const Divider(color: Colors.white12, height: 16),
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
