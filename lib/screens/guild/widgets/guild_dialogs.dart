import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/guild_model.dart';
import '../../../providers/guild_provider.dart';
import '../guild_helpers.dart';

Future<bool?> showGuildLeaveConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: const Color(0xFF171E2C),
      title: const Text('Loncadan Ayrıl'),
      content: const Text('Loncadan ayrılmak istediğine emin misin?'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Ayrıl'),
        ),
      ],
    ),
  );
}

Future<bool?> showGuildDisbandConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: const Color(0xFF171E2C),
      title: const Text('Loncayı Dağıt'),
      content: const Text(
        'Loncayı dağıtmak tüm üyeleri çıkarır ve anıt ilerlemesini siler. Emin misin?',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Dağıt'),
        ),
      ],
    ),
  );
}

Future<void> showGuildCreateDialog({
  required BuildContext context,
  required WidgetRef ref,
  required TextEditingController nameController,
  required TextEditingController descController,
  required int playerGold,
  required int createCost,
  required void Function(String message) onMessage,
}) async {
  final bool canAfford = playerGold >= createCost;
  final String formattedCost = _formatCreateCost(createCost);

  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: const Color(0xFF171E2C),
      title: const Text('Lonca Kur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: canAfford ? const Color(0x334B6FFF) : Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: canAfford ? const Color(0xFF4B6FFF) : Colors.red.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              canAfford
                  ? 'Maliyet: $formattedCost altın (bakiyen: ${_formatCreateCost(playerGold)})'
                  : 'Yetersiz altın: $formattedCost gerekli (bakiyen: ${_formatCreateCost(playerGold)})',
              style: TextStyle(
                fontSize: 12,
                color: canAfford ? const Color(0xFF8BAEFF) : Colors.redAccent,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Lonca Adı'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descController,
            decoration: const InputDecoration(labelText: 'Açıklama'),
            maxLines: 2,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: canAfford
              ? () async {
                  final String name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.of(ctx).pop();
                  final bool ok = await ref.read(guildProvider.notifier).createGuild(
                        name: name,
                        description: descController.text.trim(),
                      );
                  if (!ok) {
                    final String? err = ref.read(guildProvider).error;
                    if (err != null) onMessage(err);
                    return;
                  }
                  onMessage('Lonca kuruldu!');
                }
              : null,
          child: Text('Kur ($formattedCost Altın)'),
        ),
      ],
    ),
  );
}

String _formatCreateCost(int gold) {
  if (gold >= 1000000) {
    return '${(gold / 1000000).toStringAsFixed(gold % 1000000 == 0 ? 0 : 1)}M';
  }
  if (gold >= 1000) {
    return '${(gold / 1000).toStringAsFixed(gold % 1000 == 0 ? 0 : 1)}K';
  }
  return gold.toString();
}

Future<void> showGuildMinJoinPowerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required int current,
  required void Function(String message) onMessage,
}) async {
  final TextEditingController controller = TextEditingController(text: current > 0 ? '$current' : '');
  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: const Color(0xFF171E2C),
      title: const Text('Katılım Güç Limiti'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '0 = limit yok. Yeni üyeler bu gücün altındaysa katılamaz.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minimum güç',
              suffixText: 'güç',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () async {
            final int? value = int.tryParse(controller.text.trim());
            if (value == null || value < 0) {
              onMessage('Geçerli bir sayı girin (0 veya üzeri).');
              return;
            }
            Navigator.of(ctx).pop();
            final bool ok = await ref.read(guildProvider.notifier).setMinJoinPower(value);
            if (!ok) {
              final String? err = ref.read(guildProvider).error;
              if (err != null) onMessage(err);
              return;
            }
            onMessage(
              value == 0 ? 'Güç limiti kaldırıldı.' : 'Katılım güç limiti $value olarak ayarlandı.',
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
  controller.dispose();
}

Future<void> showGuildMemberActionsSheet({
  required BuildContext context,
  required GuildMemberData member,
  required GuildRole myRole,
  required String myPlayerId,
  required Future<void> Function({
    required String memberId,
    required String action,
    required String successMsg,
  }) onMemberAction,
}) async {
  if (member.playerId == myPlayerId) return;
  if (myRole == GuildRole.member) return;

  final bool canPromote = myRole == GuildRole.leader && member.role == GuildRole.member;
  final bool canDemote = myRole == GuildRole.leader && member.role == GuildRole.officer;
  final bool canKick =
      myRole == GuildRole.leader || (myRole == GuildRole.officer && member.role == GuildRole.member);

  if (!canPromote && !canDemote && !canKick) return;

  await showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            title: Text(
              '${guildRoleEmoji(member.role)} ${member.username} — ${guildRoleLabel(member.role)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          if (canPromote)
            ListTile(
              leading: const Icon(Icons.arrow_upward_rounded, color: Colors.green),
              title: const Text('Subay Yap'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await onMemberAction(
                  memberId: member.playerId,
                  action: 'promote_guild_member',
                  successMsg: '${member.username} subay yapıldı.',
                );
              },
            ),
          if (canDemote)
            ListTile(
              leading: const Icon(Icons.arrow_downward_rounded, color: Colors.orange),
              title: const Text('Üye Yap'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await onMemberAction(
                  memberId: member.playerId,
                  action: 'demote_guild_member',
                  successMsg: '${member.username} üye yapıldı.',
                );
              },
            ),
          if (canKick)
            ListTile(
              leading: const Icon(Icons.person_remove_rounded, color: Colors.red),
              title: const Text('Loncadan At'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await onMemberAction(
                  memberId: member.playerId,
                  action: 'kick_guild_member',
                  successMsg: '${member.username} loncadan atıldı.',
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
