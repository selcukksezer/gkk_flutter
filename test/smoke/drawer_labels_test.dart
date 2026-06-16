import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/qa/smoke_drawer_labels.dart';
import 'package:gkk_flutter/qa/smoke_route_registry.dart';

void main() {
  group('Smoke quick menu labels', () {
    test('menu label count matches registry navigable routes + logout', () {
      expect(SmokeMenuLabels.all.length, 25);
      expect(SmokeRouteRegistry.quickMenuRouteCount, 24);
    });

    test('every navigable menu label exists in route registry', () {
      final Set<String> registryLabels = SmokeRouteRegistry.quickMenuRoutes
          .map((e) => e.label)
          .toSet();
      for (final String label in SmokeMenuLabels.all) {
        if (label == 'Çıkış Yap') continue;
        expect(registryLabels, contains(label), reason: 'Missing: $label');
      }
    });
  });

  group('Smoke P0 flows', () {
    test('defines 10 flows', () {
      expect(SmokeP0Flows.all.length, 10);
      expect(SmokeP0Flows.all.first.id, 'auth_home');
    });
  });
}
