import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/game_notification_scheduler.dart';
import '../../core/services/local_notification_service.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/box_opening_provider.dart';
import '../../providers/player_provider.dart';

/// Profil/kasa/tesis verisi değişince telefon zamanlayıcılarını günceller.
class PhoneNotificationSync extends ConsumerStatefulWidget {
  const PhoneNotificationSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PhoneNotificationSync> createState() => _PhoneNotificationSyncState();
}

class _PhoneNotificationSyncState extends ConsumerState<PhoneNotificationSync> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await LocalNotificationService.instance.initialize();
    if (!mounted) return;
    _syncFromState();
  }

  void _syncFromState() {
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    final List<BoxOpening> boxes = ref.read(boxOpeningProvider);
    unawaited(
      GameNotificationScheduler.instance.syncAll(
        profile: profile,
        boxOpenings: boxes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (AuthState? prev, AuthState next) {
      if (next.status == AuthStatus.unauthenticated) {
        unawaited(GameNotificationScheduler.instance.clearAllOnLogout());
        return;
      }
      if (next.status == AuthStatus.authenticated) {
        _syncFromState();
      }
    });

    ref.listen<PlayerState>(playerProvider, (_, PlayerState next) {
      unawaited(GameNotificationScheduler.instance.syncProfile(next.profile));
    });

    ref.listen<List<BoxOpening>>(boxOpeningProvider, (_, List<BoxOpening> next) {
      unawaited(GameNotificationScheduler.instance.syncBoxOpenings(next));
    });

    return widget.child;
  }
}
