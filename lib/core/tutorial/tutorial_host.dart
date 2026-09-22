import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import 'tutorial_controller.dart';
import 'tutorial_features.dart';
import 'tutorial_navigation.dart';

/// Global tutorial shell.
///
/// When [TutorialFeatures.enabled] is false this is a passthrough — no coach,
/// no opt-in, no route sync. Auth still clears session on logout.
class TutorialHost extends ConsumerStatefulWidget {
  const TutorialHost({
    super.key,
    required this.child,
    required this.router,
  });

  final Widget child;
  final GoRouter router;

  @override
  ConsumerState<TutorialHost> createState() => _TutorialHostState();
}

class _TutorialHostState extends ConsumerState<TutorialHost> {
  StreamSubscription<AuthState>? _authSub;
  String? _lastAuthId;

  @override
  void initState() {
    super.initState();
    TutorialNavigationBridge.register(_navigateToRoute);
    _lastAuthId = SupabaseService.client.auth.currentUser?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapTutorial());
    });
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState data) {
        final String? nextId = data.session?.user.id;
        if (nextId == _lastAuthId) return;
        _lastAuthId = nextId;
        if (nextId == null) {
          ref.read(tutorialProvider.notifier).clearSession();
          return;
        }
        unawaited(_bootstrapTutorial(force: true));
      },
    );
  }

  Future<void> _bootstrapTutorial({bool force = false}) async {
    if (!mounted) return;
    await ref.read(tutorialProvider.notifier).initialize(force: force);
  }

  Future<void> _navigateToRoute(String route) async {
    if (!mounted || !TutorialFeatures.enabled) return;
    widget.router.go(route);
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    TutorialNavigationBridge.register(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tutorials killed — never mount coach overlay.
    return widget.child;
  }
}
