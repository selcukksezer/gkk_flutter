import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/social_theme_tokens.dart';

/// Authentic 2027 Aion 2 Mobile Mythic Daeva Chest vector painter.
///
/// Features an ornate 3D-angled fantasy coffer with metallic gold & obsidian trim,
/// a pulsating runic gemstone lock, and celestial energy leaking through the seams.
///
/// Supports direct GPU acceleration via [ui.FragmentShader] runtime effect with 19
/// sequential float uniforms (0..18), while seamlessly falling back to rich analytical
/// Canvas rendering in software environments.
class DaevaChestPainter extends CustomPainter {
  const DaevaChestPainter({
    required this.progress,
    this.primaryGold = SocialThemeTokens.celestialGold,
    this.secondaryAccent = SocialThemeTokens.celestialAmber,
    this.gemstoneColor = SocialThemeTokens.aetherCyan,
    this.isOpen = false,
    this.glowIntensity = 1.0,
    this.shader,
    this.time,
    this.lockPulse,
  });

  /// Total number of uniform float values declared in the Daeva Chest GPU shader pipeline.
  /// Layout:
  /// - 0..1:   uResolution (vec2)
  /// - 2:      uTime (float)
  /// - 3:      uProgress (float)
  /// - 4:      uGlowIntensity (float)
  /// - 5:      uIsOpen (float: 0.0 or 1.0)
  /// - 6..9:   uPrimaryGold (vec4, linear RGBA)
  /// - 10..13: uSecondaryAccent (vec4, linear RGBA)
  /// - 14..17: uGemstoneColor (vec4, linear RGBA)
  /// - 18:     uLockPulse (float)
  /// Total: 19 floats.
  static const int kUniformFloatCount = 19;

  final double progress;
  final Color primaryGold;
  final Color secondaryAccent;
  final Color gemstoneColor;
  final bool isOpen;
  final double glowIntensity;

  /// Optional GPU runtime fragment shader instance.
  final ui.FragmentShader? shader;

  /// Optional explicit time in seconds (defaults to progress * 2.0 * math.pi).
  final double? time;

  /// Optional explicit lock pulse override [0.0 .. 1.0].
  final double? lockPulse;

  /// Converts an sRGB color component [0.0 .. 1.0] to linear RGB space (IEC 61966-2-1).
  static double sRgbToLinear(double c) {
    final double clamped = c.clamp(0.0, 1.0);
    return (clamped <= 0.04045)
        ? (clamped / 12.92)
        : math.pow((clamped + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Converts a Flutter [Color] into 4 linear RGBA floats [r, g, b, a].
  static (double, double, double, double) colorToLinearRgba(Color color) {
    return (
      sRgbToLinear(color.r),
      sRgbToLinear(color.g),
      sRgbToLinear(color.b),
      color.a,
    );
  }

  /// Builds a contiguous [Float32List] buffer with all 19 uniforms in strict sequential order.
  static Float32List packUniforms({
    required Size size,
    required double progress,
    double? time,
    double glowIntensity = 1.0,
    bool isOpen = false,
    Color primaryGold = SocialThemeTokens.celestialGold,
    Color secondaryAccent = SocialThemeTokens.celestialAmber,
    Color gemstoneColor = SocialThemeTokens.aetherCyan,
    double? lockPulse,
  }) {
    final Float32List buffer = Float32List(kUniformFloatCount);
    final double activeTime = time ?? (progress * 2.0 * math.pi);
    final double pulseVal = lockPulse ?? (0.7 + 0.3 * math.sin(progress * 3 * math.pi));

    // 0..1: uResolution (vec2)
    buffer[0] = size.width;
    buffer[1] = size.height;

    // 2: uTime (float)
    buffer[2] = activeTime;

    // 3: uProgress (float)
    buffer[3] = progress;

    // 4: uGlowIntensity (float)
    buffer[4] = glowIntensity;

    // 5: uIsOpen (float)
    buffer[5] = isOpen ? 1.0 : 0.0;

    // 6..9: uPrimaryGold (vec4, linear RGBA)
    final (double pgr, double pgg, double pgb, double pga) = colorToLinearRgba(primaryGold);
    buffer[6] = pgr;
    buffer[7] = pgg;
    buffer[8] = pgb;
    buffer[9] = pga;

    // 10..13: uSecondaryAccent (vec4, linear RGBA)
    final (double sar, double sag, double sab, double saa) = colorToLinearRgba(secondaryAccent);
    buffer[10] = sar;
    buffer[11] = sag;
    buffer[12] = sab;
    buffer[13] = saa;

    // 14..17: uGemstoneColor (vec4, linear RGBA)
    final (double gcr, double gcg, double gcb, double gca) = colorToLinearRgba(gemstoneColor);
    buffer[14] = gcr;
    buffer[15] = gcg;
    buffer[16] = gcb;
    buffer[17] = gca;

    // 18: uLockPulse (float)
    buffer[18] = pulseVal;

    return buffer;
  }

  /// Directly binds all 19 uniforms to a Flutter [ui.FragmentShader] matching GLSL declaration order:
  /// - 0..1:   uResolution (vec2)
  /// - 2:      uTime (float)
  /// - 3:      uProgress (float)
  /// - 4:      uGlowIntensity (float)
  /// - 5:      uIsOpen (float)
  /// - 6..9:   uPrimaryGold (vec4, linear RGBA)
  /// - 10..13: uSecondaryAccent (vec4, linear RGBA)
  /// - 14..17: uGemstoneColor (vec4, linear RGBA)
  /// - 18:     uLockPulse (float)
  void applyUniforms(ui.FragmentShader targetShader, Size size) {
    final double activeTime = time ?? (progress * 2.0 * math.pi);
    final double pulseVal = lockPulse ?? (0.7 + 0.3 * math.sin(progress * 3 * math.pi));

    // 0..1: uResolution
    targetShader.setFloat(0, size.width);
    targetShader.setFloat(1, size.height);

    // 2: uTime
    targetShader.setFloat(2, activeTime);

    // 3: uProgress
    targetShader.setFloat(3, progress);

    // 4: uGlowIntensity
    targetShader.setFloat(4, glowIntensity);

    // 5: uIsOpen
    targetShader.setFloat(5, isOpen ? 1.0 : 0.0);

    // 6..9: uPrimaryGold (vec4 in linear RGBA)
    final (double pgr, double pgg, double pgb, double pga) = colorToLinearRgba(primaryGold);
    targetShader.setFloat(6, pgr);
    targetShader.setFloat(7, pgg);
    targetShader.setFloat(8, pgb);
    targetShader.setFloat(9, pga);

    // 10..13: uSecondaryAccent (vec4 in linear RGBA)
    final (double sar, double sag, double sab, double saa) = colorToLinearRgba(secondaryAccent);
    targetShader.setFloat(10, sar);
    targetShader.setFloat(11, sag);
    targetShader.setFloat(12, sab);
    targetShader.setFloat(13, saa);

    // 14..17: uGemstoneColor (vec4 in linear RGBA)
    final (double gcr, double gcg, double gcb, double gca) = colorToLinearRgba(gemstoneColor);
    targetShader.setFloat(14, gcr);
    targetShader.setFloat(15, gcg);
    targetShader.setFloat(16, gcb);
    targetShader.setFloat(17, gca);

    // 18: uLockPulse
    targetShader.setFloat(18, pulseVal);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Offset center = Offset(size.width * 0.5, size.height * 0.52);
    final double w = size.width * 0.72;
    final double h = size.height * 0.54;

    // 1. If GPU shader is provided, execute hardware-accelerated pass
    if (shader != null) {
      applyUniforms(shader!, size);
      final Paint shaderPaint = Paint()..shader = shader;
      canvas.drawRect(Offset.zero & size, shaderPaint);
    } else {
      // Hardware-independent analytical Canvas fallback
      _paintGroundAura(canvas, center, w, h);
    }

    _paintChestBody(canvas, center, w, h);
    _paintSeamGlow(canvas, center, w, h);
    _paintChestLid(canvas, center, w, h);
    _paintGoldBrackets(canvas, center, w, h);
    _paintCentralLock(canvas, center, w * 0.22);
    _paintFloatingSparks(canvas, center, w, h);
  }

  void _paintGroundAura(Canvas canvas, Offset center, double w, double h) {
    final double pulse = 0.5 + 0.5 * math.sin(progress * 2 * math.pi);
    final Paint auraPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          primaryGold.withValues(alpha: 0.35 * pulse * glowIntensity),
          secondaryAccent.withValues(alpha: 0.15 * pulse * glowIntensity),
          Colors.transparent,
        ],
        stops: const [0.15, 0.6, 1.0],
      ).createShader(Rect.fromCenter(center: center + Offset(0, h * 0.45), width: w * 1.8, height: h * 0.8));

    canvas.drawOval(
      Rect.fromCenter(center: center + Offset(0, h * 0.45), width: w * 1.8, height: h * 0.8),
      auraPaint,
    );
  }

  void _paintChestBody(Canvas canvas, Offset center, double w, double h) {
    final Rect bodyRect = Rect.fromCenter(
      center: center + Offset(0, h * 0.2),
      width: w,
      height: h * 0.58,
    );

    final Paint bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1E283D),
          Color(0xFF0F1726),
          Color(0xFF0A0F1A),
        ],
      ).createShader(bodyRect);

    final RRect bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      bottomLeft: const Radius.circular(8.0),
      bottomRight: const Radius.circular(8.0),
    );
    canvas.drawRRect(bodyRRect, bodyPaint);

    final Paint ribPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SocialThemeTokens.celestialGoldLight,
          primaryGold,
          SocialThemeTokens.celestialGoldDark,
        ],
      ).createShader(bodyRect);

    canvas.drawLine(Offset(center.dx - w * 0.28, bodyRect.top), Offset(center.dx - w * 0.28, bodyRect.bottom), ribPaint);
    canvas.drawLine(Offset(center.dx + w * 0.28, bodyRect.top), Offset(center.dx + w * 0.28, bodyRect.bottom), ribPaint);
  }

  void _paintSeamGlow(Canvas canvas, Offset center, double w, double h) {
    final double seamY = center.dy - h * 0.08;
    final double pulse = 0.6 + 0.4 * math.sin(progress * 2 * math.pi);

    final Paint seamPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          gemstoneColor.withValues(alpha: 0.9 * pulse * glowIntensity),
          Colors.white.withValues(alpha: 0.95 * pulse),
          gemstoneColor.withValues(alpha: 0.9 * pulse * glowIntensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(center.dx - w * 0.48, seamY - 3, w * 0.96, 6));

    canvas.drawRect(Rect.fromLTWH(center.dx - w * 0.48, seamY - 2.5, w * 0.96, 5), seamPaint);
  }

  void _paintChestLid(Canvas canvas, Offset center, double w, double h) {
    final double lidY = center.dy - h * 0.08;
    final double lidH = h * 0.42;

    canvas.save();
    if (isOpen) {
      // Hinge rotation when chest is opened
      canvas.translate(center.dx - w * 0.52, lidY);
      canvas.rotate(-0.35);
      canvas.translate(-(center.dx - w * 0.52), -lidY);
    }

    final Path lidPath = Path();
    lidPath.moveTo(center.dx - w * 0.52, lidY);
    lidPath.cubicTo(
      center.dx - w * 0.50,
      lidY - lidH * 1.1,
      center.dx + w * 0.50,
      lidY - lidH * 1.1,
      center.dx + w * 0.52,
      lidY,
    );
    lidPath.close();

    final Paint lidPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF2B3A58),
          Color(0xFF162238),
          Color(0xFF0F1726),
        ],
      ).createShader(Rect.fromLTWH(center.dx - w * 0.52, lidY - lidH, w * 1.04, lidH));
    canvas.drawPath(lidPath, lidPaint);

    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..shader = LinearGradient(
        colors: [
          SocialThemeTokens.celestialGoldLight,
          primaryGold,
          SocialThemeTokens.celestialGoldDark,
          primaryGold,
          SocialThemeTokens.celestialGoldLight,
        ],
      ).createShader(Rect.fromLTWH(center.dx - w * 0.52, lidY - lidH, w * 1.04, lidH));
    canvas.drawPath(lidPath, rimPaint);

    canvas.restore();
  }

  void _paintGoldBrackets(Canvas canvas, Offset center, double w, double h) {
    final Paint goldBracketPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          SocialThemeTokens.celestialGoldLight,
          primaryGold,
          SocialThemeTokens.celestialGoldDark,
        ],
      ).createShader(Rect.fromCenter(center: center, width: w, height: h));

    final double bY = center.dy + h * 0.48;
    final Path bl = Path()
      ..moveTo(center.dx - w * 0.50, bY - 14)
      ..lineTo(center.dx - w * 0.50, bY)
      ..lineTo(center.dx - w * 0.50 + 14, bY)
      ..lineTo(center.dx - w * 0.50 + 14, bY - 4)
      ..lineTo(center.dx - w * 0.50 + 4, bY - 4)
      ..lineTo(center.dx - w * 0.50 + 4, bY - 14)
      ..close();
    canvas.drawPath(bl, goldBracketPaint);

    final Path br = Path()
      ..moveTo(center.dx + w * 0.50, bY - 14)
      ..lineTo(center.dx + w * 0.50, bY)
      ..lineTo(center.dx + w * 0.50 - 14, bY)
      ..lineTo(center.dx + w * 0.50 - 14, bY - 4)
      ..lineTo(center.dx + w * 0.50 - 4, bY - 4)
      ..lineTo(center.dx + w * 0.50 - 4, bY - 14)
      ..close();
    canvas.drawPath(br, goldBracketPaint);

    final Paint rivetPaint = Paint()..color = SocialThemeTokens.celestialGoldLight;
    canvas.drawCircle(Offset(center.dx - w * 0.45, bY - 6), 1.6, rivetPaint);
    canvas.drawCircle(Offset(center.dx + w * 0.45, bY - 6), 1.6, rivetPaint);
  }

  void _paintCentralLock(Canvas canvas, Offset center, double lockSize) {
    final Offset lockCenter = Offset(center.dx, center.dy - lockSize * 0.1);

    final Rect plateRect = Rect.fromCenter(center: lockCenter, width: lockSize * 1.3, height: lockSize * 1.5);
    final Paint platePaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          SocialThemeTokens.celestialGoldLight,
          SocialThemeTokens.celestialGold,
          SocialThemeTokens.celestialGoldDark,
        ],
      ).createShader(plateRect);

    final Path shieldLock = Path()
      ..moveTo(lockCenter.dx - lockSize * 0.6, lockCenter.dy - lockSize * 0.6)
      ..lineTo(lockCenter.dx + lockSize * 0.6, lockCenter.dy - lockSize * 0.6)
      ..lineTo(lockCenter.dx + lockSize * 0.6, lockCenter.dy + lockSize * 0.1)
      ..lineTo(lockCenter.dx, lockCenter.dy + lockSize * 0.75)
      ..lineTo(lockCenter.dx - lockSize * 0.6, lockCenter.dy + lockSize * 0.1)
      ..close();
    canvas.drawPath(shieldLock, platePaint);

    final double pulse = lockPulse ?? (0.7 + 0.3 * math.sin(progress * 3 * math.pi));
    final Paint gemPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          gemstoneColor,
          gemstoneColor.withValues(alpha: 0.7),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: lockCenter, radius: lockSize * 0.45));

    final Path diamondGem = Path()
      ..moveTo(lockCenter.dx, lockCenter.dy - lockSize * 0.4)
      ..lineTo(lockCenter.dx + lockSize * 0.35, lockCenter.dy)
      ..lineTo(lockCenter.dx, lockCenter.dy + lockSize * 0.4)
      ..lineTo(lockCenter.dx - lockSize * 0.35, lockCenter.dy)
      ..close();
    canvas.drawPath(diamondGem, gemPaint);

    final Paint bloomPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          gemstoneColor.withValues(alpha: 0.65 * pulse * glowIntensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: lockCenter, radius: lockSize * 1.1));
    canvas.drawCircle(lockCenter, lockSize * 1.1, bloomPaint);
  }

  void _paintFloatingSparks(Canvas canvas, Offset center, double w, double h) {
    final Paint sparkPaint = Paint()..blendMode = BlendMode.plus;
    const int count = 8;

    for (int i = 0; i < count; i++) {
      final double seed = (i * 59.3) % 1.0;
      final double t = (progress * (0.9 + seed * 0.6) + seed) % 1.0;
      final double x = center.dx + (seed - 0.5) * w * 1.1;
      final double y = center.dy + h * 0.3 - (t * h * 0.9);
      final double alpha = math.sin(t * math.pi) * 0.85 * glowIntensity;

      sparkPaint.color = (i % 2 == 0 ? primaryGold : gemstoneColor).withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 1.6, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant DaevaChestPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryGold != primaryGold ||
        oldDelegate.secondaryAccent != secondaryAccent ||
        oldDelegate.gemstoneColor != gemstoneColor ||
        oldDelegate.isOpen != isOpen ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.shader != shader ||
        oldDelegate.time != time ||
        oldDelegate.lockPulse != lockPulse;
  }
}

/// Standalone Widget adapter for Mythic Daeva Chest.
class MythicDaevaChestWidget extends StatefulWidget {
  const MythicDaevaChestWidget({
    super.key,
    this.size = 88.0,
    this.primaryGold = SocialThemeTokens.celestialGold,
    this.secondaryAccent = SocialThemeTokens.celestialAmber,
    this.gemstoneColor = SocialThemeTokens.aetherCyan,
    this.isOpen = false,
    this.glowIntensity = 1.0,
    this.duration = const Duration(seconds: 3),
    this.shader,
    this.lockPulse,
  });

  final double size;
  final Color primaryGold;
  final Color secondaryAccent;
  final Color gemstoneColor;
  final bool isOpen;
  final double glowIntensity;
  final Duration duration;
  final ui.FragmentShader? shader;
  final double? lockPulse;

  @override
  State<MythicDaevaChestWidget> createState() => _MythicDaevaChestWidgetState();
}

class _MythicDaevaChestWidgetState extends State<MythicDaevaChestWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void didUpdateWidget(covariant MythicDaevaChestWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: DaevaChestPainter(
            progress: _controller.value,
            primaryGold: widget.primaryGold,
            secondaryAccent: widget.secondaryAccent,
            gemstoneColor: widget.gemstoneColor,
            isOpen: widget.isOpen,
            glowIntensity: widget.glowIntensity,
            shader: widget.shader,
            lockPulse: widget.lockPulse,
          ),
        );
      },
    );
  }
}
