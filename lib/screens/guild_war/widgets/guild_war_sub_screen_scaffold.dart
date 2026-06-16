import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/layout/game_chrome.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.bgSurface.withValues(alpha: 0.95),
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: () => context.pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Geri',
                        style: TextStyle(
                          color: AppColors.gold.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
