import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/common/profile_avatar.dart';
import 'friend_class_crest.dart';
import 'friend_presence_orb.dart';

/// One-tap direct whisper sheet for 2027 Aion 2 Mobile social flow.
class FriendQuickWhisperDialog extends StatefulWidget {
  const FriendQuickWhisperDialog({
    super.key,
    required this.friendshipId,
    required this.recipientName,
    this.avatarUrl,
    this.level = 1,
    this.characterClass,
    this.isOnline = true,
    required this.onSendWhisper,
  });

  final String friendshipId;
  final String recipientName;
  final String? avatarUrl;
  final int level;
  final String? characterClass;
  final bool isOnline;
  final Future<bool> Function(String message) onSendWhisper;

  static Future<void> show({
    required BuildContext context,
    required String friendshipId,
    required String recipientName,
    String? avatarUrl,
    int level = 1,
    String? characterClass,
    bool isOnline = true,
    required Future<bool> Function(String message) onSendWhisper,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => FriendQuickWhisperDialog(
        friendshipId: friendshipId,
        recipientName: recipientName,
        avatarUrl: avatarUrl,
        level: level,
        characterClass: characterClass,
        isOnline: isOnline,
        onSendWhisper: onSendWhisper,
      ),
    );
  }

  @override
  State<FriendQuickWhisperDialog> createState() =>
      _FriendQuickWhisperDialogState();
}

class _FriendQuickWhisperDialogState extends State<FriendQuickWhisperDialog> {
  final TextEditingController _msgController = TextEditingController();
  bool _sending = false;

  static const List<String> _quickMacros = <String>[
    '⚔️ Zindana hazır mısın?',
    '🛡️ Partiye katıl, 1 kişi eksik!',
    '💎 Ticaret yapalım mı?',
    '📍 Hangi bölgedesin?',
    '✨ Tebrikler!',
  ];

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _handleSend(String text) async {
    final String clean = text.trim();
    if (clean.isEmpty || _sending) return;

    setState(() => _sending = true);
    HapticFeedback.mediumImpact();

    try {
      final bool ok = await widget.onSendWhisper(clean);
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
    final EdgeInsets insets = MediaQuery.of(context).viewInsets;
    final FriendPresenceStatus status = widget.isOnline
        ? FriendPresenceStatus.online
        : FriendPresenceStatus.offline;

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.94),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 28,
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

                // Recipient Header
                Row(
                  children: <Widget>[
                    Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        ProfileAvatar(
                          size: 44,
                          avatarUrl: widget.avatarUrl,
                        ),
                        Positioned(
                          right: -3,
                          bottom: -3,
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
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  widget.recipientName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Lv.${widget.level}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          if (widget.characterClass != null)
                            ClassCrestBadge(
                              className: widget.characterClass!,
                              compact: true,
                            )
                          else
                            Text(
                              widget.isOnline ? '🟢 Çevrimiçi' : '⚫ Çevrimdışı',
                              style: TextStyle(
                                color: widget.isOnline
                                    ? const Color(0xFF10B981)
                                    : Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick Tactical Macros
                const Text(
                  'HIZLI TAKTİK MESAJLAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickMacros.map((String macro) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _sending ? null : () => _handleSend(macro),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          macro,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 14),

                // Input Bar
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '${widget.recipientName} kişisine fısılda...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                          ),
                        ),
                        onSubmitted: (String val) => _handleSend(val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _sending
                          ? null
                          : () => _handleSend(_msgController.text),
                      child: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
