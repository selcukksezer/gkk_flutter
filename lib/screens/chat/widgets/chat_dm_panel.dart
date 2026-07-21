import 'package:flutter/material.dart';

import '../chat_design_system.dart';
import '../chat_models.dart';
import 'chat_message_list.dart';
import 'chat_presence.dart';

class ChatDmPanel extends StatelessWidget {
  const ChatDmPanel({
    super.key,
    required this.activePeer,
    required this.dmSearchController,
    required this.isDmSearchLoading,
    required this.isDmLoading,
    required this.dmSearchResults,
    required this.dmConversations,
    required this.isLoadingMessages,
    required this.messages,
    required this.scrollController,
    required this.isOwnSender,
    required this.isUserOnline,
    required this.peerPresenceFallback,
    required this.onSearchChanged,
    required this.onOpenConversation,
    required this.onConversationLongPress,
    required this.onMutePeer,
    required this.onLeaveConversation,
    required this.onMuteSender,
  });

  final ChatUserSummary? activePeer;
  final TextEditingController dmSearchController;
  final bool isDmSearchLoading;
  final bool isDmLoading;
  final List<ChatUserSummary> dmSearchResults;
  final List<ChatDmConversation> dmConversations;
  final bool isLoadingMessages;
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final bool Function(String senderId) isOwnSender;
  final bool Function(String userId, {bool? fallback}) isUserOnline;
  final bool? Function(String peerUserId) peerPresenceFallback;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ChatUserSummary> onOpenConversation;
  final ValueChanged<ChatDmConversation> onConversationLongPress;
  final VoidCallback onMutePeer;
  final VoidCallback onLeaveConversation;
  final void Function(String senderId, String senderName) onMuteSender;

  @override
  Widget build(BuildContext context) {
    if (activePeer == null) {
      return Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [ChatDesignSystem.colorDmAccent.withValues(alpha: 0.08), ChatDesignSystem.colorDmAccent.withValues(alpha: 0.02)]),
              border: Border(bottom: BorderSide(color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.1))),
            ),
            child: const Text('Sohbet & Mesajlaşma', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
              child: Column(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.5),
                      border: Border.all(color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                    ),
                    child: TextField(
                      controller: dmSearchController,
                      onChanged: onSearchChanged,
                      style: const TextStyle(fontSize: 13, color: ChatDesignSystem.colorTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Oyuncu adı ile ara...',
                        hintStyle: TextStyle(fontSize: 13, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.4)),
                        suffixIcon: isDmSearchLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: Padding(
                                  padding: const EdgeInsets.all(ChatDesignSystem.spaceSm),
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(ChatDesignSystem.colorDmAccent.withValues(alpha: 0.6))),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: ChatDesignSystem.spaceMd, vertical: ChatDesignSystem.spaceSm),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (dmSearchResults.isNotEmpty) ...<Widget>[
                    const SizedBox(height: ChatDesignSystem.spaceMd),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: ChatDesignSystem.gradientBgPanel,
                          border: Border.all(color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusLg),
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.search_rounded, size: 14, color: ChatDesignSystem.colorDmAccent),
                                  const SizedBox(width: ChatDesignSystem.spaceSm),
                                  Text(
                                    'Arama Sonuçları (${dmSearchResults.length})',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ChatDesignSystem.colorDmAccent),
                                  ),
                                ],
                              ),
                            ),
                            ...dmSearchResults.map((ChatUserSummary user) {
                              return GestureDetector(
                                onTap: () => onOpenConversation(user),
                                child: Container(
                                  color: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: ChatDesignSystem.spaceMd, vertical: ChatDesignSystem.spaceSm),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(gradient: ChatDesignSystem.gradientDm, borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd)),
                                        child: Center(
                                          child: Text(
                                            user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ChatDesignSystem.colorTextPrimary),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: ChatDesignSystem.spaceMd),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            ChatPresenceNameRow(
                                              label: '@${user.username}',
                                              userId: user.id,
                                              online: isUserOnline(user.id, fallback: user.isOnline),
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ChatDesignSystem.colorTextPrimary),
                                            ),
                                            if (user.displayName != null)
                                              Text(
                                                user.displayName!,
                                                style: const TextStyle(fontSize: 10, color: ChatDesignSystem.colorTextTertiary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: ChatDesignSystem.spaceMd, vertical: ChatDesignSystem.spaceXs),
                                        decoration: BoxDecoration(
                                          color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                                        ),
                                        child: Text('Yaz', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ChatDesignSystem.colorDmAccent)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: ChatDesignSystem.spaceMd),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: ChatDesignSystem.gradientBgPanel,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusXl),
                        boxShadow: ChatDesignSystem.shadowMd,
                      ),
                      child: isDmLoading
                          ? const Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2)))
                          : dmConversations.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Icon(Icons.mail_outline_rounded, size: 48, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.3)),
                                      const SizedBox(height: ChatDesignSystem.spaceMd),
                                      Text('Henüz sohbet yok', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ChatDesignSystem.colorTextTertiary)),
                                      const SizedBox(height: ChatDesignSystem.spaceXs),
                                      Text('Oyuncu arayarak mesaj başlat', style: TextStyle(fontSize: 11, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.6))),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
                                  itemCount: dmConversations.length,
                                  separatorBuilder: (BuildContext context, int index) => const SizedBox(height: ChatDesignSystem.spaceSm),
                                  itemBuilder: (BuildContext context, int idx) {
                                    final ChatDmConversation conv = dmConversations[idx];
                                    return _DmConversationCard(
                                      conversation: conv,
                                      isUserOnline: isUserOnline,
                                      onTap: () => onOpenConversation(
                                        ChatUserSummary(id: conv.peerUserId, username: conv.peerUsername, displayName: conv.peerDisplayName),
                                      ),
                                      onLongPress: () => onConversationLongPress(conv),
                                    );
                                  },
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [ChatDesignSystem.colorDmAccent.withValues(alpha: 0.12), ChatDesignSystem.colorDmAccent.withValues(alpha: 0.04)]),
            border: Border(bottom: BorderSide(color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(gradient: ChatDesignSystem.gradientDm, borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd)),
                child: Center(
                  child: Text(
                    activePeer!.username.isNotEmpty ? activePeer!.username[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ChatDesignSystem.colorTextPrimary),
                  ),
                ),
              ),
              const SizedBox(width: ChatDesignSystem.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ChatPresenceNameRow(
                      label: '@${activePeer!.username}',
                      userId: activePeer!.id,
                      online: isUserOnline(activePeer!.id, fallback: peerPresenceFallback(activePeer!.id)),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ChatDesignSystem.colorTextPrimary),
                      dotSize: 8,
                    ),
                    if (activePeer!.displayName != null)
                      Text(
                        activePeer!.displayName!,
                        style: const TextStyle(fontSize: 11, color: ChatDesignSystem.colorTextTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onMutePeer,
                child: Container(
                  padding: const EdgeInsets.all(ChatDesignSystem.spaceSm),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.volume_off_rounded, size: 16, color: ChatDesignSystem.colorTextTertiary),
                ),
              ),
              const SizedBox(width: ChatDesignSystem.spaceSm),
              GestureDetector(
                onTap: onLeaveConversation,
                child: Container(
                  padding: const EdgeInsets.all(ChatDesignSystem.spaceSm),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: ChatDesignSystem.colorTextTertiary),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ChatMessageList(
            isLoading: isLoadingMessages,
            messages: messages,
            activeChannel: ChatChannel.dm,
            scrollController: scrollController,
            isOwnSender: isOwnSender,
            isUserOnline: isUserOnline,
            onMuteSender: onMuteSender,
          ),
        ),
      ],
    );
  }
}

class _DmConversationCard extends StatelessWidget {
  const _DmConversationCard({
    required this.conversation,
    required this.isUserOnline,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatDmConversation conversation;
  final bool Function(String userId, {bool? fallback}) isUserOnline;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.02)]),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: ChatDesignSystem.gradientDm,
                borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                border: Border.all(color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(
                  conversation.peerUsername.isNotEmpty ? conversation.peerUsername[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ChatDesignSystem.colorTextPrimary),
                ),
              ),
            ),
            const SizedBox(width: ChatDesignSystem.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ChatPresenceNameRow(
                          label: '@${conversation.peerUsername}',
                          userId: conversation.peerUserId,
                          online: isUserOnline(conversation.peerUserId, fallback: conversation.peerIsOnline),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: conversation.unreadCount > 0 ? FontWeight.w800 : FontWeight.w700,
                            color: ChatDesignSystem.colorTextPrimary,
                          ),
                        ),
                      ),
                      Text(
                        formatChatTime(conversation.lastMessageAt),
                        style: TextStyle(fontSize: 10, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: ChatDesignSystem.spaceXs),
                  Text(
                    conversation.lastMessageContent,
                    style: TextStyle(fontSize: 11, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (conversation.unreadCount > 0) ...<Widget>[
              const SizedBox(width: ChatDesignSystem.spaceMd),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 28),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: ChatDesignSystem.spaceSm, vertical: ChatDesignSystem.spaceXs),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [ChatDesignSystem.colorDmAccent.withValues(alpha: 0.3), ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15)]),
                    border: Border.all(color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(ChatDesignSystem.radiusRound),
                  ),
                  child: Text(
                    conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ChatDesignSystem.colorDmAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
