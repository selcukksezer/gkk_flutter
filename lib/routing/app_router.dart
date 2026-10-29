import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/supabase_service.dart';
import '../qa/qa_flags.dart';
// Removed achievements_screen.dart
import '../screens/auth/banned_screen.dart';
import '../screens/auth/character_select_screen.dart';
import '../screens/auth/email_confirm_waiting_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/update_password_screen.dart';
import '../screens/bank/bank_screen.dart';
import '../screens/character/character_screen.dart';
import '../screens/character/codex_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/crafting/crafting_screen.dart';
import '../screens/dungeon/dungeon_screen.dart';
import '../screens/dungeon/dungeon_battle_screen.dart';
import '../screens/dungeon/dungeon_siege_hub_screen.dart';
import '../screens/dungeon/siege_challenge_battle_screen.dart';
import '../screens/enhancement/enhancement_screen.dart';
import '../screens/facilities/facility_detail_screen.dart';
import '../screens/facilities/facilities_screen.dart';
import '../screens/guild/guild_screen.dart';
import '../screens/guild_war/guild_war_hub_screen.dart';
import '../screens/guild_war/tournament_detail_screen.dart';
import '../screens/guild_war/guild_war_attack_screen.dart';
import '../screens/guild_war/territory_detail_screen.dart';
import '../screens/guild/guild_vault_screen.dart';
import '../screens/announcements/announcements_screen.dart';
import '../screens/guild_war/guild_war_battle_result_screen.dart';
import '../screens/guild_war/war_logs_screen.dart';
import '../models/guild_war_model.dart';
import '../screens/guild/guild_monument_screen.dart';
import '../screens/guild/guild_monument_donate_screen.dart';
import '../screens/hospital/hospital_screen.dart';
import '../screens/horse_race/horse_race_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/leaderboard/leaderboard_screen.dart';
import '../screens/loot/loot_hub_screen.dart';
import '../screens/market/market_screen.dart';
import '../screens/mekans/mekans_screen.dart';
import '../screens/mekans/mekan_detail_screen.dart';
import '../screens/mekans/mekan_arena_screen.dart';
import '../screens/mekans/mekan_arena_battle_screen.dart';
import '../screens/mekans/mekan_create_screen.dart';
import '../screens/mekans/my_mekan_screen.dart';
import '../screens/friends/friends_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/prison/prison_screen.dart';

import '../screens/pvp/pvp_screen.dart';
import '../screens/pvp/pvp_history_screen.dart';
import '../screens/pvp/pvp_tournament_screen.dart';
import '../screens/quests/quests_screen.dart';
import '../screens/reputation/reputation_screen.dart';
import '../screens/season/season_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../core/legal/legal_document_content.dart';
import '../screens/legal/legal_document_screen.dart';
import '../screens/support/bug_report_detail_screen.dart';
import '../screens/support/support_screens.dart';
import '../screens/support/ticket_detail_screen.dart';
import '../screens/staff/staff_gem_reward_approvals_screen.dart';
import '../screens/staff/staff_hub_screen.dart';
import '../screens/staff/staff_liveops_screen.dart';
import '../screens/staff/staff_route_guard.dart';
import '../core/tutorial/tutorial_modal_suppress.dart';
import '../providers/policy_provider.dart';
import '../models/policy_model.dart';
import '../screens/shop/shop_screen.dart';
import '../screens/trade/trade_screen.dart';
import 'game_page_transition.dart';

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String updatePassword = '/update-password';
  static const String emailConfirm = '/email-confirm';
  static const String home = '/home';
  static const String inventory = '/inventory';
  static const String dungeon = '/dungeon';
  static const String character = '/character';
  static const String codex = '/character/codex';
  static const String horseRace = '/horse-race';
  static const String hospital = '/hospital';
  static const String market = '/market';
  static const String facilities = '/facilities';

  // New routes
// achievements route removed
  static const String bank = '/bank';
  static const String chat = '/chat';
  static const String crafting = '/crafting';
  static const String dungeonBattle = '/dungeon/battle';
  static const String dungeonSiegeHub = '/dungeon/siege';
  static const String siegeChallengeBattle = '/dungeon/siege/challenge';
  static const String enhancement = '/enhancement';
  static const String guild = '/guild';
  static const String guildWar = '/guild-war';
  static const String guildWarTournament = '/guild-war/tournament';
  static const String guildWarTerritory = '/guild-war/territory';
  static const String guildWarBattleResult = '/guild-war/battle-result';
  static const String guildWarLogs = '/guild-war/logs';
  static const String guildMonument = '/guild/monument';
  static const String guildMonumentDonate = '/guild/monument/donate';
  static const String guildVault = '/guild/vault';
  static const String guildWarAttack = '/guild-war/territory';
  static const String announcements = '/announcements';
  static const String leaderboard = '/leaderboard';
  static const String loot = '/loot';
  static const String mekans = '/mekans';
  static const String mekanCreate = '/mekans/create';
  static const String myMekan = '/my-mekan';

  static String mekanDetail(String id) => '$mekans/$id';

  static String mekanArena(String id) => '$mekans/$id/arena';
  static const String mekanArenaBattle = '/mekans/arena/battle';
  static const String banned = '/banned';
  static const String characterSelect = '/onboarding/character-select';
  static const String prison = '/prison';
  static const String pvp = '/pvp';
  static const String pvpHistory = '/pvp/history';
  static const String pvpTournament = '/pvp/tournament';
  static const String quests = '/quests';
  static const String reputation = '/reputation';
  static const String season = '/season';
  static const String settings = '/settings';
  static const String supportTickets = '/support/tickets';
  static const String createTicket = '/support/tickets/new';
  static const String bugReport = '/support/bug-report';
  static const String myBugReports = '/support/my-bug-reports';
  static const String legal = '/legal';
  static const String staffHub = '/staff';
  static const String staffLiveOps = '/staff/liveops';
  static const String staffGemRewards = '/staff/gem-rewards';
  static const String shop = '/shop';
  static const String trade = '/trade';
  static const String friends = '/friends';
  static const String notifications = '/notifications';
}

/// Deduplicates parallel redirect profile lookups during startup.
Future<Map<String, dynamic>?> _fetchRedirectUserProfile(String authId) {
  if (_redirectProfileInflight != null && _redirectProfileUserId == authId) {
    return _redirectProfileInflight!;
  }

  _redirectProfileUserId = authId;
  _redirectProfileInflight = SupabaseService.client
      .from('users')
      .select('character_class, is_banned, ban_reason, banned_until')
      .eq('auth_id', authId)
      .maybeSingle()
      .timeout(const Duration(seconds: 12))
      .then((dynamic response) {
        if (response is Map<String, dynamic>) return response;
        if (response == null) return null;
        return Map<String, dynamic>.from(response as Map);
      })
      .whenComplete(() {
        _redirectProfileInflight = null;
        _redirectProfileUserId = null;
      });

  return _redirectProfileInflight!;
}

Future<Map<String, dynamic>?>? _redirectProfileInflight;
String? _redirectProfileUserId;

bool _isActiveAccountBan(Map<String, dynamic>? profile) {
  if (profile == null || profile['is_banned'] != true) return false;
  final dynamic untilRaw = profile['banned_until'];
  if (untilRaw == null) return true;
  final DateTime? until = DateTime.tryParse(untilRaw.toString());
  if (until == null) return true;
  return until.isAfter(DateTime.now().toUtc());
}

final GlobalKey<NavigatorState> appRootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({Listenable? refreshListenable}) {
  return GoRouter(
  navigatorKey: appRootNavigatorKey,
  observers: <NavigatorObserver>[TutorialModalRouteObserver.instance],
  initialLocation: AppRoutes.splash,
  refreshListenable: refreshListenable,
  errorBuilder: (BuildContext context, GoRouterState state) => const HomeScreen(),
  redirect: (BuildContext context, GoRouterState state) async {
    final String path = state.uri.path;

    if (path == '/dungeon/' || path == '/dungeon//') {
      return AppRoutes.dungeon;
    }

    final bool hasSession = SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentSession != null;

    final bool isLegalPublic = path.startsWith('${AppRoutes.legal}/');
    final bool isForgotPassword = path == AppRoutes.forgotPassword;
    final bool isUpdatePassword = path == AppRoutes.updatePassword;
    final bool isEmailConfirm = path == AppRoutes.emailConfirm;
    final bool isAuthEntryRoute = path == AppRoutes.splash ||
        path == AppRoutes.login ||
        path == AppRoutes.register ||
        isForgotPassword ||
        isEmailConfirm;
    final bool isPublicRoute =
        isAuthEntryRoute || isLegalPublic || isForgotPassword || isEmailConfirm;

    if (!hasSession && !isPublicRoute) {
      return AppRoutes.login;
    }

    if (hasSession) {
      // Recovery / in-session password change — skip ban/class gates.
      if (isUpdatePassword) {
        return null;
      }

      final bool isOnboardingRoute = path == AppRoutes.characterSelect;
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser != null) {
        try {
          final Map<String, dynamic>? profile =
              await _fetchRedirectUserProfile(currentUser.id);
          if (_isActiveAccountBan(profile)) {
            if (path != AppRoutes.banned) {
              return AppRoutes.banned;
            }
            return null;
          }

          if (path == AppRoutes.banned) {
            return AppRoutes.home;
          }

          final String? characterClass = profile?['character_class'] as String?;
          final bool hasSelectedClass = characterClass != null && characterClass.isNotEmpty;

          if (!hasSelectedClass && !isOnboardingRoute) {
            return AppRoutes.characterSelect;
          }
          if (hasSelectedClass && isOnboardingRoute && !QaFlags.forceCharacterSelectRoute) {
            return AppRoutes.home;
          }
        } catch (e) {
          // Offline/timeout: stay put. Home also enforces class gate once
          // playerProvider loads (empty class → character-select).
          return null;
        }
      }

      if (isAuthEntryRoute) {
        return AppRoutes.home;
      }
    }

    return null;
  },
  routes: <RouteBase>[
    gameRoute(
      path: AppRoutes.splash,
      instant: true,
      build: (BuildContext context, GoRouterState state) => const SplashScreen(),
    ),
    gameRoute(
      path: AppRoutes.login,
      build: (BuildContext context, GoRouterState state) => const LoginScreen(),
    ),
    gameRoute(
      path: AppRoutes.banned,
      instant: true,
      build: (BuildContext context, GoRouterState state) => const BannedScreen(),
    ),
    gameRoute(
      path: AppRoutes.register,
      build: (BuildContext context, GoRouterState state) => const RegisterScreen(),
    ),
    gameRoute(
      path: AppRoutes.forgotPassword,
      build: (BuildContext context, GoRouterState state) =>
          const ForgotPasswordScreen(),
    ),
    gameRoute(
      path: AppRoutes.emailConfirm,
      build: (BuildContext context, GoRouterState state) {
        final String? email = state.uri.queryParameters['email'];
        return EmailConfirmWaitingScreen(email: email);
      },
    ),
    gameRoute(
      path: AppRoutes.updatePassword,
      build: (BuildContext context, GoRouterState state) =>
          const UpdatePasswordScreen(),
    ),
    gameRoute(
      path: AppRoutes.home,
      instant: true,
      build: (BuildContext context, GoRouterState state) => const HomeScreen(),
    ),
    gameRoute(
      path: AppRoutes.inventory,
      build: (BuildContext context, GoRouterState state) => const InventoryScreen(),
    ),
    gameRoute(
      path: AppRoutes.dungeon,
      build: (BuildContext context, GoRouterState state) => const DungeonScreen(),
    ),
    gameRoute(
      path: AppRoutes.dungeonSiegeHub,
      build: (BuildContext context, GoRouterState state) => const DungeonSiegeHubScreen(),
    ),
    gameRoute(
      path: AppRoutes.character,
      build: (BuildContext context, GoRouterState state) => const CharacterScreen(),
    ),
    gameRoute(
      path: AppRoutes.codex,
      build: (BuildContext context, GoRouterState state) {
        final String category = state.uri.queryParameters['category'] ?? 'item';
        final bool claim = state.uri.queryParameters['claim'] == '1';
        return CodexScreen(initialCategory: category, autoClaim: claim);
      },
    ),
    gameRoute(
      path: AppRoutes.hospital,
      build: (BuildContext context, GoRouterState state) => const HospitalScreen(),
    ),
    gameRoute(
      path: AppRoutes.market,
      build: (BuildContext context, GoRouterState state) => const MarketScreen(),
    ),
    gameRoute(
      path: AppRoutes.facilities,
      build: (BuildContext context, GoRouterState state) => const FacilitiesScreen(),
    ),
    gameRoute(
      path: '${AppRoutes.facilities}/:type',
      build: (BuildContext context, GoRouterState state) {
        final String type = state.pathParameters['type'] ?? '';
        return FacilityDetailScreen(type: type);
      },
    ),
    // achievements route removed
    gameRoute(
      path: AppRoutes.bank,
      build: (BuildContext context, GoRouterState state) => const BankScreen(),
    ),
    gameRoute(
      path: AppRoutes.chat,
      build: (BuildContext context, GoRouterState state) => const ChatScreen(),
    ),
    gameRoute(
      path: AppRoutes.crafting,
      build: (BuildContext context, GoRouterState state) => const CraftingScreen(),
    ),
    gameRoute(
      path: AppRoutes.dungeonBattle,
      build: (BuildContext context, GoRouterState state) => const DungeonBattleScreen(),
    ),
    gameRoute(
      path: AppRoutes.siegeChallengeBattle,
      build: (BuildContext context, GoRouterState state) {
        final Object? extra = state.extra;
        if (extra is SiegeChallengeBattleArgs) {
          return SiegeChallengeBattleScreen(args: extra);
        }
        return const DungeonScreen();
      },
    ),
    gameRoute(
      path: AppRoutes.enhancement,
      build: (BuildContext context, GoRouterState state) => const EnhancementScreen(),
    ),
    gameRoute(
      path: AppRoutes.guild,
      build: (BuildContext context, GoRouterState state) => const GuildScreen(),
    ),
    gameRoute(
      path: AppRoutes.guildWar,
      build: (BuildContext context, GoRouterState state) => const GuildWarHubScreen(),
    ),
    gameRoute(
      path: '${AppRoutes.guildWar}/tournament/:id',
      build: (BuildContext context, GoRouterState state) {
        final String id = state.pathParameters['id'] ?? '';
        return TournamentDetailScreen(tournamentId: id);
      },
    ),
    gameRoute(
      path: '${AppRoutes.guildWar}/territory/:id/attack',
      build: (BuildContext context, GoRouterState state) {
        final String id = state.pathParameters['id'] ?? '';
        return GuildWarAttackScreen(territoryId: id);
      },
    ),
    gameRoute(
      path: AppRoutes.guildVault,
      build: (BuildContext context, GoRouterState state) => const GuildVaultScreen(),
    ),
    gameRoute(
      path: AppRoutes.announcements,
      build: (BuildContext context, GoRouterState state) => const AnnouncementsScreen(),
    ),
    gameRoute(
      path: '${AppRoutes.guildWar}/territory/:id',
      build: (BuildContext context, GoRouterState state) {
        final String id = state.pathParameters['id'] ?? '';
        return TerritoryDetailScreen(territoryId: id);
      },
    ),
    gameRoute(
      path: AppRoutes.guildWarBattleResult,
      build: (BuildContext context, GoRouterState state) {
        final extra = state.extra;
        if (extra is GuildWarAttackResult) {
          return BattleResultScreen(result: extra);
        }
        return const GuildWarHubScreen();
      },
    ),
    gameRoute(
      path: AppRoutes.guildWarLogs,
      build: (BuildContext context, GoRouterState state) => const WarLogsScreen(),
    ),
    gameRoute(
      path: AppRoutes.guildMonument,
      build: (BuildContext context, GoRouterState state) => const GuildMonumentScreen(),
    ),
    gameRoute(
      path: AppRoutes.guildMonumentDonate,
      build: (BuildContext context, GoRouterState state) => const GuildMonumentDonateScreen(),
    ),
    gameRoute(
      path: AppRoutes.leaderboard,
      build: (BuildContext context, GoRouterState state) => const LeaderboardScreen(),
    ),
    gameRoute(
      path: AppRoutes.loot,
      build: (BuildContext context, GoRouterState state) => const LootHubScreen(),
    ),
    gameRoute(
      path: AppRoutes.horseRace,
      build: (BuildContext context, GoRouterState state) => const HorseRaceScreen(),
    ),
    gameRoute(
      path: AppRoutes.mekans,
      build: (BuildContext context, GoRouterState state) => const MekansScreen(),
    ),
    gameRoute(
      path: AppRoutes.mekanCreate,
      build: (BuildContext context, GoRouterState state) => const MekanCreateScreen(),
    ),
    gameRoute(
      path: '${AppRoutes.mekans}/:id',
      build: (BuildContext context, GoRouterState state) {
        final String id = state.pathParameters['id'] ?? '';
        return MekanDetailScreen(mekanId: id);
      },
    ),
    gameRoute(
      path: '${AppRoutes.mekans}/:id/arena',
      build: (BuildContext context, GoRouterState state) {
        final String id = state.pathParameters['id'] ?? '';
        return MekanArenaScreen(mekanId: id);
      },
    ),
    gameRoute(
      path: AppRoutes.mekanArenaBattle,
      build: (BuildContext context, GoRouterState state) {
        final Object? extra = state.extra;
        if (extra is MekanArenaBattleArgs) {
          return MekanArenaBattleScreen(args: extra);
        }
        return const MekansScreen();
      },
    ),
    gameRoute(
      path: AppRoutes.myMekan,
      build: (BuildContext context, GoRouterState state) => const MyMekanScreen(),
    ),
    gameRoute(
      path: AppRoutes.characterSelect,
      build: (BuildContext context, GoRouterState state) => const CharacterSelectScreen(),
    ),
    gameRoute(
      path: AppRoutes.prison,
      build: (BuildContext context, GoRouterState state) => const PrisonScreen(),
    ),
    gameRoute(
      path: AppRoutes.friends,
      build: (BuildContext context, GoRouterState state) => const FriendsScreen(),
    ),
    gameRoute(
      path: AppRoutes.notifications,
      build: (BuildContext context, GoRouterState state) => const NotificationsScreen(),
    ),
    gameRoute(
      path: AppRoutes.pvp,
      build: (BuildContext context, GoRouterState state) => PvpScreen(
        revengeTargetId: state.uri.queryParameters['revenge'],
      ),
    ),
    gameRoute(
      path: AppRoutes.pvpHistory,
      build: (BuildContext context, GoRouterState state) => const PvpHistoryScreen(),
    ),
    gameRoute(
      path: AppRoutes.pvpTournament,
      build: (BuildContext context, GoRouterState state) => const PvpTournamentScreen(),
    ),
    gameRoute(
      path: AppRoutes.quests,
      build: (BuildContext context, GoRouterState state) => const QuestsScreen(),
    ),
    gameRoute(
      path: AppRoutes.reputation,
      build: (BuildContext context, GoRouterState state) => const ReputationScreen(),
    ),
    gameRoute(
      path: AppRoutes.season,
      build: (BuildContext context, GoRouterState state) => const SeasonScreen(),
    ),
    gameRoute(
      path: AppRoutes.settings,
      build: (BuildContext context, GoRouterState state) => const SettingsScreen(),
    ),
    gameRoute(
      path: '${AppRoutes.supportTickets}/:id',
      build: (BuildContext context, GoRouterState state) =>
          TicketDetailScreen(ticketId: state.pathParameters['id'] ?? ''),
    ),
    gameRoute(
      path: AppRoutes.supportTickets,
      build: (BuildContext context, GoRouterState state) => const SupportTicketListScreen(),
    ),
    gameRoute(
      path: AppRoutes.createTicket,
      build: (BuildContext context, GoRouterState state) => const CreateTicketScreen(),
    ),
    gameRoute(
      path: AppRoutes.bugReport,
      build: (BuildContext context, GoRouterState state) => const BugReportScreen(),
    ),
    gameRoute(
      path: '${AppRoutes.myBugReports}/:id',
      build: (BuildContext context, GoRouterState state) =>
          PlayerBugReportDetailScreen(reportId: state.pathParameters['id'] ?? ''),
    ),
    gameRoute(
      path: AppRoutes.myBugReports,
      build: (BuildContext context, GoRouterState state) => const MyBugReportsScreen(),
    ),
    gameRoute(
      path: '${AppRoutes.legal}/:type',
      build: (BuildContext context, GoRouterState state) {
        final String type = state.pathParameters['type'] ?? 'terms';
        return Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            final PolicyState policy = ref.watch(policyProvider);
            LegalDocument? doc;
            for (final LegalDocument d in policy.documents) {
              if (d.type == type) {
                doc = d;
                break;
              }
            }
            // Unauthenticated / empty policy cache → canonical body (never hang).
            doc ??= LegalDocument(type: type, version: 1, title: '', bodyMd: '');
            return LegalDocumentScreen(document: LegalDocumentContent.resolve(doc));
          },
        );
      },
    ),
    gameRoute(
      path: AppRoutes.staffHub,
      build: (BuildContext context, GoRouterState state) =>
          const StaffRouteGuard(child: StaffHubScreen()),
    ),
    gameRoute(
      path: AppRoutes.staffLiveOps,
      build: (BuildContext context, GoRouterState state) =>
          const StaffRouteGuard(requireLiveOps: true, child: StaffLiveOpsScreen()),
    ),
    gameRoute(
      path: AppRoutes.staffGemRewards,
      build: (BuildContext context, GoRouterState state) => const StaffRouteGuard(
        requireAdmin: true,
        child: StaffGemRewardApprovalsScreen(),
      ),
    ),
    gameRoute(
      path: AppRoutes.shop,
      build: (BuildContext context, GoRouterState state) {
        final String? tab = state.uri.queryParameters['tab'];
        final int? initialTab = tab == 'night' ? 2 : null;
        return ShopScreen(initialTabIndex: initialTab);
      },
    ),
    gameRoute(
      path: AppRoutes.trade,
      build: (BuildContext context, GoRouterState state) => const TradeScreen(),
    ),
  ],
);
}

final GoRouter appRouter = createAppRouter();
