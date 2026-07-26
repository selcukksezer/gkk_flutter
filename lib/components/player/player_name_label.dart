import 'package:flutter/material.dart';

import 'staff_badge.dart';

class PlayerNameLabel extends StatelessWidget {
  const PlayerNameLabel({
    super.key,
    required this.username,
    this.displayName,
    this.staffBadge,
    this.kingBadge,
    this.style,
    this.showUsername = true,
    this.compactBadge = false,
    this.onTap,
    this.onLongPress,
  });

  final String username;
  final String? displayName;
  final String? staffBadge;
  final String? kingBadge;
  final TextStyle? style;
  final bool showUsername;
  final bool compactBadge;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  String get _primary {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    return username;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle base = style ??
        const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        );

    final Widget label = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(_primary, style: base, maxLines: 1, overflow: TextOverflow.ellipsis),
        StaffBadge(badge: staffBadge, compact: compactBadge),
        StaffBadge(badge: kingBadge, compact: compactBadge),
        if (showUsername && displayName != null && displayName!.trim().isNotEmpty)
          Text(
            ' @$username',
            style: base.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: (base.fontSize ?? 14) - 1,
              color: base.color?.withValues(alpha: 0.65),
            ),
          ),
      ],
    );

    if (onTap == null && onLongPress == null) return label;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: label,
    );
  }
}
