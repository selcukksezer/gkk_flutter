import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/item_model.dart';
import '../../models/player_badge_model.dart';
import '../../providers/player_badges_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// 2027 Aion 2 Obsidian-Glass & Celestial Color Token Manifest.
abstract final class _AionShowcaseTheme {
  static const Color obsidianVoid = Color(0xFF07090E);
  static const Color obsidianDeep = Color(0xFF0B101D);
  static const Color obsidianMid = Color(0xFF0F1526);
  static const Color obsidianCard = Color(0xE6101728);
  static const Color obsidianElevated = Color(0xF2141D30);

  // Celestial gold tier palette (#E5C158)
  static const Color celestialGold = Color(0xFFE5C158);
  static const Color celestialGoldLight = Color(0xFFFBEAA8);
  static const Color celestialGoldDim = Color(0xFF9E8133);
  static const Color celestialGoldGlow = Color(0x40E5C158);

  // Ether cyan accents
  static const Color etherCyan = Color(0xFF38E5FF);
  static const Color etherCyanDim = Color(0xFF1599AD);
  static const Color etherCyanGlow = Color(0x3338E5FF);

  // Glass borders & gradients
  static const LinearGradient obsidianGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xF011182B),
      Color(0xE60D1322),
      Color(0xF5080C16),
    ],
    stops: <double>[0.0, 0.5, 1.0],
  );

  static const LinearGradient cardBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0x80FFFFFF),
      Color(0x66E5C158),
      Color(0x3338E5FF),
      Color(0x4DE5C158),
    ],
    stops: <double>[0.0, 0.35, 0.7, 1.0],
  );
}

/// Visual classification for high-fantasy Aion 2 military and glory insignia.
enum AionBadgeType {
  abyssGeneral,
  abyssCommander,
  abyssCenturion,
  legionLegatus,
  pvpGladiator,
  conqueror,
  seasonChampion,
  artisan,
  prestigeCosmic,
}

/// Rozet Vitrini — 2027 Aion 2 Mobile High-Fantasy Standard.
/// Military Abyss Ranks, Legion Insignia, and PvP Glory Badges with Layered Canvas Renderers,
/// Obsidian-Glass frosted panels (sigma 16), Stepped Celestial Pedestals, Tier Glow,
/// full SafeArea notch resilience, and tactile HapticFeedback.
class BadgeShowcasePanel extends ConsumerStatefulWidget {
  const BadgeShowcasePanel({super.key});

  @override
  ConsumerState<BadgeShowcasePanel> createState() => _BadgeShowcasePanelState();
}

class _BadgeShowcasePanelState extends ConsumerState<BadgeShowcasePanel> {
  static const int _previewCount = 4;
  bool _expanded = false;
  int _selectedFilterIndex = 0;

  static const List<String> _filters = <String>[
    'Tümü',
    '⚔️ Askeri',
    '🏆 PvP',
    '🛡️ Lejyon',
  ];

  @override
  Widget build(BuildContext context) {
    final PlayerBadgesState badgeState = ref.watch(playerBadgesProvider);
    final List<PlayerBadge> badges = badgeState.badges;

    if (badgeState.isLoading && badges.isEmpty) {
      return _buildLoadingSkeleton();
    }
    if (badges.isEmpty) {
      return _buildEmptyPrestigeShowcase();
    }

    final List<PlayerBadge> filteredBadges = _applyFilter(badges, _selectedFilterIndex);
    final bool canExpand = filteredBadges.length > _previewCount;
    final List<PlayerBadge> visible = (!_expanded && canExpand)
        ? filteredBadges.take(_previewCount).toList(growable: false)
        : filteredBadges;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: _AionShowcaseTheme.obsidianGlassGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: -2,
              ),
              BoxShadow(
                color: _AionShowcaseTheme.etherCyan.withValues(alpha: 0.06),
                blurRadius: 24,
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.72),
                offset: const Offset(0, 6),
                blurRadius: 16,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // Runic corner ornaments with celestial gold & ether cyan nodes
              const Positioned(
                top: 5,
                left: 5,
                child: _RunicCorner(color: _AionShowcaseTheme.celestialGold),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: Transform.rotate(
                  angle: math.pi / 2,
                  child: const _RunicCorner(color: _AionShowcaseTheme.celestialGold),
                ),
              ),
              Positioned(
                bottom: 5,
                left: 5,
                child: Transform.rotate(
                  angle: -math.pi / 2,
                  child: const _RunicCorner(color: _AionShowcaseTheme.celestialGold),
                ),
              ),
              Positioned(
                bottom: 5,
                right: 5,
                child: Transform.rotate(
                  angle: math.pi,
                  child: const _RunicCorner(color: _AionShowcaseTheme.celestialGold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Header Bar with military heraldic insignia
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(7.5),
                          decoration: BoxDecoration(
                            gradient: const RadialGradient(
                              colors: <Color>[
                                Color(0xFF263352),
                                _AionShowcaseTheme.obsidianVoid,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.7),
                              width: 1.2,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.military_tech_rounded,
                            color: _AionShowcaseTheme.celestialGold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'ABYSS & LEJYON VİTRİNİ',
                                style: GoogleFonts.cinzel(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              Row(
                                children: <Widget>[
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _AionShowcaseTheme.etherCyan,
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: _AionShowcaseTheme.etherCyan,
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Yüksek Askeri Rütbe ve Zafer Nişanları',
                                    style: GoogleFonts.urbanist(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: _AionShowcaseTheme.obsidianVoid.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.55),
                              width: 1,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.18),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.workspace_premium_rounded,
                                size: 12,
                                color: _AionShowcaseTheme.celestialGold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${badges.length} Rozet',
                                style: GoogleFonts.urbanist(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _AionShowcaseTheme.celestialGoldLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Category Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List<Widget>.generate(_filters.length, (int index) {
                          final bool isSelected = _selectedFilterIndex == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedFilterIndex = index);
                                },
                                borderRadius: BorderRadius.circular(10),
                                splashColor: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.2),
                                highlightColor: _AionShowcaseTheme.etherCyan.withValues(alpha: 0.1),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _AionShowcaseTheme.celestialGold.withValues(alpha: 0.18)
                                        : _AionShowcaseTheme.obsidianVoid.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? _AionShowcaseTheme.celestialGold
                                          : Colors.white.withValues(alpha: 0.12),
                                      width: isSelected ? 1.2 : 0.8,
                                    ),
                                    boxShadow: isSelected
                                        ? <BoxShadow>[
                                            BoxShadow(
                                              color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.28),
                                              blurRadius: 10,
                                              spreadRadius: -1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    _filters[index],
                                    style: GoogleFonts.urbanist(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected
                                          ? _AionShowcaseTheme.celestialGoldLight
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Badge Grid / List with animated container
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: visible.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 28,
                                      color: AppColors.textTertiary.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Bu kategoride henüz kazanılmış rozet bulunmuyor.',
                                      style: GoogleFonts.urbanist(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 10,
                              children: visible
                                  .map((PlayerBadge badge) => _AionBadgeCard(
                                        badge: badge,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          _showBadgeDetailModal(context, badge);
                                        },
                                      ))
                                  .toList(growable: false),
                            ),
                    ),
                    if (canExpand) ...<Widget>[
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _expanded = !_expanded);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 7.5),
                            decoration: BoxDecoration(
                              color: _AionShowcaseTheme.obsidianVoid.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.35),
                                width: 0.9,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  _expanded
                                      ? 'Vitrin Kapanışını Daralt'
                                      : 'Tüm Askeri Rozetleri Aç (${filteredBadges.length})',
                                  style: GoogleFonts.cinzel(
                                    fontSize: 11,
                                    color: _AionShowcaseTheme.celestialGold,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 17,
                                  color: _AionShowcaseTheme.celestialGold,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PlayerBadge> _applyFilter(List<PlayerBadge> badges, int filterIndex) {
    if (filterIndex == 0) return badges;
    return badges.where((PlayerBadge b) {
      final AionBadgeType type = _resolveBadgeType(b);
      switch (filterIndex) {
        case 1: // Askeri
          return type == AionBadgeType.abyssGeneral ||
              type == AionBadgeType.abyssCommander ||
              type == AionBadgeType.abyssCenturion;
        case 2: // PvP
          return type == AionBadgeType.pvpGladiator ||
              type == AionBadgeType.conqueror ||
              type == AionBadgeType.seasonChampion;
        case 3: // Lejyon
          return type == AionBadgeType.legionLegatus ||
              type == AionBadgeType.artisan ||
              type == AionBadgeType.prestigeCosmic;
        default:
          return true;
      }
    }).toList(growable: false);
  }

  Widget _buildLoadingSkeleton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
          decoration: BoxDecoration(
            gradient: _AionShowcaseTheme.obsidianGlassGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: _AionShowcaseTheme.celestialGold,
                  strokeWidth: 2.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Abyss Nişanları Yükleniyor...',
                style: GoogleFonts.cinzel(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _AionShowcaseTheme.celestialGoldLight,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPrestigeShowcase() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: _AionShowcaseTheme.obsidianGlassGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.military_tech_rounded,
                    color: _AionShowcaseTheme.celestialGold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ABYSS & LEJYON VİTRİNİ',
                    style: GoogleFonts.cinzel(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Henüz askeri veya PvP rozeti kazanmadınız. Abyss savaşlarına ve lejyon zindanlarına katılarak Baş General, Bölük Komutanı ve Zafer nişanlarını açın.',
                style: GoogleFonts.urbanist(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const List<String> months = <String>[
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    final String day = dt.day.toString().padLeft(2, '0');
    final String month = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
    final int year = dt.year;
    return '$day $month $year';
  }

  void _showBadgeDetailModal(BuildContext context, PlayerBadge badge) {
    final Color rarityC = getRarityColor(badge.rarity);
    final AionBadgeType type = _resolveBadgeType(badge);
    final String lore = _getBadgeLore(type, badge.name);
    final String bonusText = _getBadgeCombatBuff(type, badge.rarity);
    final int stars = _getBadgeStars(type, badge.rarity);
    final String tierTitle = _getBadgeTierTitle(type, badge.rarity);
    final String acquisitionDate = _formatDate(badge.earnedAt);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (BuildContext ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.90,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xF510162A),
                    Color(0xF80B0F1E),
                    Color(0xFF07090F),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: rarityC.withValues(alpha: 0.6),
                  width: 1.4,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: rarityC.withValues(alpha: 0.32),
                    blurRadius: 36,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.15),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Pull Bar Pill
                      Container(
                        width: 46,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Stepped Celestial Altar Podium
                      Center(
                        child: SizedBox(
                          width: 160,
                          height: 140,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              // Multi-tiered glowing pedestal altar
                              Positioned(
                                bottom: 0,
                                child: CustomPaint(
                                  size: const Size(140, 48),
                                  painter: _AltarPedestalPainter(
                                    primaryColor: rarityC,
                                    celestialGold: _AionShowcaseTheme.celestialGold,
                                  ),
                                ),
                              ),
                              // High-Res Heraldry Canvas (100x100)
                              Positioned(
                                top: 6,
                                child: CustomPaint(
                                  size: const Size(100, 100),
                                  painter: AionBadgeCanvasPainter(
                                    badgeType: type,
                                    rarity: badge.rarity,
                                    primaryColor: rarityC,
                                    isEnlarged: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Badge Name with Tier Glow
                      Text(
                        badge.name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: rarityC,
                          letterSpacing: 0.8,
                          shadows: <Shadow>[
                            Shadow(
                              color: rarityC.withValues(alpha: 0.65),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Tier Subtitle
                      Text(
                        tierTitle,
                        style: GoogleFonts.urbanist(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _AionShowcaseTheme.celestialGoldLight,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Rarity Pill & Stars Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: rarityC.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: rarityC.withValues(alpha: 0.6)),
                            ),
                            child: Text(
                              badge.rarity.name.toUpperCase(),
                              style: GoogleFonts.urbanist(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: rarityC,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          if (stars > 0) ...<Widget>[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: _AionShowcaseTheme.obsidianVoid.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.4),
                                  width: 0.9,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List<Widget>.generate(stars, (int i) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 1),
                                    child: Icon(
                                      Icons.star_rounded,
                                      size: 13,
                                      color: _AionShowcaseTheme.celestialGold,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Lore & Combat Buff Container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _AionShowcaseTheme.obsidianCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              offset: const Offset(0, 3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.auto_stories_rounded,
                                  size: 15,
                                  color: _AionShowcaseTheme.celestialGold,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'RÜTBE HİKAYESİ VE ŞANI',
                                  style: GoogleFonts.cinzel(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _AionShowcaseTheme.celestialGoldLight,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lore,
                              style: GoogleFonts.urbanist(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Combat Buff Box
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                              decoration: BoxDecoration(
                                color: _AionShowcaseTheme.obsidianVoid.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: _AionShowcaseTheme.etherCyan.withValues(alpha: 0.45),
                                  width: 0.9,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.bolt_rounded,
                                    color: _AionShowcaseTheme.etherCyan,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      bonusText,
                                      style: GoogleFonts.urbanist(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _AionShowcaseTheme.etherCyan,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Meta Row: Earned Date & Origin
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 11,
                                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Kazanım: $acquisitionDate',
                                      style: GoogleFonts.urbanist(
                                        fontSize: 10.5,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    badge.source.toUpperCase(),
                                    style: GoogleFonts.urbanist(
                                      fontSize: 9.5,
                                      color: AppColors.textTertiary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Equip Action Button with Haptic Feedback
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: _AionShowcaseTheme.celestialGold,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${badge.name} unvan nişanı aktif başlık olarak kuşandı.',
                                        style: GoogleFonts.urbanist(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: _AionShowcaseTheme.obsidianElevated,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: rarityC.withValues(alpha: 0.6),
                                    width: 1,
                                  ),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: rarityC.withValues(alpha: 0.28),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: rarityC, width: 1.3),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                            shadowColor: rarityC.withValues(alpha: 0.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.shield_rounded,
                                size: 16,
                                color: _AionShowcaseTheme.celestialGold,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Aktif Başlık Olarak Kuşan',
                                style: GoogleFonts.cinzel(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static AionBadgeType _resolveBadgeType(PlayerBadge badge) {
    final String key = ('${badge.itemId}_${badge.name}').toLowerCase();
    if (key.contains('general') || key.contains('bas_general') || key.contains('abyss_general')) {
      return AionBadgeType.abyssGeneral;
    }
    if (key.contains('commander') || key.contains('komutan')) {
      return AionBadgeType.abyssCommander;
    }
    if (key.contains('centurion') || key.contains('yuzbasi')) {
      return AionBadgeType.abyssCenturion;
    }
    if (key.contains('legatus') || key.contains('lejyon') || key.contains('legion')) {
      return AionBadgeType.legionLegatus;
    }
    if (key.contains('gladiator') || key.contains('gladyator') || key.contains('pvp')) {
      return AionBadgeType.pvpGladiator;
    }
    if (key.contains('conqueror') || key.contains('fatih') || key.contains('zafer')) {
      return AionBadgeType.conqueror;
    }
    if (key.contains('season') || key.contains('sezon')) {
      return AionBadgeType.seasonChampion;
    }
    if (key.contains('craft') || key.contains('artisan') || key.contains('demirci')) {
      return AionBadgeType.artisan;
    }
    return switch (badge.rarity) {
      Rarity.mythic => AionBadgeType.abyssGeneral,
      Rarity.legendary => AionBadgeType.abyssCommander,
      Rarity.epic => AionBadgeType.legionLegatus,
      Rarity.rare => AionBadgeType.abyssCenturion,
      _ => AionBadgeType.prestigeCosmic,
    };
  }

  static String _getBadgeTierTitle(AionBadgeType type, Rarity rarity) {
    switch (type) {
      case AionBadgeType.abyssGeneral:
        return 'Abyss 5-Yıldızlı Başkomutan';
      case AionBadgeType.abyssCommander:
        return 'Abyss 4-Yıldızlı Bölük Komutanı';
      case AionBadgeType.abyssCenturion:
        return 'Abyss 3-Yıldızlı Kıdemli Yüzbaşı';
      case AionBadgeType.legionLegatus:
        return 'Kadim Lejyon Sancaktarı';
      case AionBadgeType.pvpGladiator:
        return 'Arena Yenilmez Gladyatörü';
      case AionBadgeType.conqueror:
        return 'Kale Kuşatması Fatihi';
      case AionBadgeType.seasonChampion:
        return 'Resmi PvP Sezon Şampiyonu';
      case AionBadgeType.artisan:
        return 'Kutsal Demirci & Zanaatkâr';
      case AionBadgeType.prestigeCosmic:
        return 'Atreia Kozmik Prestij Nişanı';
    }
  }

  static int _getBadgeStars(AionBadgeType type, Rarity rarity) {
    switch (type) {
      case AionBadgeType.abyssGeneral:
        return 5;
      case AionBadgeType.abyssCommander:
        return 4;
      case AionBadgeType.abyssCenturion:
        return 3;
      case AionBadgeType.seasonChampion:
      case AionBadgeType.conqueror:
      case AionBadgeType.pvpGladiator:
        return 3;
      case AionBadgeType.legionLegatus:
      case AionBadgeType.artisan:
      case AionBadgeType.prestigeCosmic:
        return switch (rarity) {
          Rarity.mythic => 5,
          Rarity.legendary => 4,
          Rarity.epic => 3,
          Rarity.rare => 2,
          _ => 1,
        };
    }
  }

  static String _getBadgeLore(AionBadgeType type, String name) {
    switch (type) {
      case AionBadgeType.abyssGeneral:
        return 'Abyss derinliklerindeki en çetin kale kuşatmalarında 5 yıldızlı başkomutanlık sergileyen kahramanlara bağışlanan en yüksek askeri nişan.';
      case AionBadgeType.abyssCommander:
        return 'Savaş meydanında ön cepheyi yöneten, kılıçlarıyla gök kubbeyi aydınlatan 4 yıldızlı Abyss Bölük Komutanı unvanı.';
      case AionBadgeType.abyssCenturion:
        return 'Yüzlerce çarpışmadan sağ çıkan ve sancağı asla yere düşürmeyen 3 yıldızlı kıdemli Abyss Yüzbaşısı.';
      case AionBadgeType.legionLegatus:
        return 'Lejyonun kadim sancağını taşıyan, klan üyelerine kudret ve dayanıklılık aşılayan Lejyon Sancaktarı madalyonu.';
      case AionBadgeType.pvpGladiator:
        return 'Arena kumlarında yüzlerce rakibi mağlup ederek yenilmezlik tacını kazanan gladyatör nişanı.';
      case AionBadgeType.conqueror:
        return 'Düşman kalelerini yerle bir edip zafer borusunu çalan fatihlere verilen görkemli zafer tacı.';
      case AionBadgeType.seasonChampion:
        return 'Resmi PvP ve Sıralama Sezonunu zirvede tamamlayan elit şampiyon nişanı.';
      case AionBadgeType.artisan:
        return 'Efsanevi dövüş aletlerini ve kutsal zırhları döven usta demirci ve zanaatkâr mühürü.';
      case AionBadgeType.prestigeCosmic:
        return 'Atreia evreninin kadim enerjilerini içinde barındıran kozmik prestij nişanı.';
    }
  }

  static String _getBadgeCombatBuff(AionBadgeType type, Rarity rarity) {
    switch (type) {
      case AionBadgeType.abyssGeneral:
        return '+8% PvP Saldırı Gücü · +5% İtibar Kazanımı';
      case AionBadgeType.abyssCommander:
        return '+6% PvP Saldırı Gücü · +4% Kritik Vuruş';
      case AionBadgeType.abyssCenturion:
        return '+4% PvP Savunma · +3% Blok Şansı';
      case AionBadgeType.legionLegatus:
        return '+5% Lejyon Dayanışma Bonusu · +300 Can';
      case AionBadgeType.pvpGladiator:
        return '+7% Arena Vuruş Gücü';
      case AionBadgeType.conqueror:
        return '+5% Kuşatma Hasarı · +3% Zırh Delme';
      case AionBadgeType.seasonChampion:
        return '+5% Sezon Deneyim Bonusu';
      case AionBadgeType.artisan:
        return '+10% Üretim Kritik Şansı';
      case AionBadgeType.prestigeCosmic:
        return '+2% Tüm İstatistikler';
    }
  }
}

/// Trophy Card with Stepped Pedestal Base, Tier Glow, and Rarity Framing.
class _AionBadgeCard extends StatelessWidget {
  const _AionBadgeCard({
    required this.badge,
    required this.onTap,
  });

  final PlayerBadge badge;
  final VoidCallback onTap;

  static String? _seasonLabel(String itemId) {
    final RegExp match = RegExp(r'^badge_season_(\d+)$');
    final RegExpMatch? found = match.firstMatch(itemId);
    if (found == null) return null;
    final int season = int.tryParse(found.group(1) ?? '') ?? 0;
    if (season <= 0) return null;
    return 'S$season';
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityC = getRarityColor(badge.rarity);
    final String? seasonLabel = _seasonLabel(badge.itemId);
    final AionBadgeType type = _BadgeShowcasePanelState._resolveBadgeType(badge);
    final int stars = _BadgeShowcasePanelState._getBadgeStars(type, badge.rarity);

    return Tooltip(
      message: '${badge.name} (${badge.rarity.name.toUpperCase()})',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          splashColor: rarityC.withValues(alpha: 0.25),
          highlightColor: _AionShowcaseTheme.celestialGold.withValues(alpha: 0.1),
          child: Container(
            width: 98,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  rarityC.withValues(alpha: 0.14),
                  _AionShowcaseTheme.obsidianCard,
                  _AionShowcaseTheme.obsidianVoid,
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: rarityC.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: rarityC.withValues(alpha: 0.22),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Pedestal & Heraldry Stack
                SizedBox(
                  width: 58,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      // Compact 3D Pedestal Base
                      Positioned(
                        bottom: 0,
                        child: CustomPaint(
                          size: const Size(50, 16),
                          painter: _CardPedestalPainter(
                            rarityColor: rarityC,
                            goldColor: _AionShowcaseTheme.celestialGold,
                          ),
                        ),
                      ),
                      // Layered Canvas Heraldic Insignia
                      CustomPaint(
                        size: const Size(46, 46),
                        painter: AionBadgeCanvasPainter(
                          badgeType: type,
                          rarity: badge.rarity,
                          primaryColor: rarityC,
                        ),
                      ),
                      // Season Label if available
                      if (seasonLabel != null)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: _AionShowcaseTheme.obsidianVoid,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: rarityC.withValues(alpha: 0.8),
                                width: 0.9,
                              ),
                            ),
                            child: Text(
                              seasonLabel,
                              style: GoogleFonts.urbanist(
                                color: rarityC,
                                fontWeight: FontWeight.w900,
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),

                // Stars row
                if (stars > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(stars, (int i) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 0.8),
                        child: Icon(
                          Icons.star_rounded,
                          size: 9.5,
                          color: _AionShowcaseTheme.celestialGold,
                        ),
                      );
                    }),
                  ),
                const SizedBox(height: 3),

                // Badge Title
                Text(
                  badge.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: rarityC,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Canvas renderer for 2027 Aion 2 military ranks and PvP glory heraldry.
class AionBadgeCanvasPainter extends CustomPainter {
  const AionBadgeCanvasPainter({
    required this.badgeType,
    required this.rarity,
    required this.primaryColor,
    this.isEnlarged = false,
  });

  final AionBadgeType badgeType;
  final Rarity rarity;
  final Color primaryColor;
  final bool isEnlarged;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    final Rect rect = Offset.zero & size;

    // Layer 1: Ambient Radial Aura Bloom with Celestial Gold Edge
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          primaryColor.withValues(alpha: isEnlarged ? 0.55 : 0.45),
          _AionShowcaseTheme.celestialGold.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, w * 0.48, glowPaint);

    // Layer 2: Ornate Gothic Shield Framework
    final Path shield = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.88, h * 0.22)
      ..lineTo(w * 0.82, h * 0.68)
      ..quadraticBezierTo(w * 0.5, h * 0.96, w * 0.5, h * 0.96)
      ..quadraticBezierTo(w * 0.18, h * 0.68, w * 0.18, h * 0.22)
      ..close();

    // Metallic Shield Fill (Dark Obsidian Core)
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF1E283E),
          _AionShowcaseTheme.obsidianMid,
          _AionShowcaseTheme.obsidianVoid,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shield, fillPaint);

    // Specular Highlight Reflection (45 deg sheen)
    final Path specularSheen = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.88, h * 0.22)
      ..lineTo(w * 0.5, h * 0.6)
      ..lineTo(w * 0.35, h * 0.4)
      ..close();
    canvas.drawPath(
      specularSheen,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

    // Metallic Bevel Border with Celestial Gold highlights
    final Paint borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.85),
          _AionShowcaseTheme.celestialGold,
          primaryColor,
          primaryColor.withValues(alpha: 0.4),
        ],
        stops: const <double>[0.0, 0.35, 0.7, 1.0],
      ).createShader(rect)
      ..strokeWidth = isEnlarged ? 2.4 : 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(shield, borderPaint);

    // Layer 3: Inner Medallion Accent Rings
    canvas.drawCircle(
      center,
      w * 0.28,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isEnlarged ? 1.2 : 0.8,
    );

    canvas.drawCircle(
      center,
      w * 0.22,
      Paint()
        ..color = _AionShowcaseTheme.celestialGold.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isEnlarged ? 0.9 : 0.6,
    );

    // Layer 4: Emblem Heraldry
    switch (badgeType) {
      case AionBadgeType.abyssGeneral:
        _drawAbyssGeneralEmblem(canvas, w, h);
        break;
      case AionBadgeType.abyssCommander:
        _drawCommanderEmblem(canvas, w, h);
        break;
      case AionBadgeType.abyssCenturion:
        _drawCenturionEmblem(canvas, w, h);
        break;
      case AionBadgeType.legionLegatus:
        _drawLegionEmblem(canvas, w, h);
        break;
      case AionBadgeType.pvpGladiator:
        _drawGladiatorEmblem(canvas, w, h);
        break;
      case AionBadgeType.conqueror:
        _drawConquerorEmblem(canvas, w, h);
        break;
      case AionBadgeType.seasonChampion:
        _drawSeasonEmblem(canvas, w, h);
        break;
      case AionBadgeType.artisan:
        _drawArtisanEmblem(canvas, w, h);
        break;
      case AionBadgeType.prestigeCosmic:
        _drawCosmicEmblem(canvas, w, h);
        break;
    }

    // Layer 5: Faceted Specular Gemstone at Crest Apex
    _drawApexGem(canvas, w, h);
  }

  void _drawAbyssGeneralEmblem(Canvas canvas, double w, double h) {
    // 5 Stars arc + Angelic Archon Wings + Broadsword
    final Paint gold = Paint()..color = _AionShowcaseTheme.celestialGold;

    // Archon wings with celestial radiance
    final Path wings = Path()
      ..moveTo(w * 0.5, h * 0.45)
      ..quadraticBezierTo(w * 0.2, h * 0.25, w * 0.15, h * 0.4)
      ..quadraticBezierTo(w * 0.3, h * 0.6, w * 0.5, h * 0.65)
      ..quadraticBezierTo(w * 0.7, h * 0.6, w * 0.85, h * 0.4)
      ..quadraticBezierTo(w * 0.8, h * 0.25, w * 0.5, h * 0.45);
    canvas.drawPath(wings, Paint()..color = primaryColor.withValues(alpha: 0.85));

    // Divine Sword
    final Paint blade = Paint()
      ..color = Colors.white
      ..strokeWidth = isEnlarged ? 2.4 : 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.5, h * 0.28), Offset(w * 0.5, h * 0.78), blade);
    canvas.drawLine(
      Offset(w * 0.42, h * 0.45),
      Offset(w * 0.58, h * 0.45),
      blade..strokeWidth = isEnlarged ? 2.0 : 1.4,
    );

    // 5 Stars arc
    const int count = 5;
    for (int i = 0; i < count; i++) {
      final double angle = math.pi * 0.75 + (i * (math.pi * 0.5) / (count - 1));
      final double r = w * 0.34;
      final double sx = w * 0.5 + r * math.cos(angle);
      final double sy = h * 0.52 + r * math.sin(angle);
      canvas.drawCircle(Offset(sx, sy), isEnlarged ? 2.2 : 1.6, gold);
    }
  }

  void _drawCommanderEmblem(Canvas canvas, double w, double h) {
    // Dual crossed sabers + 4 Stars
    final Paint blade = Paint()
      ..color = primaryColor
      ..strokeWidth = isEnlarged ? 2.2 : 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(w * 0.28, h * 0.72), Offset(w * 0.72, h * 0.32), blade);
    canvas.drawLine(Offset(w * 0.72, h * 0.72), Offset(w * 0.28, h * 0.32), blade);

    // Center eagle shield
    final Path miniShield = Path()
      ..moveTo(w * 0.5, h * 0.38)
      ..lineTo(w * 0.62, h * 0.46)
      ..lineTo(w * 0.58, h * 0.62)
      ..lineTo(w * 0.5, h * 0.68)
      ..lineTo(w * 0.42, h * 0.62)
      ..lineTo(w * 0.38, h * 0.46)
      ..close();
    canvas.drawPath(miniShield, Paint()..color = _AionShowcaseTheme.celestialGold);

    // 4 Stars
    const int count = 4;
    for (int i = 0; i < count; i++) {
      final double x = w * (0.34 + i * 0.11);
      canvas.drawCircle(
        Offset(x, h * 0.8),
        isEnlarged ? 2.0 : 1.5,
        Paint()..color = _AionShowcaseTheme.celestialGold,
      );
    }
  }

  void _drawCenturionEmblem(Canvas canvas, double w, double h) {
    // Lion aegis + 3 stars
    final Offset c = Offset(w * 0.5, h * 0.52);
    canvas.drawCircle(c, w * 0.18, Paint()..color = primaryColor.withValues(alpha: 0.85));
    canvas.drawCircle(
      c,
      w * 0.18,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Crossed lances
    final Paint lance = Paint()
      ..color = Colors.white70
      ..strokeWidth = isEnlarged ? 1.6 : 1.2;
    canvas.drawLine(Offset(w * 0.25, h * 0.75), Offset(w * 0.75, h * 0.28), lance);
    canvas.drawLine(Offset(w * 0.75, h * 0.75), Offset(w * 0.25, h * 0.28), lance);

    // 3 Stars
    for (int i = 0; i < 3; i++) {
      final double x = w * (0.38 + i * 0.12);
      canvas.drawCircle(
        Offset(x, h * 0.82),
        isEnlarged ? 2.0 : 1.6,
        Paint()..color = _AionShowcaseTheme.celestialGold,
      );
    }
  }

  void _drawLegionEmblem(Canvas canvas, double w, double h) {
    // Imperial dragon head silhouette + Laurel
    final Path dragon = Path()
      ..moveTo(w * 0.3, h * 0.7)
      ..lineTo(w * 0.4, h * 0.5)
      ..lineTo(w * 0.35, h * 0.35)
      ..lineTo(w * 0.6, h * 0.25)
      ..lineTo(w * 0.7, h * 0.4)
      ..lineTo(w * 0.6, h * 0.55)
      ..lineTo(w * 0.7, h * 0.7)
      ..close();
    canvas.drawPath(dragon, Paint()..color = primaryColor);
    canvas.drawPath(
      dragon,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawGladiatorEmblem(Canvas canvas, double w, double h) {
    // Crossed Battleaxes
    final Paint handle = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = isEnlarged ? 2.2 : 1.6;
    canvas.drawLine(Offset(w * 0.25, h * 0.75), Offset(w * 0.75, h * 0.35), handle);
    canvas.drawLine(Offset(w * 0.75, h * 0.75), Offset(w * 0.25, h * 0.35), handle);

    // Skull gem / Core jewel
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.55),
      w * 0.14,
      Paint()..color = const Color(0xFFFF1744),
    );
  }

  void _drawConquerorEmblem(Canvas canvas, double w, double h) {
    // Fortress crown
    final Path fortress = Path()
      ..moveTo(w * 0.25, h * 0.65)
      ..lineTo(w * 0.25, h * 0.45)
      ..lineTo(w * 0.35, h * 0.45)
      ..lineTo(w * 0.35, h * 0.52)
      ..lineTo(w * 0.45, h * 0.52)
      ..lineTo(w * 0.45, h * 0.4)
      ..lineTo(w * 0.55, h * 0.4)
      ..lineTo(w * 0.55, h * 0.52)
      ..lineTo(w * 0.65, h * 0.52)
      ..lineTo(w * 0.65, h * 0.45)
      ..lineTo(w * 0.75, h * 0.45)
      ..lineTo(w * 0.75, h * 0.65)
      ..close();
    canvas.drawPath(fortress, Paint()..color = primaryColor);
  }

  void _drawSeasonEmblem(Canvas canvas, double w, double h) {
    // Laurel Wreath with Celestial Gold
    final Paint laurel = Paint()
      ..color = _AionShowcaseTheme.celestialGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = isEnlarged ? 2.6 : 2;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.54), radius: w * 0.24),
      math.pi * 0.3,
      math.pi * 1.4,
      false,
      laurel,
    );

    // Central jewel
    canvas.drawCircle(Offset(w * 0.5, h * 0.54), w * 0.12, Paint()..color = primaryColor);
  }

  void _drawArtisanEmblem(Canvas canvas, double w, double h) {
    // Sacred Anvil
    final Path anvil = Path()
      ..moveTo(w * 0.3, h * 0.45)
      ..lineTo(w * 0.7, h * 0.45)
      ..lineTo(w * 0.65, h * 0.58)
      ..lineTo(w * 0.55, h * 0.58)
      ..lineTo(w * 0.6, h * 0.72)
      ..lineTo(w * 0.4, h * 0.72)
      ..lineTo(w * 0.45, h * 0.58)
      ..lineTo(w * 0.35, h * 0.58)
      ..close();
    canvas.drawPath(anvil, Paint()..color = primaryColor);
  }

  void _drawCosmicEmblem(Canvas canvas, double w, double h) {
    // Cosmic 8-point star with ether cyan pulse
    final Path star = Path();
    final double cx = w * 0.5;
    final double cy = h * 0.52;
    const int points = 8;
    final double rOuter = w * 0.22;
    final double rInner = w * 0.09;

    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? rOuter : rInner;
      final double angle = (i * math.pi) / points - math.pi / 2;
      final double x = cx + r * math.cos(angle);
      final double y = cy + r * math.sin(angle);
      if (i == 0) {
        star.moveTo(x, y);
      } else {
        star.lineTo(x, y);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = primaryColor);
  }

  void _drawApexGem(Canvas canvas, double w, double h) {
    final Path gem = Path()
      ..moveTo(w * 0.5, h * 0.11)
      ..lineTo(w * 0.56, h * 0.17)
      ..lineTo(w * 0.5, h * 0.23)
      ..lineTo(w * 0.44, h * 0.17)
      ..close();

    canvas.drawPath(gem, Paint()..color = const Color(0xFFFF1744));
    canvas.drawCircle(Offset(w * 0.48, h * 0.15), 1, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant AionBadgeCanvasPainter oldDelegate) {
    return oldDelegate.badgeType != badgeType ||
        oldDelegate.rarity != rarity ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.isEnlarged != isEnlarged;
  }
}

/// Dedicated Altar Podium Painter for High-Resolution Detail Modal.
class _AltarPedestalPainter extends CustomPainter {
  const _AltarPedestalPainter({
    required this.primaryColor,
    required this.celestialGold,
  });

  final Color primaryColor;
  final Color celestialGold;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Ambient radial bottom glow
    final Rect glowRect = Rect.fromLTWH(0, h * 0.2, w, h * 0.8);
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          primaryColor.withValues(alpha: 0.55),
          celestialGold.withValues(alpha: 0.25),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(glowRect);
    canvas.drawOval(glowRect, glowPaint);

    // Tier 1 (Base Platform): Wide Stepped Rim
    final Rect baseRect = Rect.fromCenter(
      center: Offset(w / 2, h * 0.78),
      width: w * 0.94,
      height: h * 0.38,
    );
    final Paint baseFill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF222E48),
          Color(0xFF0F1524),
          Color(0xFF06090F),
        ],
      ).createShader(baseRect);
    canvas.drawOval(baseRect, baseFill);

    final Paint baseStroke = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          celestialGold.withValues(alpha: 0.8),
          primaryColor.withValues(alpha: 0.5),
        ],
      ).createShader(baseRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawOval(baseRect, baseStroke);

    // Tier 2 (Elevated Altar Step): Concentric Higher Pedestal
    final Rect stepRect = Rect.fromCenter(
      center: Offset(w / 2, h * 0.62),
      width: w * 0.72,
      height: h * 0.32,
    );
    final Paint stepFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          celestialGold.withValues(alpha: 0.3),
          const Color(0xFF141B2D),
          const Color(0xFF080C16),
        ],
      ).createShader(stepRect);
    canvas.drawOval(stepRect, stepFill);

    final Paint stepStroke = Paint()
      ..color = celestialGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(stepRect, stepStroke);

    // Runic light ring marks on altar surface
    final Paint tickPaint = Paint()
      ..color = _AionShowcaseTheme.etherCyan.withValues(alpha: 0.75)
      ..strokeWidth = 1.2;

    for (int i = 0; i < 8; i++) {
      final double angle = i * (math.pi / 4);
      final double rx = (w * 0.34) * math.cos(angle);
      final double ry = (h * 0.14) * math.sin(angle);
      canvas.drawCircle(Offset(w / 2 + rx, h * 0.62 + ry), 1.2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AltarPedestalPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.celestialGold != celestialGold;
}

/// Compact Pedestal Painter for Badge Cards.
class _CardPedestalPainter extends CustomPainter {
  const _CardPedestalPainter({
    required this.rarityColor,
    required this.goldColor,
  });

  final Color rarityColor;
  final Color goldColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Rect rect = Rect.fromLTWH(0, 0, w, h);

    // Base Tier Glow
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          rarityColor.withValues(alpha: 0.5),
          goldColor.withValues(alpha: 0.2),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawOval(rect, glow);

    // Beveled Pedestal Rim
    final Rect rim = Rect.fromCenter(
      center: Offset(w / 2, h * 0.65),
      width: w * 0.88,
      height: h * 0.5,
    );
    final Paint fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF1B243A),
          Color(0xFF080D18),
        ],
      ).createShader(rim);
    canvas.drawOval(rim, fill);

    final Paint border = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          goldColor.withValues(alpha: 0.8),
          rarityColor.withValues(alpha: 0.5),
        ],
      ).createShader(rim)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawOval(rim, border);
  }

  @override
  bool shouldRepaint(covariant _CardPedestalPainter oldDelegate) =>
      oldDelegate.rarityColor != rarityColor || oldDelegate.goldColor != goldColor;
}

/// Ornate High-Definition Runic Corner Ornament.
class _RunicCorner extends StatelessWidget {
  const _RunicCorner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _RunicCornerPainter(color: color),
    );
  }
}

class _RunicCornerPainter extends CustomPainter {
  const _RunicCornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final Path outer = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0);

    final Path inner = Path()
      ..moveTo(3, size.height - 3)
      ..lineTo(3, 3)
      ..lineTo(size.width - 3, 3);

    canvas.drawPath(outer, p);
    canvas.drawPath(
      inner,
      p
        ..strokeWidth = 0.8
        ..color = color.withValues(alpha: 0.35),
    );

    canvas.drawCircle(
      const Offset(3.5, 3.5),
      1.4,
      Paint()..color = color.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _RunicCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}
