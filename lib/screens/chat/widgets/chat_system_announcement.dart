import 'package:flutter/material.dart';

import '../chat_design_system.dart';
import '../chat_models.dart';
import 'chat_item_preview_modal.dart';

/// System announcement banner featuring glowing Aion-2 runic borders and animated pulse.
class ChatSystemAnnouncementBanner extends StatefulWidget {
  const ChatSystemAnnouncementBanner({
    super.key,
    required this.message,
    this.onItemTap,
  });

  final ChatMessage message;
  final ValueChanged<ChatItemLink>? onItemTap;

  @override
  State<ChatSystemAnnouncementBanner> createState() => _ChatSystemAnnouncementBannerState();
}

class _ChatSystemAnnouncementBannerState extends State<ChatSystemAnnouncementBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.message.systemTone) {
      case 'danger':
        return const Color(0xFFEF4444); // Crimson Blood-Fire / Abyssal Boss
      case 'success':
        return const Color(0xFF10B981); // Emerald / Victory
      case 'warning':
        return const Color(0xFFFB923C); // Solar Flare Amber
      case 'legendary':
      case 'drop':
        return const Color(0xFFF59E0B); // Radiant Gold / Mythic Broadcast
      default:
        return const Color(0xFF38BDF8); // Aether Cyan / General Info
    }
  }

  IconData get _icon {
    switch (widget.message.systemTone) {
      case 'danger':
        return Icons.local_fire_department_rounded;
      case 'success':
        return Icons.military_tech_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'legendary':
      case 'drop':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  String get _runicLeftGlyph {
    switch (widget.message.systemTone) {
      case 'danger':
        return 'ᛉ᚛';
      case 'success':
        return 'ᛟ᚛';
      default:
        return 'ᚱ᚛';
    }
  }

  String get _runicRightGlyph {
    switch (widget.message.systemTone) {
      case 'danger':
        return '᚜ᛉ';
      case 'success':
        return '᚜ᛟ';
      default:
        return '᚜ᚱ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _accentColor;
    final List<ChatItemLink> itemLinks = widget.message.itemLinks ?? const <ChatItemLink>[];

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (BuildContext ctx, Widget? child) {
          final double glowVal = _glowAnimation.value;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.16 + (glowVal * 0.08)),
                  const Color(0xFF090D15).withValues(alpha: 0.95),
                  accent.withValues(alpha: 0.08 + (glowVal * 0.05)),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(ChatDesignSystem.radiusMd),
              border: Border.all(
                color: accent.withValues(alpha: glowVal),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: glowVal * 0.4),
                  blurRadius: 10 + (glowVal * 6),
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Runic Header Row
                Row(
                  children: <Widget>[
                    Text(
                      _runicLeftGlyph,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accent.withValues(alpha: 0.8),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(_icon, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'AION DUYURUSU',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Text(
                      formatChatTime(widget.message.timestamp),
                      style: TextStyle(
                        fontSize: 9,
                        color: accent.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _runicRightGlyph,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accent.withValues(alpha: 0.8),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Content
                Text(
                  widget.message.content,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                    height: 1.35,
                  ),
                ),

                // Embedded Item Links if any
                if (itemLinks.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: itemLinks.map((ChatItemLink item) {
                      return ChatItemLinkChip(
                        item: item,
                        onTap: () {
                          if (widget.onItemTap != null) {
                            widget.onItemTap!(item);
                          } else {
                            ChatItemPreviewModal.show(context, item);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
