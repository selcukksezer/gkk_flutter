import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../settings/graphics_settings_provider.dart';
import '../../settings/graphics_settings_service.dart';
import '../models/announcement_models.dart';
import '../services/announcements_repository.dart';
import 'event_countdown_pill.dart';
import 'patch_notes_viewer.dart';

/// Bento announcement card elevated to 2027 AAA Studio V3 standards.
///
/// Features:
/// - Frosted glassmorphism container with AdaptiveQualityScaler integration (zero-jank on Eco tier).
/// - Luminous announcement tags and luxury typography (GoogleFonts.plusJakartaSans & JetBrains Mono).
/// - Priority badges (Urgent ending events, claimable gift rewards, unread glow pip, version pill).
/// - Real vector icon bindings with dual-layer runic bevel, radial glow aura, and metallic trim.
/// - Tactile haptic feedback and press scale animation for 390x844 responsive mobile screens.
/// - Custom painter with multi-stop luminous border, specular glass gleam, and Aion 2 runic corner brackets.
class AnnouncementCard extends ConsumerStatefulWidget {
  const AnnouncementCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final AnnouncementItem item;
  final VoidCallback? onTap;

  @override
  ConsumerState<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends ConsumerState<AnnouncementCard> {
  bool _isPressed = false;

  String _timeAgo(DateTime at) {
    final Duration d = DateTime.now().difference(at.toLocal());
    if (d.isNegative || d.inMinutes < 1) return 'Az önce';
    if (d.inHours < 1) return '${d.inMinutes} dk';
    if (d.inDays < 1) return '${d.inHours} sa';
    if (d.inDays < 7) return '${d.inDays} g';
    return '${at.day}.${at.month}';
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      PatchNotesViewerModal.show(
        context: context,
        item: widget.item,
        ref: ref,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AnnouncementItem item = widget.item;
    final AnnouncementsScreenState state =
        ref.watch(announcementsControllerProvider);
    final bool isRead = state.readIds.contains(item.id);
    final bool isClaimed = state.claimedIds.contains(item.id);
    final bool hasUnclaimedGift = item.rewards.isNotEmpty && !isClaimed;
    final bool isUrgentEvent =
        item.hasEventSchedule && item.eventStatus == EventStatus.endingSoon;

    // Adaptive Quality tier scaling
    final GraphicsConfigData? graphicsConfig =
        ref.watch(graphicsSettingsProvider);
    final GraphicsQualityTier tier =
        graphicsConfig?.tier ?? GraphicsQualityTier.med;
    final bool isEcoTier = tier == GraphicsQualityTier.eco;
    final double blurSigma =
        isEcoTier ? 0.0 : (tier == GraphicsQualityTier.low ? 6.0 : 14.0);

    final BorderRadius cardRadius = BorderRadius.circular(16);
    final double borderWidth = isRead ? 1.0 : 1.4;

    final Gradient surfaceGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isEcoTier
          ? (isRead
              ? const <Color>[
                  Color(0xFF0E1422),
                  Color(0xFF090D18),
                  AppColors.carbonVoid,
                ]
              : <Color>[
                  item.accentColor.withValues(alpha: 0.14),
                  const Color(0xFF0E1526),
                  AppColors.carbonVoid,
                ])
          : (isRead
              ? <Color>[
                  const Color(0xDD0D1322),
                  const Color(0xCC090D18),
                  AppColors.carbonVoid.withValues(alpha: 0.88),
                ]
              : <Color>[
                  item.accentColor.withValues(alpha: 0.20),
                  const Color(0xE80D1424),
                  AppColors.carbonVoid.withValues(alpha: 0.92),
                ]),
      stops: const <double>[0.0, 0.45, 1.0],
    );

    final Gradient borderGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isRead
          ? <Color>[
              Colors.white.withValues(alpha: 0.22),
              AppColors.borderDefault.withValues(alpha: 0.40),
              Colors.white.withValues(alpha: 0.06),
            ]
          : <Color>[
              item.accentColor.withValues(alpha: 0.85),
              AppColors.liquidGold.withValues(alpha: 0.55),
              item.accentColor.withValues(alpha: 0.25),
            ],
      stops: const <double>[0.0, 0.45, 1.0],
    );

    Widget cardContent = DecoratedBox(
      decoration: BoxDecoration(
        gradient: surfaceGradient,
        borderRadius: cardRadius,
      ),
      child: CustomPaint(
        foregroundPainter: _AionAnnouncementCardOrnamentPainter(
          borderRadius: cardRadius,
          borderGradient: borderGradient,
          borderWidth: borderWidth,
          isRead: isRead,
          accentColor: item.accentColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Leading Icon with Aion Runic Frame & Vector binding
              _buildLeadingIcon(item, isRead),
              const SizedBox(width: AppSpacing.md),

              // Center Details Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Top header row with badges & timestamp
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              _buildCategoryPill(item),
                              if (item.versionTag != null)
                                _buildVersionPill(item.versionTag!),
                              if (hasUnclaimedGift)
                                _buildGiftBadge(),
                              if (isUrgentEvent)
                                _buildUrgentBadge(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTimestampAndUnread(item.publishedAt, isRead),
                      ],
                    ),

                    const SizedBox(height: 7),

                    // Title
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: isRead
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontWeight:
                            isRead ? FontWeight.w600 : FontWeight.w800,
                        fontSize: 14.5,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Subtitle
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: isRead
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.38,
                        letterSpacing: 0.1,
                      ),
                    ),

                    // Optional Countdown row if event
                    if (item.eventEndTime != null) ...<Widget>[
                      const SizedBox(height: 8),
                      EventCountdownPill(
                        endTime: item.eventEndTime!,
                        startTime: item.eventStartTime,
                        compact: true,
                        eventTitle: item.title,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Author & Chevron CTA footer
                    Row(
                      children: <Widget>[
                        if (item.author.isNotEmpty) ...<Widget>[
                          Icon(
                            Icons.verified_user_outlined,
                            size: 11,
                            color: AppColors.textTertiary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              item.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textTertiary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Ayrıntılar',
                              style: GoogleFonts.plusJakartaSans(
                                color: item.accentColor.withValues(
                                  alpha: isRead ? 0.60 : 0.90,
                                ),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: item.accentColor.withValues(
                                alpha: isRead ? 0.60 : 0.90,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Apply BackdropFilter only when not in Eco tier to save GPU TBDR overhead
    if (!isEcoTier) {
      cardContent = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: cardContent,
      );
    }

    return Semantics(
      button: true,
      label:
          '${item.badgeLabel}: ${item.title}. ${isRead ? "Okundu" : "Okunmadı"}.',
      hint: 'Ayrıntıları ve yama notlarını görüntülemek için dokunun',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.982 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: cardRadius,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: isRead
                      ? Colors.black.withValues(alpha: 0.35)
                      : item.accentColor.withValues(alpha: 0.18),
                  blurRadius: isRead ? 10 : 18,
                  spreadRadius: isRead ? -2 : -2,
                  offset: const Offset(0, 4),
                ),
                if (!isRead)
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.10),
                    blurRadius: 22,
                    spreadRadius: -4,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: cardRadius,
              child: cardContent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(AnnouncementItem item, bool isRead) {
    final IconData iconData = _getIconData(item);
    final Color accent = item.accentColor;

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: isRead ? 0.10 : 0.28),
            AppColors.spaceNavy.withValues(alpha: 0.65),
            AppColors.bgDeep.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead
              ? Colors.white.withValues(alpha: 0.14)
              : accent.withValues(alpha: 0.60),
          width: 1.1,
        ),
        boxShadow: isRead
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.10),
                  blurRadius: 14,
                  spreadRadius: -4,
                ),
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  accent.withValues(alpha: isRead ? 0.15 : 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Icon(
            iconData,
            size: 24,
            color: isRead ? accent.withValues(alpha: 0.70) : accent,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(AnnouncementItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: item.accentColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: item.accentColor.withValues(alpha: 0.45),
          width: 0.9,
        ),
      ),
      child: Text(
        item.badgeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          color: item.accentColor,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildVersionPill(String versionTag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.accentCyan.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.40),
          width: 0.9,
        ),
      ),
      child: Text(
        versionTag,
        maxLines: 1,
        style: GoogleFonts.jetBrainsMono(
          color: AppColors.accentCyan,
          fontWeight: FontWeight.w700,
          fontSize: 9.5,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildGiftBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.liquidGold.withValues(alpha: 0.25),
            AppColors.goldLight.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.70),
          width: 0.9,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: 0.20),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.card_giftcard_rounded,
            size: 10,
            color: AppColors.liquidGold,
          ),
          const SizedBox(width: 3),
          Text(
            'Hediye',
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.liquidGold,
              fontWeight: FontWeight.w800,
              fontSize: 9.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.coralFlare.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.coralFlare.withValues(alpha: 0.70),
          width: 0.9,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.coralFlare.withValues(alpha: 0.25),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.bolt_rounded,
            size: 11,
            color: AppColors.coralFlare,
          ),
          const SizedBox(width: 2),
          Text(
            'Son Saatler',
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.coralFlare,
              fontWeight: FontWeight.w800,
              fontSize: 9.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampAndUnread(DateTime publishedAt, bool isRead) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.schedule_rounded,
          size: 11,
          color: AppColors.textTertiary.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 3.5),
        Text(
          _timeAgo(publishedAt),
          maxLines: 1,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textTertiary,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!isRead) ...<Widget>[
          const SizedBox(width: 6),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.accentCyan,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.accentCyan.withValues(alpha: 0.85),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  IconData _getIconData(AnnouncementItem item) {
    if (item.type == AnnouncementType.patchNotes) {
      return Icons.auto_stories_rounded;
    }
    if (item.type == AnnouncementType.event) {
      return Icons.military_tech_rounded;
    }
    if (item.type == AnnouncementType.maintenance) {
      return Icons.build_circle_rounded;
    }
    if (item.type == AnnouncementType.broadcast) {
      return Icons.campaign_rounded;
    }
    if (item.rewards.isNotEmpty) {
      return Icons.card_giftcard_rounded;
    }

    final String titleUpper = item.title.toUpperCase();
    final String badgeUpper = item.badgeLabel.toUpperCase();

    if (titleUpper.contains('🛡️') ||
        badgeUpper.contains('LONCA') ||
        titleUpper.contains('LONCA')) {
      return Icons.shield_rounded;
    }
    if (titleUpper.contains('🔥') ||
        badgeUpper.contains('KUŞATMA') ||
        titleUpper.contains('KUŞATMA')) {
      return Icons.local_fire_department_rounded;
    }
    if (titleUpper.contains('👑') ||
        badgeUpper.contains('KRALİYET') ||
        titleUpper.contains('KRALİYET')) {
      return Icons.workspace_premium_rounded;
    }
    if (titleUpper.contains('✨') ||
        badgeUpper.contains('GÜÇLENDİRME') ||
        titleUpper.contains('GÜÇLENDİRME')) {
      return Icons.auto_awesome_rounded;
    }
    if (titleUpper.contains('🌙') ||
        badgeUpper.contains('GECE PAZARI') ||
        titleUpper.contains('GECE')) {
      return Icons.nightlight_round;
    }
    if (titleUpper.contains('🚫') ||
        badgeUpper.contains('İNFAZ') ||
        badgeUpper.contains('YARGI')) {
      return Icons.gavel_rounded;
    }
    if (titleUpper.contains('⚔️') ||
        badgeUpper.contains('BOSS') ||
        titleUpper.contains('BOSS')) {
      return Icons.sports_kabaddi_rounded;
    }

    return Icons.campaign_rounded;
  }
}

/// Custom painter for Aion 2 frosted glass luminous border, specular glint, and runic corner brackets.
class _AionAnnouncementCardOrnamentPainter extends CustomPainter {
  const _AionAnnouncementCardOrnamentPainter({
    required this.borderRadius,
    required this.borderGradient,
    required this.borderWidth,
    required this.isRead,
    required this.accentColor,
  });

  final BorderRadius borderRadius;
  final Gradient borderGradient;
  final double borderWidth;
  final bool isRead;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Rect rect = Offset.zero & size;
    final RRect rrect = borderRadius.toRRect(rect).deflate(borderWidth / 2);

    // 1. Luminous Gradient Border
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = borderGradient.createShader(rect);

    canvas.drawRRect(rrect, borderPaint);

    // 2. Specular Top Gleam (Glossy glass reflection)
    final double topY = borderWidth / 2 + 0.5;
    final double startX = borderRadius.topLeft.x + 4.0;
    final double endX = size.width - borderRadius.topRight.x - 4.0;

    if (endX > startX) {
      final Paint gleamPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: isRead ? 0.15 : 0.40),
            Colors.white.withValues(alpha: isRead ? 0.30 : 0.80),
            Colors.white.withValues(alpha: isRead ? 0.15 : 0.40),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(Rect.fromLTWH(startX, topY, endX - startX, 1.0));

      canvas.drawLine(Offset(startX, topY), Offset(endX, topY), gleamPaint);
    }

    // 3. Aion 2 Runic Micro-Brackets on All Corners
    final Paint runicPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isRead ? 1.2 : 1.8
      ..color = isRead
          ? Colors.white.withValues(alpha: 0.25)
          : accentColor.withValues(alpha: 0.75);

    const double bracketSize = 8.0;

    // Top-left bracket
    canvas.drawLine(
      Offset(borderRadius.topLeft.x, borderWidth / 2),
      Offset(borderRadius.topLeft.x + bracketSize, borderWidth / 2),
      runicPaint,
    );
    canvas.drawLine(
      Offset(borderWidth / 2, borderRadius.topLeft.y),
      Offset(borderWidth / 2, borderRadius.topLeft.y + bracketSize),
      runicPaint,
    );

    // Top-right bracket
    canvas.drawLine(
      Offset(size.width - borderRadius.topRight.x - bracketSize, borderWidth / 2),
      Offset(size.width - borderRadius.topRight.x, borderWidth / 2),
      runicPaint,
    );
    canvas.drawLine(
      Offset(size.width - borderWidth / 2, borderRadius.topRight.y),
      Offset(size.width - borderWidth / 2, borderRadius.topRight.y + bracketSize),
      runicPaint,
    );

    // Bottom-left bracket
    canvas.drawLine(
      Offset(borderWidth / 2, size.height - borderRadius.bottomLeft.y - bracketSize),
      Offset(borderWidth / 2, size.height - borderRadius.bottomLeft.y),
      runicPaint,
    );
    canvas.drawLine(
      Offset(borderRadius.bottomLeft.x, size.height - borderWidth / 2),
      Offset(borderRadius.bottomLeft.x + bracketSize, size.height - borderWidth / 2),
      runicPaint,
    );

    // Bottom-right bracket
    canvas.drawLine(
      Offset(size.width - borderRadius.bottomRight.x - bracketSize, size.height - borderWidth / 2),
      Offset(size.width - borderRadius.bottomRight.x, size.height - borderWidth / 2),
      runicPaint,
    );
    canvas.drawLine(
      Offset(size.width - borderWidth / 2, size.height - borderRadius.bottomRight.y - bracketSize),
      Offset(size.width - borderWidth / 2, size.height - borderRadius.bottomRight.y),
      runicPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AionAnnouncementCardOrnamentPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.isRead != isRead ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.borderGradient != borderGradient;
  }
}
