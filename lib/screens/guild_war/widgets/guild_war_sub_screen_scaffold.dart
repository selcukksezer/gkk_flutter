import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/layout/game_chrome.dart';
import '../../../theme/app_spacing.dart';
import 'guild_war_design.dart';

/// Sub-screens under guild war with back navigation.
class GuildWarSubScreenScaffold extends ConsumerWidget {
  const GuildWarSubScreenScaffold({
    super.key,
    required this.title,
    required this.onLogout,
    required this.body,
    this.currentRoute,
    this.floatingAction,
  });

  final String title;
  final Future<void> Function() onLogout;
  final Widget body;
  final String? currentRoute;
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBody: currentRoute != null,
      appBar: GameTopBar(title: title, onLogout: onLogout),
      bottomNavigationBar: currentRoute != null
          ? GameBottomBar(currentRoute: currentRoute!, onLogout: onLogout)
          : null,
      floatingActionButton: floatingAction,
      body: WarBackdrop(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
              child: WarPressable(
                onTap: () => context.pop(),
                child: WarNeonCard(
                  accent: WarPalette.gold,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  radius: 12,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: WarPalette.gold),
                      SizedBox(width: 6),
                      Text(
                        'Geri',
                        style: TextStyle(
                          color: WarPalette.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
