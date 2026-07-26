import 'package:flutter/material.dart';

import '../../../components/player/player_name_label.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../l10n/l10n.dart';
import '../../../models/guild_model.dart';
import '../guild_helpers.dart';

class GuildMemberView extends StatelessWidget {
  const GuildMemberView({
    super.key,
    required this.guild,
    required this.myPlayerId,
    required this.myRole,
    required this.memberActionLoading,
    required this.onMemberTap,
    this.onStaffMemberAction,
    required this.onLeave,
    required this.leaveLabel,
    required this.onGuildWar,
    required this.onMonument,
    required this.onVault,
    required this.onRefresh,
    this.onEditMinJoinPower,
  });

  final GuildData guild;
  final String myPlayerId;
  final GuildRole myRole;
  final bool memberActionLoading;
  final Future<void> Function(GuildMemberData) onMemberTap;
  final void Function(GuildMemberData)? onStaffMemberAction;
  final VoidCallback onLeave;
  final String leaveLabel;
  final VoidCallback onGuildWar;
  final VoidCallback onMonument;
  final VoidCallback onVault;
  final Future<void> Function() onRefresh;
  final VoidCallback? onEditMinJoinPower;

  @override
  Widget build(BuildContext context) {
    final List<GuildMemberData> sortedMembers = guild.members == null
        ? <GuildMemberData>[]
        : List<GuildMemberData>.from(guild.members!)
      ..sort((GuildMemberData a, GuildMemberData b) =>
          guildRoleSortOrder(a.role).compareTo(guildRoleSortOrder(b.role)));

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TutorialAnchorScope(
              id: TutorialAnchorId.guildHeader,
              child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x334B6FFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.groups_rounded, color: Color(0xFF4B6FFF), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          guild.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B6FFF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Sv. ${guild.level}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF4B6FFF), fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      GuildStatChip(icon: Icons.people_rounded, label: '${guild.memberCount}/${guild.maxMembers} Üye'),
                      GuildStatChip(icon: Icons.bolt_rounded, label: '${formatGuildCompact(guild.totalPower)} Güç'),
                      GuildStatChip(icon: Icons.account_balance_outlined, label: 'Anıt Sv.${guild.monumentLevel}'),
                      GuildStatChip(
                        icon: Icons.paid_rounded,
                        label: '${formatGuildCompact(guild.monumentGoldPool)} 🪙 Havuz',
                      ),
                      GuildStatChip(
                        icon: Icons.shield_rounded,
                        label: guild.minJoinPower > 0
                            ? 'Min ${formatGuildCompact(guild.minJoinPower)} güç'
                            : 'Güç limiti yok',
                      ),
                    ],
                  ),
                  if (onEditMinJoinPower != null) ...<Widget>[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onEditMinJoinPower,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: Text(context.l10n.kat_l_m_g_limiti),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF4B6FFF)),
                        foregroundColor: const Color(0xFF8BAEFF),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ),
            const SizedBox(height: 14),
            TutorialAnchorScope(
              id: TutorialAnchorId.guildJoinBtn,
              child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: onGuildWar,
                    icon: const Icon(Icons.flag_rounded, size: 16),
                    label: Text(context.l10n.lonca_sava),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: onMonument,
                    icon: const Icon(Icons.account_balance_rounded, size: 16),
                    label: const Text('Anıt'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: onVault,
                    icon: const Icon(Icons.savings_rounded, size: 16),
                    label: const Text('Lonca Kasası'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFFB800)),
                      foregroundColor: const Color(0xFFFFB800),
                    ),
                  ),
                ),
              ],
            ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onLeave,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
                child: Text(leaveLabel),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                const Text(
                  'Üyeler',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                if (memberActionLoading) ...<Widget>[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (sortedMembers.isEmpty)
              Text(
                guild.loadError ?? 'Henüz üye kaydı yok.',
                style: const TextStyle(color: Colors.white38),
              )
            else
              ...sortedMembers.map(
                (GuildMemberData member) => GuildMemberTile(
                  member: member,
                  isMe: member.playerId == myPlayerId,
                  canAct: myRole != GuildRole.member && member.playerId != myPlayerId,
                  onTap: () => onMemberTap(member),
                  onLongPress: onStaffMemberAction != null && member.userId != null
                      ? () => onStaffMemberAction!(member)
                      : null,
                  onStaffTap: onStaffMemberAction != null &&
                          member.userId != null &&
                          member.userId!.isNotEmpty &&
                          member.playerId != myPlayerId
                      ? () => onStaffMemberAction!(member)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GuildMemberTile extends StatelessWidget {
  const GuildMemberTile({
    super.key,
    required this.member,
    required this.isMe,
    required this.canAct,
    required this.onTap,
    this.onLongPress,
    this.onStaffTap,
  });

  final GuildMemberData member;
  final bool isMe;
  final bool canAct;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onStaffTap;

  @override
  Widget build(BuildContext context) {
    final bool online = member.isOnline == true;
    return GestureDetector(
      onTap: canAct ? onTap : null,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4B6FFF).withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? const Color(0x334B6FFF) : Colors.white12,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? Colors.green : Colors.white24,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        guildRoleEmoji(member.role),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 5),
                      PlayerNameLabel(
                        username: member.username,
                        staffBadge: member.staffBadge,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isMe ? const Color(0xFF8BAEFF) : Colors.white,
                        ),
                        compactBadge: true,
                        showUsername: false,
                        onTap: onStaffTap,
                      ),
                      if (isMe)
                        const Text(
                          ' (Ben)',
                          style: TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sv.${member.level} · ${guildRoleLabel(member.role)} · ${formatGuildCompact(member.power)} güç',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
            if (canAct)
              const Icon(Icons.more_vert_rounded, size: 16, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class GuildStatChip extends StatelessWidget {
  const GuildStatChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}
