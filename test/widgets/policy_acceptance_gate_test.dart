import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/policy_model.dart';
import 'package:gkk_flutter/screens/legal/legal_document_reader_overlay.dart';
import 'package:gkk_flutter/screens/support/widgets/support_design.dart';

void main() {
  testWidgets('Okudum disabled until scroll reaches bottom', (
    WidgetTester tester,
  ) async {
    const LegalDocument doc = LegalDocument(
      type: 'terms',
      version: 2,
      title: 'Kullanım Koşulları',
      bodyMd: '',
    );

    String? finishedType;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LegalDocumentReaderOverlay(
            document: doc,
            onFinished: (String type) => finishedType = type,
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder okudum = find.widgetWithText(SettingsPrimaryButton, 'Okudum');
    expect(tester.widget<SettingsPrimaryButton>(okudum).onPressed, isNull);

    await tester.drag(find.byType(Scrollable), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(tester.widget<SettingsPrimaryButton>(okudum).onPressed, isNotNull);
    await tester.tap(okudum);
    await tester.pumpAndSettle();

    expect(finishedType, 'terms');
  });
}
