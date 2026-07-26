import 'package:flutter/material.dart';

import 'package:flutter_markdown/flutter_markdown.dart';

import '../../components/layout/game_screen_background.dart';
import '../../models/policy_model.dart';
import '../../theme/app_text_styles.dart';
import '../support/widgets/support_design.dart';
import '../support/widgets/support_screen_shell.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return SupportScreenShell(
      title: document.title,
      body: ListView(
        padding: GameScrollLayout.padding(context),
        children: <Widget>[
          SettingsGlassCard(
            accent: SettingsPalette.gold,
            glow: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Sürüm ${document.version}',
                  style: AppTextStyles.captionBold.copyWith(color: SettingsPalette.gold),
                ),
                const SizedBox(height: 12),
                MarkdownBody(
                  data: document.bodyMd.replaceAll('\\n', '\n'),
                  styleSheet: MarkdownStyleSheet(
                    p: supportBodyStyle.copyWith(fontSize: 14),
                    h1: AppTextStyles.h3.copyWith(color: SettingsPalette.gold),
                    h2: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi, fontSize: 16),
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
        ],
      ),
    );
  }
}
