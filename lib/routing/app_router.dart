import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/services/supabase_service.dart';
import '../qa/qa_flags.dart';
// Removed achievements_screen.dart
import '../screens/auth/character_select_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/bank/bank_screen.dart';
import '../screens/character/character_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/crafting/crafting_screen.dart';
import '../screens/dungeon/dungeon_screen.dart';
import '../screens/dungeon/dungeon_battle_screen.dart';
import '../screens/enhancement/enhancement_screen.dart';
import '../screens/facilities/facility_detail_screen.dart';
import '../screens/facilities/facilities_screen.dart';
import '../screens/guild/guild_screen.dart';
import '../screens/guild_war/guild_war_hub_screen.dart';
import '../screens/guild_war/tournament_detail_screen.dart';
import '../screens/guild_war/territory_detail_screen.dart';
import '../screens/guild_war/battle_result_screen.dart';
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
import '../screens/mekans/mekan_create_screen.dart';
import '../screens/mekans/my_mekan_screen.dart';
import '../screens/prison/prison_screen.dart';

import '../screens/pvp/pvp_screen.dart';
import '../screens/pvp/pvp_history_screen.dart';
import '../screens/pvp/pvp_tournament_screen.dart';
import '../screens/quests/quests_screen.dart';
import '../screens/reputation/reputation_screen.dart';
import '../screens/season/season_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shop/shop_screen.dart';
import '../screens/trade/trade_screen.dart';
import 'game_page_transition.dart';

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String inventory = '/inventory';
  static const String dungeon = '/dungeon';
  static const String character = '/character';
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
  static const String enhancement = '/enhancement';
  static const String guild = '/guild';
  static const String guildWar = '/guild-war';
  static const String guildWarTournament = '/guild-war/tournament';
  static const String guildWarTerritory = '/guild-war/territory';
  static const String guildWarBattleResult = '/guild-war/battle-result';
  static const String guildWarLogs = '/guild-war/logs';
  static const String guildMonument = '/guild/monument';
  static const String guildMonumentDonate = '/guild/monument/donate';
  static const String leaderboard = '/leaderboard';
  static const String loot = '/loot';
  static const String mekans = '/mekans';
  static const String mekanCreate = '/mekans/create';
  static const String myMekan = '/my-mekan';
  static const String characterSelect = '/onboarding/character-select';
  static const String prison = '/prison';
  static const String pvp = '/pvp';
  static const String pvpHistory = '/pvp/history';
  static const String pvpTournament = '/pvp/tournament';
  static const String quests = '/quests';
  static const String reputation = '/reputation';
  static const String season = '/season';
  static const String settings = '/settings';
  static const String shop = '/shop';
  static const String trade = '/trade';
}

/// Deduplicates parallel redirect profile lookups during startup.
Future<Map<String, dynamic>?> _fetchRedirectUserProfile(String authId) {
  if (_redirectProfileInflight != null && _redirectProfileUserId == authId) {
    return _redirectProfileInflight!;
  }

  _redirectProfileUserId = authId;
  _redirectProfileInflight = SupabaseService.client
      .from('users')
      .select('character_class, is_banned')
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

final GlobalKey<NavigatorState> appRootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({Listenable? refreshListenable}) {
  return GoRouter(
  navigatorKey: appRootNavigatorKey,
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

    final bool isPublicRoute =
        path == AppRoutes.splash || path == AppRoutes.login || path == AppRoutes.register;

    if (!hasSession && !isPublicRoute) {
      return AppRoutes.login;
    }

    if (hasSession) {
      final bool isOnboardingRoute = path == AppRoutes.characterSelect;
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser != null) {
        try {
          final Map<String, dynamic>? profile =
              await _fetchRedirectUserProfile(currentUser.id);
          final bool isBanned = profile?['is_banned'] == true;
          if (isBanned) {
            await SupabaseService.client.auth.signOut();
            return AppRoutes.login;
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
          if (!isOnboardingRoute) {
            return AppRoutes.characterSelect;
          }
        }
      }

      if (isPublicRoute) {
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
      path: AppRoutes.register,
      build: (BuildContext context, GoRouterState state) => const RegisterScreen(),
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
      path: AppRoutes.character,
      build: (BuildContext context, GoRouterState state) => const CharacterScreen(),
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
      path: AppRoutes.pvp,
      build: (BuildContext context, GoRouterState state) => const PvpScreen(),
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
      path: AppRoutes.shop,
      build: (BuildContext context, GoRouterState state) => const ShopScreen(),
    ),
    gameRoute(
      path: AppRoutes.trade,
      build: (BuildContext context, GoRouterState state) => const TradeScreen(),
    ),
  ],
);
}

final GoRouter appRouter = createAppRouter();
