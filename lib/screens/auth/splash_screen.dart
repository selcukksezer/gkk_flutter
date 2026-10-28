import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../providers/auth_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _fallbackTimer;

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
        _fallbackTimer?.cancel();
        GoRouter.of(context).refresh();
        return;
      }

      if (next.status == AuthStatus.unauthenticated ||
          next.status == AuthStatus.error) {
        _fallbackTimer?.cancel();
        // Splash is a public auth-entry route; redirect alone won't leave it.
        context.go(AppRoutes.login);
      }
    });
    deferProviderUpdate(() {
      ref.read(authProvider.notifier).loadSession();
    });

    // Emniyet kilidi: ağ/oturum servisi yanıt vermezse bile splash ekranında takılma.
    _fallbackTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      final bool hasSession = SupabaseService.isInitialized &&
          SupabaseService.client.auth.currentSession != null;
      context.go(hasSession ? AppRoutes.home : AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.carbonVoid,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.liquidGold,
        ),
      ),
    );
  }
}
