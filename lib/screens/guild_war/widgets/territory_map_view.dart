import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../models/guild_war_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../guild_war_siege_lighting.dart';
import 'defense_power_bar.dart';
import 'faction_crest_painter.dart';
import 'faction_war_banner.dart';
import 'fortress_siege_illustration.dart';
import 'guild_war_design.dart';

/// Strategic continent coordinates for dark fantasy territory nodes.
class NodePosition {
  const NodePosition(this.xPercent, this.yPercent, this.fortressType, this.faction);

  final double xPercent; // 0.0 to 1.0
  final double yPercent; // 0.0 to 1.0
  final String fortressType;
  final FactionType faction;
}



/// Overhauled, Mobile-first TerritoryMapView with dark fantasy fortress siege battlefield map.
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

  @override
  State<TerritoryMapView> createState() => _TerritoryMapViewState();
}

class _TerritoryMapViewState extends State<TerritoryMapView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseAnim;
  int _viewMode = 0; // 0 = Tactical Siege Map, 1 = Card Grid
  int? _selectedTerritoryIndex;

  static const List<NodePosition> _predefinedNodes = <NodePosition>[
    NodePosition(0.22, 0.28, 'Şafak Hisarı', FactionType.elyos),
    NodePosition(0.78, 0.26, 'Uçurum Kalesi', FactionType.asmodian),
    NodePosition(0.50, 0.46, 'Merkez Bastion', FactionType.elyos),
    NodePosition(0.20, 0.72, 'Ejderha Mabedi', FactionType.asmodian),
    NodePosition(0.80, 0.74, 'Obsidiyen Kule', FactionType.asmodian),
    NodePosition(0.50, 0.82, 'Batık Geçit', FactionType.neutral),
  ];

  static const List<String> _fortressIcons = <String>['🏰', '🌾', '🐉', '⚓', '🔥', '🏔'];

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    if (widget.territories.isNotEmpty) {
      _selectedTerritoryIndex = 0;
    }
  }

  @override
  void dispose() {
    _pulseAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.territories.isEmpty) {
      return const WarEmptyTab(
        icon: '🗺',
        message: 'Haritada henüz bölge yok. Sezon ilerledikçe bölgeler açılacak.',
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isLandscape = constraints.maxWidth > 550;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Faction Clash Banner at the top of the War Map
            const FactionClashBanner(
              elyosScore: 1840,
              asmodianScore: 1690,
              elyosTerritoryCount: 4,
              asmodianTerritoryCount: 2,
              battleTimerText: 'Kuşatma Aktif',
            ),
            const SizedBox(height: AppSpacing.sm),

            // Section Header & View Mode Switcher
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const WarSectionHeader(
                  title: 'Kuşatma Haritası',
                  subtitle: 'Kontrol noktalarına dokun',
                  accent: WarPalette.neon,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141926),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _ViewModeTab(
                        label: 'Harita',
                        icon: Icons.map_rounded,
                        isSelected: _viewMode == 0,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _viewMode = 0);
                        },
                      ),
                      _ViewModeTab(
                        label: 'Kartlar',
                        icon: Icons.grid_view_rounded,
                        isSelected: _viewMode == 1,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _viewMode = 1);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Content: Interactive Tactical Map or Card Grid
            if (_viewMode == 0)
              _buildTacticalSiegeMap(isLandscape)
            else
              _buildCardGrid(),

            const SizedBox(height: AppSpacing.sm),

            // Legend Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _LegendDot(color: WarPalette.gold, label: 'Senin Loncan'),
                const SizedBox(width: 14),
                _LegendDot(color: WarPalette.ruby, label: 'Düşman Kalesi'),
                const SizedBox(width: 14),
                _LegendDot(color: WarPalette.coral, label: 'Sahipsiz'),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTacticalSiegeMap(bool isLandscape) {
    final double mapHeight = isLandscape ? 280.0 : 340.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          // Interactive Map Area
          SizedBox(
            height: mapHeight,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double w = constraints.maxWidth;
                final double h = constraints.maxHeight;

                final List<Offset> positions = <Offset>[];
                for (int i = 0; i < widget.territories.length; i++) {
                  final NodePosition def = _predefinedNodes[i % _predefinedNodes.length];
                  positions.add(Offset(w * def.xPercent, h * def.yPercent));
                }

                return AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (BuildContext context, Widget? child) {
                    return Stack(
                      children: <Widget>[
                        // Background painter with terrain, ley-lines and ripples
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ContinentTacticalMapPainter(
                              nodePositions: positions,
                              selectedNodeIndex: _selectedTerritoryIndex,
                              pulseValue: _pulseAnim.value,
                            ),
                          ),
                        ),

                        // Interactive Glowing Nodes
                        for (int i = 0; i < widget.territories.length; i++)
                          _buildNodeWidget(
                            index: i,
                            offset: positions[i],
                            territory: widget.territories[i],
                            isSelected: _selectedTerritoryIndex == i,
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Tactical Fortress Summary Drawer for Selected Node
          if (_selectedTerritoryIndex != null &&
              _selectedTerritoryIndex! < widget.territories.length)
            _buildTacticalDetailDrawer(widget.territories[_selectedTerritoryIndex!]),
        ],
      ),
    );
  }

  Widget _buildNodeWidget({
    required int index,
    required Offset offset,
    required TerritoryData territory,
    required bool isSelected,
  }) {
    final bool isOwner = territory.ownerGuildId == widget.playerGuildId;
    final Color nodeColor = isOwner
        ? WarPalette.gold
        : territory.isUnclaimed
            ? WarPalette.coral
            : WarPalette.ruby;

    final String icon = _fortressIcons[index % _fortressIcons.length];

    return Positioned(
      left: offset.dx - 26,
      top: offset.dy - 26,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTerritoryIndex = index);
        },
        child: SizedBox(
          width: 52,
          height: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Pulsing Fortress Node Circle
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Glowing pulse ring
                  Container(
                    width: isSelected ? 44 : 36,
                    height: isSelected ? 44 : 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: nodeColor.withValues(
                            alpha: 0.5 + 0.3 * _pulseAnim.value,
                          ),
                          blurRadius: isSelected ? 16 : 10,
                          spreadRadius: isSelected ? 3 : 1,
                        ),
                      ],
                    ),
                  ),

                  // Node Base
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF141926),
                      border: Border.all(
                        color: isSelected ? Colors.white : nodeColor,
                        width: isSelected ? 2.2 : 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                  // "Under Siege" Flame Badge if defense damaged
                  if (territory.defensePower < territory.baseDefensePower)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF1744),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),

              // Fortress Name Label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: nodeColor.withValues(alpha: 0.6),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  territory.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : nodeColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTacticalDetailDrawer(TerritoryData territory) {
    final bool isOwner = territory.ownerGuildId == widget.playerGuildId;
    final Color accent = isOwner
        ? WarPalette.gold
        : territory.isUnclaimed
            ? WarPalette.coral
            : WarPalette.ruby;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF131724),
        border: Border(
          top: BorderSide(color: Colors.white12, width: 1.0),
        ),
      ),
      child: Row(
        children: <Widget>[
          // High-Res Aion-2 Fortress Siege Miniature
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 58,
              height: 50,
              child: FortressSiegeIllustration(
                fortressName: territory.name,
                faction: isOwner
                    ? FactionType.elyos
                    : (territory.isUnclaimed ? FactionType.neutral : FactionType.asmodian),
                shieldIntegrity:
                    (territory.defensePower / math.max(1, territory.baseDefensePower)).clamp(0.0, 1.0),
                isUnderSiege: territory.defensePower < territory.baseDefensePower,
                showTitle: false,
                height: 50,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Territory Info & Defense Bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      territory.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isOwner)
                      const WarStatusPill(label: 'Loncan', color: WarPalette.gold)
                    else if (territory.isUnclaimed)
                      const WarStatusPill(label: 'Sahipsiz', color: WarPalette.coral),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  territory.isUnclaimed
                      ? 'Boş Kale · Doğrudan ele geçir'
                      : 'Sahip: ${territory.ownerGuildName ?? '—'}',
                  style: const TextStyle(color: WarPalette.titanium, fontSize: 10),
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
          const SizedBox(width: 12),

          // Quick Action Button
          ElevatedButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              widget.onTerritoryTap(territory);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isOwner ? 'Yönet' : 'Saldır',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGrid() {
    return GameFixedGrid(
      crossAxisCount: 2,
      spacing: 10,
      itemCount: widget.territories.length,
      itemBuilder: (BuildContext context, int index) {
        final TerritoryData t = widget.territories[index];
        final bool isOwner = t.ownerGuildId == widget.playerGuildId;
        return _MapTile(
          territory: t,
          icon: _fortressIcons[index % _fortressIcons.length],
          isOwner: isOwner,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTerritoryTap(t);
          },
        );
      },
    );
  }
}

class _ViewModeTab extends StatelessWidget {
  const _ViewModeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.liquidGold : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.black : Colors.white60,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
          height: 154,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FortressSiegeIllustration(
                    fortressName: territory.name,
                    faction: isOwner
                        ? FactionType.elyos
                        : (territory.isUnclaimed ? FactionType.neutral : FactionType.asmodian),
                    shieldIntegrity:
                        (territory.defensePower / math.max(1, territory.baseDefensePower)).clamp(0.0, 1.0),
                    isUnderSiege: territory.defensePower < territory.baseDefensePower,
                    showTitle: false,
                    height: 52,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Text(icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      territory.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isOwner)
                    const WarStatusPill(label: 'Sen', color: WarPalette.gold),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                territory.isUnclaimed ? 'Sahipsiz' : (territory.ownerGuildName ?? '—'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: WarPalette.titanium, fontSize: 10),
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
        Text(label, style: const TextStyle(color: WarPalette.titanium, fontSize: 10)),
      ],
    );
  }
}
