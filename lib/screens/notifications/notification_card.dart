import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/notification_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// 2027 Aion 2 Mobile Rich Notification Card.
///
/// Features:
/// - Swipe-to-dismiss gesture with dynamic ruby/crimson progressive glow & haptics.
/// - Glassmorphism container with category accent glow and dot-grid micro texture.
/// - Dual-layer radial icon badge with glowing aura and archetype micro-pip.
/// - Luminous unread indicators: vertical edge lightbar and glowing neon beacon dot.
/// - Precise relative timestamps ("Şimdi", "5 dk", "2 sa", "Dün").
/// - Category pill and high-priority indicator badge.
/// - Deep-link navigation CTA chip with forward chevron.
class NotificationCard extends StatefulWidget {
  const NotificationCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDismiss,
    this.isUnread = true,
  });

  final GameNotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final bool isUnread;

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  double _dismissProgress = 0.0;
  bool _thresholdReached = false;

  @override
  Widget build(BuildContext context) {
    final GameNotificationItem item = widget.item;
    final Color accent = item.kind.accentColor;
    final bool isHighPriority = item.priority >= 75;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Dismissible(
        key: ValueKey<String>('dismiss_${item.id}'),
        direction: DismissDirection.endToStart,
        movementDuration: const Duration(milliseconds: 260),
        resizeDuration: const Duration(milliseconds: 220),
        onUpdate: (DismissUpdateDetails details) {
          if (details.reached != _thresholdReached) {
            _thresholdReached = details.reached;
            if (_thresholdReached) {
              HapticFeedback.mediumImpact();
            }
          }
          if ((details.progress - _dismissProgress).abs() > 0.02) {
            setState(() {
              _dismissProgress = details.progress;
            });
          }
        },
        onDismissed: (_) {
          HapticFeedback.heavyImpact();
          widget.onDismiss();
        },
        background: _buildDismissBackground(accent),
        secondaryBackground: _buildDismissBackground(accent),
        child: _NotificationCardBody(
          item: item,
          accent: accent,
          isHighPriority: isHighPriority,
          isUnread: widget.isUnread,
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          onDismiss: () {
            HapticFeedback.lightImpact();
            widget.onDismiss();
          },
        ),
      ),
    );
  }

  Widget _buildDismissBackground(Color accent) {
    return _DismissFeedbackBackground(
      progress: _dismissProgress,
      isReached: _thresholdReached,
      accent: accent,
    );
  }
}

/// Dynamic swipe-to-dismiss feedback background with progressive ruby glow & scaling icon.
class _DismissFeedbackBackground extends StatelessWidget {
  const _DismissFeedbackBackground({
    required this.progress,
    required this.isReached,
    required this.accent,
  });

  final double progress;
  final bool isReached;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final double clampedProgress = progress.clamp(0.0, 1.0);
    final double dynamicAlpha = (0.25 + (clampedProgress * 0.70)).clamp(0.0, 0.95);
    final double iconScale = (0.85 + (clampedProgress * 0.35)).clamp(0.85, 1.25);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              AppColors.mysticRuby.withValues(alpha: 0.08),
              AppColors.mysticRuby.withValues(alpha: dynamicAlpha * 0.45),
              AppColors.mysticRuby.withValues(alpha: dynamicAlpha),
            ],
            stops: const <double>[0.0, 0.45, 1.0],
          ),
          border: Border.all(
            color: isReached
                ? AppColors.mysticRuby
                : AppColors.mysticRuby.withValues(alpha: 0.45 + (clampedProgress * 0.45)),
            width: isReached ? 1.6 : 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.mysticRuby.withValues(alpha: 0.30 + (clampedProgress * 0.40)),
              blurRadius: isReached ? 22 : 14,
              spreadRadius: isReached ? 1 : -2,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: GoogleFonts.urbanist(
                color: Colors.white.withValues(alpha: isReached ? 1.0 : 0.82),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.3,
              ),
              child: const Text('KALDIR'),
            ),
            const SizedBox(width: 9),
            Transform.scale(
              scale: iconScale,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isReached
                      ? AppColors.mysticRuby
                      : Colors.black.withValues(alpha: 0.45),
                  border: Border.all(
                    color: isReached
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.mysticRuby.withValues(
                        alpha: isReached ? 0.8 : 0.4,
                      ),
                      blurRadius: isReached ? 16 : 8,
                      spreadRadius: isReached ? 2 : 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


enum _NotificationArchetype {
  combat,
  reward,
  social,
  system,
}

extension _NotificationKindArchetypeX on NotificationKind {
  _NotificationArchetype get archetype => switch (this) {
        NotificationKind.pvpInvite ||
        NotificationKind.pvpResult ||
        NotificationKind.nemesisRevenge ||
        NotificationKind.nemesisOnline ||
        NotificationKind.lowHealth ||
        NotificationKind.healthFull ||
        NotificationKind.classBuff =>
          _NotificationArchetype.combat,
        NotificationKind.dailyReward ||
        NotificationKind.questReward ||
        NotificationKind.referralReward ||
        NotificationKind.boxReady ||
        NotificationKind.codexNewEntry ||
        NotificationKind.codexMilestone =>
          _NotificationArchetype.reward,
        NotificationKind.friendRequest ||
        NotificationKind.friendRequestAccepted ||
        NotificationKind.friendRequestRejected ||
        NotificationKind.tradeInvite ||
        NotificationKind.chatMessage =>
          _NotificationArchetype.social,
        NotificationKind.facilityReady ||
        NotificationKind.hospital ||
        NotificationKind.hospitalDischarge ||
        NotificationKind.prison ||
        NotificationKind.nightMarketOpen ||
        NotificationKind.nightMarketEnding ||
        NotificationKind.bugReportUpdate ||
        NotificationKind.marketSale ||
        NotificationKind.craftReady =>
          _NotificationArchetype.system,
      };

  IconData get archetypeEmblem => switch (archetype) {
        _NotificationArchetype.combat => Icons.local_fire_department_rounded,
        _NotificationArchetype.reward => Icons.auto_awesome_rounded,
        _NotificationArchetype.social => Icons.all_inclusive_rounded,
        _NotificationArchetype.system => Icons.memory_rounded,
      };
}

class _NotificationCardBody extends StatefulWidget {
  const _NotificationCardBody({
    required this.item,
    required this.accent,
    required this.isHighPriority,
    required this.isUnread,
    required this.onTap,
    required this.onDismiss,
  });

  final GameNotificationItem item;
  final Color accent;
  final bool isHighPriority;
  final bool isUnread;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_NotificationCardBody> createState() => _NotificationCardBodyState();
}

class _NotificationCardBodyState extends State<_NotificationCardBody> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final GameNotificationItem item = widget.item;
    final Color accent = widget.accent;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.bgCardElevated.withValues(
                      alpha: widget.isUnread ? 0.92 : 0.82,
                    ),
                    AppColors.bgSurface.withValues(
                      alpha: widget.isUnread ? 0.95 : 0.88,
                    ),
                  ],
                ),
                border: Border.all(
                  color: widget.isHighPriority
                      ? AppColors.mysticRuby.withValues(alpha: 0.75)
                      : (widget.isUnread
                          ? accent.withValues(alpha: 0.45)
                          : accent.withValues(alpha: 0.22)),
                  width: widget.isHighPriority ? 1.4 : 1.1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (widget.isHighPriority ? AppColors.mysticRuby : accent)
                        .withValues(
                      alpha: widget.isHighPriority
                          ? 0.26
                          : (widget.isUnread ? 0.14 : 0.05),
                    ),
                    blurRadius: widget.isHighPriority ? 18 : 12,
                    spreadRadius: -2,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: AppColors.bgDeep.withValues(alpha: 0.65),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  // Ambient radial glow behind the icon badge
                  Positioned(
                    top: -24,
                    left: -24,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            accent.withValues(
                              alpha: widget.isHighPriority ? 0.22 : 0.12,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Dot Grid Micro Texture
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _NotificationDotGridPainter(
                        spacing: 16,
                        dotOpacity: 0.045,
                      ),
                    ),
                  ),
                  // Luminous Top Border Line
                  Positioned(
                    top: 0,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 1.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            widget.isHighPriority
                                ? AppColors.mysticRuby.withValues(alpha: 0.95)
                                : accent.withValues(alpha: 0.78),
                            Colors.transparent,
                          ],
                          stops: const <double>[0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Luminous Unread Vertical Edge Lightbar
                  if (widget.isUnread)
                    Positioned(
                      left: 0,
                      top: 10,
                      bottom: 10,
                      child: Container(
                        width: 3.5,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(3),
                            bottomRight: Radius.circular(3),
                          ),
                          color: widget.isHighPriority
                              ? AppColors.mysticRuby
                              : accent,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: (widget.isHighPriority
                                      ? AppColors.mysticRuby
                                      : accent)
                                  .withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Card Inner Padding
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      widget.isUnread ? 14 : 12,
                      12,
                      10,
                      12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Dual-Layer Radial Icon Badge with Archetype Emblem
                        _buildIconBadge(accent),
                        const SizedBox(width: AppSpacing.md),
                        // Content Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Header Row: Category Pill + Priority indicator + Unread Beacon + Relative Timestamp
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Flexible(
                                          child: _buildCategoryPill(accent),
                                        ),
                                        if (widget.isHighPriority) ...<Widget>[
                                          const SizedBox(width: 6),
                                          _buildPriorityIndicator(accent),
                                        ],
                                        if (widget.isUnread) ...<Widget>[
                                          const SizedBox(width: 6),
                                          _buildUnreadBeacon(accent),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildTimestamp(item.createdAt),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Title with 390x844 responsive wrapping (maxLines: 2)
                              Text(
                                item.title,
                                style: GoogleFonts.urbanist(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.25,
                                  height: 1.25,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              // Body Text with 390x844 responsive bounds (maxLines: 3)
                              Text(
                                item.body,
                                style: GoogleFonts.urbanist(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.38,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Deep-Link Navigation Action Chip (if actionable)
                              if (item.isActionable) ...<Widget>[
                                const SizedBox(height: AppSpacing.sm),
                                _buildActionChip(accent),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Quick Dismiss 'X' Button
                        _buildDismissButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconBadge(Color accent) {
    final IconData emblem = widget.item.kind.archetypeEmblem;

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent.withValues(alpha: 0.32),
                  accent.withValues(alpha: 0.09),
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.58),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.30),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.18),
                  ),
                ),
                Icon(
                  widget.item.kind.icon,
                  color: accent,
                  size: 22,
                ),
              ],
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgDeep,
                border: Border.all(
                  color: accent.withValues(alpha: 0.75),
                  width: 1.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                emblem,
                size: 9.5,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnreadBeacon(Color accent) {
    return Container(
      width: 6.5,
      height: 6.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.9),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: accent.withValues(alpha: 0.14),
        border: Border.all(
          color: accent.withValues(alpha: 0.38),
          width: 0.8,
        ),
      ),
      child: Text(
        widget.item.kind.sectionLabel.toUpperCase(),
        style: GoogleFonts.urbanist(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: accent,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPriorityIndicator(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: AppColors.mysticRuby.withValues(alpha: 0.22),
        border: Border.all(
          color: AppColors.mysticRuby.withValues(alpha: 0.55),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.mysticRuby,
            ),
          ),
          const SizedBox(width: 3.5),
          Text(
            'ÖNEMLİ',
            style: GoogleFonts.urbanist(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.mysticRuby,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp(DateTime dateTime) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.access_time_rounded,
          size: 11,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 3),
        Text(
          _formatRelativeTime(dateTime),
          style: GoogleFonts.urbanist(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionChip(Color accent) {
    final String ctaLabel = _resolveActionLabel(widget.item);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: accent.withValues(alpha: 0.12),
            border: Border.all(
              color: accent.withValues(alpha: 0.38),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  ctaLabel,
                  style: GoogleFonts.urbanist(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: accent,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDismissButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onDismiss();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: AppColors.bgDeep.withValues(alpha: 0.65),
              border: Border.all(
                color: AppColors.borderDefault.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.close_rounded,
              size: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  static String _resolveActionLabel(GameNotificationItem item) {
    return switch (item.kind) {
      NotificationKind.dailyReward => 'Ödülü Al',
      NotificationKind.questReward => 'Ödülü Topla',
      NotificationKind.boxReady => 'Kasayı Aç',
      NotificationKind.pvpInvite => 'Düelloya Git',
      NotificationKind.pvpResult => 'Sonucu Gör',
      NotificationKind.tradeInvite => 'Ticareti İncele',
      NotificationKind.friendRequest => 'İsteği Gör',
      NotificationKind.chatMessage => 'Sohbete Git',
      NotificationKind.facilityReady => 'Üretimi Al',
      NotificationKind.craftReady => 'Eşyayı Al',
      NotificationKind.marketSale => 'Pazara Git',
      NotificationKind.hospital => 'Hastaneye Git',
      NotificationKind.prison => 'Hapishaneye Git',
      NotificationKind.lowHealth => 'İksir Kullan',
      NotificationKind.codexNewEntry || NotificationKind.codexMilestone => 'Kodexi Aç',
      _ => 'Görüntüle',
    };
  }

  static String _formatRelativeTime(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays == 1) return 'Dün';
    if (diff.inDays < 7) return '${diff.inDays} g';
    return '${dateTime.day}.${dateTime.month}';
  }
}

class _NotificationDotGridPainter extends CustomPainter {
  const _NotificationDotGridPainter({
    this.spacing = 16,
    this.dotRadius = 1.0,
    this.dotOpacity = 0.045,
  });

  final double spacing;
  final double dotRadius;
  final double dotOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: dotOpacity)
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NotificationDotGridPainter oldDelegate) =>
      spacing != oldDelegate.spacing ||
      dotRadius != oldDelegate.dotRadius ||
      dotOpacity != oldDelegate.dotOpacity;
}
