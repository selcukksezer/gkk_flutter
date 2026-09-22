import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../components/layout/game_screen_background.dart';
import '../../core/legal/legal_document_content.dart';
import '../../models/policy_model.dart';
import '../../theme/app_text_styles.dart';
import '../support/widgets/support_design.dart';

/// Paylaşılan markdown gövdesi — ekran + sheet.
class LegalDocumentBody extends StatelessWidget {
  const LegalDocumentBody({
    super.key,
    required this.document,
    this.scrollController,
  });

  final LegalDocument document;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final LegalDocument resolved = LegalDocumentContent.resolve(document);
    return ListView(
      controller: scrollController,
      padding: GameScrollLayout.padding(context),
      children: <Widget>[
        SettingsGlassCard(
          accent: SettingsPalette.gold,
          glow: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Sürüm ${resolved.version}',
                style: AppTextStyles.captionBold.copyWith(color: SettingsPalette.gold),
              ),
              const SizedBox(height: 12),
              MarkdownBody(
                data: resolved.bodyMd.replaceAll('\\n', '\n'),
                styleSheet: MarkdownStyleSheet(
                  p: supportBodyStyle.copyWith(fontSize: 14),
                  h1: AppTextStyles.h3.copyWith(color: SettingsPalette.gold),
                  h2: AppTextStyles.bodyBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 16,
                  ),
                  h3: AppTextStyles.bodyBold.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 14,
                  ),
                  listBullet: supportBodyStyle.copyWith(fontSize: 14),
                  tableHead: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.gold,
                  ),
                  tableBody: supportBodyStyle.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SettingsGlassCard(
          accent: SettingsPalette.neon,
          child: Text(
            'Destek: support@gkk.game · uygulama içi ticket',
            style: supportCaptionStyle,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
