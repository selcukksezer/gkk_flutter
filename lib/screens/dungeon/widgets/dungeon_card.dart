import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../models/dungeon_model.dart';
import '../../../theme/app_colors.dart';
import '../dungeon_zone_data.dart';
import 'dungeon_progress_row.dart';

class DungeonCard extends StatelessWidget {
  const DungeonCard({
    super.key,
    required this.dungeon,
    required this.zone,
    required this.canEnter,
    required this.inHospital,
    required this.inPrison,
    required this.entering,
    required this.successPercent,
    required this.playerPower,
    required this.powerRequirement,
    this.debugText,
    required this.onEnter,
    required this.onLoot,
    this.useTutorialAnchors = false,
    this.onCardTap,
    this.siegeActive = false,
    this.siegeOccupiedSlots = 0,
    this.siegeHasMySlot = false,
    this.onSiegeTap,
  });

  final DungeonData dungeon;
  final DungeonZone? zone;
  final bool canEnter;
  final bool inHospital;
  final bool inPrison;
  final bool entering;
  final int successPercent;
  final int playerPower;
  final int powerRequirement;
  final String? debugText;
  final VoidCallback onEnter;
  final VoidCallback onLoot;
  final bool useTutorialAnchors;
  final VoidCallback? onCardTap;
  final bool siegeActive;
  final int siegeOccupiedSlots;
  final bool siegeHasMySlot;
  final VoidCallback? onSiegeTap;

  bool get _isBoss => dungeon.difficulty.toLowerCase().contains('dungeon');

  Color get _threatColor {
    if (_isBoss) return const Color(0xFF6366F1);
    if (successPercent >= 80) return const Color(0xFF22C55E);
    if (successPercent >= 55) return const Color(0xFFF59E0B);
    if (successPercent >= 30) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  String get _threatLabel {
    if (_isBoss) return 'BOSS';
    if (successPercent >= 80) return 'KOLAY';
    if (successPercent >= 55) return 'ORTA';
    if (successPercent >= 30) return 'ZOR';
    return 'ÖLÜMCÜL';
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = zone?.color ?? const Color(0xFF5B8FFF);
    final Color threat = _threatColor;

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0D1525),
        border: Border.all(color: const Color(0xFF1A2540)),
        boxShadow: _isBoss
            ? <BoxShadow>[
                BoxShadow(
                  color: threat.withValues(alpha: 0.12),
                  blurRadius: 18,
                  spreadRadius: 0,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    if (zone != null) ...<Widget>[
                                      Icon(zone!.icon, size: 11, color: zone!.color.withValues(alpha: 0.75)),
                                      const SizedBox(width: 4),
                                      Text(
                                        zone!.name.split(' ')[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: threat.withValues(alpha: 0.15),
                                        border: Border.all(color: threat.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        _threatLabel,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                    if (siegeActive || onSiegeTap != null) ...<Widget>[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: onSiegeTap,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            color: siegeActive
                                                ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                                                : Colors.white.withValues(alpha: 0.06),
                                            border: Border.all(
                                              color: siegeActive
                                                  ? const Color(0xFFEF4444).withValues(alpha: 0.55)
                                                  : Colors.white24,
                                            ),
                                          ),
                                          child: Text(
                                            siegeActive
                                                ? 'KUŞATMA ${siegeHasMySlot ? '★' : '$siegeOccupiedSlots/5'}'
                                                : 'KUŞATMA',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: siegeActive
                                                  ? const Color(0xFFFCA5A5)
                                                  : Colors.white54,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  dungeon.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                if (dungeon.description.isNotEmpty)
                                  Text(
                                    dungeon.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      height: 1.4,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _DungeonSuccessRing(percent: successPercent, color: threat),
                        ],
                      ),
                      if (kDebugMode && debugText != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          debugText!,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF3A5080)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _DungeonStatsRow(
                        energyCost: dungeon.energyCost,
                        minGold: dungeon.minGold,
                        maxGold: dungeon.maxGold,
                        powerReq: powerRequirement,
                      ),
                      const SizedBox(height: 8),
                      DungeonProgressRow(dungeon: dungeon, accent: accent),
                      if (powerRequirement > 0) ...<Widget>[
                        const SizedBox(height: 10),
                        _DungeonPowerBar(
                          playerPower: playerPower,
                          required: powerRequirement,
                          threat: threat,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          _DungeonLootButton(accent: accent, onTap: onLoot),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DungeonEnterButton(
                              canEnter: canEnter,
                              entering: entering,
                              inHospital: inHospital,
                              inPrison: inPrison,
                              color: threat,
                              onEnter: onEnter,
                              useTutorialAnchor: useTutorialAnchors,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (useTutorialAnchors) {
      card = TutorialAnchorScope(
        id: TutorialAnchorId.dungeonZone0,
        child: card,
      );
    }
    if (onCardTap != null) {
      card = GestureDetector(
        onTap: onCardTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }
    return card;
  }
}

class _DungeonSuccessRingPainter extends CustomPainter {
  const _DungeonSuccessRingPainter({required this.percent, required this.color});
  final double percent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 3;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
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
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DungeonSuccessRingPainter old) => old.percent != percent || old.color != color;
}

class _DungeonSuccessRing extends StatelessWidget {
  const _DungeonSuccessRing({required this.percent, required this.color});
  final int percent;
  final Color color;

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
            painter: _DungeonSuccessRingPainter(
              percent: percent.toDouble(),
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$percent',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const Text('%', style: TextStyle(fontSize: 8, color: Colors.white, height: 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DungeonStatsRow extends StatelessWidget {
  const _DungeonStatsRow({
    required this.energyCost,
    required this.minGold,
    required this.maxGold,
    required this.powerReq,
  });

  final int energyCost;
  final int minGold;
  final int maxGold;
  final int powerReq;

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        _chip(Icons.bolt, '${energyCost}E', Colors.white),
        _chip(Icons.monetization_on_outlined, '${_fmt(minGold)}-${_fmt(maxGold)}G', const Color(0xFFF5C842), isGold: true),
        if (powerReq > 0) _chip(Icons.security, _fmt(powerReq), Colors.white),
      ],
    );
  }

  Widget _chip(IconData icon, String text, Color color, {bool isGold = false}) {
    final Color iconColor = isGold ? color : Colors.white;
    final Color textColor = isGold ? color : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: (isGold ? color : Colors.white).withValues(alpha: 0.1),
        border: Border.all(color: (isGold ? color : Colors.white).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: iconColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }
}

class _DungeonPowerBar extends StatelessWidget {
  const _DungeonPowerBar({
    required this.playerPower,
    required this.required,
    required this.threat,
  });

  final int playerPower;
  final int required;
  final Color threat;

  @override
  Widget build(BuildContext context) {
    final double ratio = required > 0 ? (playerPower / required).clamp(0.0, 2.0) : 1.0;
    final double displayRatio = (ratio / 2).clamp(0.0, 1.0);
    final bool ok = ratio >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              'GÜÇ KARŞILAŞTIRMA',
              style: TextStyle(fontSize: 9, color: Colors.white, letterSpacing: 0.5),
            ),
            const Spacer(),
            Text(
              ok ? 'YETERLİ' : 'YETERSİZ',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: displayRatio,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            valueColor: AlwaysStoppedAnimation<Color>(ok ? const Color(0xFF22C55E) : threat),
          ),
        ),
      ],
    );
  }
}

class _DungeonLootButton extends StatelessWidget {
  const _DungeonLootButton({required this.accent, required this.onTap});
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: accent.withValues(alpha: 0.1),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.inventory_2_outlined, size: 14, color: Colors.white),
            SizedBox(width: 5),
            Text(
              'Ganimet',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _DungeonEnterButton extends StatelessWidget {
  const _DungeonEnterButton({
    required this.canEnter,
    required this.entering,
    required this.inHospital,
    required this.inPrison,
    required this.color,
    required this.onEnter,
    this.useTutorialAnchor = false,
  });

  final bool canEnter;
  final bool entering;
  final bool inHospital;
  final bool inPrison;
  final Color color;
  final VoidCallback onEnter;
  final bool useTutorialAnchor;

  String get _label {
    if (entering) return 'Girilyor...';
    if (inHospital) return 'Hastane Kilidi';
    if (inPrison) return 'Hapis Kilidi';
    if (!canEnter) return 'Enerji Yetersiz';
    return 'Zindana Gir';
  }

  @override
  Widget build(BuildContext context) {
    final bool active = canEnter && !entering;
    final Color actionColor = active
        ? AppColors.liquidGold
        : !inHospital && !inPrison && !canEnter
            ? AppColors.warningSolar
            : const Color(0xFF1E2D50);
    final Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: active ? actionColor.withValues(alpha: 0.88) : const Color(0xFF111A2A),
        border: Border.all(color: actionColor),
      ),
      child: Center(
        child: entering
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    active ? Icons.play_arrow_rounded : Icons.lock_outline,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );

    return GestureDetector(
      onTap: active ? onEnter : null,
      child: useTutorialAnchor
          ? TutorialAnchorScope(
              id: TutorialAnchorId.dungeonEnterBtn,
              child: button,
            )
          : button,
    );
  }
}
