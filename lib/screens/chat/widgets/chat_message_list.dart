import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../chat_design_system.dart';
import '../chat_models.dart';
import '../../../components/player/player_name_label.dart';
import '../../../theme/app_colors.dart';
import 'chat_presence.dart';

class ChatMessageList extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(height: ChatDesignSystem.spaceMd),
            Text('Mesajlar yükleniyor...', style: TextStyle(fontSize: 12, color: ChatDesignSystem.colorTextTertiary)),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.chat_bubble_outline_rounded, size: 56, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.2)),
            const SizedBox(height: ChatDesignSystem.spaceLg),
            Text('Henüz mesaj yok', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ChatDesignSystem.colorTextTertiary)),
            const SizedBox(height: ChatDesignSystem.spaceXs),
            Text('Konuşmayı başlatmak için bir mesaj yaz', style: TextStyle(fontSize: 11, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: ChatDesignSystem.gradientBgPanel,
        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListView.builder(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: messages.length,
        padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
        itemBuilder: (BuildContext context, int i) {
          final ChatMessage m = messages[i];
          final bool isOwn = isOwnSender(m.senderId);
          final double maxBubbleWidth = math.min(520, MediaQuery.sizeOf(context).width * 0.78);

          if (m.isSystem) {
            final Color accent = switch (m.systemTone) {
              'success' => ChatDesignSystem.colorSuccess,
              'danger' => ChatDesignSystem.colorError,
              'warning' => ChatDesignSystem.colorWarning,
              _ => ChatDesignSystem.colorInfo,
            };
            final IconData icon = switch (m.systemTone) {
              'success' => Icons.auto_awesome_rounded,
              'danger' => Icons.local_fire_department_rounded,
              'warning' => Icons.trending_down_rounded,
              _ => Icons.info_outline_rounded,
            };

            return Padding(
              padding: const EdgeInsets.only(bottom: ChatDesignSystem.spaceMd),
              child: Container(
                padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[accent.withValues(alpha: 0.16), accent.withValues(alpha: 0.05)],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                  borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(icon, size: 16, color: accent.withValues(alpha: 0.85)),
                    const SizedBox(width: ChatDesignSystem.spaceSm),
                    Expanded(
                      child: Text(
                        m.content,
                        style: TextStyle(
                          fontSize: 12,
                          color: accent.withValues(alpha: 0.95),
                          fontWeight: m.systemTone == null ? FontWeight.normal : FontWeight.w600,
                          fontStyle: m.systemTone == null ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (m.isDeleted) {
            return Padding(
              padding: const EdgeInsets.only(bottom: ChatDesignSystem.spaceMd),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: ChatDesignSystem.colorWarning.withValues(alpha: 0.08),
                      border: Border.all(color: ChatDesignSystem.colorWarning.withValues(alpha: 0.22)),
                      borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.delete_outline_rounded, size: 14, color: ChatDesignSystem.colorWarning.withValues(alpha: 0.8)),
                        const SizedBox(width: ChatDesignSystem.spaceSm),
                        Flexible(
                          child: Text(
                            m.content,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: ChatDesignSystem.colorTextSecondary.withValues(alpha: 0.9),
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

          final bool allowLongPress = !isOwn || canModerateMessages;

          final bool muteProtected =
              m.senderStaffBadge == 'admin' || m.senderStaffBadge == 'gm';

          Future<void> showPeerActions() async {
            final String? action = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: AppColors.bgCard,
              builder: (BuildContext ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (canModerateMessages && !m.isDeleted && onModerateMessage != null) ...<Widget>[
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        title: const Text('Mesajı sil'),
                        onTap: () => Navigator.pop(ctx, 'mod_delete'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_outlined, color: Colors.orangeAccent),
                        title: const Text('Sil + 15 dk sustur'),
                        onTap: () => Navigator.pop(ctx, 'mod_delete_mute_15'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_outlined, color: Colors.orangeAccent),
                        title: const Text('Sil + 1 saat sustur'),
                        onTap: () => Navigator.pop(ctx, 'mod_delete_mute_60'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_outlined, color: Colors.orangeAccent),
                        title: const Text('Sil + 3 gün sustur'),
                        onTap: () => Navigator.pop(ctx, 'mod_delete_mute_4320'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_outlined, color: Colors.orangeAccent),
                        title: const Text('Sil + 5 gün sustur'),
                        onTap: () => Navigator.pop(ctx, 'mod_delete_mute_7200'),
                      ),
                      const Divider(height: 1),
                    ],
                    if (onStaffPlayerAction != null &&
                        m.senderAuthId != null &&
                        m.senderAuthId!.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.admin_panel_settings_outlined),
                        title: const Text('Staff işlemleri'),
                        onTap: () => Navigator.pop(ctx, 'staff_player'),
                      ),
                    if (!isOwn)
                      ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: const Text('Raporla'),
                        onTap: () => Navigator.pop(ctx, 'report'),
                      ),
                    if (!isOwn && !muteProtected)
                      ListTile(
                        leading: const Icon(Icons.volume_off_outlined),
                        title: const Text('Sustur'),
                        onTap: () => Navigator.pop(ctx, 'mute'),
                      )
                    else if (!isOwn && muteProtected)
                      const ListTile(
                        leading: Icon(Icons.shield_outlined),
                        title: Text('Yetkili susturulamaz'),
                        enabled: false,
                      ),
                  ],
                ),
              ),
            );
            if (action == null) return;
            if (action == 'staff_player' &&
                onStaffPlayerAction != null &&
                m.senderAuthId != null &&
                m.senderAuthId!.isNotEmpty) {
              onStaffPlayerAction!(m);
              return;
            }
            if (action.startsWith('mod_') && onModerateMessage != null) {
              onModerateMessage!(m, action);
              return;
            }
            if (action == 'report' && onReportMessage != null) {
              onReportMessage!(m);
            } else if (action == 'mute') {
              onMuteSender(m.senderId, m.senderName);
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: ChatDesignSystem.spaceMd),
            child: Align(
              alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: GestureDetector(
                  onLongPress: allowLongPress ? () => unawaited(showPeerActions()) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isOwn
                          ? LinearGradient(
                              colors: [ChatDesignSystem.colorGlobalAccent.withValues(alpha: 0.15), ChatDesignSystem.colorGlobalAccent.withValues(alpha: 0.06)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.03)]),
                      border: Border.all(color: isOwn ? ChatDesignSystem.colorGlobalAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                      boxShadow: [
                        BoxShadow(
                          color: isOwn ? ChatDesignSystem.colorGlobalAccent.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (isOwn)
                              Flexible(
                                child: Text(
                                  'Sen',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ChatDesignSystem.colorGlobalAccent),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (m.senderId.isNotEmpty) ...<Widget>[
                                      OnlineStatusDot(
                                        online: isUserOnline(m.senderId, fallback: m.senderIsOnline),
                                        size: 7,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    if (_showSenderGuild(activeChannel, m.senderGuildName))
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Text(
                                          '[${m.senderGuildName}]',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: ChatDesignSystem.colorGuildAccent.withValues(alpha: 0.9),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    Flexible(
                                      child: PlayerNameLabel(
                                        username: m.senderName,
                                        staffBadge: m.senderStaffBadge,
                                        kingBadge: m.senderKingBadge,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: activeChannel.accentColor,
                                        ),
                                        compactBadge: true,
                                        showUsername: false,
                                        onTap: onStaffPlayerAction != null &&
                                                m.senderAuthId != null &&
                                                m.senderAuthId!.isNotEmpty
                                            ? () => onStaffPlayerAction!(m)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: ChatDesignSystem.spaceSm),
                            Text(
                              formatChatTime(m.timestamp),
                              style: TextStyle(fontSize: 9, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                        const SizedBox(height: ChatDesignSystem.spaceSm),
                        Text(m.content, style: const TextStyle(fontSize: 12, color: ChatDesignSystem.colorTextPrimary, height: 1.4)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static bool _showSenderGuild(ChatChannel channel, String? guildName) {
    return guildName != null && guildName.isNotEmpty;
  }
}
