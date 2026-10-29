import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/services/app_haptics.dart';
import '../chat_design_system.dart';
import '../chat_models.dart';

class ChatChannelBar extends StatelessWidget {
  const ChatChannelBar({
    super.key,
    required this.activeChannel,
    required this.guildUnreadCount,
    required this.dmUnreadCount,
    required this.onChannelSelected,
    this.partyUnreadCount = 0,
    this.systemUnreadCount = 0,
    this.tradeUnreadCount = 0,
    this.chatBoxMode,
    this.onToggleMode,
  });

  final ChatChannel activeChannel;
  final int guildUnreadCount;
  final int dmUnreadCount;
  final int partyUnreadCount;
  final int systemUnreadCount;
  final int tradeUnreadCount;
  final ValueChanged<ChatChannel> onChannelSelected;
  final dynamic chatBoxMode;
  final VoidCallback? onToggleMode;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: ChatDesignSystem.blurGlassSigma,
          sigmaY: ChatDesignSystem.blurGlassSigma,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.72),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0F172A).withValues(alpha: 0.75),
                ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.88),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              bottom: BorderSide(
                color: activeChannel.accentColor.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: activeChannel.accentColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: ChatDesignSystem.spaceMd,
                    vertical: 2,
                  ),
                  child: Row(
                    children: <Widget>[
                      ...ChatChannel.values.map((ChatChannel c) {
                        return _buildChannelTab(c);
                      }),
                    ],
                  ),
                ),
              ),
              if (onToggleMode != null) ...<Widget>[
                _buildModeToggleButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelTab(ChatChannel c) {
    final bool active = c == activeChannel;
    final int badge = switch (c) {
      ChatChannel.guild => guildUnreadCount,
      ChatChannel.dm => dmUnreadCount,
      ChatChannel.party => partyUnreadCount,
      ChatChannel.system => systemUnreadCount,
      ChatChannel.trade => tradeUnreadCount,
      _ => 0,
    };

    final Color badgeTextColor = c.accentColor.computeLuminance() > 0.4
        ? const Color(0xFF0F172A)
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!active) {
              AppHaptics.selection();
              onChannelSelected(c);
            }
          },
          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusXl),
          splashColor: c.accentColor.withValues(alpha: 0.2),
          highlightColor: c.accentColor.withValues(alpha: 0.1),
          child: AnimatedContainer(
            duration: ChatDesignSystem.durationBase,
            curve: ChatDesignSystem.curveEaseInOut,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              gradient: active
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        c.accentColor.withValues(alpha: 0.28),
                        c.accentColor.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.35),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.035),
                        Colors.white.withValues(alpha: 0.015),
                      ],
                    ),
              border: Border.all(
                color: active
                    ? c.accentColor.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.08),
                width: active ? 1.4 : 1,
              ),
              borderRadius: BorderRadius.circular(ChatDesignSystem.radiusXl),
              boxShadow: active
                  ? <BoxShadow>[
                      BoxShadow(
                        color: c.accentColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: c.accentColor.withValues(alpha: 0.18),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  c.icon,
                  size: 14,
                  color: active ? c.accentColor : ChatDesignSystem.colorTextTertiary,
                  shadows: active
                      ? <Shadow>[
                          Shadow(
                            color: c.accentColor.withValues(alpha: 0.7),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  c.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: active ? 0.3 : 0.2,
                    color: active ? Colors.white : ChatDesignSystem.colorTextTertiary,
                    shadows: active
                        ? <Shadow>[
                            Shadow(
                              color: c.accentColor.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (active) ...<Widget>[
                  const SizedBox(width: 5),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accentColor,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: c.accentColor,
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
                if (badge > 0) ...<Widget>[
                  const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: ChatDesignSystem.durationBase,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c.accentColor,
                          c.accentColor.withValues(alpha: 0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(ChatDesignSystem.radiusRound),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: c.accentColor.withValues(alpha: 0.55),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        height: 1.1,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggleButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AppHaptics.light();
            onToggleMode?.call();
          },
          borderRadius: BorderRadius.circular(ChatDesignSystem.radiusSm),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(ChatDesignSystem.radiusSm),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: const Tooltip(
              message: 'Görünüm Boyutu',
              child: Icon(
                Icons.aspect_ratio_rounded,
                size: 16,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
