import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/layout/game_chrome.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../routing/app_router.dart';

/// Support / legal / staff sub-screens: back bar + bottom nav + dot backdrop.
class SupportScreenShell extends ConsumerWidget {
  const SupportScreenShell({
    super.key,
    required this.title,
    required this.body,
    this.fallbackRoute = AppRoutes.settings,
    this.bottomNavRoute = AppRoutes.settings,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final String fallbackRoute;
  final String bottomNavRoute;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return GameSubScreenScaffold(
      title: title,
      onLogout: logout,
      fallbackRoute: fallbackRoute,
      bottomNavRoute: bottomNavRoute,
      floatingActionButton: floatingActionButton,
      body: GameScreenBackground(child: body),
    );
  }
}
