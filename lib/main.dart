import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widgets/session_enforcement_gate.dart';
import 'widgets/ban_enforcement_gate.dart';
import 'components/common/connectivity_gate.dart';
import 'components/common/level_up_host.dart';
import 'components/common/power_change_host.dart';
import 'core/tutorial/tutorial_host.dart';
import 'components/notifications/notification_inbox_host.dart';
import 'components/notifications/phone_notification_sync.dart';
import 'components/pvp/pvp_invite_host.dart';
import 'components/trade/trade_invite_host.dart';
import 'core/services/app_foreground_service.dart';
import 'core/services/app_settings_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/music_service.dart';
import 'core/services/presence_service.dart';
import 'core/services/supabase_service.dart';
import 'core/utils/keyboard_dismiss.dart';
import 'l10n/l10n.dart';
import 'providers/locale_provider.dart';
import 'routing/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppForegroundService.instance.start();
  await SupabaseService.initialize();
  // Prefs race: settings UI MusicService/AppSettings yüklenmeden okumasın.
  await Future.wait<void>(<Future<void>>[
    AppSettingsService.instance.load(),
    MusicService.instance.start(),
    LocalNotificationService.instance.initialize(),
  ]);

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
    _router = createAppRouter(refreshListenable: _routerRefreshNotifier);
    if (SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentSession != null) {
      PresenceService.instance.start();
    }
    _presenceAuthSub = authRefreshStream.listen((dynamic event) {
      if (!SupabaseService.isInitialized) return;
      if (event is AuthState &&
          event.event == AuthChangeEvent.passwordRecovery) {
        _router.go(AppRoutes.updatePassword);
      }
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

    return PhoneNotificationSync(
      child: NotificationInboxHost(
        child: PvpInviteHost(
          child: TradeInviteHost(
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
              builder: (BuildContext context, Widget? child) {
                final TextStyle baseText =
                    Theme.of(context).textTheme.bodyMedium ??
                    AppTheme.dark.textTheme.bodyMedium!;
                return DismissKeyboard(
                  child: DefaultTextStyle(
                    style: baseText.copyWith(
                      decoration: TextDecoration.none,
                      decorationThickness: 0,
                    ),
                    // Blocking gates ABOVE TutorialHost → policy/ban/offline
                    // cover coach automatically. TutorialSuppressScope still
                    // hides overlay while those layers are active.
                    child: ConnectivityGate(
                      child: BanEnforcementGate(
                        child: SessionEnforcementGate(
                          // Legal consent = register screen only (no in-game gate).
                          child: TutorialHost(
                              router: _router,
                              child: LevelUpHost(
                                child: PowerChangeHost(
                                  child:
                                      child ??
                                      const ColoredBox(
                                        color: AppColors.carbonVoid,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.liquidGold,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              routerConfig: _router,
            ),
          ),
        ),
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
      _debounceTimer = Timer(
        const Duration(milliseconds: 250),
        notifyListeners,
      );
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
