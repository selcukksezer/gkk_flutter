import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/common/app_messenger.dart';
import '../core/services/supabase_service.dart';
import '../core/tutorial/tutorial_modal_suppress.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../routing/app_router.dart';
import '../screens/support/widgets/support_design.dart';
import '../theme/app_text_styles.dart';

class BanStatus {
  const BanStatus({
    required this.isBanned,
    this.reason,
    this.until,
  });

  final bool isBanned;
  final String? reason;
  final DateTime? until;

  static const BanStatus clear = BanStatus(isBanned: false);
}

/// Polls + realtime ban updates; blocks all gameplay when active.
class BanEnforcementGate extends ConsumerStatefulWidget {
  const BanEnforcementGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BanEnforcementGate> createState() => _BanEnforcementGateState();
}

class _BanEnforcementGateState extends ConsumerState<BanEnforcementGate> {
  BanStatus _status = BanStatus.clear;
  bool _loading = false;
  bool _notified = false;
  Timer? _pollTimer;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!SupabaseService.isInitialized) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());

    SupabaseService.client.auth.onAuthStateChange.listen((_) {
      final session = SupabaseService.client.auth.currentSession;
      if (session == null) {
        if (mounted) {
          setState(() {
            _status = BanStatus.clear;
            _notified = false;
          });
        }
        _channel?.unsubscribe();
        _channel = null;
      } else {
        unawaited(_refresh());
        _subscribeRealtime(session.user.id);
      }
    });

    final session = SupabaseService.client.auth.currentSession;
    if (session != null) {
      await _refresh();
      _subscribeRealtime(session.user.id);
    }
  }

  void _subscribeRealtime(String authId) {
    if (!SupabaseService.isInitialized) return;
    _channel?.unsubscribe();
    _channel = SupabaseService.client
        .channel('ban-watch-$authId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'auth_id',
            value: authId,
          ),
          callback: (_) => unawaited(_refresh()),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentSession == null ||
        _loading) {
      return;
    }
    _loading = true;
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('get_my_ban_status');
      if (!mounted) return;
      if (raw is! Map) return;

      final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
      if (data['success'] != true) return;

      final bool banned = data['is_banned'] == true;
      final String? reason = data['ban_reason']?.toString();
      final DateTime? until = data['banned_until'] != null
          ? DateTime.tryParse(data['banned_until'].toString())?.toLocal()
          : null;

      final bool wasBanned = _status.isBanned;
      setState(() {
        _status = banned
            ? BanStatus(isBanned: true, reason: reason, until: until)
            : BanStatus.clear;
      });

      if (banned && !wasBanned && !_notified && mounted) {
        _notified = true;
        final String untilLabel = until == null
            ? 'Kalıcı'
            : '${until.day.toString().padLeft(2, '0')}.${until.month.toString().padLeft(2, '0')}.${until.year} ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
        AppMessenger.showError(
          context,
          'Hesabın askıya alındı.\nSebep: ${reason ?? 'Belirtilmedi'}\nSüre: $untilLabel',
        );
      }
      if (!banned) {
        _notified = false;
      }
    } catch (_) {
      // Offline — keep last known status.
    } finally {
      _loading = false;
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
    if (!_status.isBanned) return widget.child;

    return TutorialSuppressScope(
      active: true,
      child: Stack(
        children: <Widget>[
          IgnorePointer(child: widget.child),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: SettingsPalette.void_.withValues(alpha: 0.88)),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
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
                      _status.reason ?? 'Belirtilmedi',
                      style: AppTextStyles.body.copyWith(color: SettingsPalette.textHi),
                    ),
                    const SizedBox(height: 12),
                  Text(
                    'Süre',
                    style: AppTextStyles.caption.copyWith(color: SettingsPalette.titanium),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatUntil(_status.until),
                    style: AppTextStyles.body.copyWith(color: SettingsPalette.textHi),
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
        ],
      ),
    );
  }
}
