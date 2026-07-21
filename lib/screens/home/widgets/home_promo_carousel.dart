import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../core/services/supabase_service.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';

/// Home promo carousel — loot slide pixel-faithful to original `_CratePromoBanner`.
///
/// Source: `git show 6210515:lib/screens/home/home_screen.dart` (`_CratePromoBanner`).
/// Crate art MUST overflow the card (`Positioned` negative insets + `Clip.none`).
class HomePromoCarousel extends StatefulWidget {
  const HomePromoCarousel({super.key});

  @override
  State<HomePromoCarousel> createState() => _HomePromoCarouselState();
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
    this.overflowArt = false,
    this.ctaIcon = Icons.diamond,
    this.ctaIconColor = Colors.cyanAccent,
    this.radialInner = const Color(0xFF8B0000),
    this.radialOuter = const Color(0xFF1A0000),
    this.borderColor,
    this.ctaGradient = const <Color>[Color(0xFFE50000), Color(0xFF990000)],
    this.ctaBorderColor = const Color(0xFFFF3333),
  });

  final String id;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String route;
  final String artAsset;
  final bool showTimer;
  /// Loot only: intentional large overflow. Other slides keep art contained.
  final bool overflowArt;
  final IconData ctaIcon;
  final Color ctaIconColor;
  final Color radialInner;
  final Color radialOuter;
  final Color? borderColor;
  final List<Color> ctaGradient;
  final Color ctaBorderColor;
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

class _HomePromoCarouselState extends State<HomePromoCarousel> {
  late final PageController _pageController;
  int _page = 0;
  _FeaturedLootBox? _featuredBox;
  Timer? _autoTimer;
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeaturedBox();
      _startAutoAdvance();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<_HomePromoSlide> get _slides {
    final _FeaturedLootBox? box = _featuredBox;
    final String lootCta = box == null ? '500 ile Aç' : _lootPriceLabel(box);

    return <_HomePromoSlide>[
      // LOOT — exact original `_CratePromoBanner` chrome + redcase overflow art.
      _HomePromoSlide(
        id: 'loot',
        title: 'KASA AÇ',
        subtitle: 'Sınırlı bir süre için.\nEfsanevi hediyeler seni bekliyor.',
        ctaLabel: lootCta,
        route: AppRoutes.loot,
        artAsset: 'assets/elements/redcase512px.png',
        showTimer: false,
        overflowArt: true,
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
        radialInner: AppColors.accentPurpleDim,
        radialOuter: Color(0xFF0D0618),
        borderColor: AppColors.accentPurpleGlow,
        ctaGradient: <Color>[AppColors.accentPurple, AppColors.accentPurpleDim],
        ctaBorderColor: AppColors.accentPurple,
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
        ctaIcon: Icons.ac_unit_rounded,
        ctaIconColor: Colors.white70,
        radialInner: Color(0xFF0D47A1),
        radialOuter: Color(0xFF020B1A),
        borderColor: Color(0x4D2196F3),
        ctaGradient: <Color>[Color(0xFF1E88E5), Color(0xFF0D47A1)],
        ctaBorderColor: Color(0xFF64B5F6),
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

    // Match original: LayoutBuilder width (ListView content) → compact.
    // Margin horizontal 16 like original `_CratePromoBanner`.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 390;
        final double bannerHeight = compact ? 190 : 200;

        // Original margin: horizontal 16. Overflow paints past card (Clip.none).
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
                    // CRITICAL: default Clip.hardEdge killed crate overflow.
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

/// Pixel-faithful shell from original `_CratePromoBanner` (6210515).
class _CrateBannerShell extends StatelessWidget {
  const _CrateBannerShell({
    required this.slide,
    required this.compact,
    required this.bannerHeight,
    required this.onTap,
  });

  final _HomePromoSlide slide;
  final bool compact;
  final double bannerHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Loot: intentional large overflow. Other slides: contained ~40% right rail.
    final bool overflow = slide.overflowArt;
    final double imageWidth = overflow
        ? (compact ? 240.0 : 280.0)
        : (compact ? 118.0 : 132.0);
    final double imageRight = overflow
        ? (compact ? -34.0 : -50.0)
        : (compact ? 8.0 : 12.0);
    final double imageTopBottom = overflow
        ? (compact ? -36.0 : -50.0)
        : (compact ? 18.0 : 22.0);
    final double contentRight = overflow
        ? (compact ? 148.0 : 180.0)
        : (compact ? 132.0 : 150.0);
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
            // Background layer — original red radial + grid (loot); accents vary.
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: RadialGradient(
                    center: const Alignment(0.6, 0.0),
                    radius: 1.5,
                    colors: <Color>[slide.radialInner, slide.radialOuter],
                  ),
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: overflow
                      ? const CustomPaint(painter: _GridPainter())
                      : const CustomPaint(
                          painter: DotGridPainter(
                            spacing: 18,
                            dotRadius: 0.9,
                            dotOpacity: 0.07,
                          ),
                        ),
                ),
              ),
            ),
            // Image — loot overflows; other slides stay inside the card.
            Positioned(
              right: imageRight,
              top: imageTopBottom,
              bottom: imageTopBottom,
              width: imageWidth,
              child: Image.asset(
                slide.artAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => overflow
                    ? Image.asset(
                        'assets/elements/redcase512px.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      )
                    : Icon(
                        slide.ctaIcon,
                        size: compact ? 56 : 64,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
              ),
            ),
            // Left Content
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
                          spreadRadius: 0,
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

/// Original grid texture from `_CratePromoBanner`.
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
