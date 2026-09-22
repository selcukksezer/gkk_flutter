import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/provider_scheduling.dart';
import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<AuthState>(authProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      if (!mounted) return;

      // Session already persisted → no onAuthStateChange. Refresh router so
      // redirect (ban / class / home) is the single navigation source.
      if (next.status == AuthStatus.authenticated) {
        GoRouter.of(context).refresh();
        return;
      }

      if (next.status == AuthStatus.unauthenticated ||
          next.status == AuthStatus.error) {
        // Splash is a public auth-entry route; redirect alone won't leave it.
        context.go(AppRoutes.login);
      }
    });
    deferProviderUpdate(() {
      ref.read(authProvider.notifier).loadSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
