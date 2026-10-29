import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/common/profile_avatar.dart';
import 'friend_class_crest.dart';
import 'friend_presence_orb.dart';

/// Role for party invitation.
enum PartyRole {
  dps(name: 'DPS', icon: Icons.sports_martial_arts_rounded, color: Color(0xFFEF4444)),
  tank(name: 'Tank', icon: Icons.shield_rounded, color: Color(0xFF3B82F6)),
  healer(name: 'Şifacı', icon: Icons.healing_rounded, color: Color(0xFF10B981)),
  support(name: 'Destek', icon: Icons.auto_awesome_rounded, color: Color(0xFFA855F7));

  const PartyRole({
    required this.name,
    required this.icon,
    required this.color,
  });

  final String name;
  final IconData icon;
  final Color color;
}

/// Quick Party Invite Sheet for 2027 Aion 2 Mobile.
class FriendPartyInviteCtaSheet extends StatefulWidget {
  const FriendPartyInviteCtaSheet({
    super.key,
    required this.friendshipId,
    required this.friendName,
    this.avatarUrl,
    this.level = 1,
    this.power = 0,
    this.characterClass,
    this.isOnline = true,
    required this.onSendInvite,
  });

  final String friendshipId;
  final String friendName;
  final String? avatarUrl;
  final int level;
  final int power;
  final String? characterClass;
  final bool isOnline;
  final Future<bool> Function({
    required String targetUser,
    required PartyRole role,
    required String activity,
  }) onSendInvite;

  static Future<void> show({
    required BuildContext context,
    required String friendshipId,
    required String friendName,
    String? avatarUrl,
    int level = 1,
    int power = 0,
    String? characterClass,
    bool isOnline = true,
    required Future<bool> Function({
      required String targetUser,
      required PartyRole role,
      required String activity,
    }) onSendInvite,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => FriendPartyInviteCtaSheet(
        friendshipId: friendshipId,
        friendName: friendName,
        avatarUrl: avatarUrl,
        level: level,
        power: power,
        characterClass: characterClass,
        isOnline: isOnline,
        onSendInvite: onSendInvite,
      ),
    );
  }

  @override
  State<FriendPartyInviteCtaSheet> createState() =>
      _FriendPartyInviteCtaSheetState();
}

class _FriendPartyInviteCtaSheetState extends State<FriendPartyInviteCtaSheet> {
  PartyRole _selectedRole = PartyRole.dps;
  String _selectedActivity = 'Zindan Kuşatması';
  bool _sending = false;

  static const List<String> _activities = <String>[
    'Zindan Kuşatması',
    'Abyss Boss Baskını',
    'PvP 3v3 Arena',
    'Açık Dünya Keşfi',
  ];

  Future<void> _handleInvite() async {
    if (_sending) return;
    setState(() => _sending = true);
    HapticFeedback.mediumImpact();

    try {
      final bool ok = await widget.onSendInvite(
        targetUser: widget.friendName,
        role: _selectedRole,
        activity: _selectedActivity,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FriendPresenceStatus status = widget.isOnline
        ? FriendPresenceStatus.online
        : FriendPresenceStatus.offline;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1424).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.groups_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'GRUP & PARTİ DAVETİ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Friend Profile Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: <Widget>[
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        ProfileAvatar(
                          size: 46,
                          avatarUrl: widget.avatarUrl,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: FriendPresenceOrb(
                            status: status,
                            size: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.friendName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: <Widget>[
                              Text(
                                'Lv.${widget.level}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (widget.characterClass != null) ...<Widget>[
                                ClassCrestBadge(
                                  className: widget.characterClass!,
                                  compact: true,
                                ),
                                const SizedBox(width: 6),
                              ],
                              CombatPowerBadge(power: widget.power),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Role Selector
              const Text(
                'PARTİDEKİ ROL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: PartyRole.values.map((PartyRole role) {
                  final bool isSelected = _selectedRole == role;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedRole = role);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? role.color.withValues(alpha: 0.22)
                                : Colors.black26,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? role.color
                                  : Colors.white12,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: <Widget>[
                              Icon(
                                role.icon,
                                size: 18,
                                color: isSelected ? role.color : Colors.white60,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                role.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 14),

              // Activity Target
              const Text(
                'HEDEF ETKİNLİK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _activities.map((String act) {
                  final bool isSelected = _selectedActivity == act;
                  return ChoiceChip(
                    label: Text(act),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _selectedActivity = act);
                      }
                    },
                    selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                    backgroundColor: Colors.black26,
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFF59E0B)
                          : Colors.white12,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 18),

              // Confirm CTA Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _sending ? null : _handleInvite,
                  icon: _sending
                      ? const SizedBox.shrink()
                      : const Icon(Icons.group_add_rounded, size: 20),
                  label: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFF0F172A),
                          ),
                        )
                      : Text(
                          '${widget.friendName} Kişisini Partiye Çağır',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
