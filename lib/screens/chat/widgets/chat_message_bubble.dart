import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/player/player_name_label.dart';
import '../../../core/services/app_haptics.dart';
import '../chat_design_system.dart';
import '../chat_models.dart';
import 'chat_item_preview_modal.dart';
import 'chat_presence.dart';
import 'chat_sender_badge.dart';

/// Stylized chat message bubble with class/faction insignia, level badges, and responsive touch feedback.
///
/// Elevated to V3 AAA Cyber-Fantasy luxury standard:
/// - Frosted obsidian-glass sheen with specular reflection line and zero-jank hardware acceleration.
/// - Distinctive asymmetrical geometry for own vs other player bubbles.
/// - Channel-specific luminescence: Guild green, Party blue, World gold, Whisper purple.
/// - Monospaced tabular timestamp typography with delivery verification indicators.
/// - Tactile haptic feedback via [AppHaptics] on press, link chips, and long-press clipboard copy.
class ChatMessageBubble extends StatefulWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    required this.isOnline,
    required this.activeChannel,
    this.onLongPress,
    this.onTap,
    this.onItemTap,
    this.onAvatarTap,
    this.onStaffPlayerAction,
    this.showGuild = true,
    this.maxBubbleWidth,
  });

  final ChatMessage message;
  final bool isOwn;
  final bool isOnline;
  final ChatChannel activeChannel;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final ValueChanged<ChatItemLink>? onItemTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onStaffPlayerAction;
  final bool showGuild;
  final double? maxBubbleWidth;

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    AppHaptics.selection();
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  Future<void> _handleLongPress(BuildContext context) async {
    await AppHaptics.heavy();
    if (widget.onLongPress != null) {
      widget.onLongPress!();
    } else {
      await _copyMessageToClipboard(context);
    }
  }

  Future<void> _copyMessageToClipboard(BuildContext context) async {
    final String content = widget.message.content.trim();
    if (content.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;

    await AppHaptics.success();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: Color(0xFF10B981),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Mesaj kopyalandı',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF141B26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
      ),
    );
  }

  static Color _getChannelLuminescence(ChatChannel channel) {
    switch (channel) {
      case ChatChannel.guild:
        return const Color(0xFF10B981); // Guild emerald green
      case ChatChannel.party:
        return const Color(0xFF38BDF8); // Party cyber blue
      case ChatChannel.global:
        return const Color(0xFFF5C842); // World celestial gold
      case ChatChannel.dm:
        return const Color(0xFFA855F7); // Whisper arcane purple
      case ChatChannel.trade:
        return const Color(0xFFFBBF24); // Trade amber gold
      case ChatChannel.system:
        return const Color(0xFFF43F5E); // System crimson rose
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxW = widget.maxBubbleWidth ??
        (MediaQuery.sizeOf(context).width * 0.78).clamp(240.0, 520.0);

    final ChatMessage m = widget.message;
    final bool isOwn = widget.isOwn;
    final ChatChannel effectiveChannel = m.channel;
    final Color luminescence = _getChannelLuminescence(effectiveChannel);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: ChatDesignSystem.spaceMd),
        child: Align(
          alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!isOwn) ...<Widget>[
                  ChatAvatarThumbnail(
                    avatarUrl: m.senderAvatarUrl,
                    senderClass: m.senderClass,
                    isOnline: widget.isOnline,
                    size: 32,
                    onTap: widget.onAvatarTap ?? widget.onStaffPlayerAction,
                  ),
                  const SizedBox(width: ChatDesignSystem.spaceSm),
                ],
                Flexible(
                  child: GestureDetector(
                    onTapDown: _handleTapDown,
                    onTapUp: _handleTapUp,
                    onTapCancel: _handleTapCancel,
                    onLongPress: () => _handleLongPress(context),
                    child: AnimatedScale(
                      scale: _isPressed ? 0.985 : 1.0,
                      duration: const Duration(milliseconds: 90),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: isOwn
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    luminescence.withValues(alpha: 0.20),
                                    const Color(0xFF0F172A).withValues(alpha: 0.90),
                                    const Color(0xFF090D15).withValues(alpha: 0.95),
                                  ],
                                  stops: const <double>[0.0, 0.45, 1.0],
                                )
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    const Color(0xFF141C2B).withValues(alpha: 0.92),
                                    const Color(0xFF0C111C).withValues(alpha: 0.96),
                                    luminescence.withValues(alpha: 0.07),
                                  ],
                                  stops: const <double>[0.0, 0.65, 1.0],
                                ),
                          border: Border.all(
                            color: isOwn
                                ? luminescence.withValues(alpha: 0.48)
                                : luminescence.withValues(alpha: 0.28),
                            width: 1.1,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(ChatDesignSystem.radiusMd + 2),
                            topRight: const Radius.circular(ChatDesignSystem.radiusMd + 2),
                            bottomLeft: Radius.circular(isOwn ? (ChatDesignSystem.radiusMd + 2) : 3),
                            bottomRight: Radius.circular(isOwn ? 3 : (ChatDesignSystem.radiusMd + 2)),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: luminescence.withValues(alpha: isOwn ? 0.14 : 0.08),
                              blurRadius: 10,
                              spreadRadius: -1,
                              offset: const Offset(0, 3),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // Specular glass highlight sheen line
                            Container(
                              height: 1,
                              margin: const EdgeInsets.only(bottom: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: isOwn ? 0.35 : 0.20),
                                    luminescence.withValues(alpha: 0.35),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                  stops: const <double>[0.0, 0.35, 0.75, 1.0],
                                ),
                              ),
                            ),

                            // Sender meta header line
                            _buildHeaderLine(m, isOwn, luminescence, effectiveChannel),
                            const SizedBox(height: 6),

                            // Content body (text + item chips)
                            _buildContentBody(context, m, luminescence),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderLine(
    ChatMessage m,
    bool isOwn,
    Color luminescence,
    ChatChannel channel,
  ) {
    if (isOwn) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Miniature Channel luminescence indicator pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.2),
            decoration: BoxDecoration(
              color: luminescence.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(3.5),
              border: Border.all(
                color: luminescence.withValues(alpha: 0.35),
                width: 0.75,
              ),
            ),
            child: Text(
              channel.tag,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: luminescence,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 5),

          if (m.senderClass != null) ...<Widget>[
            SenderClassInsignia(senderClass: m.senderClass!, size: 14),
            const SizedBox(width: 4),
          ],
          if (m.senderLevel != null) ...<Widget>[
            SenderLevelBadge(level: m.senderLevel!, compact: true),
            const SizedBox(width: 4),
          ],

          // Own "Sen" badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: luminescence.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: luminescence.withValues(alpha: 0.45),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.person_rounded,
                  size: 10,
                  color: luminescence,
                ),
                const SizedBox(width: 2.5),
                Text(
                  'Sen',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: luminescence,
                    letterSpacing: 0.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Timestamp elegance with double checkmark
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.access_time_rounded,
                size: 9.5,
                color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 2.5),
              Text(
                formatChatTime(m.timestamp),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.8),
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 3.5),
              Icon(
                Icons.done_all_rounded,
                size: 11,
                color: luminescence.withValues(alpha: 0.85),
              ),
            ],
          ),
        ],
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      runSpacing: 3,
      children: <Widget>[
        // Channel luminescence tag pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.2),
          decoration: BoxDecoration(
            color: luminescence.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(3.5),
            border: Border.all(
              color: luminescence.withValues(alpha: 0.35),
              width: 0.75,
            ),
          ),
          child: Text(
            channel.tag,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: luminescence,
              letterSpacing: 0.2,
            ),
          ),
        ),

        // Faction crest
        if (m.senderFaction != null)
          SenderFactionInsignia(faction: m.senderFaction!, size: 14, showRune: true),

        // Class insignia
        if (m.senderClass != null)
          SenderClassInsignia(senderClass: m.senderClass!, size: 15),

        // Level badge
        if (m.senderLevel != null)
          SenderLevelBadge(level: m.senderLevel!, compact: true),

        // Online status dot
        if (m.senderId.isNotEmpty)
          OnlineStatusDot(online: widget.isOnline, size: 6.5),

        // Guild Tag
        if (widget.showGuild && m.senderGuildName != null && m.senderGuildName!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
            decoration: BoxDecoration(
              color: ChatDesignSystem.colorGuildAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3.5),
              border: Border.all(
                color: ChatDesignSystem.colorGuildAccent.withValues(alpha: 0.3),
                width: 0.65,
              ),
            ),
            child: Text(
              '<${m.senderGuildName}>',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: ChatDesignSystem.colorGuildAccent,
              ),
            ),
          ),

        // Player Name with staff and king badges
        PlayerNameLabel(
          username: m.senderName,
          staffBadge: m.senderStaffBadge,
          kingBadge: m.senderKingBadge,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: luminescence,
            letterSpacing: 0.2,
          ),
          compactBadge: true,
          showUsername: false,
          onTap: widget.onStaffPlayerAction,
        ),

        // Timestamp elegance
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.access_time_rounded,
              size: 9.5,
              color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 2.5),
            Text(
              formatChatTime(m.timestamp),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.8),
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContentBody(
    BuildContext context,
    ChatMessage m,
    Color luminescence,
  ) {
    final List<ChatItemLink> itemLinks = m.itemLinks ?? const <ChatItemLink>[];

    // If there are explicit item links or [item:...] tags, render parsed rich flow
    if (itemLinks.isNotEmpty) {
      final List<Widget> widgets = <Widget>[];

      // Remove the [item:...] tags from main text or render item link chips
      String cleanedText = m.content;
      for (final ChatItemLink link in itemLinks) {
        cleanedText = cleanedText.replaceAll(link.tag, '').trim();
      }
      final RegExp genericTag = RegExp(r'\[item:[^\]]+\]');
      cleanedText = cleanedText.replaceAll(genericTag, '').trim();

      if (cleanedText.isNotEmpty) {
        widgets.add(
          Text(
            cleanedText,
            style: const TextStyle(
              fontSize: 12.5,
              color: ChatDesignSystem.colorTextPrimary,
              height: 1.42,
              letterSpacing: 0.1,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 6));
      }

      widgets.add(
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: itemLinks.map((ChatItemLink item) {
            return ChatItemLinkChip(
              item: item,
              onTap: () {
                AppHaptics.light();
                if (widget.onItemTap != null) {
                  widget.onItemTap!(item);
                } else {
                  ChatItemPreviewModal.show(
                    context,
                    item,
                    senderName: m.senderName,
                  );
                }
              },
            );
          }).toList(),
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: widgets,
      );
    }

    // Standard message body
    return Text(
      m.content,
      style: const TextStyle(
        fontSize: 12.5,
        color: ChatDesignSystem.colorTextPrimary,
        height: 1.42,
        letterSpacing: 0.1,
      ),
    );
  }
}
