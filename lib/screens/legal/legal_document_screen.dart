import 'package:flutter/material.dart';

import '../../core/legal/legal_document_content.dart';
import '../../models/policy_model.dart';
import '../support/widgets/support_screen_shell.dart';
import 'legal_document_body.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final LegalDocument resolved = LegalDocumentContent.resolve(document);
    return SupportScreenShell(
      title: resolved.title,
      body: LegalDocumentBody(document: resolved),
    );
  }
}
