import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/policy_model.dart';
import 'package:gkk_flutter/providers/policy_provider.dart';

void main() {
  test('register-only docs never block gameplay gate', () {
    const PolicyStatus status = PolicyStatus(
      allAccepted: false,
      missing: <String>['community', 'terms', 'privacy'],
    );
    const PolicyState state = PolicyState(status: status);
    expect(state.needsAcceptance, isFalse);
    expect(status.missingForGameplay, isEmpty);
    expect(
      kRegisterOnlyLegalDocTypes,
      containsAll(<String>['community', 'terms', 'privacy']),
    );
  });
}
