import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../chat_design_system.dart';
import '../chat_models.dart';
import 'chat_item_preview_modal.dart';
import 'chat_message_bubble.dart';
import 'chat_system_announcement.dart';

/// AAA luxury chat message list with glassmorphic borders, date separation,
/// responsive bubbles, scroll-to-bottom jump pill with unread counter,
/// and rich moderation & peer actions.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.isLoading,
    required this.messages,
    required this.activeChannel,
    required this.scrollController,
    required this.isOwnSender,
    required this.isUserOnline,
    required this.onMuteSender,
    this.onStaffPlayerAction,
    this.onReportMessage,
    this.canModerateMessages = false,
    this.onModerateMessage,
    this.onItemLinkTap,
    this.onQuoteMessage,
  });

  final bool isLoading;
  final List<ChatMessage> messages;
  final ChatChannel activeChannel;
  final ScrollController scrollController;
  final bool Function(String senderId) isOwnSender;
  final bool Function(String userId, {bool? fallback}) isUserOnline;
  final void Function(String senderId, String senderName) onMuteSender;
  final void Function(ChatMessage message)? onStaffPlayerAction;
  final void Function(ChatMessage message)? onReportMessage;
  final bool canModerateMessages;
  final void Function(ChatMessage message, String action)? onModerateMessage;
  final ValueChanged<ChatItemLink>? onItemLinkTap;
  final ValueChanged<ChatMessage>? onQuoteMessage;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  bool _showScrollToBottom = false;
  int _newMessagesCount = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      try {
        oldWidget.scrollController.removeListener(_onScroll);
      } catch (_) {}
      widget.scrollController.addListener(_onScroll);
    }

    if (widget.activeChannel != oldWidget.activeChannel) {
      _newMessagesCount = 0;
      _showScrollToBottom = false;
      _scrollToBottom(smooth: false);
    } else if (widget.messages.length > oldWidget.messages.length) {
      final int diff = widget.messages.length - oldWidget.messages.length;
      final ChatMessage latest = widget.messages.last;
      final bool isOwn = widget.isOwnSender(latest.senderId);

      if (!_showScrollToBottom || isOwn) {
        _scrollToBottom(smooth: !isOwn);
      } else {
        setState(() {
          _newMessagesCount += diff;
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      widget.scrollController.removeListener(_onScroll);
    } catch (_) {}
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !widget.scrollController.hasClients) return;
    final ScrollPosition position = widget.scrollController.position;
    final double maxScroll = position.maxScrollExtent;
    final double currentScroll = position.pixels;
    final bool isScrolledUp = (maxScroll - currentScroll) > 160;

    if (isScrolledUp != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = isScrolledUp;
        if (!isScrolledUp) {
          _newMessagesCount = 0;
        }
      });
    }
  }

  void _scrollToBottom({bool smooth = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;
      final double target = widget.scrollController.position.maxScrollExtent;
      if (smooth) {
        widget.scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        widget.scrollController.jumpTo(target);
      }
      if (_newMessagesCount != 0 || _showScrollToBottom) {
        setState(() {
          _newMessagesCount = 0;
          _showScrollToBottom = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;

    if (widget.isLoading) {
      content = _buildLoadingState();
    } else if (widget.messages.isEmpty) {
      content = _buildEmptyState();
    } else {
      content = Stack(
        children: <Widget>[
          Scrollbar(
            controller: widget.scrollController,
            thumbVisibility: false,
            radius: const Radius.circular(4),
            thickness: 4,
            child: ListView.builder(
              controller: widget.scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              cacheExtent: 650,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: widget.messages.length,
              padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
              findChildIndexCallback: (Key key) {
                if (key is ValueKey<String>) {
                  final String val = key.value;
                  if (val.startsWith('msg_col_') || val.startsWith('msg_sub_')) {
                    final String id = val.substring(8);
                    final int idx = widget.messages.indexWhere((ChatMessage m) => m.id == id);
                    return idx >= 0 ? idx : null;
                  }
                }
                return null;
              },
              itemBuilder: (BuildContext context, int i) {
                final ChatMessage m = widget.messages[i];
                final bool isOwn = widget.isOwnSender(m.senderId);
                final double maxBubbleWidth = math.min(
                  540.0,
                  math.max(260.0, MediaQuery.sizeOf(context).width * 0.82),
                );

                final bool showDateSeparator = i == 0 ||
                    _isDifferentDay(m.timestamp, widget.messages[i - 1].timestamp);

                final Widget bubbleWidget;

                // Rich Glowing System Announcement Banner
                if (m.isSystem) {
                  bubbleWidget = ChatSystemAnnouncementBanner(
                    message: m,
                    onItemTap: widget.onItemLinkTap ??
                        (ChatItemLink item) => ChatItemPreviewModal.show(context, item),
                  );
                } else if (m.isDeleted) {
                  bubbleWidget = _buildDeletedPlaceholder(m, maxBubbleWidth);
                } else {
                  const bool allowLongPress = true;

                  bubbleWidget = ChatMessageBubble(
                    key: ValueKey<String>('msg_${m.id}'),
                    message: m,
                    isOwn: isOwn,
                    isOnline: widget.isUserOnline(m.senderId, fallback: m.senderIsOnline),
                    activeChannel: widget.activeChannel,
                    maxBubbleWidth: maxBubbleWidth,
                    onLongPress: allowLongPress ? () => unawaited(_showPeerActions(context, m, isOwn)) : null,
                    onAvatarTap: allowLongPress ? () => unawaited(_showPeerActions(context, m, isOwn)) : null,
                    onItemTap: widget.onItemLinkTap ??
                        (ChatItemLink item) => ChatItemPreviewModal.show(
                              context,
                              item,
                              senderName: m.senderName,
                            ),
                    onStaffPlayerAction: widget.onStaffPlayerAction != null &&
                            m.senderAuthId != null &&
                            m.senderAuthId!.isNotEmpty
                        ? () => widget.onStaffPlayerAction!(m)
                        : null,
                    showGuild: _showSenderGuild(widget.activeChannel, m.senderGuildName),
                  );
                }

                if (showDateSeparator) {
                  return Column(
                    key: ValueKey<String>('msg_col_${m.id}'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _DateSeparatorBadge(date: m.timestamp),
                      bubbleWidget,
                    ],
                  );
                }

                return KeyedSubtree(
                  key: ValueKey<String>('msg_sub_${m.id}'),
                  child: bubbleWidget,
                );
              },
            ),
          ),
          if (_showScrollToBottom)
            Positioned(
              bottom: 12,
              right: 16,
              child: _ScrollToBottomButton(
                channel: widget.activeChannel,
                newMessagesCount: _newMessagesCount,
                onTap: () => _scrollToBottom(smooth: true),
              ),
            ),
        ],
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: ChatDesignSystem.gradientBgPanel,
        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _buildLoadingState() {
    final Color accent = widget.activeChannel.accentColor;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: ChatDesignSystem.spaceMd),
          const Text(
            'Mesajlar yükleniyor...',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: ChatDesignSystem.colorTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.activeChannel.label} kanalı senkronize ediliyor',
            style: TextStyle(
              fontSize: 11,
              color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final IconData icon = widget.activeChannel.icon;
    final Color accent = widget.activeChannel.accentColor;

    final String title;
    final String subtitle;

    switch (widget.activeChannel) {
      case ChatChannel.guild:
        title = 'Lonca sohbeti sessiz';
        subtitle = 'Klan arkadaşlarına selam vererek konuşmayı başlat';
        break;
      case ChatChannel.party:
        title = 'Grup sohbetinde mesaj yok';
        subtitle = 'Grup üyeleriyle stratejini planlamaya başla';
        break;
      case ChatChannel.dm:
        title = 'Fısıltı geçmişi temiz';
        subtitle = 'Gizli ve doğrudan bir mesaj gönder';
        break;
      case ChatChannel.trade:
        title = 'Pazar kanalında ilan yok';
        subtitle = 'Eşya alım veya satım teklifini hemen duyur';
        break;
      case ChatChannel.system:
        title = 'Sistem bildirimi bulunmuyor';
        subtitle = 'Önemli sunucu olayları ve duyurular burada yer alır';
        break;
      case ChatChannel.global:
      default:
        title = 'Henüz mesaj yok';
        subtitle = 'Dünya sohbetine ilk mesajı bırak!';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ChatDesignSystem.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.08),
                border: Border.all(
                  color: accent.withValues(alpha: 0.22),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, size: 30, color: accent.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: ChatDesignSystem.spaceLg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ChatDesignSystem.colorTextPrimary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: ChatDesignSystem.spaceXs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedPlaceholder(ChatMessage m, double maxBubbleWidth) {
    final String deletedText = m.content.trim().isNotEmpty ? m.content : 'Bu mesaj silindi';
    return Padding(
      padding: const EdgeInsets.only(bottom: ChatDesignSystem.spaceMd),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ChatDesignSystem.colorWarning.withValues(alpha: 0.07),
              border: Border.all(
                color: ChatDesignSystem.colorWarning.withValues(alpha: 0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.delete_outline_rounded,
                  size: 14,
                  color: ChatDesignSystem.colorWarning.withValues(alpha: 0.8),
                ),
                const SizedBox(width: ChatDesignSystem.spaceSm),
                Flexible(
                  child: Text(
                    deletedText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: ChatDesignSystem.colorTextSecondary.withValues(alpha: 0.85),
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

  Future<void> _showPeerActions(BuildContext context, ChatMessage m, bool isOwn) async {
    final String badge = (m.senderStaffBadge ?? '').toLowerCase();
    final bool muteProtected = badge == 'admin' || badge == 'gm';

    final String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Message Header Preview
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: widget.activeChannel.accentColor.withValues(alpha: 0.15),
                      child: Icon(
                        widget.activeChannel.icon,
                        size: 16,
                        color: widget.activeChannel.accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            m.senderName.isEmpty ? 'Savaşçı' : m.senderName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ChatDesignSystem.colorTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.content,
                            style: TextStyle(
                              fontSize: 11,
                              color: ChatDesignSystem.colorTextSecondary.withValues(alpha: 0.75),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              // Moderation Actions
              if (widget.canModerateMessages && !m.isDeleted && widget.onModerateMessage != null) ...<Widget>[
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Mesajı sil', style: TextStyle(color: Colors.redAccent)),
                  onTap: () => Navigator.pop(ctx, 'mod_delete'),
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.orangeAccent),
                  title: const Text('Sil + 15 dk sustur', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, 'mod_delete_mute_15'),
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.orangeAccent),
                  title: const Text('Sil + 1 saat sustur', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, 'mod_delete_mute_60'),
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.orangeAccent),
                  title: const Text('Sil + 3 gün sustur', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, 'mod_delete_mute_4320'),
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.orangeAccent),
                  title: const Text('Sil + 5 gün sustur', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, 'mod_delete_mute_7200'),
                ),
                const Divider(height: 1, color: Colors.white12),
              ],
              // Copy text
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF38BDF8)),
                title: const Text('Metni kopyala', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
              // Quote
              if (widget.onQuoteMessage != null && !m.isDeleted)
                ListTile(
                  leading: const Icon(Icons.reply_rounded, color: Color(0xFFA855F7)),
                  title: const Text('Alıntı yap', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, 'quote'),
                ),
              // Staff
              if (widget.onStaffPlayerAction != null &&
                  m.senderAuthId != null &&
                  m.senderAuthId!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFFBBF24)),
                  title: const Text('Staff işlemleri', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, 'staff_player'),
                ),
              // Report
              if (!isOwn && widget.onReportMessage != null)
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.amberAccent),
                  title: const Text('Raporla', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, 'report'),
                ),
              // Mute
              if (!isOwn && !muteProtected)
                ListTile(
                  leading: const Icon(Icons.volume_off_outlined, color: Colors.redAccent),
                  title: const Text('Sustur', style: TextStyle(color: Colors.redAccent)),
                  onTap: () => Navigator.pop(ctx, 'mute'),
                )
              else if (!isOwn && muteProtected)
                const ListTile(
                  leading: Icon(Icons.shield_outlined, color: Colors.white38),
                  title: Text('Yetkili susturulamaz', style: TextStyle(color: Colors.white38)),
                  enabled: false,
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.content));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesaj panoya kopyalandı'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (action == 'quote' && widget.onQuoteMessage != null) {
      widget.onQuoteMessage!(m);
      return;
    }

    if (action == 'staff_player' &&
        widget.onStaffPlayerAction != null &&
        m.senderAuthId != null &&
        m.senderAuthId!.isNotEmpty) {
      widget.onStaffPlayerAction!(m);
      return;
    }

    if (action.startsWith('mod_') && widget.onModerateMessage != null) {
      widget.onModerateMessage!(m, action);
      return;
    }

    if (action == 'report' && widget.onReportMessage != null) {
      widget.onReportMessage!(m);
    } else if (action == 'mute') {
      widget.onMuteSender(m.senderId, m.senderName);
    }
  }

  static bool _showSenderGuild(ChatChannel channel, String? guildName) {
    if (channel == ChatChannel.guild) return false;
    return guildName != null && guildName.trim().isNotEmpty;
  }

  static bool _isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }
}

class _DateSeparatorBadge extends StatelessWidget {
  const _DateSeparatorBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ChatDesignSystem.spaceMd),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ChatDesignSystem.spaceMd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(ChatDesignSystem.radiusRound),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Text(
                _formatDateSeparator(date),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: ChatDesignSystem.colorTextTertiary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateSeparator(DateTime dt) {
    final DateTime now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Bugün';
    }
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'Dün';
    }
    const List<String> months = <String>[
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final String monthName = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
    if (dt.year == now.year) {
      return '${dt.day} $monthName';
    }
    return '${dt.day} $monthName ${dt.year}';
  }
}

class _ScrollToBottomButton extends StatelessWidget {
  const _ScrollToBottomButton({
    required this.channel,
    required this.newMessagesCount,
    required this.onTap,
  });

  final ChatChannel channel;
  final int newMessagesCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasNew = newMessagesCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusRound),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: hasNew ? 14 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(ChatDesignSystem.radiusRound),
            border: Border.all(
              color: channel.accentColor.withValues(alpha: hasNew ? 0.6 : 0.3),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: channel.accentColor.withValues(alpha: hasNew ? 0.35 : 0.18),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: channel.accentColor,
              ),
              if (hasNew) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: channel.accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    newMessagesCount > 99 ? '99+' : '$newMessagesCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'yeni',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

