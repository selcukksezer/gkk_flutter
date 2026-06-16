import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/power_formula.dart';
import '../../../models/dungeon_model.dart';
import 'dungeon_cave_theme.dart';
import 'dungeon_progress_row.dart';

const double _kCaveArtSize = 165.0;
const Color _kCardText = Color(0xFFFFFFFF);

/// Hero card for featured dungeons — cave art right, theme from art palette.
class FeaturedCaveDungeonCard extends StatelessWidget {
  const FeaturedCaveDungeonCard({
    super.key,
    required this.dungeon,
    required this.theme,
    required this.zoneIcon,
    required this.zoneLabel,
    required this.zoneColor,
    required this.canEnter,
    required this.inHospital,
    required this.inPrison,
    required this.entering,
    required this.successPercent,
    required this.energyCost,
    required this.minGold,
    required this.maxGold,
    required this.powerRequirement,
    required this.playerPower,
    this.debugText,
    required this.onEnter,
    required this.onLoot,
  });

  final DungeonData dungeon;
  final CaveCardTheme theme;
  final IconData zoneIcon;
  final String zoneLabel;
  final Color zoneColor;
  final bool canEnter;
  final bool inHospital;
  final bool inPrison;
  final bool entering;
  final int successPercent;
  final int energyCost;
  final int minGold;
  final int maxGold;
  final int powerRequirement;
  final int playerPower;
  final String? debugText;
  final VoidCallback onEnter;
  final VoidCallback onLoot;

  String get _threatLabel {
    if (successPercent >= 80) return 'KOLAY';
    if (successPercent >= 55) return 'ORTA';
    if (successPercent >= 30) return 'ZOR';
    return 'ÖLÜMCÜL';
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  String get _enterLabel {
    if (entering) return 'Giriliyor...';
    if (inHospital) return 'Hastane Kilidi';
    if (inPrison) return 'Hapis Kilidi';
    if (!canEnter) return 'Enerji Yetersiz';
    return 'Zindana Gir';
  }

  @override
  Widget build(BuildContext context) {
    final Color threat = theme.threatForSuccess(successPercent);
    final bool active = canEnter && !entering;
    final double powerRatio =
        powerRequirement > 0 ? (playerPower / powerRequirement).clamp(0.0, 2.0) : 1.0;
    final bool powerOk = powerRatio >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.surfaceDeep,
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.32),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: theme.surfaceDeep.withValues(alpha: 0.6),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ColoredBox(color: theme.artBackground),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: CaveArtWithFeatherEdge(
                    size: _kCaveArtSize,
                    theme: theme,
                  ),
                ),
              ),
              Positioned.fill(child: CaveCardLeftGradient(theme: theme)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(zoneIcon, size: 12, color: _kCardText),
                              const SizedBox(width: 5),
                              DungeonInsetText(
                                zoneLabel,
                                style: CaveTextStyle.label(color: _kCardText),
                              ),
                              const SizedBox(width: 8),
                              _ThreatBadge(
                                label: _threatLabel,
                                color: threat,
                                panel: theme.panel,
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          DungeonInsetText(
                            dungeon.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: CaveTextStyle.title(
                              color: _kCardText,
                              size: 18,
                            ),
                          ),
                          if (dungeon.description.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            DungeonInsetText(
                              dungeon.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: CaveTextStyle.body(
                                color: _kCardText,
                                size: 11,
                              ),
                              depthOffset: const Offset(0, 1),
                            ),
                          ],
                          if (kDebugMode && debugText != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              debugText!,
                              style: CaveTextStyle.body(
                                color: theme.textMuted,
                                size: 10,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              _CaveStatChip(
                                icon: Icons.bolt,
                                label: '${energyCost}E',
                                color: _kCardText,
                                panel: theme.panel,
                              ),
                              _CaveStatChip(
                                icon: Icons.monetization_on_outlined,
                                label: '${_fmt(minGold)}-${_fmt(maxGold)}G',
                                color: theme.gold,
                                panel: theme.panel,
                                isGold: true,
                              ),
                              if (powerRequirement > 0)
                                _CaveStatChip(
                                  icon: Icons.security,
                                  label: _fmt(powerRequirement),
                                  color: _kCardText,
                                  panel: theme.panel,
                                ),
                            ],
                          ),
                          if (powerRequirement > 0) ...<Widget>[
                            const SizedBox(height: 8),
                            _CavePowerBar(
                              ratio: (powerRatio / 2).clamp(0.0, 1.0),
                              ok: powerOk,
                              threat: threat,
                              theme: theme,
                            ),
                          ],
                          const SizedBox(height: 8),
                          DungeonProgressRow(dungeon: dungeon, accent: theme.accent),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              _CaveLootButton(onTap: onLoot, theme: theme),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CaveEnterButton(
                                  active: active,
                                  entering: entering,
                                  label: _enterLabel,
                                  theme: theme,
                                  onTap: active ? onEnter : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: _kCaveArtSize * 0.55),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 4,
                child: _CaveSuccessRing(
                  percent: successPercent,
                  color: threat,
                  panel: theme.panel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreatBadge extends StatelessWidget {
  const _ThreatBadge({
    required this.label,
    required this.color,
    required this.panel,
  });
  final String label;
  final Color color;
  final Color panel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: panel.withValues(alpha: 0.7),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(label, style: CaveTextStyle.label(color: _kCardText, size: 8)),
    );
  }
}

class _CaveSuccessRing extends StatelessWidget {
  const _CaveSuccessRing({
    required this.percent,
    required this.color,
    required this.panel,
  });
  final int percent;
  final Color color;
  final Color panel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: const Size(52, 52),
            painter: _CaveRingPainter(
              percent: percent.toDouble(),
              color: color,
              track: panel,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DungeonInsetText(
                '$percent',
                style: CaveTextStyle.title(color: _kCardText, size: 13),
                depthOffset: const Offset(0, 1),
              ),
              Text('%', style: CaveTextStyle.label(color: _kCardText, size: 7)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaveRingPainter extends CustomPainter {
  const _CaveRingPainter({
    required this.percent,
    required this.color,
    required this.track,
  });
  final double percent;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 3;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    if (percent > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * (percent / 100),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CaveRingPainter old) =>
      old.percent != percent || old.color != color || old.track != track;
}

class _CaveStatChip extends StatelessWidget {
  const _CaveStatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.panel,
    this.isGold = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color panel;
  final bool isGold;

  @override
  Widget build(BuildContext context) {
    final Color display = isGold ? color : _kCardText;
    final Color border = isGold ? color : _kCardText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: panel.withValues(alpha: 0.65),
        border: Border.all(color: border.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: display),
          const SizedBox(width: 4),
          Text(label, style: CaveTextStyle.body(color: display, size: 11)),
        ],
      ),
    );
  }
}

class _CavePowerBar extends StatelessWidget {
  const _CavePowerBar({
    required this.ratio,
    required this.ok,
    required this.threat,
    required this.theme,
  });
  final double ratio;
  final bool ok;
  final Color threat;
  final CaveCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            DungeonInsetText(
              'GÜÇ',
              style: CaveTextStyle.label(color: _kCardText, size: 8),
              depthOffset: const Offset(0, 0.8),
            ),
            const Spacer(),
            Text(
              ok ? 'YETERLİ' : 'YETERSİZ',
              style: CaveTextStyle.label(
                color: _kCardText,
                size: 8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: ratio,
            backgroundColor: theme.panel,
            valueColor: AlwaysStoppedAnimation<Color>(
              ok ? theme.powerOk : threat,
            ),
          ),
        ),
      ],
    );
  }
}

class _CaveLootButton extends StatelessWidget {
  const _CaveLootButton({required this.onTap, required this.theme});
  final VoidCallback onTap;
  final CaveCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.panel.withValues(alpha: 0.8),
            border: Border.all(
              color: theme.loot.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: _kCardText,
              ),
              const SizedBox(width: 5),
              Text(
                'Loot',
                style: CaveTextStyle.body(color: _kCardText, size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaveEnterButton extends StatelessWidget {
  const _CaveEnterButton({
    required this.active,
    required this.entering,
    required this.label,
    required this.theme,
    this.onTap,
  });

  final bool active;
  final bool entering;
  final String label;
  final CaveCardTheme theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: active
                ? LinearGradient(
                    colors: <Color>[theme.accent, theme.accentDeep],
                  )
                : null,
            color: active ? null : theme.panel.withValues(alpha: 0.85),
            border: Border.all(
              color: active
                  ? theme.accentGlow.withValues(alpha: 0.55)
                  : theme.textMuted.withValues(alpha: 0.25),
            ),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: entering
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kCardText,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        active ? Icons.play_arrow_rounded : Icons.lock_outline,
                        size: 17,
                        color: _kCardText,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: CaveTextStyle.title(
                          color: _kCardText,
                          size: 13,
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

CaveCardTheme? featuredCaveThemeFor(DungeonData dungeon) =>
    CaveCardTheme.forDungeonNumber(parseDungeonNumber(dungeon.dungeonId));

bool isFeaturedCaveDungeon(DungeonData dungeon) =>
    featuredCaveThemeFor(dungeon) != null;
