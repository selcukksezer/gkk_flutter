import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../models/announcement_models.dart';
import '../services/announcements_repository.dart';
import 'event_countdown_pill.dart';
import 'event_gift_claim_sheet.dart';
import 'patch_notes_viewer.dart';

/// 2027 Aion 2 Hero banner carousel featuring animated gradient borders,
/// obsidian frosted glass, procedural filigree ornaments, multi-tier haptics,
/// and responsive 390x844 mobile adaptation.
class HeroBannerCarousel extends ConsumerStatefulWidget {
  const HeroBannerCarousel({
    super.key,
    required this.banners,
  });

  final List<AnnouncementItem> banners;

  @override
  ConsumerState<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends ConsumerState<HeroBannerCarousel>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _gradientAnimController;
  late AnimationController _sheenAnimController;
  late AnimationController _pulseAnimController;
  late AnimationController _autoScrollProgressController;
  int _currentPage = 0;
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageScroll);

    _gradientAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _sheenAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    )..repeat();

    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _autoScrollProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );

    _autoScrollProgressController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        if (!mounted || _userInteracting || !_pageController.hasClients) return;
        _goToNextPage();
      }
    });

    _startAutoScroll();
  }

  void _onPageScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startAutoScroll() {
    if (widget.banners.length <= 1) return;
    _autoScrollProgressController.forward(from: 0.0);
  }

  void _goToNextPage() {
    if (widget.banners.isEmpty || !_pageController.hasClients) return;
    final int next = (_currentPage + 1) % widget.banners.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
    );
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients || index == _currentPage) return;
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
    _autoScrollProgressController.forward(from: 0.0);
  }

  void _onPointerDown() {
    _userInteracting = true;
    _autoScrollProgressController.stop();
  }

  void _onPointerUp() {
    _userInteracting = false;
    if (widget.banners.length > 1) {
      _autoScrollProgressController.forward();
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _gradientAnimController.dispose();
    _sheenAnimController.dispose();
    _pulseAnimController.dispose();
    _autoScrollProgressController.dispose();
    super.dispose();
  }

  String _resolveBannerImageAsset(AnnouncementItem banner) {
    final String titleLower = banner.title.toLowerCase();
    final String idLower = banner.id.toLowerCase();
    final String subtitleLower = banner.subtitle.toLowerCase();

    if (idLower.contains('patch') ||
        idLower.contains('abyss') ||
        titleLower.contains('uçurum') ||
        subtitleLower.contains('impeller') ||
        banner.type == AnnouncementType.patchNotes) {
      return 'assets/images/backgrounds/dungeons/bg_abyss_core_warzone.png';
    }
    if (idLower.contains('solorius') ||
        idLower.contains('winter') ||
        titleLower.contains('kış') ||
        titleLower.contains('şenlik') ||
        subtitleLower.contains('solorius')) {
      return 'assets/images/backgrounds/asmodae/bg_beluslan_frozen_sea.png';
    }
    if (idLower.contains('market') ||
        idLower.contains('night') ||
        titleLower.contains('gece pazarı') ||
        titleLower.contains('tüccar')) {
      return 'assets/images/backgrounds/asmodae/bg_pandaemonium_capital.png';
    }
    if (idLower.contains('siege') ||
        idLower.contains('war') ||
        titleLower.contains('kuşatma') ||
        titleLower.contains('savaş')) {
      return 'assets/images/backgrounds/dungeons/bg_dark_poeta_burning.png';
    }
    if (idLower.contains('arena') ||
        idLower.contains('pvp') ||
        titleLower.contains('arena')) {
      return 'assets/images/backgrounds/dungeons/bg_empyrean_arena.png';
    }
    if (idLower.contains('sanctum') || titleLower.contains('kutsal')) {
      return 'assets/images/backgrounds/elysea/bg_sanctum_citadel.png';
    }
    return 'assets/images/backgrounds/asmodae/bg_asmodae_skybox.png';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    final AnnouncementsScreenState portalState =
        ref.watch(announcementsControllerProvider);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        final bool isCompact = maxWidth < 390;
        final bool isLarge = maxWidth >= 600;
        final double bannerHeight =
            isCompact ? 204.0 : (isLarge ? 232.0 : 216.0);
        final double horizontalPadding = isCompact ? 12.0 : 16.0;
        final double cardPaddingH = isCompact ? 14.0 : 18.0;
        final double cardPaddingV = isCompact ? 12.0 : 16.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: bannerHeight,
              child: Listener(
                onPointerDown: (_) => _onPointerDown(),
                onPointerUp: (_) => _onPointerUp(),
                onPointerCancel: (_) => _onPointerUp(),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.banners.length,
                  onPageChanged: (int index) {
                    if (_userInteracting) {
                      HapticFeedback.selectionClick();
                    }
                    setState(() {
                      _currentPage = index;
                    });
                    if (widget.banners.length > 1) {
                      _autoScrollProgressController.forward(from: 0.0);
                    }
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final AnnouncementItem banner = widget.banners[index];
                    final bool isClaimed =
                        portalState.claimedIds.contains(banner.id);
                    final String bgAsset = _resolveBannerImageAsset(banner);

                    // Parallax & 3D Depth Interpolation
                    double pageOffset = 0.0;
                    if (_pageController.hasClients &&
                        _pageController.position.haveDimensions) {
                      final double? page = _pageController.page;
                      if (page != null) {
                        pageOffset = page - index;
                      }
                    } else {
                      pageOffset = (_currentPage - index).toDouble();
                    }
                    final double parallaxOffset =
                        (pageOffset * 28.0).clamp(-40.0, 40.0);
                    final double cardScale =
                        (1.0 - (pageOffset.abs() * 0.03)).clamp(0.95, 1.0);

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Transform.scale(
                        scale: cardScale,
                        child: AnimatedBuilder(
                          animation: _gradientAnimController,
                          builder: (BuildContext context, Widget? child) {
                            final double t = _gradientAnimController.value;
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: SweepGradient(
                                  center: Alignment.center,
                                  startAngle: 0.0,
                                  endAngle: math.pi * 2,
                                  transform:
                                      GradientRotation(t * math.pi * 2),
                                  colors: <Color>[
                                    banner.accentColor,
                                    AppColors.goldLight,
                                    AppColors.accentCyan,
                                    AppColors.cyberFuchsia,
                                    banner.accentColor,
                                  ],
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: banner.accentColor
                                        .withValues(alpha: 0.32),
                                    blurRadius: 18,
                                    spreadRadius: -2,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.65),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(1.5),
                                child: child,
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: 12.0,
                                sigmaY: 12.0,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    PatchNotesViewerModal.show(
                                      context: context,
                                      item: banner,
                                      ref: ref,
                                    );
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xF4080B14),
                                    ),
                                    child: Stack(
                                      children: <Widget>[
                                        // 1. Real Cinematic Aion 2 Artwork with Parallax Shift
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: Transform.translate(
                                              offset: Offset(parallaxOffset, 0),
                                              child: Image.asset(
                                                bgAsset,
                                                fit: BoxFit.cover,
                                                alignment: Alignment.center,
                                                errorBuilder:
                                                    (BuildContext context,
                                                        Object error,
                                                        StackTrace?
                                                            stackTrace) {
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                        colors:
                                                            banner.bannerGradient,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 2. High-contrast Dark Vignette & Horizontal Reading Gradient
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                stops: const <double>[
                                                  0.0,
                                                  0.42,
                                                  0.82,
                                                  1.0,
                                                ],
                                                colors: <Color>[
                                                  const Color(0xF5080B14),
                                                  const Color(0xDD0C1220),
                                                  const Color(0x9910182E),
                                                  banner.accentColor.withValues(
                                                      alpha: 0.18),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Vertical Vignette (for razor-sharp legibility)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                stops: <double>[0.0, 0.40, 1.0],
                                                colors: <Color>[
                                                  Color(0x6606080E),
                                                  Colors.transparent,
                                                  Color(0xEE06080E),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 3. Procedural Aion 2 filigree & celestial runes (rotating dynamically)
                                        Positioned.fill(
                                          child: AnimatedBuilder(
                                            animation: _gradientAnimController,
                                            builder: (BuildContext context,
                                                Widget? child) {
                                              return CustomPaint(
                                                painter:
                                                    _AionBannerFiligreePainter(
                                                  accentColor: banner.accentColor,
                                                  rotationProgress:
                                                      _gradientAnimController
                                                          .value,
                                                  hasRewards: banner
                                                      .rewards.isNotEmpty,
                                                ),
                                              );
                                            },
                                          ),
                                        ),

                                        // 4. Animated Specular Sheen (Gleam highlight sweep)
                                        Positioned.fill(
                                          child: AnimatedBuilder(
                                            animation: _sheenAnimController,
                                            builder: (BuildContext context,
                                                Widget? child) {
                                              return IgnorePointer(
                                                child: CustomPaint(
                                                  painter: _BannerSheenPainter(
                                                    sheenProgress:
                                                        _sheenAnimController
                                                            .value,
                                                    accentColor:
                                                        banner.accentColor,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),

                                        // 5. Vector watermark emblem
                                        Positioned(
                                          right: -12,
                                          top: -15,
                                          child: IgnorePointer(
                                            child: Opacity(
                                              opacity: 0.08,
                                              child: Icon(
                                                banner.rewards.isNotEmpty
                                                    ? Icons.card_giftcard_rounded
                                                    : (banner.type ==
                                                            AnnouncementType
                                                                .patchNotes
                                                        ? Icons
                                                            .auto_stories_rounded
                                                        : Icons
                                                            .military_tech_rounded),
                                                size: 155,
                                                color: banner.accentColor,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 6. Radial ambient glow
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          width: 190,
                                          height: 190,
                                          child: IgnorePointer(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: RadialGradient(
                                                  center: Alignment.topRight,
                                                  radius: 1.1,
                                                  colors: <Color>[
                                                    banner.accentColor
                                                        .withValues(
                                                            alpha: 0.22),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 7. Foreground Content Layer
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: cardPaddingH,
                                            vertical: cardPaddingV,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              // Top Row: Badge, Version Tag & Countdown
                                              Row(
                                                children: <Widget>[
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal:
                                                          isCompact ? 8 : 10,
                                                      vertical: isCompact
                                                          ? 3.5
                                                          : 4.5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          const Color(0xAA0B101C),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color: banner.accentColor
                                                            .withValues(
                                                                alpha: 0.65),
                                                        width: 1.0,
                                                      ),
                                                      boxShadow: <BoxShadow>[
                                                        BoxShadow(
                                                          color: banner
                                                              .accentColor
                                                              .withValues(
                                                                  alpha: 0.25),
                                                          blurRadius: 8,
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: <Widget>[
                                                        // Pulsing Neon Indicator Dot
                                                        AnimatedBuilder(
                                                          animation:
                                                              _pulseAnimController,
                                                          builder: (BuildContext
                                                                  context,
                                                              Widget? child) {
                                                            final double p =
                                                                _pulseAnimController
                                                                    .value;
                                                            return Container(
                                                              width: 6,
                                                              height: 6,
                                                              decoration:
                                                                  BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                color: banner
                                                                    .accentColor,
                                                                boxShadow: <
                                                                    BoxShadow>[
                                                                  BoxShadow(
                                                                    color: banner
                                                                        .accentColor
                                                                        .withValues(
                                                                      alpha: 0.5 +
                                                                          (p *
                                                                              0.5),
                                                                    ),
                                                                    blurRadius: 5 +
                                                                        (p *
                                                                            4),
                                                                    spreadRadius:
                                                                        p *
                                                                            1.5,
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                          banner.badgeLabel,
                                                          style: TextStyle(
                                                            color: banner
                                                                .accentColor,
                                                            fontSize: isCompact
                                                                ? 9.5
                                                                : 10.5,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            letterSpacing: 0.8,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (banner.versionTag !=
                                                      null) ...<Widget>[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal: isCompact
                                                            ? 6
                                                            : 8,
                                                        vertical: isCompact
                                                            ? 3.0
                                                            : 3.5,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.08),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                          color: Colors.white
                                                              .withValues(
                                                                  alpha: 0.14),
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        banner.versionTag!,
                                                        style: TextStyle(
                                                          color: AppColors
                                                              .textSecondary,
                                                          fontSize: isCompact
                                                              ? 9.0
                                                              : 10.0,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  const Spacer(),
                                                  if (banner.eventEndTime !=
                                                      null)
                                                    EventCountdownPill(
                                                      endTime:
                                                          banner.eventEndTime!,
                                                      compact: true,
                                                      prefixLabel: 'KALAN:',
                                                    ),
                                                ],
                                              ),

                                              const Spacer(),

                                              // Title with crisp text shadows
                                              Text(
                                                banner.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: isCompact
                                                      ? 15.5
                                                      : 17.5,
                                                  fontWeight: FontWeight.w900,
                                                  height: 1.25,
                                                  shadows: const <Shadow>[
                                                    Shadow(
                                                      color: Colors.black,
                                                      offset: Offset(0, 1.5),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                  height: isCompact ? 3 : 5),

                                              // Subtitle
                                              Text(
                                                banner.subtitle,
                                                maxLines: isCompact ? 1 : 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: isCompact
                                                      ? 11.5
                                                      : 12.5,
                                                  height: 1.35,
                                                  shadows: const <Shadow>[
                                                    Shadow(
                                                      color: Colors.black87,
                                                      offset: Offset(0, 1),
                                                      blurRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              SizedBox(
                                                  height: isCompact ? 8 : 10),

                                              // Bottom action / quick claim button
                                              Row(
                                                children: <Widget>[
                                                  InkWell(
                                                    onTap: () {
                                                      HapticFeedback
                                                          .selectionClick();
                                                      PatchNotesViewerModal.show(
                                                        context: context,
                                                        item: banner,
                                                        ref: ref,
                                                      );
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        vertical: 2,
                                                        horizontal: 2,
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: <Widget>[
                                                          Text(
                                                            'Detayları İncele',
                                                            style: TextStyle(
                                                              color: banner
                                                                  .accentColor,
                                                              fontSize: isCompact
                                                                  ? 11.0
                                                                  : 12.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              letterSpacing:
                                                                  0.2,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Icon(
                                                            Icons
                                                                .arrow_forward_rounded,
                                                            size: isCompact
                                                                ? 12
                                                                : 14,
                                                            color: banner
                                                                .accentColor,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  if (banner.rewards.isNotEmpty)
                                                    GestureDetector(
                                                      onTap: () {
                                                        if (isClaimed) {
                                                          HapticFeedback
                                                              .selectionClick();
                                                          PatchNotesViewerModal
                                                              .show(
                                                            context: context,
                                                            item: banner,
                                                            ref: ref,
                                                          );
                                                        } else {
                                                          HapticFeedback
                                                              .mediumImpact();
                                                          EventGiftClaimSheet
                                                              .show(
                                                            context: context,
                                                            item: banner,
                                                            ref: ref,
                                                          );
                                                        }
                                                      },
                                                      child: AnimatedBuilder(
                                                        animation:
                                                            _pulseAnimController,
                                                        builder: (BuildContext
                                                                context,
                                                            Widget? child) {
                                                          final double p =
                                                              _pulseAnimController
                                                                  .value;
                                                          return Container(
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                              horizontal:
                                                                  isCompact
                                                                      ? 10
                                                                      : 13,
                                                              vertical:
                                                                  isCompact
                                                                      ? 4.5
                                                                      : 5.5,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              gradient: isClaimed
                                                                  ? null
                                                                  : AppColors
                                                                      .liquidGoldGradient,
                                                              color: isClaimed
                                                                  ? Colors.white
                                                                      .withValues(
                                                                          alpha:
                                                                              0.08)
                                                                  : null,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              border: Border.all(
                                                                color: isClaimed
                                                                    ? Colors
                                                                        .white12
                                                                    : AppColors
                                                                        .goldLight
                                                                        .withValues(
                                                                            alpha: 0.8),
                                                                width: 0.8,
                                                              ),
                                                              boxShadow: isClaimed
                                                                  ? null
                                                                  : <BoxShadow>[
                                                                      BoxShadow(
                                                                        color: AppColors
                                                                            .liquidGold
                                                                            .withValues(
                                                                          alpha:
                                                                              0.35 + (p * 0.25),
                                                                        ),
                                                                        blurRadius:
                                                                            10 + (p * 4),
                                                                        spreadRadius:
                                                                            p * 1.0,
                                                                        offset:
                                                                            const Offset(0, 2),
                                                                      ),
                                                                    ],
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: <
                                                                  Widget>[
                                                                Icon(
                                                                  isClaimed
                                                                      ? Icons
                                                                          .check_circle_outline_rounded
                                                                      : Icons
                                                                          .card_giftcard_rounded,
                                                                  size: isCompact
                                                                      ? 12
                                                                      : 14,
                                                                  color: isClaimed
                                                                      ? AppColors
                                                                          .textSecondary
                                                                      : const Color(
                                                                          0xFF0F1523),
                                                                ),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                  isClaimed
                                                                      ? 'Alındı'
                                                                      : 'Hediyeni Al',
                                                                  style:
                                                                      TextStyle(
                                                                    color: isClaimed
                                                                        ? AppColors
                                                                            .textSecondary
                                                                        : const Color(
                                                                            0xFF0F1523),
                                                                    fontSize:
                                                                        isCompact
                                                                            ? 10.5
                                                                            : 11.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w900,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
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
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            if (widget.banners.length > 1) ...<Widget>[
              SizedBox(height: isCompact ? 8 : 10),

              // AAA Aion 2 Frosted Capsule Page Indicator with Live Auto-Scroll Progress
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x77080B14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.8,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Tabular slide counter: "01 / 03"
                        Text(
                          '${(_currentPage + 1).toString().padLeft(2, '0')} / ${widget.banners.length.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            fontFeatures: const <ui.FontFeature>[
                              ui.FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 10,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        const SizedBox(width: 8),

                        // Interactive Indicators with Animated Progress Line
                        ...List<Widget>.generate(widget.banners.length,
                            (int index) {
                          final bool isSelected = index == _currentPage;
                          final Color activeColor =
                              widget.banners[_currentPage].accentColor;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _goToPage(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 2,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                width: isSelected ? 30 : 7,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.18)
                                      : Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: isSelected
                                    ? AnimatedBuilder(
                                        animation:
                                            _autoScrollProgressController,
                                        builder: (BuildContext context,
                                            Widget? child) {
                                          final double p =
                                              _autoScrollProgressController
                                                  .value;
                                          return FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: p.clamp(0.04, 1.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: <Color>[
                                                    activeColor,
                                                    AppColors.goldLight,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                                boxShadow: <BoxShadow>[
                                                  BoxShadow(
                                                    color:
                                                        activeColor.withValues(
                                                      alpha: 0.85,
                                                    ),
                                                    blurRadius: 5,
                                                    spreadRadius: 0.5,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Procedural Aion 2 dark fantasy filigree & celestial runes painter.
/// Draws corner brackets, runic bevels, rotating tick marks, and subtle celestial geometry.
class _AionBannerFiligreePainter extends CustomPainter {
  const _AionBannerFiligreePainter({
    required this.accentColor,
    this.rotationProgress = 0.0,
    this.hasRewards = false,
  });

  final Color accentColor;
  final double rotationProgress;
  final bool hasRewards;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Subtle celestial runic ring in the upper-right corner
    final Paint runeRingPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Offset runeCenter = Offset(w - 28, 28);
    canvas.drawCircle(runeCenter, 58, runeRingPaint);
    canvas.drawCircle(runeCenter, 44, runeRingPaint);

    // Celestial crosshair / radiating axes
    final Paint runeAxisPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(runeCenter.dx - 68, runeCenter.dy),
      Offset(runeCenter.dx + 68, runeCenter.dy),
      runeAxisPaint,
    );
    canvas.drawLine(
      Offset(runeCenter.dx, runeCenter.dy - 68),
      Offset(runeCenter.dx, runeCenter.dy + 68),
      runeAxisPaint,
    );

    // Rotating diagonal tick marks
    const double tickR = 51.0;
    final double baseRotation = rotationProgress * math.pi * 2;
    for (int i = 0; i < 8; i++) {
      final double angle = baseRotation + ((i * math.pi) / 4);
      final double cosA = math.cos(angle);
      final double sinA = math.sin(angle);
      canvas.drawLine(
        Offset(runeCenter.dx + (tickR - 3) * cosA,
            runeCenter.dy + (tickR - 3) * sinA),
        Offset(runeCenter.dx + (tickR + 3) * cosA,
            runeCenter.dy + (tickR + 3) * sinA),
        runeAxisPaint,
      );
    }

    // 2. Corner filigree brackets
    final Paint cornerPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final Paint cornerDotPaint = Paint()
      ..color = AppColors.goldLight.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    const double inset = 6.0;
    const double arm = 12.0;

    // Top-Left corner
    final Path tlPath = Path()
      ..moveTo(inset + arm, inset)
      ..lineTo(inset, inset)
      ..lineTo(inset, inset + arm);
    canvas.drawPath(tlPath, cornerPaint);
    canvas.drawCircle(const Offset(inset, inset), 1.5, cornerDotPaint);

    // Top-Right corner
    final Path trPath = Path()
      ..moveTo(w - inset - arm, inset)
      ..lineTo(w - inset, inset)
      ..lineTo(w - inset, inset + arm);
    canvas.drawPath(trPath, cornerPaint);
    canvas.drawCircle(Offset(w - inset, inset), 1.5, cornerDotPaint);

    // Bottom-Left corner
    final Path blPath = Path()
      ..moveTo(inset + arm, h - inset)
      ..lineTo(inset, h - inset)
      ..lineTo(inset, h - inset - arm);
    canvas.drawPath(blPath, cornerPaint);
    canvas.drawCircle(Offset(inset, h - inset), 1.5, cornerDotPaint);

    // Bottom-Right corner
    final Path brPath = Path()
      ..moveTo(w - inset - arm, h - inset)
      ..lineTo(w - inset, h - inset)
      ..lineTo(w - inset, h - inset - arm);
    canvas.drawPath(brPath, cornerPaint);
    canvas.drawCircle(Offset(w - inset, h - inset), 1.5, cornerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _AionBannerFiligreePainter oldDelegate) =>
      oldDelegate.accentColor != accentColor ||
      oldDelegate.rotationProgress != rotationProgress ||
      oldDelegate.hasRewards != hasRewards;
}

/// Cinematic specular light sheen painter that sweeps across the card at an angle.
class _BannerSheenPainter extends CustomPainter {
  const _BannerSheenPainter({
    required this.sheenProgress,
    required this.accentColor,
  });

  final double sheenProgress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (sheenProgress <= 0.0 || sheenProgress >= 1.0) return;
    final double w = size.width;
    final double h = size.height;
    final double travel = w + h + 180.0;
    final double currentX = -90.0 + sheenProgress * travel;

    final Paint sheenPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(currentX - 55, 0),
        Offset(currentX + 55, h),
        <Color>[
          Colors.transparent,
          accentColor.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.16),
          accentColor.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        <double>[0.0, 0.35, 0.50, 0.65, 1.0],
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sheenPaint);
  }

  @override
  bool shouldRepaint(covariant _BannerSheenPainter oldDelegate) =>
      oldDelegate.sheenProgress != sheenProgress ||
      oldDelegate.accentColor != accentColor;
}
