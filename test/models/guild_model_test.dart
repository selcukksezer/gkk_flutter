import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/guild_model.dart';

void main() {
  group('GuildData', () {
    test('fromJson maps guild_id from id fallback', () {
      final guild = GuildData.fromJson(<String, dynamic>{
        'id': 'abc-123',
        'name': 'Test Lonca',
        'member_count': 3,
      });

      expect(guild.guildId, 'abc-123');
      expect(guild.isValid, isTrue);
    });

    test('tryFromJson returns null for success false', () {
      final guild = GuildData.tryFromJson(<String, dynamic>{
        'success': false,
        'error': 'Herhangi bir loncada degilsiniz',
      });

      expect(guild, isNull);
    });

    test('tryFromJson returns null for empty guild id', () {
      final guild = GuildData.tryFromJson(<String, dynamic>{
        'success': true,
        'name': '',
      });

      expect(guild, isNull);
    });

    test('parses commander role as officer', () {
      final member = GuildMemberData.fromJson(<String, dynamic>{
        'player_id': 'p1',
        'username': 'hero',
        'level': 10,
        'role': 'commander',
        'power': 100,
      });

      expect(member.role, GuildRole.officer);
    });
  });

  group('GuildRpcResult', () {
    test('fromResponse handles no-guild error payload', () {
      final result = GuildRpcResult.fromResponse(<String, dynamic>{
        'success': false,
        'error': 'Herhangi bir loncada degilsiniz',
      });

      expect(result.success, isFalse);
      expect(result.guild, isNull);
      expect(result.error, isNotEmpty);
    });

    test('fromResponse handles leave success without guild body', () {
      final result = GuildRpcResult.fromResponse(<String, dynamic>{
        'success': true,
      });

      expect(result.success, isTrue);
      expect(result.guild, isNull);
    });

    test('fromResponse parses full guild payload', () {
      final result = GuildRpcResult.fromResponse(<String, dynamic>{
        'success': true,
        'guild_id': 'g1',
        'name': 'Lonca A',
        'member_count': 2,
        'members': <Map<String, dynamic>>[],
      });

      expect(result.success, isTrue);
      expect(result.guild?.name, 'Lonca A');
    });

    test('fromResponse handles member action failure payload', () {
      final result = GuildRpcResult.fromResponse(<String, dynamic>{
        'success': false,
        'error': 'Sadece lider yukseltebilir',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('lider'));
    });
  });

  group('guildSizeMultiplier', () {
    test('returns PLAN_10 size tiers', () {
      expect(guildSizeMultiplier(5), 0.35);
      expect(guildSizeMultiplier(15), 0.55);
      expect(guildSizeMultiplier(25), 0.75);
      expect(guildSizeMultiplier(35), 0.90);
      expect(guildSizeMultiplier(45), 1.00);
    });
  });

  group('canUpgradeMonument', () {
    test('allows leader officer commander', () {
      expect(canUpgradeMonument('leader'), isTrue);
      expect(canUpgradeMonument('officer'), isTrue);
      expect(canUpgradeMonument('commander'), isTrue);
      expect(canUpgradeMonument('member'), isFalse);
    });
  });
}
