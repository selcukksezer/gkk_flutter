import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';
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
        return AuthDesign.gold;
      case AuthScreenKind.register:
        return AuthDesign.fuchsia;
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
      backgroundColor: AuthDesign.void_,
      body: AuthBackdrop(
        accent: _accent,
        secondaryAccent: kind == AuthScreenKind.register
            ? AuthDesign.gold
            : AuthDesign.fuchsia,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AuthFadeSlide(
                  child: AuthGlassPanel(
                    accent: _accent,
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
