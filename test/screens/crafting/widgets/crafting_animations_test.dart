import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/screens/crafting/widgets/anvil_hammer_strike_impact.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_particle_burst.dart';
import 'package:gkk_flutter/screens/crafting/widgets/critical_craft_fanfare.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_success_dialog.dart';
import 'package:gkk_flutter/screens/inventory/widgets/aion_rarity_glow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnvilHammerStrikeImpact', () {
    testWidgets('renders correctly and respects dimensions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnvilHammerStrikeImpact(
                width: 260,
                height: 200,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnvilHammerStrikeImpact), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('controller triggers strike and fires onImpact and onSequenceComplete',
        (WidgetTester tester) async {
      final AnvilHammerController controller = AnvilHammerController();
      bool impactFired = false;
      bool sequenceCompleteFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnvilHammerStrikeImpact(
                controller: controller,
                enableHaptics: false,
                onImpact: () => impactFired = true,
                onSequenceComplete: () => sequenceCompleteFired = true,
              ),
            ),
          ),
        ),
      );

      expect(controller.isStriking, isFalse);

      // Trigger single strike
      controller.strike();
      await tester.pump();
      expect(controller.isStriking, isTrue);

      // Advance animation halfway to hit impact frame
      await tester.pump(const Duration(milliseconds: 280));
      expect(impactFired, isTrue);

      // Advance to completion
      await tester.pump(const Duration(milliseconds: 320));
      expect(sequenceCompleteFired, isTrue);
      expect(controller.isStriking, isFalse);
    });

    testWidgets('controller handles strikeSequence and reset', (WidgetTester tester) async {
      final AnvilHammerController controller = AnvilHammerController();
      int impactCount = 0;
      bool sequenceDone = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnvilHammerStrikeImpact(
                controller: controller,
                enableHaptics: false,
                onImpact: () => impactCount++,
                onSequenceComplete: () => sequenceDone = true,
              ),
            ),
          ),
        ),
      );

      controller.strikeSequence(2);
      await tester.pump();
      expect(controller.isStriking, isTrue);

      // Strike 1
      await tester.pump(const Duration(milliseconds: 300));
      expect(impactCount, 1);
      await tester.pump(const Duration(milliseconds: 300));

      // Strike 2
      await tester.pump(const Duration(milliseconds: 300));
      expect(impactCount, 2);
      await tester.pump(const Duration(milliseconds: 300));

      expect(sequenceDone, isTrue);

      // Reset
      controller.reset();
      await tester.pump();
      expect(controller.isStriking, isFalse);
    });
  });

  group('CraftingParticleBurst', () {
    testWidgets('renders child and triggers particle explosion on controller burst',
        (WidgetTester tester) async {
      final CraftingParticleBurstController controller = CraftingParticleBurstController();
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CraftingParticleBurst(
                controller: controller,
                tier: AionRarityTier.archon,
                particleCount: 20,
                burstDuration: const Duration(milliseconds: 400),
                onCompleted: () => completed = true,
                child: const Text('Crafting Center'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Crafting Center'), findsOneWidget);

      controller.burst(origin: const Offset(100, 100), count: 16);
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      // Simulate physics ticks
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 250));

      expect(completed, isTrue);

      controller.clear();
      await tester.pump();
    });

    test('CraftParticle physics kinematics update correctly', () {
      final CraftParticle particle = CraftParticle(
        origin: const Offset(50, 50),
        velocity: const Offset(100, -200),
        gravity: 400,
        drag: 1.2,
        rotation: 0.0,
        angularVelocity: 2.0,
        size: 8.0,
        color: Colors.amber,
        secondaryColor: Colors.yellow,
        maxLifetime: 1.0,
        shape: CraftParticleShape.star4,
      );

      expect(particle.isDead, isFalse);
      expect(particle.opacity, 1.0);

      particle.update(0.5);
      expect(particle.lifetime, 0.5);
      expect(particle.rotation, 1.0);
      expect(particle.position.dx, isNot(50.0));
      expect(particle.opacity, closeTo(0.5, 0.01));

      particle.update(0.6);
      expect(particle.isDead, isTrue);
      expect(particle.opacity, 0.0);
    });

    testWidgets('burstOverlay static helper inserts and auto-removes overlay',
        (WidgetTester tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) {
                capturedContext = ctx;
                return const Text('Overlay Host');
              },
            ),
          ),
        ),
      );

      final entry = CraftingParticleBurst.burstOverlay(
        capturedContext,
        origin: const Offset(120, 120),
        particleCount: 10,
        duration: const Duration(milliseconds: 300),
      );

      await tester.pump();
      expect(find.byType(CraftingParticleBurst), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      expect(entry.mounted, isFalse);
    });
  });

  group('CriticalCraftFanfare', () {
    testWidgets('renders fanfare banner, sunburst rays, and bonus callouts',
        (WidgetTester tester) async {
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CriticalCraftFanfare(
              title: 'KRİTİK BAŞARI!',
              subtitle: 'Efsanevi Seviye Üretim',
              enableHaptics: false,
              bonusCallouts: const <CriticalBonusCallout>[
                CriticalBonusCallout(
                  label: 'Bonus Verim',
                  value: '+50%',
                  icon: Icons.auto_awesome,
                ),
              ],
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      // Entrance animation
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('KRİTİK BAŞARI!'), findsOneWidget);
      expect(find.text('Efsanevi Seviye Üretim'), findsOneWidget);
      expect(find.text('Bonus Verim: '), findsOneWidget);
      expect(find.text('+50%'), findsOneWidget);

      // Tap Devam Et dismiss button
      await tester.tap(find.text('Devam Et'));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('autoDismissDuration triggers onDismiss automatically',
        (WidgetTester tester) async {
      bool autoDismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CriticalCraftFanfare(
              autoDismissDuration: const Duration(milliseconds: 500),
              enableHaptics: false,
              onDismiss: () => autoDismissed = true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(autoDismissed, isFalse);

      await tester.pump(const Duration(milliseconds: 350));
      expect(autoDismissed, isTrue);
    });
  });

  group('CraftingSuccessDialog', () {
    testWidgets('renders item showcase, XP reward, and claim button',
        (WidgetTester tester) async {
      bool claimed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CraftingSuccessDialog(
              itemName: 'Aion Ejder Kılıcı',
              itemIcon: '⚔️',
              rarity: 'epic',
              quantity: 2,
              itemType: 'Silah',
              xpReward: 85,
              onClaim: () => claimed = true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Aion Ejder Kılıcı'), findsOneWidget);
      expect(find.text('SILAH'), findsOneWidget);
      expect(find.text('x2'), findsOneWidget);
      expect(find.text('+85 DP'), findsOneWidget);
      expect(find.text('Koleksiyona Ekle'), findsOneWidget);

      // Tap claim button
      await tester.tap(find.text('Koleksiyona Ekle'));
      await tester.pump();
      expect(claimed, isTrue);
    });

    testWidgets('renders critical header badge when isCritical is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CraftingSuccessDialog(
              itemName: 'Kutsal Aion Zırhı',
              itemIcon: '🛡️',
              rarity: 'mythic',
              isCritical: true,
              criticalBonusTitle: 'Çift Üretim!',
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('KRİTİK BAŞARI! · Çift Üretim!'), findsOneWidget);
      expect(find.text('Kutsal Aion Zırhı'), findsOneWidget);
    });

    testWidgets('showCraftingSuccessDialog launches modal dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) {
                return ElevatedButton(
                  onPressed: () {
                    showCraftingSuccessDialog(
                      ctx,
                      itemName: 'Ejderha İksiri',
                      itemIcon: '🧪',
                      rarity: 'rare',
                      quantity: 5,
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(CraftingSuccessDialog), findsOneWidget);
      expect(find.text('Ejderha İksiri'), findsOneWidget);
      expect(find.text('x5'), findsOneWidget);
    });
  });
}
