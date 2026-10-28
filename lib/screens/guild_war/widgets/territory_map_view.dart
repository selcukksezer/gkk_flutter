import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../core/services/game_sfx_service.dart';
import '../../../core/services/graphics_quality_service.dart';
import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'defense_power_bar.dart';
import 'guild_war_design.dart';

/// V15 Pack 1: Interactive 2.5D Isometric Continent Conquest Map + Tactical Grid!
///
/// Renders `assets/v15/continent_siege_map.jpg` with live war-road supply lines,
/// catapult siege trajectories, burning fortress indicators, and clickable
/// regional strongholds, plus the compact tactical cards underneath.
class TerritoryMapView extends StatefulWidget {
  const TerritoryMapView({
    super.key,
    required this.territories,
    required this.playerGuildId,
    required this.onTerritoryTap,
  });

  final List<TerritoryData> territories;
  final String? playerGuildId;
  final ValueChanged<TerritoryData> onTerritoryTap;

  static const List<String> _icons = <String>['🏰', '🌾', '🐉', '⚓', '🔥', '🏔', '⚔️'];

  /// Normalized `(x, y)` coordinates matching the strongholds on `continent_siege_map.jpg`.
  static const List<Offset> _citadelAnchors = <Offset>[
    Offset(0.50, 0.18), // North-Center Obsidian Royal Citadel
    Offset(0.18, 0.75), // South-West Golden Harvest Watchtowers
    Offset(0.82, 0.22), // North-East Dragonspire Volcanic Peak
    Offset(0.82, 0.75), // South-East Ironclad Naval Harbor
    Offset(0.50, 0.79), // Center-South Magma Rift Fortress
    Offset(0.18, 0.22), // North-West Frostcrown Glacier Keep
    Offset(0.50, 0.48), // Central Heartland Frontier Bastion
  ];

  @visibleForTesting
  static bool debugAnimateInTests = false;

  @override
  State<TerritoryMapView> createState() => _TerritoryMapViewState();
}

class _TerritoryMapViewState extends State<TerritoryMapView>
    with SingleTickerProviderStateMixin {
  AnimationController? _siegePulseCtrl;

  static bool get _isTestBinding {
    if (TerritoryMapView.debugAnimateInTests) return false;
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    GraphicsQualityService.instance.addListener(_syncTicker);
    _syncTicker();
  }

  void _syncTicker() {
    final bool animate =
        !_isTestBinding && !GraphicsQualityService.instance.profile.isLow;
    if (animate) {
      _siegePulseCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3600),
      );
      if (!_siegePulseCtrl!.isAnimating) {
        _siegePulseCtrl!.repeat();
      }
    } else {
      _siegePulseCtrl?.stop();
    }
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_syncTicker);
    _siegePulseCtrl?.dispose();
    super.dispose();
  }

  Offset _anchorForIndex(int index) {
    final Offset base =
        TerritoryMapView._citadelAnchors[index % TerritoryMapView._citadelAnchors.length];
    if (index < TerritoryMapView._citadelAnchors.length) return base;
    final int ring = index ~/ TerritoryMapView._citadelAnchors.length;
    return Offset(
      (base.dx + ring * 0.06).clamp(0.14, 0.86),
      (base.dy + ring * 0.05).clamp(0.16, 0.84),
    );
  }

  void _handleSelect(TerritoryData t) {
    unawaited(GameSfxService.instance.play(GameSfx.siegeHorn));
    widget.onTerritoryTap(t);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.territories.isEmpty) {
      return const WarEmptyTab(
        icon: '🗺',
        message:
            'Haritada henüz bölge yok. Sezon ilerledikçe bölgeler açılacak.',
      );
    }

    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final int mapCacheWidth = gfx.isLow ? 640 : 1280;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const WarSectionHeader(
          title: '2.5D Kıta Fetih Haritası',
          subtitle: 'Kaleye dokunarak kuşatma başlat veya bölgeyi incele',
          accent: WarPalette.neon,
        ),
        const SizedBox(height: AppSpacing.sm),
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Container(
            key: const Key('continent_siege_map_stage'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: WarPalette.gold.withValues(alpha: 0.45),
                width: 1.4,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double mapW = constraints.maxWidth;
                  final double mapH = constraints.maxHeight;
                  final List<Offset> points = <Offset>[
                    for (int i = 0; i < widget.territories.length; i++)
                      Offset(
                        _anchorForIndex(i).dx * mapW,
                        _anchorForIndex(i).dy * mapH,
                      ),
                  ];

                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image(
                        image: ResizeImage.resizeIfNeeded(
                          mapCacheWidth,
                          null,
                          const AssetImage('assets/v15/continent_siege_map.jpg'),
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xFF0E1726),
                                Color(0xFF1F1624),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 0.95,
                            colors: <Color>[
                              Color(0x08000000),
                              Color(0x88050811),
                            ],
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation:
                            _siegePulseCtrl ?? const AlwaysStoppedAnimation<double>(0.3),
                        builder: (BuildContext context, _) {
                          return CustomPaint(
                            key: const ValueKey<String>('continent_siege_vector_paint'),
                            painter: _ContinentSiegeVectorPainter(
                              points: points,
                              territories: widget.territories,
                              playerGuildId: widget.playerGuildId,
                              phase: _siegePulseCtrl?.value ?? 0.3,
                              isLowTier: gfx.isLow,
                            ),
                          );
                        },
                      ),
                      for (int i = 0; i < widget.territories.length; i++)
                        _CitadelMapPin(
                          key: ValueKey<String>(
                            'citadel_pin_${widget.territories[i].id}',
                          ),
                          position: points[i],
                          mapSize: Size(mapW, mapH),
                          territory: widget.territories[i],
                          icon: TerritoryMapView._icons[
                              i % TerritoryMapView._icons.length],
                          isOwner: widget.territories[i].ownerGuildId != null &&
                              widget.territories[i].ownerGuildId ==
                                  widget.playerGuildId,
                          onTap: () => _handleSelect(widget.territories[i]),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const _LegendDot(color: WarPalette.gold, label: 'Senin loncan'),
            const SizedBox(width: 14),
            const _LegendDot(color: WarPalette.ruby, label: 'Rakip kale'),
            const SizedBox(width: 14),
            const _LegendDot(color: WarPalette.coral, label: 'Sahipsiz'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GameFixedGrid(
          crossAxisCount: 2,
          spacing: 10,
          itemCount: widget.territories.length,
          itemBuilder: (BuildContext context, int index) {
            final TerritoryData t = widget.territories[index];
            final bool isOwner =
                t.ownerGuildId != null && t.ownerGuildId == widget.playerGuildId;
            return _MapTile(
              territory: t,
              icon: TerritoryMapView._icons[
                  index % TerritoryMapView._icons.length],
              isOwner: isOwner,
              onTap: () => _handleSelect(t),
            );
          },
        ),
      ],
    );
  }
}

class _ContinentSiegeVectorPainter extends CustomPainter {
  const _ContinentSiegeVectorPainter({
    required this.points,
    required this.territories,
    required this.playerGuildId,
    required this.phase,
    required this.isLowTier,
  });

  final List<Offset> points;
  final List<TerritoryData> territories;
  final String? playerGuildId;
  final double phase;
  final bool isLowTier;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // 1. War-road connections + marching siege bolts
    final Paint roadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFFBBF24).withValues(alpha: 0.34);

    for (int i = 0; i < points.length - 1; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % points.length];
      final Offset ctrl = Offset(
        (a.dx + b.dx) * 0.5,
        math.min(a.dy, b.dy) - 18.0,
      );
      final Path arc = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
      canvas.drawPath(arc, roadPaint);

      if (!isLowTier) {
        final double t = (phase + i * 0.21) % 1.0;
        final double u = 1.0 - t;
        final Offset bolt = Offset(
          u * u * a.dx + 2 * u * t * ctrl.dx + t * t * b.dx,
          u * u * a.dy + 2 * u * t * ctrl.dy + t * t * b.dy,
        );
        canvas.drawCircle(
          bolt,
          3.4,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = const Color(0xFFFF6B2B).withValues(alpha: 0.85),
        );
      }
    }

    // 2. Pulsing territory aura & siege fire halos on damaged strongholds
    for (int i = 0; i < points.length; i++) {
      final TerritoryData td = territories[i];
      final Offset c = points[i];
      final bool isOwner =
          td.ownerGuildId != null && td.ownerGuildId == playerGuildId;
      final Color col = isOwner
          ? WarPalette.gold
          : (td.isUnclaimed ? WarPalette.coral : WarPalette.ruby);
      final double pulse =
          isLowTier ? 0.5 : (0.5 + 0.5 * math.sin(phase * math.pi * 2 + i));
      canvas.drawCircle(
        c,
        18.0 + pulse * 8.0,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = col.withValues(alpha: 0.52 - pulse * 0.22),
      );
      if (td.baseDefensePower > 0 &&
          td.defensePower < td.baseDefensePower * 0.85) {
        canvas.drawCircle(
          c.translate(0, -10),
          12.0,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = const Color(0xFFFF5722).withValues(alpha: 0.35),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ContinentSiegeVectorPainter oldDelegate) {
    return (oldDelegate.phase - phase).abs() > 0.01 ||
        oldDelegate.territories != territories;
  }
}

class _CitadelMapPin extends StatelessWidget {
  const _CitadelMapPin({
    super.key,
    required this.position,
    required this.mapSize,
    required this.territory,
    required this.icon,
    required this.isOwner,
    required this.onTap,
  });

  final Offset position;
  final Size mapSize;
  final TerritoryData territory;
  final String icon;
  final bool isOwner;
  final VoidCallback onTap;

  Color get _accent {
    if (isOwner) return WarPalette.gold;
    if (territory.isUnclaimed) return WarPalette.coral;
    return WarPalette.ruby;
  }

  @override
  Widget build(BuildContext context) {
    const double pinW = 94;
    const double pinH = 50;
    final double left =
        (position.dx - pinW * 0.5).clamp(4.0, math.max(4.0, mapSize.width - pinW - 4.0));
    final double top =
        (position.dy - pinH * 0.5).clamp(4.0, math.max(4.0, mapSize.height - pinH - 4.0));

    return Positioned(
      left: left,
      top: top,
      width: pinW,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xDA0B101D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _accent.withValues(alpha: 0.85), width: 1.3),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _accent.withValues(alpha: 0.32),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(icon, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      territory.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isOwner
                    ? '👑 Senin Loncan'
                    : (territory.isUnclaimed
                        ? '⚔ Sahipsiz'
                        : (territory.ownerGuildName ?? 'Rakip')),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _accent,
                  fontSize: 8.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  const _MapTile({
    required this.territory,
    required this.icon,
    required this.isOwner,
    required this.onTap,
  });

  final TerritoryData territory;
  final String icon;
  final bool isOwner;
  final VoidCallback onTap;

  Color get _accent {
    if (isOwner) return WarPalette.gold;
    if (territory.isUnclaimed) return WarPalette.coral;
    return WarPalette.ruby;
  }

  @override
  Widget build(BuildContext context) {
    return WarPressable(
      onTap: onTap,
      child: WarHeroBanner(
        accent: _accent,
        child: SizedBox(
          height: 122,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(icon, style: const TextStyle(fontSize: 24)),
                  const Spacer(),
                  if (isOwner)
                    const WarStatusPill(label: 'Sen', color: WarPalette.gold),
                ],
              ),
              const Spacer(),
              Text(
                territory.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                territory.isUnclaimed
                    ? 'Sahipsiz'
                    : (territory.ownerGuildName ?? '—'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: WarPalette.titanium,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 6),
              DefensePowerBar(
                current: territory.defensePower,
                max: territory.baseDefensePower,
                height: 4,
                showLabel: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: WarPalette.titanium, fontSize: 10),
        ),
      ],
    );
  }
}
