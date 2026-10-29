import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';
import '../../support/widgets/support_design.dart';

/// Staff rank classification for Aion 2 2027 visual tiering.
enum StaffRank {
  grandmaster('GRANDMASTER', 'RANK 00 · SUPREME', SettingsPalette.gold, Color(0xFFD4AF37), Color(0xFF8A2BE2)),
  leadArchon('LEAD ARCHON', 'RANK 01 · ARCHON', SettingsPalette.neon, Color(0xFF00E5FF), Color(0xFF1E88E5)),
  warden('WARDEN', 'RANK 02 · SENTINEL', SettingsPalette.coral, Color(0xFFFF5252), Color(0xFFFFA000));

  const StaffRank(
    this.title,
    this.code,
    this.accent,
    this.primaryColor,
    this.secondaryColor,
  );

  final String title;
  final String code;
  final Color accent;
  final Color primaryColor;
  final Color secondaryColor;

  static StaffRank fromRole(String? role) {
    if (role == null) return StaffRank.warden;
    final String r = role.toLowerCase().trim();
    if (r.contains('admin') || r.contains('owner') || r.contains('grandmaster') || r.contains('super')) {
      return StaffRank.grandmaster;
    }
    if (r.contains('gm') || r.contains('archon') || r.contains('lead') || r.contains('master')) {
      return StaffRank.leadArchon;
    }
    return StaffRank.warden;
  }
}

/// Animated high-res rank border painter for staff portraits.
class StaffRankBorderPainter extends CustomPainter {
  StaffRankBorderPainter({
    required this.rank,
    required this.progress,
    required this.pulse,
  });

  final StaffRank rank;
  final double progress; // 0.0 -> 1.0 (rotation/sweep)
  final double pulse; // 0.0 -> 1.0 (breathing scale/glow)

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2;

    switch (rank) {
      case StaffRank.grandmaster:
        _paintGrandmaster(canvas, center, radius);
        break;
      case StaffRank.leadArchon:
        _paintLeadArchon(canvas, center, radius);
        break;
      case StaffRank.warden:
        _paintWarden(canvas, center, radius);
        break;
    }
  }

  void _paintGrandmaster(Canvas canvas, Offset center, double radius) {
    final double outerGlowRadius = radius * (1.08 + pulse * 0.06);

    // 1. Ambient radial gold-violet aura
    final Paint auraPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        outerGlowRadius,
        <Color>[
          rank.primaryColor.withValues(alpha: 0.25 + pulse * 0.15),
          rank.secondaryColor.withValues(alpha: 0.15 + pulse * 0.1),
          Colors.transparent,
        ],
        <double>[0.0, 0.75, 1.0],
      );
    canvas.drawCircle(center, outerGlowRadius, auraPaint);

    // 2. Rotating celestial runic ring
    final double ringRadius = radius - 4;
    final double angleOffset = progress * 2 * math.pi;

    final Paint ringPaint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        <Color>[
          rank.primaryColor.withValues(alpha: 0.2),
          rank.secondaryColor,
          rank.primaryColor,
          rank.secondaryColor.withValues(alpha: 0.2),
        ],
        <double>[0.0, 0.45, 0.85, 1.0],
        TileMode.clamp,
        angleOffset,
        angleOffset + 2 * math.pi,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // 3. Four cardinal diamond brackets
    final Paint diamondPaint = Paint()
      ..color = rank.primaryColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final double angle = angleOffset + (i * math.pi / 2);
      final double dx = center.dx + (ringRadius) * math.cos(angle);
      final double dy = center.dy + (ringRadius) * math.sin(angle);
      final Path diamond = Path()
        ..moveTo(dx, dy - 5)
        ..lineTo(dx + 5, dy)
        ..lineTo(dx, dy + 5)
        ..lineTo(dx - 5, dy)
        ..close();
      canvas.drawPath(diamond, diamondPaint);
    }

    // 4. Inner metallic bevel border
    final Paint innerBevel = Paint()
      ..color = const Color(0xFFFFF0A0).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 8, innerBevel);
  }

  void _paintLeadArchon(Canvas canvas, Offset center, double radius) {
    final double pulseRadius = radius * (1.05 + pulse * 0.05);

    // 1. Arcane cyan plasma aura
    final Paint plasmaAura = Paint()
      ..shader = ui.Gradient.radial(
        center,
        pulseRadius,
        <Color>[
          rank.primaryColor.withValues(alpha: 0.3 + pulse * 0.15),
          rank.secondaryColor.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        <double>[0.0, 0.7, 1.0],
      );
    canvas.drawCircle(center, pulseRadius, plasmaAura);

    // 2. Hexagonal energy shield
    const int sides = 6;
    final double hexRadius = radius - 4;
    final double rotation = progress * math.pi;

    final Path hexPath = Path();
    for (int i = 0; i < sides; i++) {
      final double angle = rotation + (i * 2 * math.pi / sides);
      final double x = center.dx + hexRadius * math.cos(angle);
      final double y = center.dy + hexRadius * math.sin(angle);
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();

    final Paint hexPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - radius, center.dy - radius),
        Offset(center.dx + radius, center.dy + radius),
        <Color>[rank.primaryColor, rank.secondaryColor, rank.primaryColor],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(hexPath, hexPaint);

    // 3. Counter-rotating arc flares
    final double flareAngle = -progress * 2 * math.pi;
    final Paint arcPaint = Paint()
      ..color = rank.primaryColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      flareAngle,
      math.pi / 2.5,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      flareAngle + math.pi,
      math.pi / 2.5,
      false,
      arcPaint,
    );
  }

  void _paintWarden(Canvas canvas, Offset center, double radius) {
    final double outerGlow = radius * (1.04 + pulse * 0.04);

    // 1. Deep forge molten crimson aura
    final Paint forgeAura = Paint()
      ..shader = ui.Gradient.radial(
        center,
        outerGlow,
        <Color>[
          rank.primaryColor.withValues(alpha: 0.25 + pulse * 0.12),
          rank.secondaryColor.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        <double>[0.0, 0.75, 1.0],
      );
    canvas.drawCircle(center, outerGlow, forgeAura);

    // 2. Heavy fortress border with notched shield teeth
    final Paint fortressPaint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        <Color>[
          rank.primaryColor,
          rank.secondaryColor,
          rank.primaryColor,
          rank.secondaryColor,
        ],
        <double>[0.0, 0.33, 0.66, 1.0],
        TileMode.clamp,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius - 5, fortressPaint);

    // 3. Forge bolts (8 perimeter rivets)
    final Paint boltPaint = Paint()
      ..color = rank.secondaryColor
      ..style = PaintingStyle.fill;
    final Paint boltCore = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    const int boltCount = 8;
    for (int i = 0; i < boltCount; i++) {
      final double angle = (i * 2 * math.pi / boltCount) + (progress * 0.5 * math.pi);
      final double bx = center.dx + (radius - 5) * math.cos(angle);
      final double by = center.dy + (radius - 5) * math.sin(angle);
      canvas.drawCircle(Offset(bx, by), 3.0, boltPaint);
      canvas.drawCircle(Offset(bx, by), 1.2, boltCore);
    }
  }

  @override
  bool shouldRepaint(covariant StaffRankBorderPainter oldDelegate) {
    return oldDelegate.rank != rank ||
        oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse;
  }
}

/// High-res avatar container with animated rank frame.
class StaffRankAvatarFrame extends StatefulWidget {
  const StaffRankAvatarFrame({
    super.key,
    required this.rank,
    this.size = 80,
    this.avatarUrl,
    this.avatarAsset,
    this.fallbackInitials = 'GM',
    this.isOnline = true,
    this.badgeText,
    this.onTap,
  });

  final StaffRank rank;
  final double size;
  final String? avatarUrl;
  final String? avatarAsset;
  final String fallbackInitials;
  final bool isOnline;
  final String? badgeText;
  final VoidCallback? onTap;

  @override
  State<StaffRankAvatarFrame> createState() => _StaffRankAvatarFrameState();
}

class _StaffRankAvatarFrameState extends State<StaffRankAvatarFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double innerSize = widget.size - 20;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (BuildContext context, Widget? child) {
            final double progress = _anim.value;
            final double pulse = 0.5 + 0.5 * math.sin(progress * 2 * math.pi);

            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Animated rank border
                Positioned.fill(
                  child: CustomPaint(
                    painter: StaffRankBorderPainter(
                      rank: widget.rank,
                      progress: progress,
                      pulse: pulse,
                    ),
                  ),
                ),

                // High-res avatar clip
                Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SettingsPalette.navy,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: widget.rank.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildAvatarContent(),
                  ),
                ),

                // Online/LiveOps status dot
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isOnline ? SettingsPalette.neon : SettingsPalette.ruby,
                      border: Border.all(color: SettingsPalette.navy, width: 2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: (widget.isOnline ? SettingsPalette.neon : SettingsPalette.ruby)
                              .withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),

                // Optional rank chip
                if (widget.badgeText != null)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SettingsPalette.navy.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.rank.primaryColor.withValues(alpha: 0.7),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.badgeText!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: widget.rank.primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    if (widget.avatarAsset != null && widget.avatarAsset!.isNotEmpty) {
      return Image.asset(
        widget.avatarAsset!,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => _buildFallback(),
      );
    }
    if (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty) {
      return Image.network(
        widget.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: <Color>[
            widget.rank.primaryColor.withValues(alpha: 0.35),
            SettingsPalette.obsidian,
          ],
        ),
      ),
      child: Center(
        child: Text(
          widget.fallbackInitials,
          style: TextStyle(
            fontSize: widget.size * 0.28,
            fontWeight: FontWeight.w900,
            color: widget.rank.primaryColor,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

/// Glassmorphism Staff Card with high-res portrait and badge info.
class StaffPortraitCard extends StatelessWidget {
  const StaffPortraitCard({
    super.key,
    required this.name,
    required this.rank,
    required this.statusSubtitle,
    this.avatarUrl,
    this.avatarAsset,
    this.isOnline = true,
    this.onTap,
  });

  final String name;
  final StaffRank rank;
  final String statusSubtitle;
  final String? avatarUrl;
  final String? avatarAsset;
  final bool isOnline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SettingsGlassCard(
        accent: rank.primaryColor,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            StaffRankAvatarFrame(
              rank: rank,
              size: 68,
              avatarUrl: avatarUrl,
              avatarAsset: avatarAsset,
              fallbackInitials: name.isNotEmpty ? name.substring(0, math.min(2, name.length)).toUpperCase() : 'GM',
              isOnline: isOnline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          name,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: SettingsPalette.textHi,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: rank.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: rank.primaryColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          rank.title,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: rank.primaryColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rank.code,
                    style: supportCaptionStyle.copyWith(
                      color: rank.primaryColor.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusSubtitle,
                    style: supportCaptionStyle.copyWith(
                      color: SettingsPalette.textMid,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

/// Telemetry pulse status node for real-time LiveOps monitoring.
class LiveOpsPulseNode extends StatefulWidget {
  const LiveOpsPulseNode({
    super.key,
    required this.nodeName,
    required this.latencyMs,
    required this.loadPercent,
    required this.accent,
    this.statusText = 'OPERATIONAL',
    this.isCritical = false,
  });

  final String nodeName;
  final int latencyMs;
  final int loadPercent;
  final Color accent;
  final String statusText;
  final bool isCritical;

  @override
  State<LiveOpsPulseNode> createState() => _LiveOpsPulseNodeState();
}

class _LiveOpsPulseNodeState extends State<LiveOpsPulseNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isCritical ? 800 : 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SettingsPalette.obsidian.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: <Widget>[
          // Pulsing ping radar
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (BuildContext context, Widget? child) {
              final double wave = _pulseCtrl.value;
              return SizedBox(
                width: 22,
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Ripple
                    Container(
                      width: 10 + (12 * wave),
                      height: 10 + (12 * wave),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.accent.withValues(alpha: 0.6 * (1.0 - wave)),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Core
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.accent,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.8),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.nodeName,
                  style: supportBodyStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${widget.latencyMs}ms · ${widget.loadPercent}% load · ${widget.statusText}',
                  style: supportCaptionStyle.copyWith(
                    color: widget.isCritical ? SettingsPalette.ruby : SettingsPalette.textMid,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter for LiveOps waveform/sparkline telemetry charts.
class TelemetryWaveformPainter extends CustomPainter {
  TelemetryWaveformPainter({
    required this.values,
    required this.lineColor,
    required this.fillGradient,
    required this.phase,
  });

  final List<double> values;
  final Color lineColor;
  final Gradient fillGradient;
  final double phase; // Animation phase for live shimmer

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    final double dx = width / (values.length - 1).clamp(1, 999);

    final Path linePath = Path();
    final Path fillPath = Path();

    // Map values (0.0 to 1.0) to coordinates
    double getY(double val) => height - (val.clamp(0.0, 1.0) * (height - 8)) - 4;

    linePath.moveTo(0, getY(values.first));
    fillPath.moveTo(0, height);
    fillPath.lineTo(0, getY(values.first));

    for (int i = 0; i < values.length - 1; i++) {
      final double x0 = i * dx;
      final double y0 = getY(values[i]);
      final double x1 = (i + 1) * dx;
      final double y1 = getY(values[i + 1]);

      final double cx = (x0 + x1) / 2;
      linePath.cubicTo(cx, y0, cx, y1, x1, y1);
      fillPath.cubicTo(cx, y0, cx, y1, x1, y1);
    }

    fillPath.lineTo(width, height);
    fillPath.close();

    // Draw gradient fill
    final Paint fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw luminous curve line
    final Paint strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;
    canvas.drawPath(linePath, strokePaint);

    // Pulsing end beacon node
    final double lastX = width;
    final double lastY = getY(values.last);
    final double beaconPulse = 4.0 + 2.0 * math.sin(phase * 2 * math.pi);

    final Paint beaconGlow = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), beaconPulse + 4, beaconGlow);

    final Paint beaconPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 3.5, beaconPaint);
  }

  @override
  bool shouldRepaint(covariant TelemetryWaveformPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.phase != phase;
  }
}

/// Real-time LiveOps monitoring telemetry chart widget.
class LiveOpsTelemetryChart extends StatefulWidget {
  const LiveOpsTelemetryChart({
    super.key,
    required this.title,
    required this.currentMetric,
    required this.metricUnit,
    required this.dataPoints,
    this.lineColor = SettingsPalette.neon,
    this.subtitle,
    this.height = 110,
  });

  final String title;
  final String currentMetric;
  final String metricUnit;
  final List<double> dataPoints; // Normalized 0.0 -> 1.0 or raw
  final Color lineColor;
  final String? subtitle;
  final double height;

  @override
  State<LiveOpsTelemetryChart> createState() => _LiveOpsTelemetryChartState();
}

class _LiveOpsTelemetryChartState extends State<LiveOpsTelemetryChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<double> normalized = _normalizeData(widget.dataPoints);

    return SettingsGlassCard(
      accent: widget.lineColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: supportBodyStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: supportCaptionStyle.copyWith(fontSize: 10),
                    ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    widget.currentMetric,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: widget.lineColor,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    widget.metricUnit,
                    style: supportCaptionStyle.copyWith(
                      color: SettingsPalette.textMid,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: widget.height,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: TelemetryWaveformPainter(
                    values: normalized,
                    lineColor: widget.lineColor,
                    fillGradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        widget.lineColor.withValues(alpha: 0.35),
                        widget.lineColor.withValues(alpha: 0.02),
                      ],
                    ),
                    phase: _anim.value,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<double> _normalizeData(List<double> raw) {
    if (raw.isEmpty) return const <double>[0.5, 0.5];
    final double maxVal = raw.reduce(math.max);
    final double minVal = raw.reduce(math.min);
    if ((maxVal - minVal).abs() < 0.001) {
      return raw.map((_) => 0.5).toList();
    }
    return raw.map((double v) => ((v - minVal) / (maxVal - minVal)).clamp(0.05, 0.95)).toList();
  }
}
