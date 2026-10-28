import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/services/connectivity_service.dart';
import 'package:gkk_flutter/core/services/music_service.dart';
import 'package:gkk_flutter/main.dart';
import 'package:gkk_flutter/screens/auth/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'GkkMobileApp cold boots past SplashScreen onto LoginScreen without hanging even when Supabase is uninitialized',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: GkkMobileApp(),
        ),
      );

      // Pump startup frames and allow SplashScreen -> LoginScreen transition.
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);

      // Drain background post-frame plugin/socket timeouts cleanly in FakeAsync.
      ConnectivityService.instance.stop();
      unawaited(MusicService.instance.stop());
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    },
  );
}
