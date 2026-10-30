import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gkk_flutter/models/auth_model.dart';
import 'package:gkk_flutter/models/daily_reward_model.dart';
import 'package:gkk_flutter/models/dungeon_model.dart';
import 'package:gkk_flutter/models/dungeon_siege_model.dart';
import 'package:gkk_flutter/models/guild_model.dart';
import 'package:gkk_flutter/models/guild_vault_model.dart';
import 'package:gkk_flutter/models/guild_war_model.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/market_model.dart';
import 'package:gkk_flutter/models/player_model.dart';
import 'package:gkk_flutter/models/pvp_model.dart';
import 'package:gkk_flutter/models/staff_model.dart';
import 'package:gkk_flutter/providers/auth_provider.dart';
import 'package:gkk_flutter/providers/box_opening_provider.dart';
import 'package:gkk_flutter/providers/comeback_summary_provider.dart';
import 'package:gkk_flutter/providers/crafting_provider.dart';
import 'package:gkk_flutter/providers/daily_reward_provider.dart';
import 'package:gkk_flutter/providers/dungeon_provider.dart';
import 'package:gkk_flutter/providers/dungeon_siege_provider.dart';
import 'package:gkk_flutter/providers/guild_provider.dart';
import 'package:gkk_flutter/providers/guild_vault_provider.dart';
import 'package:gkk_flutter/providers/guild_war_provider.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';
import 'package:gkk_flutter/providers/kingdom_market_blessing_provider.dart';
import 'package:gkk_flutter/providers/market_provider.dart';
import 'package:gkk_flutter/providers/player_badges_provider.dart';
import 'package:gkk_flutter/providers/player_inbox_provider.dart';
import 'package:gkk_flutter/providers/player_provider.dart';
import 'package:gkk_flutter/providers/pvp_invite_provider.dart';
import 'package:gkk_flutter/providers/pvp_provider.dart';
import 'package:gkk_flutter/providers/staff_provider.dart';

void main() {
  group('Fullstack Provider State & Transition Contracts', () {
    test('ProviderContainer initialization and default state contracts', () {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          pvpInviteProvider.overrideWith(() => _MockPvpInviteNotifier()),
          boxOpeningProvider.overrideWith(() => _MockBoxOpeningNotifier()),
          playerInboxProvider.overrideWith(() => _MockPlayerInboxNotifier()),
          playerBadgesProvider.overrideWith(() => _MockPlayerBadgesNotifier()),
          staffProvider.overrideWith(() => _MockStaffNotifier()),
          guildVaultProvider.overrideWith(() => _MockGuildVaultNotifier()),
          kingdomMarketBlessingProvider.overrideWith(() => _MockKingdomBlessingNotifier()),
          dailyRewardProvider.overrideWith(() => _MockDailyRewardNotifier()),
          comebackSummaryProvider.overrideWith(() => _MockComebackSummaryNotifier()),
        ],
      );
      addTearDown(container.dispose);

      // Verify Initial Provider State Contracts
      final PvpInviteState pvpInvite = container.read(pvpInviteProvider);
      expect(pvpInvite.activeInvites, isEmpty);

      final List<BoxOpening> boxOpening = container.read(boxOpeningProvider);
      expect(boxOpening, isEmpty);

      final List<PlayerInboxItem> inbox = container.read(playerInboxProvider);
      expect(inbox, isEmpty);

      final PlayerBadgesState badges = container.read(playerBadgesProvider);
      expect(badges.isLoading, isFalse);

      final StaffState staff = container.read(staffProvider);
      expect(staff.profile, equals(StaffProfile.none));

      final GuildVaultState vault = container.read(guildVaultProvider);
      expect(vault.vaultGold, equals(1000000));
      expect(vault.hydrated, isTrue);

      final DailyRewardState daily = container.read(dailyRewardProvider);
      expect(daily.autoPromptedThisSession, isTrue);
    });

    test('PlayerState and InventoryState immutability contracts', () {
      const PlayerState initialPlayer = PlayerState(status: PlayerStatus.initial);
      expect(initialPlayer.status, equals(PlayerStatus.initial));
      expect(initialPlayer.profile, isNull);

      const InventoryState initialInv = InventoryState(
        status: InventoryStatus.initial,
        items: <InventoryItem>[],
        equippedItems: <String, InventoryItem?>{},
      );
      expect(initialInv.items, isEmpty);
      expect(initialInv.status, equals(InventoryStatus.initial));
    });

    test('MarketState and CraftingState contracts', () {
      const MarketState market = MarketState(
        status: MarketStatus.ready,
        tickers: <MarketTicker>[
          MarketTicker(
            itemId: 'mat_scale',
            itemName: 'Ejder Pulu',
            itemType: 'material',
            rarity: 'mythic',
            isStackable: true,
            lowestPrice: 5000,
            volume: 120,
            priceChange: 200,
            maxAvailableQty: 40,
          ),
        ],
        myOrders: <MarketOrder>[],
        tickersLoaded: true,
        myOrdersLoaded: true,
      );

      expect(market.status, equals(MarketStatus.ready));
      expect(market.tickers.length, equals(1));
      expect(market.tickers.first.itemId, equals('mat_scale'));
      expect(market.tickersLoaded, isTrue);
    });

    test('GuildState and GuildWarState contracts', () {
      const GuildState guildState = GuildState(
        guild: GuildData(
          guildId: 'guild_01',
          name: 'Kadim Daeva',
          level: 5,
          leaderId: 'usr_01',
          memberCount: 15,
          maxMembers: 50,
          totalPower: 1500000,
          monumentLevel: 3,
          monumentStructural: 100,
          monumentMystical: 100,
          monumentCritical: 100,
          monumentGoldPool: 1000000,
        ),
        isLoading: false,
      );

      expect(guildState.guild?.name, equals('Kadim Daeva'));
      expect(guildState.guild?.level, equals(5));

      const GuildWarState warState = GuildWarState(
        season: GuildWarSeason(season: 1, week: 2),
        tournaments: <GuildWarTournament>[],
        territories: <TerritoryData>[],
        rankings: <GuildWarRanking>[],
        attackLogs: <GuildWarAttackLog>[],
        isLoading: false,
      );

      expect(warState.season.season, equals(1));
      expect(warState.season.week, equals(2));
      expect(warState.isLoading, isFalse);
    });
  });
}

class _MockPvpInviteNotifier extends PvpInviteNotifier {
  @override
  PvpInviteState build() => const PvpInviteState();
}

class _MockBoxOpeningNotifier extends BoxOpeningNotifier {
  @override
  List<BoxOpening> build() => const <BoxOpening>[];
}

class _MockPlayerInboxNotifier extends PlayerInboxNotifier {
  @override
  List<PlayerInboxItem> build() => const <PlayerInboxItem>[];
}

class _MockPlayerBadgesNotifier extends PlayerBadgesNotifier {
  @override
  PlayerBadgesState build() => const PlayerBadgesState();
}

class _MockStaffNotifier extends StaffNotifier {
  @override
  StaffState build() => const StaffState(profile: StaffProfile.none);
}

class _MockGuildVaultNotifier extends GuildVaultNotifier {
  @override
  GuildVaultState build() => const GuildVaultState(
        vaultGold: 1000000,
        hydrated: true,
        canCollect: false,
      );
}

class _MockKingdomBlessingNotifier extends KingdomMarketBlessingNotifier {
  @override
  KingdomMarketBlessingStatus build() => KingdomMarketBlessingStatus.inactive();
}

class _MockDailyRewardNotifier extends DailyRewardNotifier {
  @override
  DailyRewardState build() =>
      const DailyRewardState(autoPromptedThisSession: true);
}

class _MockComebackSummaryNotifier extends ComebackSummaryNotifier {
  @override
  ComebackSummaryState build() =>
      const ComebackSummaryState(shownThisSession: true);
}
