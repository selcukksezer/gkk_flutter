import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/supabase_service.dart';
import '../../../models/retention_promos_model.dart';
import '../../../providers/retention_promos_provider.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';

/// Home promo carousel — hepsi kasa chrome. Yeni sistemler (Gece / Kodex / Nemesis) sabit.
class HomePromoCarousel extends ConsumerStatefulWidget {
  const HomePromoCarousel({super.key});

  @override
  ConsumerState<HomePromoCarousel> createState() => _HomePromoCarouselState();
}

class _HomePromoSlide {
  const _HomePromoSlide({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.route,
    required this.artAsset,
    this.showTimer = false,
    this.timerSeconds = 0,
    this.ctaIcon = Icons.diamond,
    this.ctaIconColor = Colors.cyanAccent,
    this.radialInner = const Color(0xFF8B0000),
    this.radialOuter = const Color(0xFF1A0000),
    this.borderColor,
    this.ctaGradient = const <Color>[Color(0xFFE50000), Color(0xFF990000)],
    this.ctaBorderColor = const Color(0xFFFF3333),
    this.showDismiss = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String route;
  final String artAsset;
  final bool showTimer;
  final int timerSeconds;
  final IconData ctaIcon;
  final Color ctaIconColor;
  final Color radialInner;
  final Color radialOuter;
  final Color? borderColor;
  final List<Color> ctaGradient;
  final Color ctaBorderColor;
  final bool showDismiss;
}

class _FeaturedLootBox {
  const _FeaturedLootBox({
    required this.name,
    required this.description,
    required this.price,
    required this.currencyType,
  });

  final String name;
  final String description;
  final int price;
  final String currencyType;

  factory _FeaturedLootBox.fromMap(Map<String, dynamic> map) {
    return _FeaturedLootBox(
      name: map['name']?.toString() ?? 'Kasa',
      description: map['description']?.toString() ?? '',
      price: _lootInt(map['price']),
      currencyType: map['currency_type']?.toString() ?? 'gems',
    );
  }
}

class _HomePromoCarouselState extends ConsumerState<HomePromoCarousel> {
  late final PageController _pageController;
  int _page = 0;
  _FeaturedLootBox? _featuredBox;
  Timer? _autoTimer;
  Timer? _countdownTimer;
  bool _userInteracting = false;
  bool _dismissingNemesis = false;
  int _nightMarketBaseSeconds = 0;
  DateTime? _nightMarketSyncedAt;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(retentionPromosProvider.notifier).load(silent: true);
      _loadFeaturedBox();
      _startAutoAdvance();
      _startCountdownTick();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _countdownTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _syncNightMarketClock(RetentionPromos promos) {
    if (!promos.nightMarket.active) {
      _nightMarketSyncedAt = null;
      return;
    }
    final int serverSecs = promos.nightMarket.secondsLeft;
    if (_nightMarketSyncedAt == null) {
      _nightMarketBaseSeconds = serverSecs;
      _nightMarketSyncedAt = DateTime.now();
      return;
    }
    final int elapsed = DateTime.now().difference(_nightMarketSyncedAt!).inSeconds;
    final int localSecs = (_nightMarketBaseSeconds - elapsed).clamp(0, 999999);
    if ((localSecs - serverSecs).abs() > 3) {
      _nightMarketBaseSeconds = serverSecs;
      _nightMarketSyncedAt = DateTime.now();
    }
  }

  int _liveNightMarketSeconds(RetentionPromos promos) {
    if (!promos.nightMarket.active) return 0;
    _syncNightMarketClock(promos);
    if (_nightMarketSyncedAt == null) return promos.nightMarket.secondsLeft;
    final int elapsed = DateTime.now().difference(_nightMarketSyncedAt!).inSeconds;
    return (_nightMarketBaseSeconds - elapsed).clamp(0, 999999);
  }

  Future<void> _dismissNemesisBanner() async {
    if (_dismissingNemesis) return;
    setState(() => _dismissingNemesis = true);
    try {
      await SupabaseService.client.rpc('dismiss_nemesis_banner');
      await ref.read(retentionPromosProvider.notifier).load(silent: true);
    } catch (_) {
      // Sessiz.
    } finally {
      if (mounted) setState(() => _dismissingNemesis = false);
    }
  }

  void _startCountdownTick() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final RetentionPromos promos = ref.read(retentionPromosProvider).promos;
      _syncNightMarketClock(promos);
      if (promos.nightMarket.active) {
        setState(() {});
      }
    });
  }

  /// Yeni sistemler — her zaman carousel'de (kasa chrome).
  List<_HomePromoSlide> _newSystemSlides(RetentionPromos promos) {
    final bool nightOpen = promos.nightMarket.active;
    final int nightSecs = _liveNightMarketSeconds(promos);
    final bool claimable = promos.codex.claimableMilestones > 0;
    final bool hasRival = promos.nemesis.hasRival && !promos.nemesis.dismissed;
    final String rival = promos.nemesis.rivalUsername ?? 'Rakip';
    final String revengeRoute = promos.nemesis.rivalId != null
        ? '${AppRoutes.pvp}?revenge=${promos.nemesis.rivalId}'
        : AppRoutes.pvp;

    return <_HomePromoSlide>[
      _HomePromoSlide(
        id: 'night_market',
        title: 'GECE PAZARI',
        subtitle: nightOpen
            ? 'Günlük gem teklifleri.\nSınırlı stok — kaçırma.'
            : 'Her gün 20:00–22:00 TR.\nGem fırsatları seni bekliyor.',
        ctaLabel: nightOpen ? 'Pazara Git' : 'Mağazaya Git',
        route: '${AppRoutes.shop}?tab=night',
        artAsset: 'assets/menuitems/magaza.png',
        showTimer: nightOpen && nightSecs > 0,
        timerSeconds: nightSecs,
        ctaIcon: Icons.nights_stay_rounded,
        ctaIconColor: AppColors.warningSolar,
        radialInner: const Color(0xFF6B1A4A),
        radialOuter: const Color(0xFF12040C),
        borderColor: AppColors.cyberFuchsia.withValues(alpha: 0.45),
        ctaGradient: const <Color>[
          Color(0xFFFFB800),
          Color(0xFFE08A00),
        ],
        ctaBorderColor: AppColors.liquidGold,
      ),
      _HomePromoSlide(
        id: 'codex',
        title: 'KODEX',
        subtitle: claimable
            ? '${promos.codex.discovered}/${promos.codex.total} keşif · ${promos.codex.claimableMilestones} ödül bekliyor.'
            : '${promos.codex.discovered}/${promos.codex.total} keşif.\nBoss, eşya, zindan topla.',
        ctaLabel: claimable ? 'Ödülleri Al' : 'Kodex\'i Aç',
        route: claimable ? '${AppRoutes.codex}?claim=1' : AppRoutes.codex,
        artAsset: 'assets/menuitems/karakter.png',
        ctaIcon: Icons.menu_book_rounded,
        ctaIconColor: AppColors.liquidGold,
        radialInner: const Color(0xFF6B5200),
        radialOuter: const Color(0xFF120E00),
        borderColor: AppColors.liquidGold.withValues(alpha: 0.4),
        ctaGradient: const <Color>[
          Color(0xFFFFD64A),
          Color(0xFFFFB800),
          Color(0xFFE08A00),
        ],
        ctaBorderColor: AppColors.liquidGold,
      ),
      if (hasRival)
        _HomePromoSlide(
          id: 'nemesis',
          title: 'NEMESIS',
          subtitle: '$rival — ${promos.nemesis.losses} yenilgi.\nİntikam zamanı.',
          ctaLabel: 'Düello Gönder',
          route: revengeRoute,
          artAsset: 'assets/menuitems/pvp.png',
          ctaIcon: Icons.sports_mma_rounded,
          ctaIconColor: Colors.white,
          radialInner: const Color(0xFF8B0000),
          radialOuter: const Color(0xFF1A0000),
          borderColor: AppColors.mysticRuby.withValues(alpha: 0.45),
          ctaGradient: const <Color>[
            Color(0xFFE52E2E),
            Color(0xFF8B0000),
          ],
          ctaBorderColor: AppColors.mysticRuby,
          showDismiss: true,
        )
      else
        const _HomePromoSlide(
          id: 'nemesis',
          title: 'NEMESIS',
          subtitle: 'PvP rakibin peşinde.\nİntikam + bonus altın.',
          ctaLabel: 'Arenaya Gir',
          route: AppRoutes.pvp,
          artAsset: 'assets/menuitems/pvp.png',
          ctaIcon: Icons.sports_mma_rounded,
          ctaIconColor: Colors.white70,
          radialInner: Color(0xFF5A1010),
          radialOuter: Color(0xFF120404),
          borderColor: Color(0x73E52E2E),
          ctaGradient: <Color>[Color(0xFFE52E2E), Color(0xFF8B0000)],
          ctaBorderColor: AppColors.mysticRuby,
        ),
    ];
  }

  List<_HomePromoSlide> get _slides {
    final RetentionPromos promos = ref.watch(retentionPromosProvider).promos;
    final _FeaturedLootBox? box = _featuredBox;
    final String lootCta = box == null ? '500 ile Aç' : _lootPriceLabel(box);

    final List<_HomePromoSlide> classic = <_HomePromoSlide>[
      _HomePromoSlide(
        id: 'loot',
        title: 'KASA AÇ',
        subtitle: 'Sınırlı bir süre için.\nEfsanevi hediyeler seni bekliyor.',
        ctaLabel: lootCta,
        route: AppRoutes.loot,
        artAsset: 'assets/elements/redcase512px.png',
        ctaIcon: Icons.diamond,
        ctaIconColor: Colors.cyanAccent,
      ),
      const _HomePromoSlide(
        id: 'dungeon',
        title: 'ZİNDAN',
        subtitle: 'Boss avla.\nEfsanevi loot seni bekliyor.',
        ctaLabel: 'Zindana Gir',
        route: AppRoutes.dungeon,
        artAsset: 'assets/menuitems/zindan.png',
        ctaIcon: Icons.shield_moon_outlined,
        ctaIconColor: Colors.white70,
        radialInner: Color(0xFF6B1A4A),
        radialOuter: Color(0xFF12040C),
        borderColor: Color(0x73E01E5A),
        ctaGradient: <Color>[AppColors.cyberFuchsia, Color(0xFF9A1040)],
        ctaBorderColor: AppColors.cyberFuchsia,
      ),
      const _HomePromoSlide(
        id: 'horse',
        title: 'AT YARIŞI',
        subtitle: 'Bahis yap.\nJackpot peşinde koş.',
        ctaLabel: 'Yarışa Git',
        route: AppRoutes.horseRace,
        artAsset: 'assets/menuitems/magaza.png',
        ctaIcon: Icons.sports_motorsports_rounded,
        ctaIconColor: Colors.white70,
        radialInner: Color(0xFF1B5E20),
        radialOuter: Color(0xFF061208),
        borderColor: Color(0x4D4CAF50),
        ctaGradient: <Color>[Color(0xFF43A047), Color(0xFF1B5E20)],
        ctaBorderColor: Color(0xFF81C784),
      ),
      const _HomePromoSlide(
        id: 'season',
        title: 'SAVAŞ GEÇİDİ',
        subtitle: 'Sezon ödüllerini kaçırma.\nSavaş geçidini aç.',
        ctaLabel: 'Geçidi Aç',
        route: AppRoutes.season,
        artAsset: 'assets/menuitems/battlepass.png',
        ctaIcon: Icons.military_tech_rounded,
        ctaIconColor: AppColors.liquidGold,
        radialInner: Color(0xFF6B5200),
        radialOuter: Color(0xFF120E00),
        borderColor: Color(0x66FFB800),
        ctaGradient: <Color>[
          Color(0xFFFFD64A),
          AppColors.liquidGold,
          Color(0xFFE08A00),
        ],
        ctaBorderColor: AppColors.liquidGold,
      ),
      const _HomePromoSlide(
        id: 'enhance',
        title: 'EŞYA YÜKSELT',
        subtitle: 'Forge ile güç katla.\nEfsane ol.',
        ctaLabel: 'Yükselt',
        route: AppRoutes.enhancement,
        artAsset: 'assets/menuitems/itemupgrade.png',
        ctaIcon: Icons.auto_fix_high_outlined,
        ctaIconColor: Colors.white70,
        radialInner: Color(0xFFE65100),
        radialOuter: Color(0xFF1A0A00),
        borderColor: Color(0x4DFF9800),
        ctaGradient: <Color>[Color(0xFFFF6D00), Color(0xFFE65100)],
        ctaBorderColor: Color(0xFFFFB74D),
      ),
      const _HomePromoSlide(
        id: 'pvp',
        title: 'PvP ARENA',
        subtitle: 'Rakipleri ez.\nSıralamada yüksel.',
        ctaLabel: 'Düelloya Gir',
        route: AppRoutes.pvp,
        artAsset: 'assets/menuitems/pvp.png',
        ctaIcon: Icons.sports_kabaddi_rounded,
        ctaIconColor: Colors.white70,
        radialInner: Color(0xFFB71C1C),
        radialOuter: Color(0xFF1A0000),
        borderColor: Color(0x4DF44336),
        ctaGradient: <Color>[Color(0xFFE53935), Color(0xFFB71C1C)],
        ctaBorderColor: Color(0xFFEF9A9A),
      ),
    ];

    // Yeni sistemler önde → kasa → klasik.
    return <_HomePromoSlide>[
      ..._newSystemSlides(promos),
      ...classic,
    ];
  }

  Future<void> _loadFeaturedBox() async {
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('get_loot_boxes_with_stats');
      final List<Map<String, dynamic>> rows = _lootRowsFromRpc(raw);
      _FeaturedLootBox? featured;
      for (final Map<String, dynamic> row in rows) {
        final _FeaturedLootBox box = _FeaturedLootBox.fromMap(row);
        if (box.currencyType == 'gems') {
          featured = box;
          break;
        }
      }
      featured ??=
          rows.isNotEmpty ? _FeaturedLootBox.fromMap(rows.first) : null;
      if (mounted) setState(() => _featuredBox = featured);
    } catch (_) {
      // Keep static CTA fallback.
    }
  }

  void _startAutoAdvance() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _userInteracting || !_pageController.hasClients) return;
      final int next = (_page + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onPointerDown() {
    _userInteracting = true;
    _autoTimer?.cancel();
  }

  void _onPointerUp() {
    _userInteracting = false;
    _startAutoAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final List<_HomePromoSlide> slides = _slides;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 390;
        final double bannerHeight = compact ? 190 : 200;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
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
                    clipBehavior: Clip.none,
                    itemCount: slides.length,
                    onPageChanged: (int index) {
                      setState(() => _page = index);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      return _CrateBannerShell(
                        slide: slides[index],
                        compact: compact,
                        bannerHeight: bannerHeight,
                        onTap: () => context.push(slides[index].route),
                        onDismiss: slides[index].showDismiss
                            ? _dismissNemesisBanner
                            : null,
                        dismissLoading: _dismissingNemesis,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _PageDots(count: slides.length, index: _page),
            ],
          ),
        );
      },
    );
  }
}

/// Kasa chrome — tüm slide'lar aynı shell (overflow art + grid + radial).
class _CrateBannerShell extends StatelessWidget {
  const _CrateBannerShell({
    required this.slide,
    required this.compact,
    required this.bannerHeight,
    required this.onTap,
    this.onDismiss,
    this.dismissLoading = false,
  });

  final _HomePromoSlide slide;
  final bool compact;
  final double bannerHeight;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;
  final bool dismissLoading;

  @override
  Widget build(BuildContext context) {
    // Kasa: büyük overflow. Diğerleri: daha küçük contained art.
    final bool isLoot = slide.id == 'loot';
    final double imageWidth = isLoot
        ? (compact ? 240.0 : 280.0)
        : (compact ? 118.0 : 132.0);
    final double imageRight = isLoot
        ? (compact ? -34.0 : -50.0)
        : (compact ? 8.0 : 12.0);
    final double imageTopBottom = isLoot
        ? (compact ? -36.0 : -50.0)
        : (compact ? 22.0 : 26.0);
    final double contentRight = isLoot
        ? (compact ? 148.0 : 180.0)
        : (compact ? 128.0 : 146.0);
    final Color borderColor =
        slide.borderColor ?? Colors.red.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        height: bannerHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: RadialGradient(
                    center: const Alignment(0.6, 0.0),
                    radius: 1.5,
                    colors: <Color>[slide.radialInner, slide.radialOuter],
                  ),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: const CustomPaint(painter: _GridPainter()),
                ),
              ),
            ),
            Positioned(
              right: imageRight,
              top: imageTopBottom,
              bottom: imageTopBottom,
              width: imageWidth,
              child: Image.asset(
                slide.artAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  slide.ctaIcon,
                  size: compact ? 72 : 88,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
            if (onDismiss != null)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: AppColors.carbonVoid.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: dismissLoading ? null : onDismiss,
                    tooltip: '24 saat gizle',
                    iconSize: 18,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: dismissLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                  ),
                ),
              ),
            Positioned(
              left: 20,
              top: compact ? 18 : 24,
              bottom: compact ? 18 : 24,
              right: contentRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      slide.title,
                      style: GoogleFonts.urbanist(
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 24 : 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  if (slide.showTimer && slide.timerSeconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.carbonVoid.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppColors.warningSolar.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          _formatTimer(slide.timerSeconds),
                          style: GoogleFonts.urbanist(
                            fontSize: compact ? 11 : 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warningSolar,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    slide.subtitle,
                    style: GoogleFonts.urbanist(
                      textStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: compact ? 12 : 13,
                        height: 1.4,
                      ),
                    ),
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: slide.ctaGradient,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          offset: const Offset(0, 1),
                          blurRadius: 0,
                        ),
                      ],
                      border: Border.all(
                        color: slide.ctaBorderColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          slide.ctaLabel,
                          style: GoogleFonts.urbanist(
                            textStyle: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 15 : 16,
                              fontWeight: FontWeight.bold,
                              shadows: const <Shadow>[
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          slide.ctaIcon,
                          color: slide.ctaIconColor,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (int i) {
        final bool active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 14 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: active
                ? const Color(0xFFE50000)
                : Colors.white.withValues(alpha: 0.28),
          ),
        );
      }),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    const double cell = 20.0;
    for (double x = 0.0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0.0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatTimer(int seconds) {
  final int h = seconds ~/ 3600;
  final int m = (seconds % 3600) ~/ 60;
  final int s = seconds % 60;
  if (h > 0) return '${h}s ${m}dk ${s}sn';
  if (m > 0) return '${m}dk ${s}sn';
  return '${s}sn';
}

List<Map<String, dynamic>> _lootRowsFromRpc(dynamic raw) {
  if (raw is! List) return <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
      .toList();
}

int _lootInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _lootPriceLabel(_FeaturedLootBox box) {
  final String amount = _compactLootPrice(box.price);
  return box.currencyType == 'gems'
      ? '$amount ile Aç'
      : '$amount Altın ile Aç';
}

String _compactLootPrice(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
