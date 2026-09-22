import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/legal/legal_document_content.dart';
import '../../../models/policy_model.dart';
import '../../../theme/app_spacing.dart';
import 'auth_design.dart';
import 'auth_legal_document_dialog.dart';

enum CommunityRulesDecision { pending, accepted, rejected }

/// Short friendly bullets for the register gate card (full text via dialog).
const String _kCommunityPreview = '''
• Saygı: küfür, nefret, taciz yok
• Adil oyun: hile, bot, exploit yasak
• Ekonomi: RMT / scam / sahte trade yasak
• Spam ve reklam yok
• İhlalde: uyarı → susturma → ban
''';

/// Kayıt ekranı — Topluluk Kuralları kabul / red (oyun içi gate değil).
Future<CommunityRulesDecision?> showRegisterCommunityRulesDialog(
  BuildContext context, {
  required LegalDocument document,
}) {
  final LegalDocument resolved = LegalDocumentContent.resolve(document);
  return showDialog<CommunityRulesDecision>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) =>
        _RegisterCommunityRulesDialog(document: resolved),
  );
}

class _RegisterCommunityRulesDialog extends StatelessWidget {
  const _RegisterCommunityRulesDialog({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AuthGlassPanel(
            accent: AuthDesign.fuchsia,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: AuthDesign.fuchsiaGradient,
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            document.title,
                            style:
                                AuthDesign.heroTitle().copyWith(fontSize: 18),
                          ),
                          Text(
                            'Sürüm ${document.version}',
                            style: AuthDesign.sectionCaps(
                              color: AuthDesign.titanium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Kayıt olmak için Topluluk Kurallarını kabul etmelisin. '
                  'Reddedersen hesap oluşturamazsın.',
                  style: AuthDesign.bodyMuted(color: AuthDesign.textMid),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AuthDesign.obsidian.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    _kCommunityPreview.trim(),
                    style: AuthDesign.bodyMuted(color: AuthDesign.textMid)
                        .copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => showAuthLegalDocumentDialog(
                      context,
                      document: document,
                    ),
                    child: Text(
                      'Tam metni oku (tablolar + detay)',
                      style: GoogleFonts.urbanist(
                        color: AuthDesign.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(
                          context,
                          CommunityRulesDecision.rejected,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AuthDesign.titanium,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Reddet'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AuthGoldButton(
                        label: 'Kabul Et',
                        icon: Icons.check_rounded,
                        onPressed: () => Navigator.pop(
                          context,
                          CommunityRulesDecision.accepted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Red / bekleme durumu — kayıt formu altında.
class CommunityRulesStatusBanner extends StatelessWidget {
  const CommunityRulesStatusBanner({
    super.key,
    required this.decision,
    required this.onReviewAgain,
  });

  final CommunityRulesDecision decision;
  final VoidCallback onReviewAgain;

  @override
  Widget build(BuildContext context) {
    if (decision == CommunityRulesDecision.pending) {
      return const SizedBox.shrink();
    }

    final bool rejected = decision == CommunityRulesDecision.rejected;
    final Color accent = rejected ? const Color(0xFFE52E2E) : AuthDesign.gold;
    final String message = rejected
        ? 'Topluluk Kurallarını reddettin. Kayıt olamazsın.'
        : 'Topluluk Kuralları kabul edildi.';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              rejected ? Icons.block_rounded : Icons.verified_rounded,
              color: accent,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AuthDesign.bodyMuted(color: AuthDesign.textHi),
              ),
            ),
            if (rejected)
              TextButton(
                onPressed: onReviewAgain,
                child: Text(
                  'Tekrar',
                  style: GoogleFonts.urbanist(
                    color: AuthDesign.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
