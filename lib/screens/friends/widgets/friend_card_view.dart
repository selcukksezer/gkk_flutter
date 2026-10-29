import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../components/common/profile_avatar.dart';
import '../../../core/services/app_haptics.dart';
import 'friend_class_crest.dart';
import 'friend_party_invite_cta.dart';
import 'friend_presence_orb.dart';
import 'friend_quick_whisper_dialog.dart';

/// 2027 Aion 2 Mobile Glassmorphism Friend Card (V3 AAA Cyber-Fantasy).
class FriendCardView extends StatelessWidget {
  const FriendCardView({
    super.key,
    required this.friendshipId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.level = 1,
    this.power = 0,
    this.isOnline = false,
    this.characterClass,
    this.location,
    this.guildName,
    this.activityStatus,
    this.isInParty = false,
    this.onPartyInvite,
    this.onDirectWhisper,
    this.onRemove,
    this.onTapCard,
  });

  final String friendshipId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int level;
  final int power;
  final bool isOnline;
  final String? characterClass;
  final String? location;
  final String? guildName;
  final String? activityStatus;
  final bool isInParty;

  final Future<bool> Function({
    required String targetUser,
    required PartyRole role,
    required String activity,
  })? onPartyInvite;

  final Future<bool> Function(String message)? onDirectWhisper;
  final VoidCallback? onRemove;
  final VoidCallback? onTapCard;

  String get name =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : username;

  static Color _getLevelTierColor(int lvl) {
    if (lvl >= 80) return const Color(0xFFF59E0B); // Mythic Gold
    if (lvl >= 60) return const Color(0xFFA855F7); // Arcane Violet
    if (lvl >= 40) return const Color(0xFF38BDF8); // Celestial Azure
    if (lvl >= 20) return const Color(0xFF10B981); // Verdant Emerald
    return const Color(0xFF94A3B8); // Slate Silver
  }

  Widget _buildLevelBadge(int lvl) {
    final Color tierColor = _getLevelTierColor(lvl);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            tierColor.withValues(alpha: 0.22),
            tierColor.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: tierColor.withValues(alpha: 0.5),
          width: 0.9,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tierColor.withValues(alpha: 0.18),
            blurRadius: 4,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.military_tech_rounded,
            size: 10,
            color: tierColor,
          ),
          const SizedBox(width: 2),
          Text(
            'Lv.$lvl',
            style: TextStyle(
              color: tierColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuildBadge(String guild) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color(0xFF818CF8).withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.shield_rounded,
            size: 9.5,
            color: Color(0xFF818CF8),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              guild,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFC7D2FE),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceBadge({
    required FriendPresenceStatus status,
    required bool isOnline,
    String? activity,
  }) {
    final Color color = status.primaryColor;
    final String label = (activity != null && activity.isNotEmpty && isOnline)
        ? activity
        : status.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            status.icon,
            size: 9,
            color: color,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FriendPresenceStatus status = FriendPresenceStatus.fromOnline(
      isOnline: isOnline,
      activity: isInParty ? 'parti' : activityStatus,
    );

    final Color statusColor = status.primaryColor;
    final String activeLocation =
        location ?? (isOnline ? 'Sanctum Tapınağı' : 'Çevrimdışı');
    final String cls = characterClass ?? 'Savaşçı';

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isOnline
                  ? statusColor.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.35),
              blurRadius: isOnline ? 16 : 8,
              offset: const Offset(0, 4),
              spreadRadius: isOnline ? -1 : 0,
            ),
            if (isOnline)
              BoxShadow(
                color: statusColor.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isOnline
                      ? <Color>[
                          const Color(0xFF131D31).withValues(alpha: 0.88),
                          const Color(0xFF0B111E).withValues(alpha: 0.82),
                        ]
                      : <Color>[
                          const Color(0xFF0F1523).withValues(alpha: 0.70),
                          const Color(0xFF080C14).withValues(alpha: 0.75),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOnline
                      ? statusColor.withValues(alpha: 0.38)
                      : Colors.white.withValues(alpha: 0.09),
                  width: 1.1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    AppHaptics.light();
                    onTapCard?.call();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: <Widget>[
                        // Top Row: Avatar + Info + Remove Menu
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Avatar with Presence Orb & Ambient Glow
                            Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: <BoxShadow>[
                                      if (isOnline)
                                        BoxShadow(
                                          color: statusColor
                                              .withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                    ],
                                  ),
                                  child: ProfileAvatar(
                                    size: 48,
                                    avatarUrl: avatarUrl,
                                  ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: FriendPresenceOrb(
                                    status: status,
                                    size: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            // Friend Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  // Name & Level Badge & Guild Tag
                                  Row(
                                    children: <Widget>[
                                      Flexible(
                                        child: Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildLevelBadge(level),
                                      if (guildName != null &&
                                          guildName!.isNotEmpty) ...<Widget>[
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: _buildGuildBadge(guildName!),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 5),

                                  // Class Crest, Combat Power & Status Badge
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: <Widget>[
                                      ClassCrestBadge(
                                        className: cls,
                                        compact: true,
                                      ),
                                      CombatPowerBadge(power: power),
                                      _buildPresenceBadge(
                                        status: status,
                                        isOnline: isOnline,
                                        activity: activityStatus,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),

                                  // Location
                                  LocationBadge(
                                    location: activeLocation,
                                    isOnline: isOnline,
                                  ),
                                ],
                              ),
                            ),

                            // Dropdown menu / Remove Action
                            if (onRemove != null)
                              PopupMenuButton<String>(
                                tooltip: 'Seçenekler',
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                                color: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                elevation: 8,
                                onSelected: (String value) {
                                  if (value == 'remove') {
                                    AppHaptics.medium();
                                    onRemove?.call();
                                  }
                                },
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'remove',
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.person_remove_outlined,
                                          color: Color(0xFFEF4444),
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Arkadaşlıktan Çıkar',
                                          style: TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),

                        // Bottom Action Bar: Quick Party Invite CTA & One-Tap Direct Whisper
                        if (isOnline) ...<Widget>[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 0.8,
                                ),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                // Quick Party Invite CTA Button
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      AppHaptics.light();
                                      if (onPartyInvite != null) {
                                        FriendPartyInviteCtaSheet.show(
                                          context: context,
                                          friendshipId: friendshipId,
                                          friendName: name,
                                          avatarUrl: avatarUrl,
                                          level: level,
                                          power: power,
                                          characterClass: cls,
                                          isOnline: isOnline,
                                          onSendInvite: onPartyInvite!,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 7.5,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: <Color>[
                                            const Color(0xFFF59E0B)
                                                .withValues(alpha: 0.22),
                                            const Color(0xFFD97706)
                                                .withValues(alpha: 0.10),
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.45),
                                          width: 0.9,
                                        ),
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: const Color(0xFFF59E0B)
                                                .withValues(alpha: 0.12),
                                            blurRadius: 6,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          Icon(
                                            isInParty
                                                ? Icons.groups_rounded
                                                : Icons.group_add_rounded,
                                            size: 14.5,
                                            color: const Color(0xFFFBBF24),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isInParty
                                                ? 'Partide'
                                                : 'Partiye Çağır',
                                            style: const TextStyle(
                                              color: Color(0xFFFBBF24),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // One-tap Direct Whisper Action Button
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      AppHaptics.light();
                                      if (onDirectWhisper != null) {
                                        FriendQuickWhisperDialog.show(
                                          context: context,
                                          friendshipId: friendshipId,
                                          recipientName: name,
                                          avatarUrl: avatarUrl,
                                          level: level,
                                          characterClass: cls,
                                          isOnline: isOnline,
                                          onSendWhisper: onDirectWhisper!,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 7.5,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: <Color>[
                                            const Color(0xFF0284C7)
                                                .withValues(alpha: 0.22),
                                            const Color(0xFF0369A1)
                                                .withValues(alpha: 0.10),
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF38BDF8)
                                              .withValues(alpha: 0.45),
                                          width: 0.9,
                                        ),
                                        boxShadow: <BoxShadow>[
                                          BoxShadow(
                                            color: const Color(0xFF0284C7)
                                                .withValues(alpha: 0.12),
                                            blurRadius: 6,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 14.5,
                                            color: Color(0xFF38BDF8),
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'Fısılda',
                                            style: TextStyle(
                                              color: Color(0xFF38BDF8),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

