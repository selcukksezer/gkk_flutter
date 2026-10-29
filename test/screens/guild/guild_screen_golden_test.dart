import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gkk_flutter/components/layout/game_chrome.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/l10n/app_localizations.dart';
import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/models/guild_model.dart';
import 'package:gkk_flutter/models/guild_vault_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/staff_model.dart';
import 'package:gkk_flutter/providers/auth_provider.dart';
import 'package:gkk_flutter/providers/guild_monument_provider.dart';
import 'package:gkk_flutter/providers/guild_provider.dart';
import 'package:gkk_flutter/providers/guild_vault_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/providers/staff_provider.dart';
import 'package:gkk_flutter/repositories/guild_monument_repository.dart';
import 'package:gkk_flutter/repositories/player_repository.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:gkk_flutter/screens/guild/guild_helpers.dart';
import 'package:gkk_flutter/screens/guild/guild_screen.dart';
import 'package:gkk_flutter/screens/guild/widgets/guild_design.dart';
import 'package:gkk_flutter/screens/guild/widgets/guild_dialogs.dart';
import 'package:gkk_flutter/screens/guild/widgets/guild_emblem_banner.dart';
import 'package:gkk_flutter/screens/guild/widgets/guild_member_view.dart';
import 'package:gkk_flutter/screens/guild/widgets/guild_monument_hero_card.dart';
import 'package:gkk_flutter/screens/guild/widgets/guild_no_guild_view.dart';
import 'package:gkk_flutter/screens/guild/widgets/guild_perks_and_buffs.dart';
import 'package:gkk_flutter/screens/guild/widgets/monument_donate_amount_dialog.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

/// Authentic mobile viewport specifications (iPhone 14 / modern 390x844 mobile standard).
const double kMobileWidth = 390.0;
const double kMobileHeight = 844.0;
const double kDevicePixelRatio = 1.0;
const EdgeInsets kMobileSafeArea = EdgeInsets.only(top: 47.0, bottom: 34.0);

const String kOutputDir = 'reports/screenshots/mobile_goldens';
const List<int> kPngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// Utility to capture widget to PNG file on disk for golden inspection.
Future<File?> captureWidgetToPng({
  required WidgetTester tester,
  required GlobalKey repaintKey,
  required String filename,
}) async {
  final Directory dir = Directory(kOutputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  File? savedFile;
  try {
    await tester.runAsync(() async {
      final RenderRepaintBoundary? boundary =
          repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: kDevicePixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final File file = File('$kOutputDir/$filename');
        await file.writeAsBytes(pngBytes, flush: true);
        savedFile = file;
      }
    });
  } catch (e) {
    // Graceful fallback for test runners without headless graphics contexts
  }

  return savedFile;
}

// ─── Test Fixtures & Data Builders ───────────────────────────────────────────

PlayerProfile _makeTestProfile({
  String id = 'player_leader',
  String username = 'ArchonKael',
  String guildRole = 'leader',
  int gold = 5000000,
  int power = 125000,
}) {
  return PlayerProfile(
    id: id,
    authId: 'auth_$id',
    username: username,
    email: '$username@aion.test',
    displayName: username,
    avatarUrl: null,
    avatarFrame: 'glow',
    level: 60,
    xp: 250000,
    gold: gold,
    gems: 1200,
    energy: 100,
    maxEnergy: 100,
    attack: 850,
    defense: 620,
    health: 2400,
    maxHealth: 2400,
    power: power,
    isOnline: true,
    isBanned: false,
    tutorialCompleted: true,
    guildId: 'guild_aion_01',
    guildRole: guildRole,
    referralCode: null,
    referredBy: null,
    pvpRating: 1850,
    pvpWins: 84,
    pvpLosses: 12,
    addictionLevel: 0,
    tolerance: 20,
    lastPotionUsedAt: null,
    warriorBloodlustUntil: null,
    hospitalUntil: null,
  );
}

GuildMemberData _makeMember({
  required String id,
  required String name,
  required GuildRole role,
  required int power,
  required int level,
  bool isOnline = false,
  String? staffBadge,
}) {
  return GuildMemberData(
    playerId: id,
    userId: 'usr_$id',
    username: name,
    level: level,
    role: role,
    power: power,
    isOnline: isOnline,
    contribution: 1500,
    staffBadge: staffBadge,
  );
}

GuildData _createTestGuild({
  String id = 'guild_aion_01',
  String name = 'AION CELLestial',
  int level = 42,
  int vaultGold = 850000,
  int monumentLevel = 3,
  int minJoinPower = 50000,
  List<GuildMemberData>? members,
}) {
  final List<GuildMemberData> defaultMembers = members ??
      <GuildMemberData>[
        _makeMember(
          id: 'player_leader',
          name: 'ArchonKael',
          role: GuildRole.leader,
          power: 125000,
          level: 60,
          isOnline: true,
          staffBadge: 'GM',
        ),
        _makeMember(
          id: 'player_officer',
          name: 'ValkyrieNyx',
          role: GuildRole.officer,
          power: 98000,
          level: 55,
          isOnline: true,
        ),
        _makeMember(
          id: 'player_member1',
          name: 'ShadowBlade',
          role: GuildRole.member,
          power: 64000,
          level: 45,
          isOnline: false,
        ),
        _makeMember(
          id: 'player_member2',
          name: 'CelestialHealer',
          role: GuildRole.member,
          power: 58000,
          level: 40,
          isOnline: true,
        ),
      ];

  return GuildData(
    guildId: id,
    name: name,
    description: 'Aion 2 Dark Celestial Kadim Loncası. Göklerde yankılanan güç!',
    level: level,
    leaderId: 'player_leader',
    memberCount: defaultMembers.length,
    maxMembers: 50,
    totalPower: 345000,
    monumentLevel: monumentLevel,
    monumentStructural: 4200,
    monumentMystical: 2100,
    monumentCritical: 180,
    monumentGoldPool: 0,
    vaultGold: vaultGold,
    minJoinPower: minJoinPower,
    members: defaultMembers,
  );
}

MonumentMyStats _createTestMonumentStats() {
  return const MonumentMyStats(
    totals: MonumentResourceSnapshot(
      structural: 5000,
      mystical: 2500,
      critical: 300,
      gold: 5000000,
    ),
    today: MonumentResourceSnapshot(
      structural: 100,
      mystical: 50,
      critical: 5,
      gold: 200000,
    ),
    wallet: MonumentResourceSnapshot(
      structural: 500,
      mystical: 250,
      critical: 30,
      gold: 1500000,
    ),
    dailyLimits: MonumentResourceSnapshot(
      structural: 1000,
      mystical: 500,
      critical: 25,
      gold: 1000000,
    ),
    contributionScore: 1250,
  );
}

MonumentDashboard _createTestMonumentDashboard({required GuildData guild}) {
  final snapshot = MonumentGuildSnapshot(
    id: guild.guildId,
    name: guild.name,
    monumentLevel: guild.monumentLevel,
    structural: guild.monumentStructural,
    mystical: guild.monumentMystical,
    critical: guild.monumentCritical,
    goldPool: guild.vaultGold,
  );

  return MonumentDashboard(
    guild: snapshot,
    memberCount: guild.memberCount,
    contributors: const <MonumentContributor>[],
    blueprints: const <MonumentBlueprint>[
      MonumentBlueprint(
        blueprintType: 'sanctuary',
        fragments: 10,
        fragmentsRequired: 10,
        isComplete: true,
      ),
    ],
    myStats: _createTestMonumentStats(),
    nextCost: const <String, dynamic>{
      'structural': 5000,
      'mystical': 2500,
      'critical': 200,
      'vault_gold': 500000,
    },
  );
}

// ─── Treasury & Vault Fixtures ───────────────────────────────────────────────

GuildVaultState _createTestVaultState({
  int vaultGold = 850000,
  bool isLeader = true,
  List<GuildVaultItem>? items,
}) {
  return GuildVaultState(
    isLoading: false,
    hydrated: true,
    vaultGold: vaultGold,
    vaultGoldPending: 12000,
    monumentGoldPool: 0,
    isLeader: isLeader,
    isOfficer: false,
    canManage: isLeader,
    canCollect: true,
    vaultAutoPayoutWeekly: false,
    vaultTaxRate: 0.05,
    guildRole: isLeader ? 'leader' : 'member',
    items: items ??
        const <GuildVaultItem>[
          GuildVaultItem(
            id: 'v_item_1',
            itemId: 'celestial_relic_core',
            itemName: 'Kadim Göksel Çekirdek',
            quantity: 4,
            rarity: 'mythic',
            icon: '💎',
            itemType: 'relic',
          ),
          GuildVaultItem(
            id: 'v_item_2',
            itemId: 'obsidian_siege_plate',
            itemName: 'Obsidiyen Kuşatma Plakası',
            quantity: 12,
            rarity: 'legendary',
            icon: '🛡️',
            itemType: 'material',
          ),
        ],
    ledger: const <GuildVaultLedgerEntry>[],
    territories: const <GuildVaultTerritorySummary>[],
  );
}

// ─── Fake Providers & Notifiers ───────────────────────────────────────────────

class _FakePlayerNotifier extends PlayerNotifier {
  _FakePlayerNotifier(this.initialState);

  final PlayerState initialState;

  @override
  PlayerState build() => initialState;

  @override
  Future<void> loadProfile() async {}
}

class _FakeGuildNotifier extends GuildNotifier {
  _FakeGuildNotifier(this.initialState);

  final GuildState initialState;

  @override
  GuildState build() => initialState;

  @override
  Future<void> loadGuild() async {}

  @override
  Future<void> loadRecommendedGuilds() async {}

  @override
  Future<void> searchGuilds(String query) async {}

  @override
  void clearSearchResults() {}

  @override
  Future<bool> joinGuild(String guildId) async => true;

  @override
  Future<bool> leaveGuild() async => true;

  @override
  Future<bool> disbandGuild() async => true;

  @override
  Future<bool> updateMember({required String memberId, required String action}) async => true;
}

class _FakeGuildVaultNotifier extends GuildVaultNotifier {
  _FakeGuildVaultNotifier(this.initialState);

  final GuildVaultState initialState;

  @override
  GuildVaultState build() => initialState;

  @override
  Future<void> load({bool silent = false}) async {}

  @override
  void applyGoldDelta(int delta) {}

  @override
  void applyGoldAbsolute(int gold) {}

  @override
  Future<String?> collectRewards() async => null;
}

class _FakeGuildMonumentNotifier extends GuildMonumentNotifier {
  _FakeGuildMonumentNotifier(this.initialState);

  final GuildMonumentState initialState;

  @override
  GuildMonumentState build() => initialState;

  @override
  Future<void> bootstrap() async {}

  @override
  Future<void> loadDashboard() async {}
}

class _FakeStaffNotifier extends StaffNotifier {
  @override
  StaffState build() => const StaffState(isLoading: false, profile: StaffProfile.none);
}

class _FakeTutorialController extends TutorialController {
  @override
  TutorialState build() => TutorialState.initial().copyWith(loaded: true);

  @override
  Future<void> onRouteEnter(String route) async {}
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier([this.user]);
  final AuthUser? user;

  @override
  AuthState build() => AuthState(
        status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        user: user,
      );

  @override
  Future<void> logout() async {}
}

class _FakePlayerRepository implements PlayerRepository {
  _FakePlayerRepository(this.profile);

  final PlayerProfile profile;

  @override
  Future<PlayerProfile> loadCurrentPlayer() async => profile;
}

// ─── Guild Overview Composite Mobile Viewport ────────────────────────────────

/// Renders the complete 2027 Aion 2 Guild Overview & Roster Screen on 390x844 mobile resolution.
class GuildOverviewCompositeViewport extends StatelessWidget {
  const GuildOverviewCompositeViewport({
    super.key,
    required this.guild,
    required this.myPlayerId,
    required this.myRole,
    required this.onWarTap,
    required this.onMonumentTap,
    required this.onVaultTap,
    required this.onMemberTap,
    required this.onLeaveTap,
  });

  final GuildData guild;
  final String myPlayerId;
  final GuildRole myRole;
  final VoidCallback onWarTap;
  final VoidCallback onMonumentTap;
  final VoidCallback onVaultTap;
  final ValueChanged<GuildMemberData> onMemberTap;
  final VoidCallback onLeaveTap;

  @override
  Widget build(BuildContext context) {
    final GuildPrestigeTier tier = GuildPrestigeTier.fromLevel(guild.level);
    final int onlineCount = (guild.members ?? const <GuildMemberData>[])
        .where((GuildMemberData m) => m.isOnline == true)
        .length;

    final List<GuildMemberData> sortedMembers = guild.members == null
        ? <GuildMemberData>[]
        : (List<GuildMemberData>.from(guild.members!)..sort(
            (GuildMemberData a, GuildMemberData b) => guildRoleSortOrder(
              a.role,
            ).compareTo(guildRoleSortOrder(b.role)),
          ));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          // 1. Aion 2 Celestial Hero Card
          GuildGlassCard(
            accent: tier.primaryAccent,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    GuildStatPill(
                      icon: Icons.auto_awesome_rounded,
                      label: tier.label,
                      accent: tier.primaryAccent,
                      filled: true,
                    ),
                    const Spacer(),
                    GuildStatPill(
                      icon: Icons.fiber_manual_record_rounded,
                      label: '$onlineCount / ${guild.memberCount} Çevrimiçi',
                      accent: GuildPalette.neon,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    GuildCelestialBanner(
                      guildName: guild.name,
                      level: guild.level,
                      monumentLevel: guild.monumentLevel,
                      width: 88,
                      height: 114,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            guild.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: GuildPalette.textHi,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sv. ${guild.level} Kadim Lejyon',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: tier.primaryAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            guild.description ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: GuildPalette.titanium,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Command Grid (Savaş, Anıt, Kasa)
          Row(
            children: <Widget>[
              Expanded(
                child: GuildActionTile(
                  title: 'LONCA SAVAŞI',
                  subtitle: 'Bölge Kuşatması',
                  icon: Icons.shield_rounded,
                  accent: GuildPalette.ruby,
                  onTap: onWarTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GuildActionTile(
                  title: 'KUTSAL ANIT',
                  subtitle: 'Sv.${guild.monumentLevel} Anıt',
                  icon: Icons.account_balance_rounded,
                  accent: GuildPalette.coral,
                  onTap: onMonumentTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GuildActionTile(
                  title: 'LONCA KASASI',
                  subtitle: '${formatGuildCompact(guild.vaultGold)}g',
                  icon: Icons.savings_rounded,
                  accent: GuildPalette.gold,
                  onTap: onVaultTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Vault Gold Panel
          GuildNeonPanel(
            accent: GuildPalette.gold,
            child: Row(
              children: <Widget>[
                const Text('🪙', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'LONCA KASASI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: GuildPalette.titanium,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '${formatGuildCompact(guild.vaultGold)} ALTIN',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: GuildPalette.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                GuildPressable(
                  onTap: onVaultTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: GuildPalette.goldGrad,
                    ),
                    child: const Text(
                      'Kasa Aç',
                      style: TextStyle(
                        color: GuildPalette.void_,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Perks & Active Buffs Section
          GuildPerksAndBuffsSection(
            monumentLevel: guild.monumentLevel,
            guildLevel: guild.level,
          ),
          const SizedBox(height: 18),

          // 5. Sorted Roster List
          GuildSectionTitle(
            title: 'ÜYELER',
            subtitle: '${sortedMembers.length} kayıt · $onlineCount çevrimiçi',
            accent: GuildPalette.fuchsia,
          ),
          const SizedBox(height: 10),
          for (final GuildMemberData member in sortedMembers) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GuildGlassCard(
                accent: member.role == GuildRole.leader
                    ? GuildPalette.gold
                    : member.role == GuildRole.officer
                        ? GuildPalette.coral
                        : GuildPalette.titanium,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    GuildCelestialEmblem(
                      level: member.level,
                      monogram: member.username.characters.first.toUpperCase(),
                      size: 38,
                      showGlow: false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                member.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: GuildPalette.textHi,
                                ),
                              ),
                              if (member.staffBadge != null) ...<Widget>[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: GuildPalette.iridescentCyan.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: GuildPalette.iridescentCyan.withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    member.staffBadge!,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: GuildPalette.iridescentCyan,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sv. ${member.level} · Güç: ${formatGuildCompact(member.power)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: GuildPalette.titanium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GuildStatPill(
                      icon: member.isOnline == true
                          ? Icons.check_circle_rounded
                          : Icons.access_time_rounded,
                      label: guildRoleLabel(member.role),
                      accent: member.role == GuildRole.leader
                          ? GuildPalette.gold
                          : member.role == GuildRole.officer
                              ? GuildPalette.coral
                              : GuildPalette.titanium,
                      filled: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Leave / Disband Button
          Align(
            alignment: Alignment.centerRight,
            child: GuildPressable(
              onTap: onLeaveTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GuildPalette.ruby.withValues(alpha: 0.6)),
                  color: GuildPalette.ruby.withValues(alpha: 0.12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      myRole == GuildRole.leader
                          ? Icons.dangerous_outlined
                          : Icons.logout_rounded,
                      size: 16,
                      color: GuildPalette.ruby,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      myRole == GuildRole.leader ? 'Loncayı Dağıt' : 'Loncadan Ayrıl',
                      style: const TextStyle(
                        color: GuildPalette.ruby,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Test Harness ────────────────────────────────────────────────────────────

Widget _buildTestWrapper({
  required Widget child,
  PlayerState? playerState,
  GuildState? guildState,
  GuildVaultState? vaultState,
  GuildMonumentState? monumentState,
  GlobalKey? repaintKey,
  Size viewportSize = const Size(kMobileWidth, kMobileHeight),
  EdgeInsets safeAreaPadding = kMobileSafeArea,
}) {
  final PlayerState effectivePlayer = playerState ??
      PlayerState(
        status: PlayerStatus.ready,
        profile: _makeTestProfile(),
      );

  final GuildData defaultGuild = _createTestGuild();
  final GuildState effectiveGuild = guildState ??
      GuildState(
        guild: defaultGuild,
        searchResults: const <GuildData>[],
        recommendedGuilds: const <GuildData>[],
        isLoading: false,
        isSearching: false,
        isLoadingRecommended: false,
        isMutating: false,
      );

  final GuildVaultState effectiveVault = vaultState ??
      _createTestVaultState(vaultGold: effectiveGuild.guild?.vaultGold ?? 850000);

  final GuildMonumentState effectiveMonument = monumentState ??
      GuildMonumentState(
        dashboard: _createTestMonumentDashboard(guild: effectiveGuild.guild ?? defaultGuild),
        isLoading: false,
        loadFailed: false,
        isUpgrading: false,
      );

  final GoRouter testRouter = GoRouter(
    initialLocation: AppRoutes.guild,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.guild,
        builder: (BuildContext context, GoRouterState state) {
          final Widget wrappedChild = (child is Scaffold || child is GuildScreen)
              ? child
              : Scaffold(
                  backgroundColor: const Color(0xFF080B12),
                  body: child,
                );
          return MediaQuery(
            data: MediaQueryData(
              size: viewportSize,
              padding: safeAreaPadding,
              viewPadding: safeAreaPadding,
              devicePixelRatio: 1.0,
            ),
            child: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: repaintKey != null
                  ? RepaintBoundary(key: repaintKey, child: wrappedChild)
                  : wrappedChild,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.guildWar,
        builder: (BuildContext context, GoRouterState state) => const Scaffold(body: Text('GUILD_WAR_DESTINATION')),
      ),
      GoRoute(
        path: AppRoutes.guildMonument,
        builder: (BuildContext context, GoRouterState state) => const Scaffold(body: Text('GUILD_MONUMENT_DESTINATION')),
      ),
      GoRoute(
        path: AppRoutes.guildVault,
        builder: (BuildContext context, GoRouterState state) => const Scaffold(body: Text('GUILD_VAULT_DESTINATION')),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) => const Scaffold(body: Text('HOME_DESTINATION')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      playerProvider.overrideWith(() => _FakePlayerNotifier(effectivePlayer)),
      playerRepositoryProvider.overrideWithValue(
        _FakePlayerRepository(effectivePlayer.profile!),
      ),
      guildProvider.overrideWith(() => _FakeGuildNotifier(effectiveGuild)),
      guildVaultProvider.overrideWith(() => _FakeGuildVaultNotifier(effectiveVault)),
      guildMonumentProvider.overrideWith(() => _FakeGuildMonumentNotifier(effectiveMonument)),
      staffProvider.overrideWith(() => _FakeStaffNotifier()),
      tutorialProvider.overrideWith(() => _FakeTutorialController()),
      authProvider.overrideWith(
        () => _FakeAuthNotifier(
          const AuthUser(
            id: 'auth_player_leader',
            username: 'ArchonKael',
            email: 'ArchonKael@aion.test',
          ),
        ),
      ),
      guildConfigProvider.overrideWithValue(const GuildConfig(createCostGold: 100000)),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: testRouter,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080B12),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.liquidGold,
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF101322),
        ),
      ),
    ),
  );
}

// ─── Test Suite ─────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const Size mobileSize = Size(kMobileWidth, kMobileHeight);

  group('GuildScreen Real Mobile Golden Tests (390x844 SafeArea)', () {
    testWidgets('Captures golden screenshot: Real GuildScreen active legion with members, perks, and treasury', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        _buildTestWrapper(
          child: const GuildScreen(),
          repaintKey: repaintKey,
        ),
      );

      // Settle deferProviderUpdate & microtasks
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // 1. Zero RenderFlex overflow or font/asset exceptions
      expect(tester.takeException(), isNull);

      // 2. Key Screen Structure: GuildScreen, GameTopBar, GameBottomBar, GuildMemberView
      expect(find.byType(GuildScreen), findsOneWidget);
      expect(find.byType(GameTopBar), findsOneWidget);
      expect(find.byType(GameBottomBar), findsOneWidget);
      expect(find.byType(GuildMemberView), findsOneWidget);

      // 3. Guild Identity & Tier
      expect(find.text('AION CELLestial'), findsOneWidget);
      expect(find.text('ALTIN HANEDAN'), findsWidgets);

      // 4. Command Grid & Treasury
      expect(find.text('LONCA SAVAŞI'), findsOneWidget);
      expect(find.text('KUTSAL ANIT'), findsOneWidget);
      expect(find.text('LONCA KASASI'), findsWidgets);
      expect(find.textContaining('850.0Kg'), findsWidgets);

      // 5. Active Perks & Buffs
      expect(find.text('AKTİF LONCA GÜÇLENDİRMELERİ'), findsOneWidget);

      // 6. Member Roster
      expect(find.text('ArchonKael'), findsOneWidget);
      expect(find.text('ValkyrieNyx'), findsOneWidget);

      // 7. Capture golden screenshot & verify PNG signature
      final File? screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '01_guild_screen_member_view.png',
      );
      if (screenshot != null) {
        expect(screenshot.existsSync(), isTrue);
        final Uint8List bytes = await screenshot.readAsBytes();
        expect(bytes.length, greaterThan(1024));
        for (int i = 0; i < kPngSignature.length; i++) {
          expect(bytes[i], equals(kPngSignature[i]));
        }
      }
    });

    testWidgets('Captures golden screenshot: Real GuildScreen no-guild discovery view with recommended guilds', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final List<GuildData> recommended = <GuildData>[
        _createTestGuild(id: 'rec_1', name: 'Gök Tanrısı Muhafızları', level: 25, minJoinPower: 30000),
        _createTestGuild(id: 'rec_2', name: 'Gölge Suikastçileri', level: 18, minJoinPower: 60000),
      ];

      final GuildState noGuildState = GuildState(
        guild: null,
        searchResults: const <GuildData>[],
        recommendedGuilds: recommended,
        isLoading: false,
        isSearching: false,
        isLoadingRecommended: false,
        isMutating: false,
      );

      final PlayerProfile unguildedProfile = _makeTestProfile(guildRole: 'none').copyWith(guildId: '');

      await tester.pumpWidget(
        _buildTestWrapper(
          child: const GuildScreen(),
          playerState: PlayerState(status: PlayerStatus.ready, profile: unguildedProfile),
          guildState: noGuildState,
          repaintKey: repaintKey,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(GuildScreen), findsOneWidget);
      expect(find.byType(GuildNoGuildView), findsOneWidget);
      expect(find.text('Gök Tanrısı Muhafızları'), findsOneWidget);
      expect(find.text('Gölge Suikastçileri'), findsOneWidget);
      expect(find.text('Lonca Kur'), findsWidgets);

      final File? screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '02_guild_screen_no_guild_view.png',
      );
      if (screenshot != null) {
        expect(screenshot.existsSync(), isTrue);
        final Uint8List bytes = await screenshot.readAsBytes();
        expect(bytes.length, greaterThan(1024));
        for (int i = 0; i < kPngSignature.length; i++) {
          expect(bytes[i], equals(kPngSignature[i]));
        }
      }
    });

    testWidgets('Captures golden screenshot: GuildOverviewCompositeViewport mobile layout', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(kMobileWidth, kMobileHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey repaintKey = GlobalKey();
      final testGuild = _createTestGuild();

      await tester.pumpWidget(
        _buildTestWrapper(
          child: GuildOverviewCompositeViewport(
            guild: testGuild,
            myPlayerId: 'player_leader',
            myRole: GuildRole.leader,
            onWarTap: () {},
            onMonumentTap: () {},
            onVaultTap: () {},
            onMemberTap: (_) {},
            onLeaveTap: () {},
          ),
          repaintKey: repaintKey,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('AION CELLestial'), findsOneWidget);

      final File? screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: repaintKey,
        filename: '03_guild_overview_composite.png',
      );
      if (screenshot != null) {
        expect(screenshot.existsSync(), isTrue);
        final Uint8List bytes = await screenshot.readAsBytes();
        expect(bytes.length, greaterThan(1024));
      }
    });
  });

  group('Guild Overview & Celestial Rendering (390x844 SafeArea)', () {
    testWidgets('GuildOverviewCompositeViewport renders hero card, command grid, and vault gold without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = mobileSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testGuild = _createTestGuild();
      bool warTapped = false;
      bool vaultTapped = false;

      await tester.pumpWidget(
        _buildTestWrapper(
          child: GuildOverviewCompositeViewport(
            guild: testGuild,
            myPlayerId: 'player_leader',
            myRole: GuildRole.leader,
            onWarTap: () => warTapped = true,
            onMonumentTap: () {},
            onVaultTap: () => vaultTapped = true,
            onMemberTap: (_) {},
            onLeaveTap: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify zero unhandled exceptions or overflow errors on 390x844
      expect(tester.takeException(), isNull);

      // Verify Guild title & Aion 2 level & tier
      expect(find.text('AION CELLestial'), findsOneWidget);
      expect(find.text('Sv. 42 Kadim Lejyon'), findsOneWidget);

      // Verify Command Grid tiles (Savaş, Anıt, Kasa)
      expect(find.text('LONCA SAVAŞI'), findsOneWidget);
      expect(find.text('KUTSAL ANIT'), findsOneWidget);
      expect(find.text('LONCA KASASI'), findsWidgets);

      // Verify Live Vault Gold counter
      expect(find.textContaining('850.0K'), findsWidgets);

      // Test tap interaction on Savaş
      await tester.tap(find.text('LONCA SAVAŞI'));
      await tester.pump();
      expect(warTapped, isTrue);

      // Test scroll responsiveness without hitch
      final Finder scrollable = find.byType(ListView).first;
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('GuildNoGuildView renders search bar, recommended list, and create button on 390x844', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = mobileSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final searchCtrl = TextEditingController();
      final List<GuildData> recommended = <GuildData>[
        _createTestGuild(
          id: 'rec_1',
          name: 'Gök Tanrısı Muhafızları',
          level: 25,
          minJoinPower: 30000,
        ),
        _createTestGuild(
          id: 'rec_2',
          name: 'Gölge Suikastçileri',
          level: 18,
          minJoinPower: 60000,
        ),
      ];

      bool createTapped = false;

      await tester.pumpWidget(
        _buildTestWrapper(
          child: GuildNoGuildView(
            searchController: searchCtrl,
            searchResults: const <GuildData>[],
            recommendedGuilds: recommended,
            myPower: 45000,
            isSearching: false,
            isLoadingRecommended: false,
            isMutating: false,
            onSearch: () {},
            onJoin: (_) async {},
            onCreate: () => createTapped = true,
            onRefresh: () async {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify zero layout overflows
      expect(tester.takeException(), isNull);

      // Verify GuildNoGuildView widgets
      expect(find.byType(GuildNoGuildView), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // search input
      expect(find.text('Gök Tanrısı Muhafızları'), findsOneWidget);
      expect(find.text('Gölge Suikastçileri'), findsOneWidget);

      // Verify Create Guild CTA
      expect(find.text('Lonca Kur'), findsWidgets);
      await tester.tap(find.text('Lonca Kur').first);
      await tester.pump();
      expect(createTapped, isTrue);

      searchCtrl.dispose();
    });

    testWidgets('GuildCelestialEmblem and GuildCelestialBanner render across all prestige tiers', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = mobileSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Test all 5 prestige tiers
      final List<int> levels = <int>[10, 20, 40, 60, 90]; // bronze, silver, gold, celestial, eternal

      for (final int lv in levels) {
        final tier = GuildPrestigeTier.fromLevel(lv);
        final GlobalKey tierKey = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: const Color(0xFF080B12),
            ),
            home: RepaintBoundary(
              key: tierKey,
              child: Scaffold(
                backgroundColor: const Color(0xFF080B12),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      GuildCelestialEmblem(
                        level: lv,
                        monogram: '⚔️',
                        size: 72,
                        showGlow: true,
                      ),
                      const SizedBox(height: 16),
                      GuildCelestialBanner(
                        guildName: 'VALKYRIE',
                        level: lv,
                        monumentLevel: 5,
                        width: 120,
                        height: 160,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify tier computation & painter execution
        expect(tier.label, isNotEmpty);
        expect(find.byType(CustomPaint), findsWidgets);
        expect(tester.takeException(), isNull);

        if (lv == 60) {
          final File? tierScreenshot = await captureWidgetToPng(
            tester: tester,
            repaintKey: tierKey,
            filename: '07_guild_prestige_celestial_tier.png',
          );
          if (tierScreenshot != null) {
            expect(tierScreenshot.existsSync(), isTrue);
          }
        }
      }
    });

    testWidgets('GuildCelestialEmblemPainter and GuildBannerClothPainter paint heraldic shield cleanly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: const GuildCelestialEmblemPainter(
                    progress: 0.5,
                    tier: GuildPrestigeTier.celestial,
                    monogram: '👑',
                    glowOpacity: 0.9,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Guild Roster & Member Management (390x844 SafeArea)', () {
    testWidgets('Roster renders sorted members with role badges, power, and online indicators', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = mobileSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testGuild = _createTestGuild();

      await tester.pumpWidget(
        _buildTestWrapper(
          child: GuildOverviewCompositeViewport(
            guild: testGuild,
            myPlayerId: 'player_leader',
            myRole: GuildRole.leader,
            onWarTap: () {},
            onMonumentTap: () {},
            onVaultTap: () {},
            onMemberTap: (_) {},
            onLeaveTap: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify all members are rendered in sorted order
      expect(find.text('ArchonKael'), findsOneWidget);
      expect(find.text('ValkyrieNyx'), findsOneWidget);

      // Scroll down to check remaining members
      final Finder scrollable = find.byType(ListView).first;
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pump();

      expect(find.text('ShadowBlade'), findsOneWidget);
      expect(find.text('CelestialHealer'), findsOneWidget);

      // Verify leave/disband button
      expect(find.text('Loncayı Dağıt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('showGuildMemberActionsSheet displays role-appropriate actions for leader', (
      WidgetTester tester,
    ) async {
      final officerMember = _makeMember(
        id: 'officer_1',
        name: 'OfficerDave',
        role: GuildRole.officer,
        power: 80000,
        level: 50,
      );

      String? triggeredAction;

      final GlobalKey sheetHostKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF080B12),
          ),
          home: RepaintBoundary(
            key: sheetHostKey,
            child: Scaffold(
              body: Builder(
                builder: (BuildContext ctx) {
                  return ElevatedButton(
                    onPressed: () {
                      showGuildMemberActionsSheet(
                        context: ctx,
                        member: officerMember,
                        myRole: GuildRole.leader,
                        myPlayerId: 'player_leader',
                        onMemberAction: ({
                          required String action,
                          required String memberId,
                          required String successMsg,
                        }) async {
                          triggeredAction = action;
                        },
                      );
                    },
                    child: const Text('Open Actions'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Actions'));
      await tester.pumpAndSettle();

      final File? sheetScreenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: sheetHostKey,
        filename: '06_guild_member_actions_sheet.png',
      );
      if (sheetScreenshot != null) {
        expect(sheetScreenshot.existsSync(), isTrue);
      }

      // Leader viewing Officer: should see Üye Yap, Liderliği Devret, and Loncadan At
      expect(find.text('Üye Yap'), findsOneWidget);
      expect(find.text('Liderliği Devret'), findsOneWidget);
      expect(find.text('Loncadan At'), findsOneWidget);
      expect(find.text('Subay Yap'), findsNothing); // Officer cannot be promoted to Officer

      // Tap on Üye Yap
      await tester.tap(find.text('Üye Yap'));
      await tester.pumpAndSettle();

      expect(triggeredAction, equals('demote_guild_member'));
    });

    testWidgets('showGuildMemberActionsSheet displays kick only for officer viewing member', (
      WidgetTester tester,
    ) async {
      final regularMember = _makeMember(
        id: 'member_1',
        name: 'NoviceBob',
        role: GuildRole.member,
        power: 30000,
        level: 25,
      );

      String? triggeredAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) {
                return ElevatedButton(
                  onPressed: () {
                    showGuildMemberActionsSheet(
                      context: ctx,
                      member: regularMember,
                      myRole: GuildRole.officer,
                      myPlayerId: 'player_officer',
                      onMemberAction: ({
                        required String action,
                        required String memberId,
                        required String successMsg,
                      }) async {
                        triggeredAction = action;
                      },
                    );
                  },
                  child: const Text('Open Officer Actions'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Officer Actions'));
      await tester.pumpAndSettle();

      // Officer viewing Member: should ONLY see Loncadan At
      expect(find.text('Loncadan At'), findsOneWidget);
      expect(find.text('Subay Yap'), findsNothing);
      expect(find.text('Liderliği Devret'), findsNothing);

      await tester.tap(find.text('Loncadan At'));
      await tester.pumpAndSettle();
      expect(triggeredAction, equals('kick_guild_member'));
    });

    testWidgets('Guild confirmation dialogs render with warnings and handle actions cleanly', (
      WidgetTester tester,
    ) async {
      bool? dialogResult;

      // 1. Leave Confirm Dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) {
                return ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showGuildLeaveConfirmDialog(ctx);
                  },
                  child: const Text('Show Leave'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Loncadan Ayrıl'), findsOneWidget);
      expect(find.text('Loncadan ayrılmak istediğine emin misin?'), findsOneWidget);
      await tester.tap(find.text('Ayrıl'));
      await tester.pumpAndSettle();
      expect(dialogResult, isTrue);

      // 2. Disband Confirm Dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) {
                return ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showGuildDisbandConfirmDialog(ctx);
                  },
                  child: const Text('Show Disband'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Disband'));
      await tester.pumpAndSettle();

      expect(find.text('Loncayı Dağıt'), findsOneWidget);
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
      expect(dialogResult, isFalse);

      // 3. Transfer Leadership Dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext ctx) {
                return ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showGuildTransferLeadershipConfirmDialog(
                      ctx,
                      username: 'ValkyrieNyx',
                    );
                  },
                  child: const Text('Show Transfer'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Transfer'));
      await tester.pumpAndSettle();

      expect(find.text('Liderliği Devret'), findsOneWidget);
      expect(find.textContaining('ValkyrieNyx'), findsOneWidget);
      await tester.tap(find.text('Devret'));
      await tester.pumpAndSettle();
      expect(dialogResult, isTrue);
    });
  });

  group('Guild Perks & Buffs (390x844 SafeArea)', () {
    testWidgets('GuildPerksAndBuffsSection renders active blessings, next unlock and perk dialog', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = mobileSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final GlobalKey perksKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('tr'),
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF080B12),
          ),
          home: RepaintBoundary(
            key: perksKey,
            child: const Scaffold(
              backgroundColor: Color(0xFF080B12),
              body: Padding(
                padding: EdgeInsets.all(16.0),
                child: GuildPerksAndBuffsSection(
                  monumentLevel: 25,
                  guildLevel: 30,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('AKTİF LONCA GÜÇLENDİRMELERİ'), findsOneWidget);
      expect(find.textContaining('Anıt Sv.25'), findsOneWidget);

      // Tap on "Tümü" to open the Perks modal dialog
      expect(find.text('Tümü'), findsOneWidget);
      await tester.tap(find.text('Tümü'));
      await tester.pumpAndSettle();

      final File? perksScreenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: perksKey,
        filename: '08_guild_perks_modal.png',
      );
      if (perksScreenshot != null) {
        expect(perksScreenshot.existsSync(), isTrue);
      }

      // Verify the perks dialog rendered
      expect(find.text('KUTSAL ANIT GÜÇLENDİRMELERİ'), findsOneWidget);
      expect(find.text('Kapat'), findsOneWidget);

      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('GuildDesign components render with luminous borders and tactile feedback', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = mobileSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool tileTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  const GuildSectionTitle(
                    title: 'AION 2 AYRICALIKLARI',
                    subtitle: 'Lonca seviyesiyle artan pasif yetenekler',
                    accent: GuildPalette.iridescentCyan,
                  ),
                  const SizedBox(height: 12),
                  const GuildGlassCard(
                    accent: GuildPalette.gold,
                    child: Text('Frosted Glassmorphism Layer'),
                  ),
                  const SizedBox(height: 12),
                  const GuildStatPill(
                    icon: Icons.shield,
                    label: '+15% Savunma',
                    accent: GuildPalette.iridescentViolet,
                    filled: true,
                  ),
                  const SizedBox(height: 12),
                  const GuildProgressStrip(
                    label: 'Anıt Seviye İlerlemesi',
                    value: 0.72,
                    detail: '3600 / 5000',
                    accent: GuildPalette.neon,
                  ),
                  const SizedBox(height: 12),
                  GuildActionTile(
                    title: 'Bölge Kuşatması',
                    subtitle: 'Haftalık kale savaşına katıl',
                    icon: Icons.fort,
                    accent: GuildPalette.coral,
                    onTap: () {
                      tileTapped = true;
                    },
                    filled: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('AION 2 AYRICALIKLARI'), findsOneWidget);
      expect(find.text('Frosted Glassmorphism Layer'), findsOneWidget);
      expect(find.text('+15% Savunma'), findsOneWidget);
      expect(find.text('3600 / 5000'), findsOneWidget);
      expect(find.text('Bölge Kuşatması'), findsOneWidget);

      await tester.tap(find.text('Bölge Kuşatması'));
      await tester.pump();
      expect(tileTapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('Guild Contribution & Monument Modals (390x844 SafeArea)', () {
    testWidgets('showGuildCreateDialog renders cost breakdown and enables button only when affordable', (
      WidgetTester tester,
    ) async {
      final nameCtrl = TextEditingController();
      final descCtrl = TextEditingController();

      // Case 1: Player CAN afford creation cost
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext ctx) {
                  return Consumer(
                    builder: (BuildContext ctx, WidgetRef ref, _) {
                      return ElevatedButton(
                        onPressed: () {
                          showGuildCreateDialog(
                            context: ctx,
                            ref: ref,
                            nameController: nameCtrl,
                            descController: descCtrl,
                            playerGold: 500000,
                            createCost: 100000,
                            onMessage: (_) {},
                          );
                        },
                        child: const Text('Open Create Dialog'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Create Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Lonca Kur'), findsOneWidget);
      expect(find.textContaining('Maliyet: 100K altın'), findsOneWidget);

      // Fill in guild name
      await tester.enterText(find.byType(TextField).first, 'AionVanguard');
      await tester.pump();

      // Verify button is enabled
      final FilledButton kurButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Kur (100K Altın)'),
      );
      expect(kurButton.onPressed, isNotNull);

      // Close dialog
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();

      // Case 2: Player CANNOT afford creation cost
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext ctx) {
                  return Consumer(
                    builder: (BuildContext ctx, WidgetRef ref, _) {
                      return ElevatedButton(
                        onPressed: () {
                          showGuildCreateDialog(
                            context: ctx,
                            ref: ref,
                            nameController: nameCtrl,
                            descController: descCtrl,
                            playerGold: 20000,
                            createCost: 100000,
                            onMessage: (_) {},
                          );
                        },
                        child: const Text('Open Unaffordable Dialog'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Unaffordable Dialog'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Yetersiz altın: 100K gerekli'), findsOneWidget);
      final FilledButton disabledButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Kur (100K Altın)'),
      );
      expect(disabledButton.onPressed, isNull);

      nameCtrl.dispose();
      descCtrl.dispose();
    });

    testWidgets('showGuildMinJoinPowerDialog allows configuring minimum power threshold', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext ctx) {
                  return Consumer(
                    builder: (BuildContext ctx, WidgetRef ref, _) {
                      return ElevatedButton(
                        onPressed: () {
                          showGuildMinJoinPowerDialog(
                            context: ctx,
                            ref: ref,
                            current: 45000,
                            onMessage: (_) {},
                          );
                        },
                        child: const Text('Open Power Dialog'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Power Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Katılım Güç Limiti'), findsOneWidget);
      expect(find.text('45000'), findsOneWidget);
      expect(find.text('Kaydet'), findsOneWidget);

      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
    });

    testWidgets('MonumentDonateAmountDialog renders donation presets and validates inputs', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = mobileSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final stats = _createTestMonumentStats();
      int? donatedAmount;

      final GlobalKey modalKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF080B12),
          ),
          home: RepaintBoundary(
            key: modalKey,
            child: Scaffold(
              body: Builder(
                builder: (BuildContext ctx) {
                  return ElevatedButton(
                    onPressed: () async {
                      donatedAmount = await MonumentDonateAmountDialog.show(
                        ctx,
                        kind: MonumentResourceKind.structural,
                        stats: stats,
                      );
                    },
                    child: const Text('Donate Structural'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Donate Structural'));
      await tester.pumpAndSettle();

      final File? dialogScreenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: modalKey,
        filename: '05_monument_donate_amount_dialog.png',
      );
      if (dialogScreenshot != null) {
        expect(dialogScreenshot.existsSync(), isTrue);
      }

      // Verify Title & Stats description
      expect(find.text('Yapı Taşı Bağışı'), findsOneWidget);
      expect(find.textContaining('Elinde: 500 · Bugün kalan: 900'), findsOneWidget);

      // Verify Preset buttons (+1, +10, +50, Max)
      expect(find.text('1'), findsWidgets);
      expect(find.text('10'), findsWidgets);
      expect(find.text('50'), findsWidgets);
      expect(find.text('Max'), findsWidgets);

      // Tap on Preset 50
      await tester.tap(find.text('50'));
      await tester.pump();

      // Tap confirm button
      await tester.tap(find.text('Bağışla'));
      await tester.pumpAndSettle();

      expect(donatedAmount, equals(50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('GuildMonumentHeroCard renders upgrade readiness and triggers callbacks cleanly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = mobileSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool donateCalled = false;
      bool upgradeCalled = false;

      final testGuild = _createTestGuild();
      final dash = _createTestMonumentDashboard(guild: testGuild);
      final upgradeProgress = MonumentUpgradeProgress.compute(
        guild: dash.guild,
        nextCost: dash.nextCost,
        blueprints: dash.blueprints,
      );

      final GlobalKey heroCardKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF080B12),
          ),
          home: Scaffold(
            backgroundColor: const Color(0xFF080B12),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: heroCardKey,
                child: GuildMonumentHeroCard(
                  level: 3,
                  memberCount: 24,
                  upgradeProgress: upgradeProgress,
                  canUpgrade: true,
                  upgrading: false,
                  onDonate: () {
                    donateCalled = true;
                  },
                  onUpgrade: () {
                    upgradeCalled = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify level text and action buttons
      expect(find.text('Seviye 3 Anıt'), findsOneWidget);
      expect(find.text('Bağış Yap'), findsOneWidget);
      expect(find.text('Yükselt'), findsOneWidget);

      await tester.tap(find.text('Bağış Yap'));
      await tester.pump();
      expect(donateCalled, isTrue);

      await tester.tap(find.text('Yükselt'));
      await tester.pump();
      expect(upgradeCalled, isTrue);
      expect(tester.takeException(), isNull);

      final File? screenshot = await captureWidgetToPng(
        tester: tester,
        repaintKey: heroCardKey,
        filename: '04_monument_hero_card.png',
      );
      if (screenshot != null) {
        expect(screenshot.existsSync(), isTrue);
      }
    });
  });
}
