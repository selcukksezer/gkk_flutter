import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/live_ticker_model.dart';
import '../../theme/app_colors.dart';

/// Kamp duyuru strip + bento kartları için glass token'ları.
abstract final class TickerPalette {
  static const Color void_ = AppColors.carbonVoid;
  static const Color navy = AppColors.spaceNavy;
  static const Color gold = AppColors.liquidGold;
  static const Color neon = AppColors.toxicNeon;
  static const Color fuchsia = AppColors.cyberFuchsia;
  static const Color ruby = AppColors.mysticRuby;
  static const Color textHi = Color(0xFFF2F6FF);
  static const Color textMid = Color(0xFFA9B7D0);
}

class LiveTickerVisual {
  const LiveTickerVisual({
    required this.icon,
    required this.accent,
    required this.label,
  });

  final String icon;
  final Color accent;
  final String label;

  static LiveTickerVisual forType(String type) {
    switch (type) {
      case 'dungeon_clear':
        return const LiveTickerVisual(icon: '⚔️', accent: TickerPalette.ruby, label: 'Boss');
      case 'enhance_success':
        return const LiveTickerVisual(icon: '✨', accent: TickerPalette.gold, label: 'Güçlendirme');
      case 'loot_rare':
        return const LiveTickerVisual(icon: '🎁', accent: TickerPalette.fuchsia, label: 'Nadir loot');
      case 'guild_war':
        return const LiveTickerVisual(icon: '🏰', accent: TickerPalette.neon, label: 'Lonca savaşı');
      case 'siege_win':
        return const LiveTickerVisual(icon: '🛡️', accent: TickerPalette.neon, label: 'Kuşatma');
      case 'siege_soon':
        return const LiveTickerVisual(icon: '🛡️', accent: TickerPalette.neon, label: 'Kuşatma yakında');
      case 'siege_start':
        return const LiveTickerVisual(icon: '🔥', accent: TickerPalette.ruby, label: 'Kuşatma başladı');
      case 'siege_live':
        return const LiveTickerVisual(icon: '🔥', accent: TickerPalette.ruby, label: 'Canlı kuşatma');
      case 'night_market':
        return const LiveTickerVisual(icon: '🌙', accent: TickerPalette.fuchsia, label: 'Gece Pazarı');
      case 'king_blessing':
        return const LiveTickerVisual(icon: '👑', accent: TickerPalette.gold, label: 'Kral indirimi');
      case 'king_gift':
        return const LiveTickerVisual(icon: '🎁', accent: TickerPalette.gold, label: 'Kral hediyesi');
      case 'staff_broadcast':
        return const LiveTickerVisual(icon: '📣', accent: TickerPalette.neon, label: 'Duyuru');
      case 'player_ban':
        return const LiveTickerVisual(icon: '🚫', accent: TickerPalette.ruby, label: 'Ban');
      default:
        return const LiveTickerVisual(icon: '📣', accent: TickerPalette.gold, label: 'Duyuru');
    }
  }
}

class TickerGlassShell extends StatelessWidget {
  const TickerGlassShell({
    super.key,
    required this.child,
    this.accent = TickerPalette.gold,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.radius = 999,
    this.onTap,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget body = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: TickerPalette.navy.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 12,
                spreadRadius: -2,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: body,
      ),
    );
  }
}

class TickerTypeChip extends StatelessWidget {
  const TickerTypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = TickerPalette.gold,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: accent.withValues(alpha: 0.22),
      checkmarkColor: accent,
      labelStyle: TextStyle(
        color: selected ? TickerPalette.textHi : TickerPalette.textMid,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected ? accent.withValues(alpha: 0.6) : Colors.white12,
      ),
      backgroundColor: Colors.black26,
    );
  }
}

class TickerBentoCard extends StatelessWidget {
  const TickerBentoCard({
    super.key,
    required this.text,
    required this.visual,
    this.createdAt,
  });

  final String text;
  final LiveTickerVisual visual;
  final DateTime? createdAt;

  String _timeAgo(DateTime? at) {
    if (at == null) return '';
    final Duration d = DateTime.now().difference(at.toLocal());
    if (d.inMinutes < 1) return 'Az önce';
    if (d.inHours < 1) return '${d.inMinutes} dk';
    if (d.inDays < 1) return '${d.inHours} sa';
    if (d.inDays < 7) return '${d.inDays} g';
    return '${at.day}.${at.month}';
  }

  @override
  Widget build(BuildContext context) {
    return TickerGlassShell(
      accent: visual.accent,
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: visual.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: visual.accent.withValues(alpha: 0.35)),
            ),
            child: Text(visual.icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      visual.label,
                      style: TextStyle(
                        color: visual.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(),
                    if (createdAt != null)
                      Text(
                        _timeAgo(createdAt),
                        style: const TextStyle(
                          color: TickerPalette.textMid,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    color: TickerPalette.textHi,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension LiveTickerItemVisual on LiveTickerItem {
  LiveTickerVisual get visual => LiveTickerVisual.forType(type);
}
