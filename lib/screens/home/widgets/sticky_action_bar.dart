import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/layout/game_chrome.dart';
import '../../../core/services/supabase_service.dart';
import '../../../providers/retention_promos_provider.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

/// 2027 AAA Studio V3 Floating Sticky Action Bar.
///
/// Features:
/// - Liquid obsidian frosted glass dock with dynamic morphing corner geometry
/// - Specular glass sheen highlight (physical optical light reflection)
/// - Luminous tier-based rank emblems (Divine Gold, Mythic Aureate, Mithril Cyan)
/// - Real-time Nemesis rivalry beacon with online pulse indicator
/// - Multi-tier tactile haptic feedback triggers (open, close, CTA, reload)
/// - Responsive quick-strengthen pill with chromatic flame gradient
/// - RepaintBoundary isolation for zero-jank 60/120 FPS mobile TBDR performance
class StickyActionBar extends ConsumerStatefulWidget {
  const StickyActionBar({
    super.key,
    this.bottomPadding,
    this.useSafeArea = true,
  });

  /// Optional explicit bottom padding override.
  final double? bottomPadding;

  /// Whether to enforce bottom SafeArea padding to avoid home indicator
  /// on iOS and modern Android gestures. Defaults to `true`.
  final bool useSafeArea;

  @override
  ConsumerState<StickyActionBar> createState() => _StickyActionBarState();
}

class _StickyActionBarState extends ConsumerState<StickyActionBar>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late AnimationController _pulseController;
  late Animation<double> _expandAnimation;
  late Animation<double> _pulseAnimation;
  int? _rank;
  int? _gap;
  bool _loading = true;
  bool _expanded = false;
  Timer? _autoCloseTimer;

  static const Duration _autoCloseDuration = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadRank();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _expandController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadRank() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
        throw StateError('Supabase hazir degil');
      }

      final dynamic result = await SupabaseService.client.rpc(
        'get_leaderboard_rank',
        params: <String, dynamic>{
          'p_category': 'power',
          'p_timeframe': 'alltime',
        },
      );

      if (!mounted) return;

      if (result is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(result);
        setState(() {
          _rank = (map['rank'] as num?)?.toInt();
          _gap = (map['gap'] as num?)?.toInt();
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // fall through
    }

    if (!mounted) return;
    setState(() {
      _rank = null;
      _gap = null;
      _loading = false;
    });
  }

  void _collapse() {
    if (!_expanded) return;
    _autoCloseTimer?.cancel();
    _expanded = false;
    _pulseController
      ..stop()
      ..reset();
    _expandController.reverse();
    if (mounted) setState(() {});
  }

  void _open() {
    if (_expanded) return;
    _expanded = true;
    _pulseController.repeat(reverse: true);
    _expandController.forward();
    _resetAutoCloseTimer();
    if (mounted) setState(() {});
  }

  void _toggleExpanded() {
    if (_expanded) {
      HapticFeedback.lightImpact();
      _collapse();
    } else {
      HapticFeedback.mediumImpact();
      _open();
    }
  }

  void _resetAutoCloseTimer() {
    _autoCloseTimer?.cancel();
    if (!_expanded) return;
    _autoCloseTimer = Timer(_autoCloseDuration, () {
      if (!mounted) return;
      _collapse();
    });
  }

  void _onPanelTap(VoidCallback action, {bool isCTA = false}) {
    if (!_expanded) return;
    if (isCTA) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    _resetAutoCloseTimer();
    action();
  }

  Color get _rankTierColor {
    if (_rank == null) return AppColors.liquidGold;
    if (_rank == 1) return const Color(0xFFFFE082); // Divine Gold
    if (_rank! <= 3) return const Color(0xFFFFD54F); // Mythic Aureate
    if (_rank! <= 10) return const Color(0xFFFFB800); // Radiant Amber
    if (_rank! <= 100) return const Color(0xFF60A5FA); // Mithril Cyan
    return const Color(0xFF94A3B8); // Obsidian Steel
  }

  IconData get _rankTierIcon {
    if (_rank == 1) return Icons.workspace_premium_rounded;
    if (_rank != null && _rank! <= 3) return Icons.military_tech_rounded;
    if (_rank != null && _rank! <= 10) return Icons.emoji_events_rounded;
    return Icons.shield_rounded;
  }

  String get _rankNumberText {
    if (_loading) return '...';
    if (_rank == null) return 'Sıra';
    return '#$_rank';
  }

  String get _rankLabel {
    if (_loading) return 'Sıralama yükleniyor...';
    if (_rank == null) return 'Sıralama: —';
    return 'Sıralaman: #$_rank';
  }

  String get _subtitleLabel {
    final promos = ref.watch(retentionPromosProvider).promos;
    final int nemesisGap = promos.nemesis.leaderboardGap;
    final bool hasNemesis = promos.nemesis.hasRival;
    final String? rivalName = promos.nemesis.rivalUsername;

    if (_loading) return 'Canlı güç sıralaması';
    if (_rank == null) return 'Henüz sıralama yok';
    if (_rank == 1) return '★ Zirvedesin!';
    if (hasNemesis && nemesisGap > 0) {
      if (rivalName != null && rivalName.isNotEmpty) {
        return 'Nemesis $rivalName: ${_compact(nemesisGap)}';
      }
      return 'Nemesis farkı: ${_compact(nemesisGap)} Güç';
    }
    if (_gap != null && _gap! > 0) return 'Rakibe ${_compact(_gap!)} Güç';
    return 'Gücünü artır, yüksel';
  }

  Widget _buildSpecularHighlight() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 1.5,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.10),
                Colors.transparent,
              ],
              stops: const <double>[0.0, 0.45, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNemesisBeacon(bool online) {
    return Positioned(
      top: 5,
      right: 5,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: online ? const Color(0xFF00FF66) : const Color(0xFFE01E5A),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.90),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (online ? const Color(0xFF00FF66) : const Color(0xFFE01E5A))
                  .withValues(alpha: 0.75),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankFab([double progress = 0.0]) {
    final promos = ref.watch(retentionPromosProvider).promos;
    final bool hasNemesis = promos.nemesis.hasRival;
    final bool nemesisOnline = promos.nemesis.online;
    final Color tierColor = _rankTierColor;
    final IconData tierIcon = _rankTierIcon;

    final double rightRadius = (1.0 - progress) * 16.0 + 6.0;

    return Tooltip(
      message: 'Sıralama (Bas: Genişlet / Uzun Bas: Yenile)',
      child: GestureDetector(
        onTap: _toggleExpanded,
        onLongPress: () {
          HapticFeedback.heavyImpact();
          _loadRank();
        },
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.horizontal(
            left: const Radius.circular(22),
            right: Radius.circular(rightRadius),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
            child: Container(
              width: kGameChatFabSize,
              height: kGameChatFabSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.horizontal(
                  left: const Radius.circular(22),
                  right: Radius.circular(rightRadius),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xF518243A),
                    Color(0xFA0B101C),
                    Color(0xFC060A14),
                  ],
                  stops: <double>[0.0, 0.55, 1.0],
                ),
                border: Border.all(
                  color: tierColor.withValues(alpha: 0.75),
                  width: 1.4,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: tierColor.withValues(alpha: 0.32),
                    blurRadius: 16,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 3),
                  ),
                  const BoxShadow(
                    color: Color(0xAA000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  _buildSpecularHighlight(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      ScaleTransition(
                        scale: _expanded
                            ? _pulseAnimation
                            : const AlwaysStoppedAnimation<double>(1.0),
                        child: Icon(
                          tierIcon,
                          color: tierColor,
                          size: 24,
                          shadows: <Shadow>[
                            Shadow(
                              color: tierColor.withValues(alpha: 0.75),
                              blurRadius: 12,
                            ),
                            const Shadow(
                              color: Colors.black,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x99060A14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: tierColor.withValues(alpha: 0.40),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          _rankNumberText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: (_rank != null && _rank! > 99) ? 8.0 : 8.5,
                            fontWeight: FontWeight.w900,
                            color: tierColor,
                            letterSpacing: 0.6,
                            shadows: const <Shadow>[
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasNemesis) _buildNemesisBeacon(nemesisOnline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelBody(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompact = screenWidth < 380;
    final promos = ref.watch(retentionPromosProvider).promos;
    final bool hasNemesis = promos.nemesis.hasRival;
    final Color tierColor = _rankTierColor;

    final Widget strengthenButton = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFE01E5A),
            Color(0xFFFF6B35),
            Color(0xFFFF9100),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFE01E5A).withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: const Color(0xFFFF9100).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.bolt_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            'Hemen Güçlen',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: isCompact ? 10.0 : 11.5,
              letterSpacing: 0.3,
              shadows: const <Shadow>[
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      height: kGameChatFabSize,
      padding: EdgeInsets.fromLTRB(
        isCompact ? 6 : 8,
        6,
        isCompact ? 8 : 10,
        6,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xF5101828),
            Color(0xFA080C16),
            Color(0xFC050810),
          ],
          stops: <double>[0.0, 0.6, 1.0],
        ),
        border: Border.all(
          color: tierColor.withValues(alpha: 0.55),
          width: 1.2,
        ),
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(22),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tierColor.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          _buildSpecularHighlight(),
          Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: () => _onPanelTap(() {
                    if (promos.nemesis.hasRival &&
                        promos.nemesis.rivalId != null) {
                      context.push(
                        '${AppRoutes.pvp}?revenge=${promos.nemesis.rivalId}',
                      );
                    } else {
                      context.push(AppRoutes.leaderboard);
                    }
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (hasNemesis) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: AppColors.cyberFuchsia.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.cyberFuchsia.withValues(alpha: 0.60),
                                  width: 0.7,
                                ),
                              ),
                              child: const Text(
                                'NEMESIS',
                                style: TextStyle(
                                  color: AppColors.cyberFuchsia,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                          Flexible(
                            child: Text(
                              _rankLabel,
                              style: TextStyle(
                                color: tierColor,
                                fontWeight: FontWeight.w900,
                                fontSize: isCompact ? 11.0 : 12.5,
                                letterSpacing: 0.3,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: tierColor.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 9,
                            color: tierColor.withValues(alpha: 0.75),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleLabel,
                        style: TextStyle(
                          color: hasNemesis
                              ? const Color(0xFFFF8A80)
                              : Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                          fontSize: isCompact ? 9.0 : 10.0,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ScaleTransition(
                scale: _pulseAnimation,
                child: GestureDetector(
                  onTap: () => _onPanelTap(
                    () => context.push(AppRoutes.inventory),
                    isCTA: true,
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: strengthenButton,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxPanelWidth = gameRankPanelMaxWidth(context);

    final Widget barContent = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (BuildContext context, Widget? child) {
          final double progress = _expandAnimation.value;
          final double panelWidth = maxPanelWidth * progress;
          final bool showPanel = panelWidth > 0.5;
          final double leftRadius = (1.0 - progress) * 16.0 + 6.0;

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _rankFab(progress),
              if (showPanel)
                ClipRRect(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(leftRadius),
                    right: const Radius.circular(22),
                  ),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                    child: SizedBox(
                      width: panelWidth,
                      height: kGameChatFabSize,
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: maxPanelWidth,
                        maxWidth: maxPanelWidth,
                        child: SizedBox(
                          width: maxPanelWidth,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: _panelBody(context),
      ),
    );

    if (widget.bottomPadding != null) {
      return Padding(
        padding: EdgeInsets.only(bottom: widget.bottomPadding!),
        child: barContent,
      );
    }

    if (widget.useSafeArea) {
      return SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        minimum: EdgeInsets.zero,
        child: barContent,
      );
    }

    return barContent;
  }
}
