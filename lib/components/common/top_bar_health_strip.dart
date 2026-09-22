import 'package:flutter/material.dart';

import '../../core/utils/player_health.dart';
import 'striped_progress_bar.dart';

/// XP + CAN side-by-side striped bars in the top-bar vitals cutout.
class TopBarVitalsBars extends StatelessWidget {
  const TopBarVitalsBars({
    super.key,
    required this.level,
    required this.xpPercent,
    required this.currentXp,
    required this.requiredXp,
    required this.health,
    required this.maxHealth,
  });

  final int level;
  final double xpPercent;
  final int currentXp;
  final int requiredXp;
  final int health;
  final int maxHealth;

  static const double _barHeight = 10;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final bool showHealth = maxHealth > 0;

    if (!showHealth) {
      return _singleXpBar();
    }

    final PlayerHealthStatus status =
        resolveHealthStatus(health: health, maxHealth: maxHealth);
    final double healthPercent =
        healthFraction(health: health, maxHealth: maxHealth);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: SizedBox(
                height: _barHeight,
                child: CustomPaint(
                  painter: StripedProgressBarPainter(percent: xpPercent),
                ),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: _barHeight,
                child: CustomPaint(
                  painter: HealthStripedBarPainter(
                    percent: healthPercent,
                    status: status,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      'LEVEL $level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$currentXp / $requiredXp',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              flex: 2,
              child: Row(
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.favorite_rounded,
                        size: 10,
                        color: HealthBarColors.label,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'CAN',
                        style: const TextStyle(
                          color: HealthBarColors.label,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatHealthRatio(health, maxHealth),
                          style: const TextStyle(
                            color: HealthBarColors.labelMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _singleXpBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 12,
          child: CustomPaint(
            painter: StripedProgressBarPainter(percent: xpPercent),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                'LEVEL $level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$currentXp / $requiredXp',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
