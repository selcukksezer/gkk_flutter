import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/legal/legal_document_content.dart';
import 'package:gkk_flutter/models/policy_model.dart';

void main() {
  group('LegalDocumentContent', () {
    test('always uses canonical body for known doc types', () {
      const LegalDocument short = LegalDocument(
        type: 'terms',
        version: 1,
        title: 'Kullanım Koşulları',
        bodyMd: 'sunucudan gelen kısa özet',
      );
      final LegalDocument resolved = LegalDocumentContent.resolve(short);
      expect(resolved.bodyMd.length, greaterThan(2000));
      expect(resolved.bodyMd, contains('## 1. Taraflar ve tanımlar'));
      expect(resolved.bodyMd, isNot(contains('sunucudan gelen')));
    });

    test('prefers canonical over long server body for privacy', () {
      final String longBody = '# Test\n${'a' * 500}';
      final LegalDocument doc = LegalDocument(
        type: 'privacy',
        version: 2,
        title: 'Gizlilik',
        bodyMd: longBody,
      );
      final LegalDocument resolved = LegalDocumentContent.resolve(doc);
      expect(resolved.bodyMd, isNot(longBody));
      expect(resolved.bodyMd, contains('KVKK'));
    });

    test('all three doc types have detailed canonical bodies', () {
      for (final String type in <String>['terms', 'privacy', 'community']) {
        final LegalDocument resolved = LegalDocumentContent.resolve(
          LegalDocument(type: type, version: 1, title: '', bodyMd: 'db stub'),
        );
        expect(resolved.bodyMd.length, greaterThan(1500));
        expect(resolved.title, isNotEmpty);
        expect(resolved.bodyMd, isNot(contains('db stub')));
      }
    });
  });
}
