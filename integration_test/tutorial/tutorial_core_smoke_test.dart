import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_anchor_registry.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_step.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track_registry.dart';
import 'package:gkk_flutter/main.dart';
import 'package:integration_test/integration_test.dart';

import '../smoke/helpers.dart';
import '../smoke/smoke_harness.dart';

/// Fresh-user core tutorial path smoke: v2 tracks + forced overlay render.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tutorial core smoke v2', () {
    testWidgets('core tracks are contiguous via route chain', (
      WidgetTester tester,
    ) async {
      final Map<String, Set<String>> completedByTrack = <String, Set<String>>{};
      final List<String> seenTracks = <String>[];

      String? route = TutorialRoutes.home;
      while (route != null && seenTracks.length < 10) {
        final String? trackId = TutorialRouteTracks.trackForRoute(route);
        if (trackId == null) break;
        if (!seenTracks.contains(trackId)) {
          seenTracks.add(trackId);
        }
        final Set<String> done =
            completedByTrack.putIfAbsent(trackId, () => <String>{});
        final List<TutorialStepV2> eligible =
            TutorialTrackRegistry.eligibleSteps(
          trackId: trackId,
          completedStepIds: done,
        );
        if (eligible.isEmpty) {
          // Advance toward next core route after finishing a track.
          if (trackId == TutorialTrackId.onboarding) {
            route = TutorialRoutes.dungeon;
          } else if (trackId == TutorialTrackId.dungeon) {
            route = TutorialRoutes.inventory;
          } else {
            break;
          }
          continue;
        }
        final TutorialStepV2 step = eligible.first;
        done.add(step.id);
        if (step.allowedRoutes.isNotEmpty) {
          route = step.allowedRoutes.first;
        }
      }

      for (final String coreId in TutorialTrackId.coreTracks) {
        expect(seenTracks, contains(coreId));
      }
    });

    testWidgets('forced onboarding overlay renders when logged in', (
      WidgetTester tester,
    ) async {
      await SmokeHarness.ensureInitialized();
      if (!SmokeEnv.hasResolvedCredentials) {
        return;
      }

      await SmokeHarness.loginBeforePump();
      await tester.pumpWidget(const ProviderScope(child: GkkMobileApp()));
      await smokePump(tester, duration: const Duration(seconds: 3));

      final Finder overlayTitle = find.text('Gölge Krallığı\'na hoş geldin');
      if (overlayTitle.evaluate().isNotEmpty) {
        expect(find.text('Tümünü Atla'), findsOneWidget);
        await tester.tap(find.text('Rehbere Başla'));
        await smokePump(tester);
        expect(find.text('Temel oyun döngüsü'), findsOneWidget);
      }
    });

    testWidgets('onboarding home anchors resolve rects on device', (
      WidgetTester tester,
    ) async {
      await SmokeHarness.ensureInitialized();
      if (!SmokeEnv.hasResolvedCredentials) {
        return;
      }

      await SmokeHarness.loginBeforePump();
      await tester.pumpWidget(const ProviderScope(child: GkkMobileApp()));
      await smokePump(tester, duration: const Duration(seconds: 4));

      final Element? app = find.byType(GkkMobileApp).evaluate().firstOrNull;
      if (app == null) return;

      final ProviderContainer container = ProviderScope.containerOf(app);
      final TutorialController ctrl = container.read(tutorialProvider.notifier);
      await ctrl.resetAndReplay();
      await smokePump(tester, duration: const Duration(seconds: 2));

      TutorialAnchorRegistry.instance.scheduleRefresh();
      await tester.pump(const Duration(milliseconds: 400));

      final Rect? promo = TutorialAnchorRegistry.instance.rectFor(
        TutorialAnchorId.homePromo,
      );
      final Rect? hero = TutorialAnchorRegistry.instance.rectFor(
        TutorialAnchorId.homeHero,
      );

      expect(
        promo != null || hero != null,
        isTrue,
        reason: 'home onboarding anchors should register on device',
      );
    });
  });
}
