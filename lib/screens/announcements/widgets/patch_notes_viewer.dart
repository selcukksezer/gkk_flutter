import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../models/announcement_models.dart';
import '../services/announcements_repository.dart';
import 'event_countdown_pill.dart';
import 'event_gift_claim_sheet.dart';

/// 2027 AAA Studio V3 Frosted Modal Sheet for patch notes and event deep viewer.
///
/// Features:
/// - Frosted glassmorphic modal sheet with dual-layer borders & ambient radial glow.
/// - Tactile drag handle and header bar with haptic feedback.
/// - Luminous version chip with auto-glow and runic sparkles.
/// - Dynamic real-time reading progress bar tracking scroll depth.
/// - High-contrast AAA markdown typography, styled blockquotes, code chips, and dividers.
/// - Attached event gift showcase with rarity badges and luxury claim CTA.
/// - Bouncing scroll physics with custom rounded scrollbar.
class PatchNotesViewerModal extends ConsumerWidget {
  const PatchNotesViewerModal({
    super.key,
    required this.item,
  });

  final AnnouncementItem item;

  static Future<void> show({
    required BuildContext context,
    required AnnouncementItem item,
    required WidgetRef ref,
  }) async {
    HapticFeedback.lightImpact();
    // Automatically mark as read when inspected
    await ref.read(announcementsControllerProvider.notifier).markAsRead(item.id);

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      useRootNavigator: true,
      builder: (BuildContext ctx) => PatchNotesViewerModal(item: item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PatchNotesSheetContent(item: item);
  }
}

/// Internal stateful sheet handling scrolling, reading progress, and AAA micro-interactions.
class _PatchNotesSheetContent extends ConsumerStatefulWidget {
  const _PatchNotesSheetContent({
    required this.item,
  });

  final AnnouncementItem item;

  @override
  ConsumerState<_PatchNotesSheetContent> createState() =>
      _PatchNotesSheetContentState();
}

class _PatchNotesSheetContentState
    extends ConsumerState<_PatchNotesSheetContent> {
  late final ScrollController _scrollController;
  double _readingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double current = _scrollController.offset;
    final double progress =
        maxScroll > 0 ? (current / maxScroll).clamp(0.0, 1.0) : 0.0;
    if ((progress - _readingProgress).abs() > 0.01) {
      setState(() {
        _readingProgress = progress;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AnnouncementItem item = widget.item;
    final AnnouncementsScreenState state =
        ref.watch(announcementsControllerProvider);
    final bool isClaimed = state.claimedIds.contains(item.id);
    final Size screenSize = MediaQuery.sizeOf(context);
    final double screenHeight = screenSize.height;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        height: screenHeight * 0.90,
        decoration: BoxDecoration(
          color: const Color(0xF5090D18),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: item.accentColor.withValues(alpha: 0.40),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: item.accentColor.withValues(alpha: 0.22),
              blurRadius: 36,
              spreadRadius: 2,
              offset: const Offset(0, -4),
            ),
            const BoxShadow(
              color: Color(0xC0000000),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Stack(
            children: <Widget>[
              // Ambient radial glow behind the top header area
              Positioned(
                top: -60,
                left: screenSize.width * 0.5 - 120,
                child: Container(
                  width: 240,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        item.accentColor.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Dot Grid Micro Texture for high-end tactical depth
              const Positioned.fill(
                child: CustomPaint(
                  painter: _PatchNotesDotGridPainter(
                    spacing: 18,
                    dotOpacity: 0.04,
                  ),
                ),
              ),

              // Luminous top rim highlight line
              Positioned(
                top: 0,
                left: 32,
                right: 32,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        item.accentColor.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                      stops: const <double>[0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Safe Area Body
              SafeArea(
                top: false,
                child: Column(
                  children: <Widget>[
                    // Drag Handle & Top Bar
                    _buildTopHeader(context, item),

                    // Slender Luminous Reading Progress Bar
                    _buildReadingProgressBar(item),

                    // Scrollable Content with smooth physics
                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        thickness: 3.5,
                        radius: const Radius.circular(8),
                        thumbVisibility: false,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Hero Banner Card with Gradient & Meta
                              _buildHeroHeaderCard(item),

                              const SizedBox(height: 20),

                              // Rich Markdown Formatted Body
                              _buildMarkdownBody(item),

                              // Attached Event Gifts Section
                              if (item.rewards.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 28),
                                _buildRewardGiftSection(context, item, isClaimed),
                              ],

                              const SizedBox(height: 20),

                              // Footer Stamp / Runic Watermark
                              _buildFooterStamp(item),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, AnnouncementItem item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Centered Tactile Drag Handle Pill
        Center(
          child: Container(
            width: 42,
            height: 4.5,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),

        // Header Action Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              // Category Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: item.accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.accentColor.withValues(alpha: 0.65),
                    width: 1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: item.accentColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  item.badgeLabel,
                  style: GoogleFonts.urbanist(
                    color: item.accentColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),

              // Luminous Version Chip
              if (item.versionTag != null) ...<Widget>[
                const SizedBox(width: 8),
                _buildLuminousVersionChip(item.versionTag!, item.accentColor),
              ],

              const Spacer(),

              // Event Countdown Pill
              if (item.eventEndTime != null)
                EventCountdownPill(
                  endTime: item.eventEndTime!,
                  compact: true,
                ),

              const SizedBox(width: 8),

              // Tactile Close Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.borderDefault.withValues(alpha: 0.8),
                        width: 0.9,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLuminousVersionChip(String versionTag, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.70),
          width: 1.1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accentColor.withValues(alpha: 0.30),
            blurRadius: 10,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.auto_awesome_rounded,
            size: 11,
            color: accentColor,
          ),
          const SizedBox(width: 4),
          Text(
            versionTag,
            style: GoogleFonts.urbanist(
              color: AppColors.textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingProgressBar(AnnouncementItem item) {
    return Container(
      width: double.infinity,
      height: 2,
      color: Colors.white.withValues(alpha: 0.05),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: _readingProgress.clamp(0.001, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                item.accentColor.withValues(alpha: 0.6),
                item.accentColor,
                AppColors.goldLight,
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: item.accentColor.withValues(alpha: 0.8),
                blurRadius: 4,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeaderCard(AnnouncementItem item) {
    final int wordCount = item.contentMarkdown.split(RegExp(r'\s+')).length;
    final int readMinutes = (wordCount / 140).ceil().clamp(1, 15);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.bannerGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.accentColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: item.accentColor.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.title,
            style: GoogleFonts.urbanist(
              color: AppColors.textPrimary,
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
              height: 1.3,
              letterSpacing: 0.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.subtitle,
            style: GoogleFonts.urbanist(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 5),
              Text(
                _formatDate(item.publishedAt),
                style: GoogleFonts.urbanist(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.menu_book_rounded,
                size: 12,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                '~$readMinutes dk okuma',
                style: GoogleFonts.urbanist(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.verified_user_rounded,
                    size: 12,
                    color: item.accentColor.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.author,
                    style: GoogleFonts.urbanist(
                      color: item.accentColor.withValues(alpha: 0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownBody(AnnouncementItem item) {
    return MarkdownBody(
      data: item.contentMarkdown,
      selectable: false,
      styleSheet: MarkdownStyleSheet(
        h1: GoogleFonts.urbanist(
          color: AppColors.liquidGold,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
          height: 1.6,
        ),
        h2: GoogleFonts.urbanist(
          color: AppColors.accentCyan,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          height: 1.5,
          letterSpacing: 0.3,
        ),
        h3: GoogleFonts.urbanist(
          color: AppColors.goldLight,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
        p: GoogleFonts.urbanist(
          color: AppColors.textPrimary.withValues(alpha: 0.95),
          fontSize: 13.5,
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
        strong: GoogleFonts.urbanist(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        em: GoogleFonts.urbanist(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        blockquote: GoogleFonts.urbanist(
          color: AppColors.goldLight,
          fontSize: 13,
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
        blockquoteDecoration: BoxDecoration(
          color: const Color(0x331E182A),
          borderRadius: BorderRadius.circular(10),
          border: const Border(
            left: BorderSide(
              color: AppColors.liquidGold,
              width: 3.5,
            ),
          ),
        ),
        code: GoogleFonts.jetBrainsMono(
          color: AppColors.accentCyan,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          backgroundColor: Colors.transparent,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0x900B101D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.borderDefault.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        listBullet: GoogleFonts.urbanist(
          color: AppColors.liquidGold,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardGiftSection(
    BuildContext context,
    AnnouncementItem item,
    bool isClaimed,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x99101626),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: 0.14),
            blurRadius: 22,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.liquidGold.withValues(alpha: 0.16),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('🎁', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'ETKİNLİK ÖDÜL SANDIĞI',
                      style: GoogleFonts.urbanist(
                        color: AppColors.liquidGold,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Bu güncellemeye özel hediyeni hemen envanterine aktar.',
                      style: GoogleFonts.urbanist(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...item.rewards.map(
            (EventRewardItem r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.bgDeep.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: r.rarityColor.withValues(alpha: 0.35),
                  width: 0.9,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Text(r.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          r.name,
                          style: GoogleFonts.urbanist(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (r.description.isNotEmpty)
                          Text(
                            r.description,
                            style: GoogleFonts.urbanist(
                              color: AppColors.textTertiary,
                              fontSize: 10.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: r.rarityColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: r.rarityColor.withValues(alpha: 0.5),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      r.rarity.toUpperCase(),
                      style: GoogleFonts.urbanist(
                        color: r.rarityColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'x${r.quantity}',
                    style: GoogleFonts.urbanist(
                      color: AppColors.liquidGold,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isClaimed
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      EventGiftClaimSheet.show(
                        context: context,
                        item: item,
                        ref: ref,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isClaimed
                    ? const Color(0xFF1E283C)
                    : AppColors.liquidGold,
                foregroundColor: isClaimed
                    ? AppColors.textDisabled
                    : const Color(0xFF0F1523),
                elevation: isClaimed ? 0 : 6,
                shadowColor: AppColors.liquidGold.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isClaimed ? Colors.white12 : AppColors.goldLight,
                    width: 1.2,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    isClaimed
                        ? Icons.check_circle_outline_rounded
                        : Icons.card_giftcard_rounded,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isClaimed
                        ? 'HEDİYE ALINDI ✓'
                        : 'ETKİNLİK HEDİYESİNİ AL',
                    style: GoogleFonts.urbanist(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterStamp(AnnouncementItem item) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 24,
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.shield_moon_outlined,
              size: 13,
              color: item.accentColor.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              'AION 2 ÇAĞI RESMİ DUYURU',
              style: GoogleFonts.urbanist(
                color: AppColors.textTertiary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _PatchNotesDotGridPainter extends CustomPainter {
  const _PatchNotesDotGridPainter({
    this.spacing = 18,
    this.dotRadius = 1.0,
    this.dotOpacity = 0.04,
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
  bool shouldRepaint(covariant _PatchNotesDotGridPainter oldDelegate) =>
      spacing != oldDelegate.spacing ||
      dotRadius != oldDelegate.dotRadius ||
      dotOpacity != oldDelegate.dotOpacity;
}
