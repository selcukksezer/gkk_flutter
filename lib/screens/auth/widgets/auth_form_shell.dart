import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'aion_rune_frame.dart';
import 'aion_sky_particles.dart';
import 'auth_design.dart';

enum AuthScreenKind { login, register, forgotPassword, updatePassword }

class AuthFormShell extends StatelessWidget {
  const AuthFormShell({
    super.key,
    required this.kind,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.sectionLabel,
    required this.child,
    required this.footer,
  });

  final AuthScreenKind kind;
  final String badge;
  final String title;
  final String subtitle;
  final String sectionLabel;
  final Widget child;
  final Widget footer;

  Color get _accent {
    switch (kind) {
      case AuthScreenKind.login:
      case AuthScreenKind.forgotPassword:
      case AuthScreenKind.updatePassword:
        return const Color(0xFFFFD700); // Aion Gold
      case AuthScreenKind.register:
        return AppColors.cyberFuchsia;
    }
  }

  Color get _glowColor {
    switch (kind) {
      case AuthScreenKind.login:
        return const Color(0xFF38BDF8); // Arcane Cyan
      case AuthScreenKind.register:
        return const Color(0xFFFF2D55); // Fuchsia Neon
      case AuthScreenKind.forgotPassword:
      case AuthScreenKind.updatePassword:
        return const Color(0xFFEAB308); // Mystic Amber
    }
  }

  IconData get _icon {
    switch (kind) {
      case AuthScreenKind.login:
        return Icons.castle_rounded;
      case AuthScreenKind.register:
        return Icons.person_add_alt_1_rounded;
      case AuthScreenKind.forgotPassword:
        return Icons.lock_reset_rounded;
      case AuthScreenKind.updatePassword:
        return Icons.password_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: AionSkyParticlesBackground(
        primaryAura: _glowColor.withValues(alpha: 0.6),
        secondaryAura: _accent.withValues(alpha: 0.4),
        accentEmissive: _accent,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AuthFadeSlide(
                  child: AionRuneCard(
                    accentColor: _accent,
                    glowColor: _glowColor,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        AuthHeroHeader(
                          badge: badge,
                          title: title,
                          subtitle: subtitle,
                          sectionLabel: sectionLabel,
                          accent: _accent,
                          icon: _icon,
                        ),
                        AuthFadeSlide(
                          delay: const Duration(milliseconds: 80),
                          child: child,
                        ),
                        const SizedBox(height: AppSpacing.base),
                        AuthFadeSlide(
                          delay: const Duration(milliseconds: 140),
                          child: footer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
