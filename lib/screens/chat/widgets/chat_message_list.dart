import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chat_design_system.dart';
import '../chat_models.dart';
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
  });

  final bool isLoading;
  final List<ChatMessage> messages;
  final ChatChannel activeChannel;
  final ScrollController scrollController;
  final bool Function(String senderId) isOwnSender;
  final bool Function(String userId, {bool? fallback}) isUserOnline;
  final void Function(String senderId, String senderName) onMuteSender;

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
        itemCount: messages.length,
        padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
        itemBuilder: (BuildContext context, int i) {
          final ChatMessage m = messages[i];
          final bool isOwn = isOwnSender(m.senderId);

          if (m.isSystem) {
            return Padding(
              padding: const EdgeInsets.only(bottom: ChatDesignSystem.spaceMd),
              child: Container(
                padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [ChatDesignSystem.colorInfo.withValues(alpha: 0.12), ChatDesignSystem.colorInfo.withValues(alpha: 0.04)]),
                  border: Border.all(color: ChatDesignSystem.colorInfo.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline_rounded, size: 16, color: ChatDesignSystem.colorInfo.withValues(alpha: 0.6)),
                    const SizedBox(width: ChatDesignSystem.spaceSm),
                    Expanded(
                      child: Text(
                        m.content,
                        style: TextStyle(fontSize: 12, color: ChatDesignSystem.colorTextSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final double maxBubbleWidth = math.min(520, MediaQuery.sizeOf(context).width * 0.78);

          return Padding(
            padding: const EdgeInsets.only(bottom: ChatDesignSystem.spaceMd),
            child: Align(
              alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: GestureDetector(
                  onLongPress: isOwn ? null : () => onMuteSender(m.senderId, m.senderName),
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
                                child: ChatPresenceNameRow(
                                  label: m.senderName,
                                  userId: m.senderId,
                                  online: isUserOnline(m.senderId, fallback: m.senderIsOnline),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: activeChannel.accentColor),
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
}
