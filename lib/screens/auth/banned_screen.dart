import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../screens/support/widgets/support_design.dart';
import '../../theme/app_text_styles.dart';

/// Login / router redirect when account ban active.
class BannedScreen extends ConsumerStatefulWidget {
  const BannedScreen({super.key});

  @override
  ConsumerState<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends ConsumerState<BannedScreen> {
  String? _reason;
  DateTime? _until;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_my_ban_status');
      if (raw is Map && raw['success'] == true && raw['is_banned'] == true) {
        if (mounted) {
          setState(() {
            _reason = raw['ban_reason']?.toString();
            _until = raw['banned_until'] != null
                ? DateTime.tryParse(raw['banned_until'].toString())?.toLocal()
                : null;
            _loading = false;
          });
        }
        return;
      }
      if (mounted) context.go(AppRoutes.home);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
    if (mounted) context.go(AppRoutes.login);
  }

  String _formatUntil(DateTime? until) {
    if (until == null) return 'Kalıcı';
    return '${until.day.toString().padLeft(2, '0')}.${until.month.toString().padLeft(2, '0')}.${until.year} '
        '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: SettingsPalette.void_,
        body: Center(child: CircularProgressIndicator(color: SettingsPalette.gold)),
      );
    }

    return Scaffold(
      backgroundColor: SettingsPalette.void_,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SettingsGlassCard(
                accent: SettingsPalette.ruby,
                glow: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SettingsSectionHeader(
                      icon: Icons.block_rounded,
                      title: 'Hesap askıya alındı',
                      subtitle: 'Bu hesapla oyuna erişemezsin',
                      accent: SettingsPalette.ruby,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sebep',
                      style: AppTextStyles.caption.copyWith(color: SettingsPalette.titanium),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _reason ?? 'Belirtilmedi',
                      style: AppTextStyles.body.copyWith(color: SettingsPalette.textHi),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Süre: ${_formatUntil(_until)}',
                      style: AppTextStyles.caption.copyWith(color: SettingsPalette.titanium),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Çıkış yap'),
                      style: FilledButton.styleFrom(
                        backgroundColor: SettingsPalette.ruby,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
