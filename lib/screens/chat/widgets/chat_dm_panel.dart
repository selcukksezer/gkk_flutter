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
    this.canModerateMessages = false,
    this.onModerateMessage,
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
  final bool canModerateMessages;
  final void Function(ChatMessage message, String action)? onModerateMessage;

  @override
  Widget build(BuildContext context) {
    if (activePeer == null) {
      final int totalUnreadCount = dmConversations.fold<int>(
        0,
        (int acc, ChatDmConversation c) => acc + c.unreadCount,
      );

      return Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ChatDesignSystem.spaceMd,
              vertical: ChatDesignSystem.spaceSm + 2,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  ChatDesignSystem.colorDmAccent.withValues(alpha: 0.12),
                  ChatDesignSystem.colorDmAccent.withValues(alpha: 0.02),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(ChatDesignSystem.radiusSm),
                    border: Border.all(
                      color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    size: 14,
                    color: ChatDesignSystem.colorDmAccent,
                  ),
                ),
                const SizedBox(width: ChatDesignSystem.spaceSm),
                const Expanded(
                  child: Text(
                    'Fısıltı & Direkt Mesajlar',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: ChatDesignSystem.colorTextPrimary,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (totalUnreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFFFF2A6D), Color(0xFFD8005A)],
                      ),
                      borderRadius: BorderRadius.circular(ChatDesignSystem.radiusRound),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFFFF2A6D).withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      '$totalUnreadCount Yeni',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(ChatDesignSystem.radiusRound),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    '${dmConversations.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
              child: Column(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.65),
                      border: Border.all(
                        color: dmSearchController.text.isNotEmpty
                            ? ChatDesignSystem.colorDmAccent.withValues(alpha: 0.45)
                            : ChatDesignSystem.colorDmAccent.withValues(alpha: 0.2),
                        width: 1.1,
                      ),
                      borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                      boxShadow: dmSearchController.text.isNotEmpty
                          ? <BoxShadow>[
                              BoxShadow(
                                color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.1),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: TextField(
                      controller: dmSearchController,
                      onChanged: onSearchChanged,
                      style: const TextStyle(fontSize: 13, color: ChatDesignSystem.colorTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Oyuncu adı ile ara...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.55),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.65),
                        ),
                        suffixIcon: isDmSearchLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: Padding(
                                  padding: const EdgeInsets.all(ChatDesignSystem.spaceSm),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      ChatDesignSystem.colorDmAccent.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ),
                              )
                            : dmSearchController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      dmSearchController.clear();
                                      onSearchChanged('');
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.7),
                                    ),
                                  )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: ChatDesignSystem.spaceMd,
                          vertical: ChatDesignSystem.spaceSm + 2,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (dmSearchResults.isNotEmpty) ...<Widget>[
                    const SizedBox(height: ChatDesignSystem.spaceSm),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: ChatDesignSystem.gradientBgPanel,
                          border: Border.all(
                            color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.25),
                          ),
                          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusLg),
                          boxShadow: ChatDesignSystem.shadowMd,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusLg),
                          child: ListView(
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ChatDesignSystem.spaceMd,
                                  vertical: ChatDesignSystem.spaceSm,
                                ),
                                decoration: BoxDecoration(
                                  color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.08),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(Icons.search_rounded, size: 14, color: ChatDesignSystem.colorDmAccent),
                                    const SizedBox(width: ChatDesignSystem.spaceSm),
                                    Text(
                                      'Arama Sonuçları (${dmSearchResults.length})',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: ChatDesignSystem.colorDmAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...dmSearchResults.map((ChatUserSummary user) {
                                final bool userOnline = isUserOnline(user.id, fallback: user.isOnline);
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => onOpenConversation(user),
                                    hoverColor: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.06),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: ChatDesignSystem.spaceMd,
                                        vertical: ChatDesignSystem.spaceSm,
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          _DmAvatar(
                                            username: user.username,
                                            isOnline: userOnline,
                                            size: 32,
                                          ),
                                          const SizedBox(width: ChatDesignSystem.spaceMd),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                ChatPresenceNameRow(
                                                  label: '@${user.username}',
                                                  userId: user.id,
                                                  online: userOnline,
                                                  showDot: false,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: ChatDesignSystem.colorTextPrimary,
                                                  ),
                                                ),
                                                if (user.displayName != null && user.displayName!.isNotEmpty)
                                                  Text(
                                                    user.displayName!,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: ChatDesignSystem.colorTextTertiary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: ChatDesignSystem.spaceMd,
                                              vertical: ChatDesignSystem.spaceXs + 1,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: <Color>[
                                                  ChatDesignSystem.colorDmAccent.withValues(alpha: 0.25),
                                                  ChatDesignSystem.colorDmAccent.withValues(alpha: 0.1),
                                                ],
                                              ),
                                              border: Border.all(
                                                color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.35),
                                              ),
                                              borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                                            ),
                                            child: const Text(
                                              'Yaz',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: ChatDesignSystem.colorDmAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else if (dmSearchController.text.trim().length >= 2 && !isDmSearchLoading) ...<Widget>[
                    const SizedBox(height: ChatDesignSystem.spaceSm),
                    Container(
                      padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
                      decoration: BoxDecoration(
                        color: ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.4),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.person_search_rounded,
                            size: 16,
                            color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: ChatDesignSystem.spaceSm),
                          Expanded(
                            child: Text(
                              '"${dmSearchController.text.trim()}" ile eşleşen oyuncu bulunamadı',
                              style: TextStyle(
                                fontSize: 11,
                                color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                          ? const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    ChatDesignSystem.colorDmAccent,
                                  ),
                                ),
                              ),
                            )
                          : dmConversations.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(ChatDesignSystem.spaceLg),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: <Widget>[
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: <Color>[
                                                ChatDesignSystem.colorDmAccent.withValues(alpha: 0.2),
                                                ChatDesignSystem.colorDmAccent.withValues(alpha: 0.02),
                                              ],
                                            ),
                                            border: Border.all(
                                              color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.forum_outlined,
                                            size: 28,
                                            color: ChatDesignSystem.colorDmAccent,
                                          ),
                                        ),
                                        const SizedBox(height: ChatDesignSystem.spaceMd),
                                        const Text(
                                          'Henüz fısıltı yok',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: ChatDesignSystem.colorTextPrimary,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: ChatDesignSystem.spaceXs),
                                        Text(
                                          'Yukarıdan bir oyuncu arayarak özel sohbet başlatabilirsiniz.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.7),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
                                  itemCount: dmConversations.length,
                                  separatorBuilder: (BuildContext context, int index) =>
                                      const SizedBox(height: ChatDesignSystem.spaceSm),
                                  itemBuilder: (BuildContext context, int idx) {
                                    final ChatDmConversation conv = dmConversations[idx];
                                    return _DmConversationCard(
                                      conversation: conv,
                                      isUserOnline: isUserOnline,
                                      onTap: () => onOpenConversation(
                                        ChatUserSummary(
                                          id: conv.peerUserId,
                                          username: conv.peerUsername,
                                          displayName: conv.peerDisplayName,
                                        ),
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

    final ChatUserSummary peer = activePeer!;
    final bool peerOnline = isUserOnline(
      peer.id,
      fallback: peerPresenceFallback(peer.id) ?? peer.isOnline,
    );

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ChatDesignSystem.spaceMd,
            vertical: ChatDesignSystem.spaceSm + 2,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15),
                ChatDesignSystem.colorDmAccent.withValues(alpha: 0.03),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              Tooltip(
                message: 'Geri dön',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onLeaveConversation,
                    borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.all(ChatDesignSystem.spaceSm),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 14,
                        color: ChatDesignSystem.colorTextSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ChatDesignSystem.spaceSm + 2),
              _DmAvatar(
                username: peer.username,
                isOnline: peerOnline,
                size: 36,
              ),
              const SizedBox(width: ChatDesignSystem.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ChatPresenceNameRow(
                      label: '@${peer.username}',
                      userId: peer.id,
                      online: peerOnline,
                      showDot: false,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ChatDesignSystem.colorTextPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: <Widget>[
                        Text(
                          peerOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: peerOnline
                                ? ChatDesignSystem.colorOnline
                                : ChatDesignSystem.colorOffline,
                          ),
                        ),
                        if (peer.displayName != null && peer.displayName!.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '• ${peer.displayName!}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: ChatDesignSystem.colorTextTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Oyuncuyu Sustur',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onMutePeer,
                    borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.all(ChatDesignSystem.spaceSm),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(
                        Icons.volume_off_rounded,
                        size: 16,
                        color: ChatDesignSystem.colorTextTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ChatDesignSystem.spaceSm),
              Tooltip(
                message: 'Görüşmeden Ayrıl',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onLeaveConversation,
                    borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.all(ChatDesignSystem.spaceSm),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: ChatDesignSystem.colorTextTertiary,
                      ),
                    ),
                  ),
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
            canModerateMessages: canModerateMessages,
            onModerateMessage: onModerateMessage,
          ),
        ),
      ],
    );
  }
}

class _DmAvatar extends StatelessWidget {
  const _DmAvatar({
    required this.username,
    required this.isOnline,
    this.size = 38,
  });

  final String username;
  final bool isOnline;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String initial = username.trim().isNotEmpty ? username.trim()[0].toUpperCase() : '?';
    final double badgeSize = (size * 0.28).clamp(8.0, 11.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: ChatDesignSystem.gradientDm,
              borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
              border: Border.all(
                color: isOnline
                    ? ChatDesignSystem.colorOnline.withValues(alpha: 0.35)
                    : ChatDesignSystem.colorDmAccent.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: isOnline
                      ? ChatDesignSystem.colorOnline.withValues(alpha: 0.12)
                      : ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w800,
                  color: ChatDesignSystem.colorTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline
                    ? ChatDesignSystem.colorOnline
                    : ChatDesignSystem.colorOffline.withValues(alpha: 0.55),
                border: Border.all(color: const Color(0xFF090D15), width: 1.8),
                boxShadow: isOnline
                    ? <BoxShadow>[
                        BoxShadow(
                          color: ChatDesignSystem.colorOnline.withValues(alpha: 0.6),
                          blurRadius: 5,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DmUnreadBadge extends StatelessWidget {
  const _DmUnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final String text = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFF2A6D), Color(0xFFD8005A)],
        ),
        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusRound),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFFF2A6D).withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
      ),
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
    final bool online = isUserOnline(
      conversation.peerUserId,
      fallback: conversation.peerIsOnline,
    );
    final bool hasUnread = conversation.unreadCount > 0;
    final String snippet = conversation.lastMessageContent.trim().isNotEmpty
        ? conversation.lastMessageContent
        : 'Sohbet başlatıldı';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
        splashColor: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15),
        highlightColor: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.08),
        hoverColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ChatDesignSystem.spaceMd,
            vertical: ChatDesignSystem.spaceSm + 2,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: hasUnread
                  ? <Color>[
                      ChatDesignSystem.colorDmAccent.withValues(alpha: 0.12),
                      ChatDesignSystem.colorDmAccent.withValues(alpha: 0.03),
                    ]
                  : <Color>[
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.015),
                    ],
            ),
            border: Border.all(
              color: hasUnread
                  ? ChatDesignSystem.colorDmAccent.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
              width: hasUnread ? 1.2 : 1.0,
            ),
            borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
            boxShadow: hasUnread
                ? <BoxShadow>[
                    BoxShadow(
                      color: ChatDesignSystem.colorDmAccent.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: <Widget>[
              _DmAvatar(
                username: conversation.peerUsername,
                isOnline: online,
                size: 38,
              ),
              const SizedBox(width: ChatDesignSystem.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ChatPresenceNameRow(
                            label: '@${conversation.peerUsername}',
                            userId: conversation.peerUserId,
                            online: online,
                            showDot: false,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                              color: hasUnread
                                  ? ChatDesignSystem.colorTextPrimary
                                  : ChatDesignSystem.colorTextSecondary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatChatTime(conversation.lastMessageAt),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            color: hasUnread
                                ? ChatDesignSystem.colorDmAccent
                                : ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      snippet,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        color: hasUnread
                            ? ChatDesignSystem.colorTextSecondary
                            : ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.75),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasUnread) ...<Widget>[
                const SizedBox(width: ChatDesignSystem.spaceSm),
                _DmUnreadBadge(count: conversation.unreadCount),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
