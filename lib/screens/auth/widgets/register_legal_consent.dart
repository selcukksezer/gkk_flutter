import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../../theme/app_spacing.dart';

/// Terms + privacy checkboxes shown during registration (store consent).
class RegisterLegalConsent extends StatelessWidget {
  const RegisterLegalConsent({
    super.key,
    required this.termsAccepted,
    required this.privacyAccepted,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
  });

  final bool termsAccepted;
  final bool privacyAccepted;
  final ValueChanged<bool?> onTermsChanged;
  final ValueChanged<bool?> onPrivacyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CheckboxListTile(
          value: termsAccepted,
          onChanged: onTermsChanged,
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text('Kullanım Koşullarını kabul ediyorum '),
              GestureDetector(
                onTap: () => context.push('${AppRoutes.legal}/terms'),
                child: const Text('(oku)', style: TextStyle(decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
        CheckboxListTile(
          value: privacyAccepted,
          onChanged: onPrivacyChanged,
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text('Gizlilik Politikasını kabul ediyorum '),
              GestureDetector(
                onTap: () => context.push('${AppRoutes.legal}/privacy'),
                child: const Text('(oku)', style: TextStyle(decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
