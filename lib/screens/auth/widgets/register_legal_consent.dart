import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/legal/legal_document_content.dart';
import '../../../models/policy_model.dart';
import '../../../theme/app_spacing.dart';
import 'auth_design.dart';
import 'auth_legal_document_dialog.dart';

/// Terms + privacy checkboxes shown during registration (store consent).
///
/// `(oku)` opens formatted markdown dialog — no `/legal` route.
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

  void _openDocument(BuildContext context, String type) {
    final LegalDocument doc = LegalDocumentContent.resolve(
      LegalDocument(type: type, version: 1, title: '', bodyMd: ''),
    );
    showAuthLegalDocumentDialog(context, document: doc);
  }

  Widget _consentRow({
    required BuildContext context,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    required String docType,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text.rich(
        TextSpan(
          style: AuthDesign.bodyMuted(color: AuthDesign.textMid),
          children: <InlineSpan>[
            TextSpan(text: '$label '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openDocument(context, docType),
                child: Text(
                  '(oku)',
                  style: GoogleFonts.urbanist(
                    color: AuthDesign.gold,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: AuthDesign.gold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _consentRow(
          context: context,
          value: termsAccepted,
          onChanged: onTermsChanged,
          label: 'Kullanım Koşullarını kabul ediyorum',
          docType: 'terms',
        ),
        _consentRow(
          context: context,
          value: privacyAccepted,
          onChanged: onPrivacyChanged,
          label: 'Gizlilik Politikasını kabul ediyorum',
          docType: 'privacy',
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
