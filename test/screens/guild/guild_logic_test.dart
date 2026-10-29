import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/guild_model.dart';
import 'package:gkk_flutter/models/guild_vault_model.dart';
import 'package:gkk_flutter/repositories/guild_monument_repository.dart';
import 'package:gkk_flutter/screens/chat/chat_models.dart';
import 'package:gkk_flutter/screens/guild/guild_helpers.dart';

void main() {
  group('1. Guild Role Resolution and Hierarchy', () {
    test('resolveMyGuildRole prioritizes guild membership over profile role', () {
      const guild = GuildData(
        guildId: 'g-1',
        name: 'Aion Vanguard',
        level: 5,
        leaderId: 'leader-1',
        memberCount: 2,
        maxMembers: 50,
        totalPower: 12000,
        monumentLevel: 10,
        monumentStructural: 500,
        monumentMystical: 200,
        monumentCritical: 50,
        monumentGoldPool: 1000000,
        members: [
          GuildMemberData(
            playerId: 'player-me',
            username: 'ShadowKnight',
            level: 45,
            role: GuildRole.officer,
            power: 6000,
          ),
          GuildMemberData(
            playerId: 'leader-1',
            username: 'GuildMaster',
            level: 50,
            role: GuildRole.leader,
            power: 6000,
          ),
        ],
      );

      // Even if player profile says 'member', membership list says 'officer'
      final resolvedRole = resolveMyGuildRole(
        guild: guild,
        playerId: 'player-me',
        profileGuildRole: 'member',
      );

      expect(resolvedRole, GuildRole.officer);
    });

    test('resolveMyGuildRole falls back to profileGuildRole when member not in list', () {
      const guild = GuildData(
        guildId: 'g-1',
        name: 'Aion Vanguard',
        level: 5,
        leaderId: 'leader-1',
        memberCount: 1,
        maxMembers: 50,
        totalPower: 6000,
        monumentLevel: 10,
        monumentStructural: 500,
        monumentMystical: 200,
        monumentCritical: 50,
        monumentGoldPool: 1000000,
        members: [
          GuildMemberData(
            playerId: 'other-player',
            username: 'Other',
            level: 30,
            role: GuildRole.leader,
            power: 6000,
          ),
        ],
      );

      final roleFromProfile = resolveMyGuildRole(
        guild: guild,
        playerId: 'player-me',
        profileGuildRole: 'leader',
      );
      expect(roleFromProfile, GuildRole.leader);

      final roleCommander = resolveMyGuildRole(
        guild: guild,
        playerId: 'player-me',
        profileGuildRole: 'commander',
      );
      expect(roleCommander, GuildRole.officer);

      final roleDefault = resolveMyGuildRole(
        guild: guild,
        playerId: 'player-me',
        profileGuildRole: null,
      );
      expect(roleDefault, GuildRole.member);
    });

    test('guildRoleLabel and guildRoleEmoji map correctly', () {
      expect(guildRoleLabel(GuildRole.leader), 'Lider');
      expect(guildRoleLabel(GuildRole.officer), 'Subay');
      expect(guildRoleLabel(GuildRole.member), 'Üye');

      expect(guildRoleEmoji(GuildRole.leader), '👑');
      expect(guildRoleEmoji(GuildRole.officer), '⭐');
      expect(guildRoleEmoji(GuildRole.member), '🛡️');
    });

    test('guildRoleSortOrder places leader first, officer second, member third', () {
      expect(guildRoleSortOrder(GuildRole.leader), 0);
      expect(guildRoleSortOrder(GuildRole.officer), 1);
      expect(guildRoleSortOrder(GuildRole.member), 2);

      final members = <GuildMemberData>[
        const GuildMemberData(
          playerId: 'p3',
          username: 'Member3',
          level: 20,
          role: GuildRole.member,
          power: 1000,
        ),
        const GuildMemberData(
          playerId: 'p1',
          username: 'Leader1',
          level: 50,
          role: GuildRole.leader,
          power: 5000,
        ),
        const GuildMemberData(
          playerId: 'p2',
          username: 'Officer2',
          level: 40,
          role: GuildRole.officer,
          power: 3000,
        ),
      ];

      members.sort((a, b) => guildRoleSortOrder(a.role).compareTo(guildRoleSortOrder(b.role)));

      expect(members[0].role, GuildRole.leader);
      expect(members[1].role, GuildRole.officer);
      expect(members[2].role, GuildRole.member);
    });
  });

  group('2. Member Action Permission Matrix', () {
    bool canPromote({required GuildRole myRole, required GuildRole targetRole, required bool isSelf}) {
      if (isSelf || myRole == GuildRole.member) return false;
      return myRole == GuildRole.leader && targetRole == GuildRole.member;
    }

    bool canDemote({required GuildRole myRole, required GuildRole targetRole, required bool isSelf}) {
      if (isSelf || myRole == GuildRole.member) return false;
      return myRole == GuildRole.leader && targetRole == GuildRole.officer;
    }

    bool canTransfer({required GuildRole myRole, required bool isSelf}) {
      if (isSelf || myRole == GuildRole.member) return false;
      return myRole == GuildRole.leader;
    }

    bool canKick({required GuildRole myRole, required GuildRole targetRole, required bool isSelf}) {
      if (isSelf || myRole == GuildRole.member) return false;
      return myRole == GuildRole.leader || (myRole == GuildRole.officer && targetRole == GuildRole.member);
    }

    test('Self-actions are universally prohibited', () {
      expect(canPromote(myRole: GuildRole.leader, targetRole: GuildRole.leader, isSelf: true), isFalse);
      expect(canDemote(myRole: GuildRole.leader, targetRole: GuildRole.officer, isSelf: true), isFalse);
      expect(canTransfer(myRole: GuildRole.leader, isSelf: true), isFalse);
      expect(canKick(myRole: GuildRole.leader, targetRole: GuildRole.leader, isSelf: true), isFalse);
    });

    test('Regular member has zero administrative actions', () {
      for (final targetRole in GuildRole.values) {
        expect(canPromote(myRole: GuildRole.member, targetRole: targetRole, isSelf: false), isFalse);
        expect(canDemote(myRole: GuildRole.member, targetRole: targetRole, isSelf: false), isFalse);
        expect(canTransfer(myRole: GuildRole.member, isSelf: false), isFalse);
        expect(canKick(myRole: GuildRole.member, targetRole: targetRole, isSelf: false), isFalse);
      }
    });

    test('Officer permissions are strictly restricted to kicking regular members', () {
      expect(canPromote(myRole: GuildRole.officer, targetRole: GuildRole.member, isSelf: false), isFalse);
      expect(canDemote(myRole: GuildRole.officer, targetRole: GuildRole.officer, isSelf: false), isFalse);
      expect(canTransfer(myRole: GuildRole.officer, isSelf: false), isFalse);

      expect(canKick(myRole: GuildRole.officer, targetRole: GuildRole.member, isSelf: false), isTrue);

      expect(canKick(myRole: GuildRole.officer, targetRole: GuildRole.officer, isSelf: false), isFalse);
      expect(canKick(myRole: GuildRole.officer, targetRole: GuildRole.leader, isSelf: false), isFalse);
    });

    test('Leader possesses full administrative governance', () {
      expect(canPromote(myRole: GuildRole.leader, targetRole: GuildRole.member, isSelf: false), isTrue);
      expect(canPromote(myRole: GuildRole.leader, targetRole: GuildRole.officer, isSelf: false), isFalse);

      expect(canDemote(myRole: GuildRole.leader, targetRole: GuildRole.officer, isSelf: false), isTrue);
      expect(canDemote(myRole: GuildRole.leader, targetRole: GuildRole.member, isSelf: false), isFalse);

      expect(canTransfer(myRole: GuildRole.leader, isSelf: false), isTrue);

      expect(canKick(myRole: GuildRole.leader, targetRole: GuildRole.member, isSelf: false), isTrue);
      expect(canKick(myRole: GuildRole.leader, targetRole: GuildRole.officer, isSelf: false), isTrue);
    });
  });

  group('3. Guild Economy and Monument Contributions', () {
    test('monumentDonateCap clamps correctly across all boundary conditions', () {
      expect(
        monumentDonateCap(owned: 100, donatedToday: 10, dailyMax: 50, requested: 20),
        20,
      );

      expect(
        monumentDonateCap(owned: 15, donatedToday: 0, dailyMax: 50, requested: 30),
        15,
      );

      expect(
        monumentDonateCap(owned: 100, donatedToday: 40, dailyMax: 50, requested: 25),
        10,
      );

      expect(
        monumentDonateCap(owned: 100, donatedToday: 50, dailyMax: 50, requested: 10),
        0,
      );

      expect(
        monumentDonateCap(owned: 0, donatedToday: 0, dailyMax: 50, requested: 10),
        0,
      );

      expect(
        monumentDonateCap(owned: 100, donatedToday: 0, dailyMax: 50, requested: 0),
        0,
      );
      expect(
        monumentDonateCap(owned: 100, donatedToday: 0, dailyMax: 50, requested: -5),
        0,
      );

      expect(
        monumentDonateCap(owned: 100, donatedToday: 60, dailyMax: 50, requested: 10),
        0,
      );
    });

    test('Monument daily limits match specifications', () {
      expect(MonumentDailyLimits.structural, 500);
      expect(MonumentDailyLimits.mystical, 200);
      expect(MonumentDailyLimits.critical, 50);
      expect(MonumentDailyLimits.gold, 10000000);
    });

    test('MonumentResourceKind metadata aligns with game definitions', () {
      expect(MonumentResourceKind.structural.shortLabel, 'Yapısal');
      expect(MonumentResourceKind.mystical.shortLabel, 'Mistik');
      expect(MonumentResourceKind.critical.shortLabel, 'Kritik');
      expect(MonumentResourceKind.gold.shortLabel, 'Altın');

      expect(MonumentResourceKind.structural.itemId, MonumentResourceIds.structural);
      expect(MonumentResourceKind.mystical.itemId, MonumentResourceIds.mystical);
      expect(MonumentResourceKind.critical.itemId, MonumentResourceIds.critical);
      expect(MonumentResourceKind.gold.itemId, isNull);

      expect(MonumentResourceKind.structural.dailyMax, 500);
      expect(MonumentResourceKind.mystical.dailyMax, 200);
      expect(MonumentResourceKind.critical.dailyMax, 50);
      expect(MonumentResourceKind.gold.dailyMax, 10000000);
    });

    test('MonumentMyStats calculates dailyLeft and maxDonatable accurately', () {
      const stats = MonumentMyStats(
        totals: MonumentResourceSnapshot(structural: 1000, mystical: 400, critical: 100, gold: 5000000),
        today: MonumentResourceSnapshot(structural: 300, mystical: 200, critical: 10, gold: 2000000),
        wallet: MonumentResourceSnapshot(structural: 150, mystical: 50, critical: 60, gold: 15000000),
        dailyLimits: MonumentResourceSnapshot(structural: 500, mystical: 200, critical: 50, gold: 10000000),
        contributionScore: 1250,
      );

      expect(stats.dailyLeft(MonumentResourceKind.structural), 200);
      expect(stats.maxDonatable(MonumentResourceKind.structural), 150);

      expect(stats.dailyLeft(MonumentResourceKind.mystical), 0);
      expect(stats.maxDonatable(MonumentResourceKind.mystical), 0);

      expect(stats.dailyLeft(MonumentResourceKind.critical), 40);
      expect(stats.maxDonatable(MonumentResourceKind.critical), 40);

      expect(stats.dailyLeft(MonumentResourceKind.gold), 8000000);
      expect(stats.maxDonatable(MonumentResourceKind.gold), 8000000);
    });

    test('Guild creation cost default is 10M gold', () {
      expect(GuildConfig.defaults.createCostGold, 10000000);
      expect(GuildEconomyConstants.createCostGold, 10000000);
    });
  });

  group('4. Perk Unlocking and Monument Progression', () {
    test('kMonumentBonuses contains exactly 20 ascending milestones', () {
      expect(kMonumentBonuses.length, 20);

      for (int i = 0; i < kMonumentBonuses.length - 1; i++) {
        expect(
          kMonumentBonuses[i].$1 < kMonumentBonuses[i + 1].$1,
          isTrue,
          reason: 'Bonuses must be sorted in strictly ascending order',
        );
      }

      expect(kMonumentBonuses.first.$1, 5);
      expect(kMonumentBonuses.first.$2, 'Lonca XP Bonusu');
      expect(kMonumentBonuses.first.$3, '+%5 XP');

      expect(kMonumentBonuses.last.$1, 100);
      expect(kMonumentBonuses.last.$2, 'ETERNAL');
      expect(kMonumentBonuses.last.$3, '+20 Enerji, +%5 Stat, Aura');
    });

    test('Monument perk unlocking behaves correctly at various levels', () {
      int countUnlockedPerks(int monumentLevel) {
        return kMonumentBonuses.where((b) => monumentLevel >= b.$1).length;
      }

      expect(countUnlockedPerks(0), 0);
      expect(countUnlockedPerks(4), 0);
      expect(countUnlockedPerks(5), 1);
      expect(countUnlockedPerks(9), 1);
      expect(countUnlockedPerks(10), 2);
      expect(countUnlockedPerks(50), 10);
      expect(countUnlockedPerks(75), 15);
      expect(countUnlockedPerks(99), 19);
      expect(countUnlockedPerks(100), 20);
      expect(countUnlockedPerks(150), 20);
    });

    test('canUpgradeMonument restricts execution to leader, officer, commander', () {
      expect(canUpgradeMonument('leader'), isTrue);
      expect(canUpgradeMonument('officer'), isTrue);
      expect(canUpgradeMonument('commander'), isTrue);
      expect(canUpgradeMonument('member'), isFalse);
      expect(canUpgradeMonument(''), isFalse);
      expect(canUpgradeMonument(null), isFalse);
      expect(canUpgradeMonument('recruit'), isFalse);
    });

    test('MonumentUpgradeProgress.compute handles partial and complete requirements', () {
      const guild = MonumentGuildSnapshot(
        id: 'g1',
        name: 'Vanguard',
        monumentLevel: 4,
        structural: 200,
        mystical: 100,
        critical: 20,
        goldPool: 500000,
      );

      final progressIncomplete = MonumentUpgradeProgress.compute(
        guild: guild,
        nextCost: <String, dynamic>{
          'next_level': 5,
          'structural': 400,
          'mystical': 100,
          'critical': 40,
          'gold': 500000,
        },
        blueprints: const <MonumentBlueprint>[],
      );

      expect(progressIncomplete, isNotNull);
      expect(progressIncomplete!.nextLevel, 5);
      expect(progressIncomplete.overallProgress, 0.5);
      expect(progressIncomplete.isReady, isFalse);

      final progressBlueprintBlocked = MonumentUpgradeProgress.compute(
        guild: guild,
        nextCost: <String, dynamic>{
          'next_level': 5,
          'structural': 200,
          'mystical': 100,
          'critical': 20,
          'gold': 500000,
          'blueprint_type': 'monument_tier_1',
        },
        blueprints: const <MonumentBlueprint>[
          MonumentBlueprint(
            blueprintType: 'monument_tier_1',
            fragments: 3,
            fragmentsRequired: 5,
            isComplete: false,
          ),
        ],
      );

      expect(progressBlueprintBlocked!.overallProgress, 0.0);
      expect(progressBlueprintBlocked.blueprintRequired, isTrue);
      expect(progressBlueprintBlocked.blueprintComplete, isFalse);
      expect(progressBlueprintBlocked.isReady, isFalse);

      final progressReady = MonumentUpgradeProgress.compute(
        guild: guild,
        nextCost: <String, dynamic>{
          'next_level': 5,
          'structural': 200,
          'mystical': 100,
          'critical': 20,
          'gold': 500000,
          'blueprint_type': 'monument_tier_1',
        },
        blueprints: const <MonumentBlueprint>[
          MonumentBlueprint(
            blueprintType: 'monument_tier_1',
            fragments: 5,
            fragmentsRequired: 5,
            isComplete: true,
          ),
        ],
      );

      expect(progressReady!.overallProgress, 1.0);
      expect(progressReady.blueprintComplete, isTrue);
      expect(progressReady.isReady, isTrue);
    });

    test('MonumentUpgradeProgress.compute returns null for max level or error', () {
      const guild = MonumentGuildSnapshot(
        id: 'g1',
        name: 'Vanguard',
        monumentLevel: 100,
        structural: 1000,
        mystical: 1000,
        critical: 1000,
        goldPool: 10000000,
      );

      expect(
        MonumentUpgradeProgress.compute(
          guild: guild,
          nextCost: <String, dynamic>{'max_level': true},
          blueprints: const <MonumentBlueprint>[],
        ),
        isNull,
      );

      expect(
        MonumentUpgradeProgress.compute(
          guild: guild,
          nextCost: <String, dynamic>{'error': 'Max level reached'},
          blueprints: const <MonumentBlueprint>[],
        ),
        isNull,
      );

      expect(
        MonumentUpgradeProgress.compute(
          guild: guild,
          nextCost: null,
          blueprints: const <MonumentBlueprint>[],
        ),
        isNull,
      );
    });
  });

  group('5. Guild Vault Logic and Balance Management', () {
    test('GuildVaultState parses JSON payload and sets permissions', () {
      final state = GuildVaultState.fromJson(<String, dynamic>{
        'vault_gold': 5000000,
        'vault_gold_pending': 250000,
        'monument_gold_pool': 1000000,
        'is_leader': true,
        'is_officer': false,
        'vault_auto_payout_weekly': true,
        'vault_tax_rate': 0.08,
        'guild_role': 'leader',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'v-item-1',
            'item_id': 'rare_crystal',
            'item_name': 'Mistik Kristal',
            'quantity': 5,
            'rarity': 'epic',
          },
        ],
        'ledger': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'led-1',
            'action': 'deposit',
            'payload': <String, dynamic>{'gold': 50000},
          },
        ],
        'territories': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 't-1',
            'name': 'Gölge Vadisi',
            'trade_income': 12000,
          },
        ],
      });

      expect(state.hydrated, isTrue);
      expect(state.vaultGold, 5000000);
      expect(state.vaultGoldPending, 250000);
      expect(state.isLeader, isTrue);
      expect(state.canManage, isTrue);
      expect(state.vaultAutoPayoutWeekly, isTrue);
      expect(state.vaultTaxRate, 0.08);
      expect(state.items.length, 1);
      expect(state.items.first.itemName, 'Mistik Kristal');
      expect(state.ledger.length, 1);
      expect(state.territories.length, 1);
      expect(state.territories.first.tradeIncome, 12000);
    });

    test('GuildVault gold mutations preserve non-negative bounds', () {
      var state = const GuildVaultState(vaultGold: 100000, hydrated: true);

      final nextGold = (state.vaultGold - 30000).clamp(0, 1 << 62);
      state = state.copyWith(vaultGold: nextGold);
      expect(state.vaultGold, 70000);

      final overspend = (state.vaultGold - 150000).clamp(0, 1 << 62);
      state = state.copyWith(vaultGold: overspend);
      expect(state.vaultGold, 0);

      state = state.copyWith(vaultGold: 500000);
      expect(state.vaultGold, 500000);
    });
  });

  group('6. Chat Integration and Guild Channel Triggers', () {
    test('ChatChannel.guild has correct key, label and mapping', () {
      expect(ChatChannel.guild.key, 'guild');
      expect(ChatChannel.guild.label, 'Lonca');
      expect(ChatChannelX.fromKey('guild'), ChatChannel.guild);
      expect(ChatChannelX.fromKey('GUILD'), ChatChannel.guild);
      expect(ChatChannelX.fromKey('invalid_key'), ChatChannel.global);
    });

    test('ChatMessage parses guild channel and metadata correctly', () {
      final msg = ChatMessage.fromJson(<String, dynamic>{
        'id': 'msg-101',
        'channel': 'guild',
        'sender_user_id': 'p-1',
        'sender_name': 'CommanderAion',
        'content': 'Lonca savaşı için toplanıyoruz!',
        'created_at': '2026-10-28T21:00:00Z',
        'guild_id': 'g-1',
        'is_system': false,
      });

      expect(msg.channel, ChatChannel.guild);
      expect(msg.senderName, 'CommanderAion');
      expect(msg.content, 'Lonca savaşı için toplanıyoruz!');
      expect(msg.guildId, 'g-1');
      expect(msg.isSystem, isFalse);
    });
  });

  group('7. Formatting and Guild Helpers', () {
    test('formatGuildCompact formats correctly', () {
      expect(formatGuildCompact(0), '0');
      expect(formatGuildCompact(850), '850');
      expect(formatGuildCompact(1000), '1.0K');
      expect(formatGuildCompact(1500), '1.5K');
      expect(formatGuildCompact(99999), '100.0K');
      expect(formatGuildCompact(1000000), '1.0M');
      expect(formatGuildCompact(2500000), '2.5M');
    });

    test('formatGuildGold formats cleanly with integer fallback', () {
      expect(formatGuildGold(500), '500');
      expect(formatGuildGold(1000), '1K');
      expect(formatGuildGold(1500), '1.5K');
      expect(formatGuildGold(1000000), '1M');
      expect(formatGuildGold(2500000), '2.5M');
    });

    test('guildSizeMultiplier and guildSizeLabel return correct tiers', () {
      expect(guildSizeMultiplier(5), 0.35);
      expect(guildSizeLabel(5), 'Küçük Lonca (0.35x)');

      expect(guildSizeMultiplier(15), 0.55);
      expect(guildSizeLabel(15), 'Orta Lonca (0.55x)');

      expect(guildSizeMultiplier(25), 0.75);
      expect(guildSizeLabel(25), 'Büyük Lonca (0.75x)');

      expect(guildSizeMultiplier(35), 0.90);
      expect(guildSizeLabel(35), 'Çok Büyük Lonca (0.90x)');

      expect(guildSizeMultiplier(45), 1.00);
      expect(guildSizeLabel(45), 'Maksimum Lonca (1.00x)');
    });
  });
}
