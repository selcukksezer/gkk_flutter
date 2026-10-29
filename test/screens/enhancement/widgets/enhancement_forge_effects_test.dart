import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/screens/enhancement/widgets/enhancement_forge_effects.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnvilStrikeSparksPainter', () {
    test('repaints only when progress, origin or color changes', () {
      final AnvilStrikeSparksPainter painter1 = AnvilStrikeSparksPainter(
        progress: 0.2,
        origin: const Offset(50, 50),
        primaryColor: const Color(0xFFFFB300),
      );
      final AnvilStrikeSparksPainter painter2 = AnvilStrikeSparksPainter(
        progress: 0.2,
        origin: const Offset(50, 50),
        primaryColor: const Color(0xFFFFB300),
      );
      final AnvilStrikeSparksPainter painter3 = AnvilStrikeSparksPainter(
        progress: 0.4,
        origin: const Offset(50, 50),
        primaryColor: const Color(0xFFFFB300),
      );
      final AnvilStrikeSparksPainter painter4 = AnvilStrikeSparksPainter(
        progress: 0.2,
        origin: const Offset(10, 10),
        primaryColor: const Color(0xFFFFB300),
      );
      final AnvilStrikeSparksPainter painter5 = AnvilStrikeSparksPainter(
        progress: 0.2,
        origin: const Offset(50, 50),
        primaryColor: const Color(0xFF00FF00),
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
      expect(painter3.shouldRepaint(painter1), isTrue);
      expect(painter4.shouldRepaint(painter1), isTrue);
      expect(painter5.shouldRepaint(painter1), isTrue);
    });

    testWidgets('paints cleanly without throwing across progress values', (WidgetTester tester) async {
      for (final double p in <double>[0.0, 0.1, 0.5, 0.9, 1.0]) {
        await tester.pumpWidget(
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(200, 200),
              painter: AnvilStrikeSparksPainter(
                progress: p,
                origin: const Offset(100, 100),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('SuccessShockwavePainter & FloatingLevelSurgeWidget', () {
    test('SuccessShockwavePainter shouldRepaint triggers correctly', () {
      final SuccessShockwavePainter p1 = SuccessShockwavePainter(progress: 0.3);
      final SuccessShockwavePainter p2 = SuccessShockwavePainter(progress: 0.3);
      final SuccessShockwavePainter p3 = SuccessShockwavePainter(progress: 0.7);

      expect(p1.shouldRepaint(p2), isFalse);
      expect(p3.shouldRepaint(p1), isTrue);
    });

    testWidgets('renders success shockwave and floating level surge badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                CustomPaint(
                  size: const Size(300, 300),
                  painter: SuccessShockwavePainter(
                    progress: 0.45,
                    maxRadius: 150,
                  ),
                ),
                const FloatingLevelSurgeWidget(
                  progress: 0.5,
                  levelText: '+7',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('+7'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_double_arrow_up_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FailureFracturePainter', () {
    test('shouldRepaint triggers on progress and isDestroyed', () {
      final FailureFracturePainter p1 = FailureFracturePainter(
        progress: 0.2,
        isDestroyed: false,
      );
      final FailureFracturePainter p2 = FailureFracturePainter(
        progress: 0.2,
        isDestroyed: false,
      );
      final FailureFracturePainter p3 = FailureFracturePainter(
        progress: 0.5,
        isDestroyed: false,
      );
      final FailureFracturePainter p4 = FailureFracturePainter(
        progress: 0.2,
        isDestroyed: true,
      );

      expect(p1.shouldRepaint(p2), isFalse);
      expect(p3.shouldRepaint(p1), isTrue);
      expect(p4.shouldRepaint(p1), isTrue);
    });

    testWidgets('paints failure fracture shockwave and destroyed rune shards', (WidgetTester tester) async {
      await tester.pumpWidget(
        RepaintBoundary(
          child: CustomPaint(
            size: const Size(200, 200),
            painter: FailureFracturePainter(
              progress: 0.5,
              isDestroyed: true,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AmbientForgeGlowPainter & ForgeAmbientHeatShimmer', () {
    test('shouldRepaint triggers on breathing phase', () {
      final AmbientForgeGlowPainter p1 = AmbientForgeGlowPainter(breathingPhase: 0.1);
      final AmbientForgeGlowPainter p2 = AmbientForgeGlowPainter(breathingPhase: 0.1);
      final AmbientForgeGlowPainter p3 = AmbientForgeGlowPainter(breathingPhase: 0.6);

      expect(p1.shouldRepaint(p2), isFalse);
      expect(p3.shouldRepaint(p1), isTrue);
    });

    testWidgets('ForgeAmbientHeatShimmer animates without exception', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 250,
              height: 250,
              child: ForgeAmbientHeatShimmer(
                intensity: 1.2,
                child: Center(child: Text('Pedestal')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Pedestal'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('EnhancementForgeVfxController', () {
    testWidgets('orchestrates anvil strike and success transitions', (WidgetTester tester) async {
      late EnhancementForgeVfxController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return _TestControllerHost(
                  onInit: (EnhancementForgeVfxController ctrl) {
                    controller = ctrl;
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(controller.state, equals(ForgeVfxState.idle));

      // Trigger Strike
      bool impactFired = false;
      controller.triggerAnvilStrike(
        point: const Offset(120, 120),
        onImpact: () {
          impactFired = true;
        },
      );
      expect(controller.state, equals(ForgeVfxState.striking));
      expect(controller.impactPoint, equals(const Offset(120, 120)));
      expect(impactFired, isTrue);

      await tester.pump(const Duration(milliseconds: 800));

      // Trigger Success
      controller.triggerSuccess(newLevel: 9, point: const Offset(100, 100));
      expect(controller.state, equals(ForgeVfxState.success));
      expect(controller.surgeLevel, equals(9));

      await tester.pump(const Duration(milliseconds: 1200));

      // Trigger Failure
      controller.triggerFailure(isDestroyed: true);
      expect(controller.state, equals(ForgeVfxState.destroyed));

      // Reset
      controller.reset();
      expect(controller.state, equals(ForgeVfxState.idle));
    });
  });

  group('EnhancementForgeEffectsLayer', () {
    testWidgets('renders all phases cleanly inside single overlay', (WidgetTester tester) async {
      for (final ForgeVfxState state in ForgeVfxState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 320,
                child: EnhancementForgeEffectsLayer(
                  vfxState: state,
                  strikeProgress: state == ForgeVfxState.striking ? 0.4 : 0.0,
                  resultProgress: (state == ForgeVfxState.success ||
                          state == ForgeVfxState.failure ||
                          state == ForgeVfxState.destroyed)
                      ? 0.5
                      : 0.0,
                  surgeLevel: 8,
                  child: const Center(child: Text('Forge Content')),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Forge Content'), findsOneWidget);
        if (state == ForgeVfxState.success) {
          expect(find.text('+8'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Legacy compatibility classes', () {
    testWidgets('ChanceRingPainter, OrbitParticlesPainter, SparkBurstPainter paint cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                CustomPaint(
                  size: const Size(120, 120),
                  painter: const ChanceRingPainter(
                    progress: 0.75,
                    rotation: 0.2,
                    color: Colors.amber,
                  ),
                ),
                CustomPaint(
                  size: const Size(120, 120),
                  painter: OrbitParticlesPainter(
                    t: 0.4,
                    color: Colors.cyan,
                  ),
                ),
                CustomPaint(
                  size: const Size(120, 120),
                  painter: SparkBurstPainter(
                    t: 0.5,
                    color: Colors.orange,
                  ),
                ),
                const ShimmerSweep(t: 0.5, borderRadius: 8),
                const ForgeRotatingBorderGlow(
                  rotation: 0.3,
                  color: Colors.amber,
                  child: SizedBox(width: 80, height: 80),
                ),
                const ForgeStaticBorderGlow(
                  color: Colors.red,
                  child: SizedBox(width: 80, height: 80),
                ),
                const ResultFlash(t: 0.3, color: Colors.amber),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

class _TestControllerHost extends StatefulWidget {
  const _TestControllerHost({required this.onInit});
  final void Function(EnhancementForgeVfxController) onInit;

  @override
  State<_TestControllerHost> createState() => _TestControllerHostState();
}

class _TestControllerHostState extends State<_TestControllerHost>
    with TickerProviderStateMixin {
  late final EnhancementForgeVfxController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EnhancementForgeVfxController(vsync: this);
    widget.onInit(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 50, height: 50);
}
