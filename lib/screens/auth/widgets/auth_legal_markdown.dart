import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_design.dart';

/// Canonical legal MD rendered for register dialogs (tables/headers readable).
class AuthLegalMarkdown extends StatelessWidget {
  const AuthLegalMarkdown({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final TextStyle body = AuthDesign.bodyMuted(color: AuthDesign.textMid);
    final TextStyle hi = AuthDesign.bodyMuted(color: AuthDesign.textHi).copyWith(
      fontWeight: FontWeight.w700,
    );
    return MarkdownBody(
      data: data.replaceAll('\\n', '\n'),
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: body.copyWith(fontSize: 14, height: 1.45),
        h1: AuthDesign.heroTitle(color: AuthDesign.gold).copyWith(fontSize: 20),
        h2: hi.copyWith(fontSize: 16, color: AuthDesign.gold),
        h3: hi.copyWith(fontSize: 14),
        strong: hi,
        em: body.copyWith(fontStyle: FontStyle.italic),
        listBullet: body.copyWith(fontSize: 14),
        blockquote: body.copyWith(color: AuthDesign.titanium),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AuthDesign.gold.withValues(alpha: 0.45),
              width: 3,
            ),
          ),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
        tableHead: GoogleFonts.urbanist(
          color: AuthDesign.gold,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        tableBody: body.copyWith(fontSize: 12, height: 1.35),
        tableBorder: TableBorder.all(
          color: AuthDesign.gold.withValues(alpha: 0.28),
          width: 0.8,
        ),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        tableColumnWidth: const IntrinsicColumnWidth(),
      ),
    );
  }
}
