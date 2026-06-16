import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/layout/game_chrome.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_spacing.dart';
import 'mekan_design.dart';

/// Hub screen — bottom nav, no back bar.
class MekanHubScaffold extends ConsumerWidget {
  const MekanHubScaffold({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      extendBody: true,
      appBar: GameTopBar(title: title, onLogout: logout),
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.mekans, onLogout: logout),
      body: MekanBackdrop(child: body),
    );
  }
}

/// Sub-screens — back bar + optional bottom nav.
class MekanSubScaffold extends ConsumerWidget {
  const MekanSubScaffold({
    super.key,
    required this.title,
    required this.body,
    this.fallbackRoute = AppRoutes.mekans,
    this.showBottomNav = true,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final String fallbackRoute;
  final bool showBottomNav;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(fallbackRoute);
      }
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) context.go(fallbackRoute);
      },
      child: Scaffold(
        extendBody: showBottomNav,
        appBar: GameTopBar(title: title, onLogout: logout),
        bottomNavigationBar: showBottomNav
            ? GameBottomBar(currentRoute: AppRoutes.mekans, onLogout: logout)
            : null,
        floatingActionButton: floatingActionButton,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MekanBackBar(onBack: goBack),
            Expanded(child: MekanBackdrop(child: body)),
          ],
        ),
      ),
    );
  }
}

class MekanBackBar extends StatelessWidget {
  const MekanBackBar({super.key, required this.onBack, this.label = 'Geri'});

  final VoidCallback onBack;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MekanPalette.void_.withValues(alpha: 0.96),
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: onBack,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: MekanPalette.aqua.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: MekanPalette.aqua.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: MekanPalette.aqua,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: const TextStyle(
                    color: MekanPalette.aqua,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
