import 'package:flutter/material.dart';

import '../chat_design_system.dart';
import '../chat_models.dart';

class ChatChannelBar extends StatelessWidget {
  const ChatChannelBar({
    super.key,
    required this.activeChannel,
    required this.guildUnreadCount,
    required this.dmUnreadCount,
    required this.onChannelSelected,
  });

  final ChatChannel activeChannel;
  final int guildUnreadCount;
  final int dmUnreadCount;
  final ValueChanged<ChatChannel> onChannelSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: ChatDesignSystem.spaceMd),
      child: Row(
        children: <Widget>[
          ...ChatChannel.values.map((ChatChannel c) {
            final bool active = c == activeChannel;
            final int badge = c == ChatChannel.guild
                ? guildUnreadCount
                : c == ChatChannel.dm
                    ? dmUnreadCount
                    : 0;

            return Padding(
              padding: const EdgeInsets.only(right: ChatDesignSystem.spaceMd),
              child: GestureDetector(
                onTap: () => onChannelSelected(c),
                child: AnimatedContainer(
                  duration: ChatDesignSystem.durationBase,
                  curve: ChatDesignSystem.curveEaseInOut,
                  padding: const EdgeInsets.symmetric(horizontal: ChatDesignSystem.spaceLg, vertical: ChatDesignSystem.spaceSm),
                  decoration: BoxDecoration(
                    gradient: active ? c.gradient : const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
                    border: Border.all(
                      color: active ? c.accentColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
                      width: active ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(ChatDesignSystem.radiusXl),
                    boxShadow: active ? ChatDesignSystem.shadowMd : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? c.accentColor : ChatDesignSystem.colorTextTertiary,
                        ),
                      ),
                      if (badge > 0) ...<Widget>[
                        const SizedBox(width: ChatDesignSystem.spaceSm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: ChatDesignSystem.spaceSm, vertical: ChatDesignSystem.spaceXs),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [c.accentColor.withValues(alpha: 0.3), c.accentColor.withValues(alpha: 0.15)]),
                            border: Border.all(color: c.accentColor.withValues(alpha: 0.4), width: 0.8),
                            borderRadius: BorderRadius.circular(ChatDesignSystem.radiusRound),
                          ),
                          child: Text(
                            badge > 99 ? '99+' : '$badge',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.accentColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
