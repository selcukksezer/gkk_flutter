import 'package:flutter/material.dart';

import '../chat_design_system.dart';

class OnlineStatusDot extends StatelessWidget {
  const OnlineStatusDot({super.key, required this.online, this.size = 7});

  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? ChatDesignSystem.colorOnline : ChatDesignSystem.colorOffline.withValues(alpha: 0.55),
        border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 1),
        boxShadow: online
            ? <BoxShadow>[
                BoxShadow(
                  color: ChatDesignSystem.colorOnline.withValues(alpha: 0.45),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }
}

class ChatPresenceNameRow extends StatelessWidget {
  const ChatPresenceNameRow({
    super.key,
    required this.label,
    required this.style,
    this.userId,
    this.online = false,
    this.showDot = true,
    this.dotSize = 7,
  });

  final String label;
  final String? userId;
  final bool online;
  final bool showDot;
  final TextStyle style;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showDot && userId != null && userId!.isNotEmpty) ...<Widget>[
          OnlineStatusDot(online: online, size: dotSize),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
