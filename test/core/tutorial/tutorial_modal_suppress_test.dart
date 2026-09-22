import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_modal_suppress.dart';

void main() {
  setUp(() {
    TutorialModalSuppress.instance.debugReset();
  });

  test('TutorialModalRouteObserver tracks popup routes', () {
    final TutorialModalRouteObserver observer =
        TutorialModalRouteObserver.instance;

    expect(TutorialModalSuppress.instance.isSuppressed, isFalse);

    final Route<void> popup = _TestPopupRoute();
    final Route<void> page = MaterialPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );

    observer.didPush(popup, null);
    expect(TutorialModalSuppress.instance.isSuppressed, isTrue);

    observer.didPush(page, popup);
    expect(TutorialModalSuppress.instance.isSuppressed, isTrue);

    observer.didPop(popup, page);
    expect(TutorialModalSuppress.instance.isSuppressed, isFalse);
  });

  test('manual hold/release suppresses without popup routes', () {
    const Object token = Object();
    expect(TutorialModalSuppress.instance.isSuppressed, isFalse);

    TutorialModalSuppress.instance.hold(token);
    expect(TutorialModalSuppress.instance.isSuppressed, isTrue);

    TutorialModalSuppress.instance.release(token);
    expect(TutorialModalSuppress.instance.isSuppressed, isFalse);
  });

  testWidgets('TutorialSuppressScope holds while active', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<bool> active = ValueNotifier<bool>(true);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (BuildContext context, bool value, _) {
            return TutorialSuppressScope(
              active: value,
              child: const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(TutorialModalSuppress.instance.isSuppressed, isTrue);

    active.value = false;
    await tester.pump();
    expect(TutorialModalSuppress.instance.isSuppressed, isFalse);

    active.dispose();
  });

  test('resetForReplay clears popup depth and holds', () {
    const Object token = Object();
    TutorialModalSuppress.instance.hold(token);
    TutorialModalRouteObserver.instance.didPush(_TestPopupRoute(), null);
    expect(TutorialModalSuppress.instance.isSuppressed, isTrue);

    TutorialModalSuppress.instance.resetForReplay();
    expect(TutorialModalSuppress.instance.isSuppressed, isFalse);
  });
}

class _TestPopupRoute extends PopupRoute<void> {
  @override
  Color? get barrierColor => Colors.black54;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'test';

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return const SizedBox.shrink();
  }
}
