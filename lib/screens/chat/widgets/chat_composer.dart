import 'package:flutter/material.dart';

import '../../../components/layout/game_chrome.dart';
import '../chat_design_system.dart';
import '../chat_models.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.asPanel,
    required this.activeChannel,
    required this.activeBan,
    required this.messageController,
    required this.isSending,
    required this.maxMessageLength,
    required this.blockedUserCount,
    required this.onSend,
    required this.onOpenBlockedUsers,
  });

  final bool asPanel;
  final ChatChannel activeChannel;
  final ChatBan? activeBan;
  final TextEditingController messageController;
  final bool isSending;
  final int maxMessageLength;
  final int blockedUserCount;
  final VoidCallback onSend;
  final VoidCallback onOpenBlockedUsers;

  @override
  Widget build(BuildContext context) {
    final bool canSend = !isSending && activeBan == null && messageController.text.trim().isNotEmpty;
    final int charCount = messageController.text.length;
    final double bottomBarPadding = asPanel ? 0 : gameBottomBarClearance(context) - MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      bottom: asPanel,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomBarPadding),
        child: Container(
          padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (charCount > maxMessageLength * 0.8)
                Padding(
                  padding: const EdgeInsets.only(bottom: ChatDesignSystem.spaceMd),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '$charCount/$maxMessageLength',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: charCount >= maxMessageLength ? ChatDesignSystem.colorError : ChatDesignSystem.colorWarning,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.5),
                        border: Border.all(
                          color: activeBan != null
                              ? ChatDesignSystem.colorError.withValues(alpha: 0.3)
                              : activeChannel.accentColor.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                      ),
                      child: TextField(
                        controller: messageController,
                        enabled: activeBan == null,
                        maxLength: maxMessageLength,
                        maxLines: 1,
                        onSubmitted: (_) => onSend(),
                        style: const TextStyle(fontSize: 13, color: ChatDesignSystem.colorTextPrimary),
                        decoration: InputDecoration(
                          hintText: activeBan != null
                              ? 'Sohbete erişiminiz kısıtlı'
                              : activeChannel == ChatChannel.dm
                                  ? 'Mesaj yaz...'
                                  : '${activeChannel.label} kanalında yaz...',
                          hintStyle: TextStyle(fontSize: 13, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.4)),
                          counter: const Offstage(),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: ChatDesignSystem.spaceMd, vertical: ChatDesignSystem.spaceMd),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: ChatDesignSystem.spaceSm),
                  PopupMenuButton<String>(
                    tooltip: 'Sohbet seçenekleri',
                    icon: Icon(Icons.more_vert_rounded, size: 20, color: ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.8)),
                    color: ChatDesignSystem.colorBgSecondary,
                    onSelected: (String value) {
                      if (value == 'blocked') {
                        onOpenBlockedUsers();
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'blocked',
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.volume_off_rounded, size: 16, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text(
                              'Susturulanlar${blockedUserCount == 0 ? '' : ' ($blockedUserCount)'}',
                              style: const TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: ChatDesignSystem.spaceSm),
                  GestureDetector(
                    onTap: canSend ? onSend : null,
                    child: Container(
                      padding: const EdgeInsets.all(ChatDesignSystem.spaceMd),
                      decoration: BoxDecoration(
                        gradient: canSend
                            ? LinearGradient(colors: [activeChannel.accentColor.withValues(alpha: 0.4), activeChannel.accentColor.withValues(alpha: 0.2)])
                            : LinearGradient(colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04)]),
                        border: Border.all(color: canSend ? activeChannel.accentColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
                      ),
                      child: isSending
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(activeChannel.accentColor)),
                            )
                          : Icon(Icons.send_rounded, size: 16, color: canSend ? activeChannel.accentColor : Colors.white.withValues(alpha: 0.3)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
