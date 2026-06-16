import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../components/layout/game_chrome.dart';
import '../../../core/services/supabase_service.dart';
import '../../../routing/app_router.dart';

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

class StickyActionBar extends StatefulWidget {
  const StickyActionBar({super.key});

  @override
  State<StickyActionBar> createState() => _StickyActionBarState();
}

class _StickyActionBarState extends State<StickyActionBar>
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
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
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
    setState(() {});
  }

  void _open() {
    if (_expanded) return;
    _expanded = true;
    _pulseController.repeat(reverse: true);
    _expandController.forward();
    _resetAutoCloseTimer();
    setState(() {});
  }

  void _toggleExpanded() {
    if (_expanded) {
      _collapse();
    } else {
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

  void _onPanelTap(VoidCallback action) {
    if (!_expanded) return;
    _resetAutoCloseTimer();
    action();
  }

  String get _rankLabel {
    if (_loading) return 'Siralama yukleniyor...';
    if (_rank == null) return 'Siralama: —';
    return 'Siralaman: #$_rank';
  }

  String get _subtitleLabel {
    if (_loading) return 'Canli guc siralamasi';
    if (_rank == null) return 'Henuz siralama yok';
    if (_rank == 1) return 'Zirvedesin!';
    if (_gap != null && _gap! > 0) return 'Rakibe ${_compact(_gap!)} Guc';
    return 'Gucunu artir, yuksel';
  }

  Widget _rankFab() {
    return GestureDetector(
      onTap: _toggleExpanded,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: kGameChatFabSize,
        height: kGameChatFabSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xF0141B26), Color(0xF0090D15)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFFB800),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              'Sira',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelBody() {
    final Widget strengthenButton = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFE01E5A), Color(0xFFFFB800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFE01E5A).withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Text(
        'Hemen Güçlen',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: kGameChatFabSize,
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF121826).withValues(alpha: 0.82),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(20),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: () => _onPanelTap(
                    () => context.push(AppRoutes.leaderboard),
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _rankLabel,
                        style: const TextStyle(
                          color: Color(0xFF00B4FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.54),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ScaleTransition(
                scale: _pulseAnimation,
                child: GestureDetector(
                  onTap: () => _onPanelTap(
                    () => context.push(AppRoutes.inventory),
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: strengthenButton,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxPanelWidth = gameRankPanelMaxWidth(context);

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (BuildContext context, Widget? child) {
        final double progress = _expandAnimation.value;
        final double panelWidth = maxPanelWidth * progress;
        final bool showPanel = panelWidth > 0.5;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _rankFab(),
            if (showPanel)
              ClipRect(
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
          ],
        );
      },
      child: _panelBody(),
    );
  }
}
