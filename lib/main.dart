import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'components/trade/trade_invite_host.dart';
import 'core/services/presence_service.dart';
import 'core/services/supabase_service.dart';
import 'l10n/l10n.dart';
import 'providers/locale_provider.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: GkkMobileApp()));
}

class GkkMobileApp extends ConsumerStatefulWidget {
  const GkkMobileApp({super.key});

  @override
  ConsumerState<GkkMobileApp> createState() => _GkkMobileAppState();
}

class _GkkMobileAppState extends ConsumerState<GkkMobileApp> {
  late final GoRouter _router;
  late final _RouterRefreshNotifier _routerRefreshNotifier;
  StreamSubscription<dynamic>? _presenceAuthSub;

  @override
  void initState() {
    super.initState();
    final Stream<dynamic> authRefreshStream = SupabaseService.isInitialized
        ? SupabaseService.client.auth.onAuthStateChange
        : const Stream<dynamic>.empty();
    _routerRefreshNotifier = _RouterRefreshNotifier(authRefreshStream);
    _router = createAppRouter(
      refreshListenable: _routerRefreshNotifier,
    );
    if (SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentSession != null) {
      PresenceService.instance.start();
    }
    _presenceAuthSub = authRefreshStream.listen((_) {
      if (!SupabaseService.isInitialized) return;
      if (SupabaseService.client.auth.currentSession != null) {
        PresenceService.instance.start();
      } else {
        PresenceService.instance.stop();
      }
    });
  }

  @override
  void dispose() {
    _presenceAuthSub?.cancel();
    _routerRefreshNotifier.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Locale locale = ref.watch(localeProvider);

    return TradeInviteHost(
      child: MaterialApp.router(
        title: 'GKK Mobile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router,
      ),
    );
  }
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Stream<dynamic> stream) {
    _subscription = stream.listen((_) {
      // Coalesce rapid token refresh events so GoRouter redirect does not
      // restart the home page transition mid-animation (black screen).
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 250), notifyListeners);
    });
  }

  late final StreamSubscription<dynamic> _subscription;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
