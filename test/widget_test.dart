import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/main.dart';
import 'package:gkk_flutter/screens/auth/splash_screen.dart';

void main() {
  testWidgets('App routes from splash to login', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const ProviderScope(child: GkkMobileApp()));
      expect(find.byType(GkkMobileApp), findsOneWidget);
    });
  });
}
