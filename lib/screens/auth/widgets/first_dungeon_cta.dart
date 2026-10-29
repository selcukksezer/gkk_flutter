import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tutorial/tutorial_features.dart';
import '../../../l10n/l10n.dart';
import 'auth_design.dart';

/// After character select: one clear CTA to first dungeon.
/// Skipped when in-game tutorial is enabled (onboarding already guides there).
Future<void> presentFirstDungeonCta(BuildContext context) async {
  if (!context.mounted) return;

  if (TutorialFeatures.enabled) {
    context.go('/home');
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final bool? goDungeon = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return AlertDialog(
        backgroundColor: AuthDesign.obsidian,
        title: Text(
          l10n.auth_first_dungeon_title,
          style: AuthDesign.heroTitle(color: AuthDesign.textHi).copyWith(
            fontSize: 20,
          ),
        ),
        content: Text(
          l10n.auth_first_dungeon_body,
          style: AuthDesign.bodyMuted(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.auth_first_dungeon_home),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AuthDesign.gold,
              foregroundColor: AuthDesign.void_,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.auth_first_dungeon_cta),
          ),
        ],
      );
    },
  );

  if (!context.mounted) return;
  if (goDungeon == true) {
    context.go('/dungeon');
  } else {
    context.go('/home');
  }
}
