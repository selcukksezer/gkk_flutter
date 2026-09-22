import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/legal/legal_document_content.dart';
import '../../../models/policy_model.dart';
import 'auth_design.dart';
import 'auth_legal_markdown.dart';

/// Full legal document reader for register (terms / privacy / community).
Future<void> showAuthLegalDocumentDialog(
  BuildContext context, {
  required LegalDocument document,
}) {
  final LegalDocument resolved = LegalDocumentContent.resolve(document);
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
            decoration: BoxDecoration(
              color: AuthDesign.navy.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AuthDesign.gold.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          resolved.title,
                          style: AuthDesign.heroTitle(color: AuthDesign.gold)
                              .copyWith(fontSize: 18),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AuthDesign.titanium,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Text(
                    'Sürüm ${resolved.version}',
                    style: AuthDesign.sectionCaps(color: AuthDesign.titanium),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    child: AuthLegalMarkdown(data: resolved.bodyMd),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
