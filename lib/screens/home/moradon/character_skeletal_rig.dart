import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/graphics_quality_service.dart';
import '../../../models/moradon_models.dart';
import 'moradon_v5_layers.dart';

final Expando<ui.ImageShader> _kAtlasShaderCache =
    Expando<ui.ImageShader>('MoradonAtlasShaderCache');

ui.ImageShader _shaderForAtlas(ui.Image atlas) {
  final ui.ImageShader? cached = _kAtlasShaderCache[atlas];
  if (cached != null) return cached;
  final ui.ImageShader created = ui.ImageShader(
    atlas,
    TileMode.clamp,
    TileMode.clamp,
    Float64List.fromList(const <double>[
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ]),
  );
  _kAtlasShaderCache[atlas] = created;
  return created;
}

const int _kCharCols = 6;
const int _kCharRows = 7;
const int _kCharVertexFloats = (_kCharCols + 1) * (_kCharRows + 1) * 2;

final Uint16List _kCharMeshIndices = _buildGridIndices(_kCharCols, _kCharRows);
final Float32List _kScratchPositions = Float32List(_kCharVertexFloats);
final Float32List _kScratchTexCoords = Float32List(_kCharVertexFloats);

Uint16List _buildGridIndices(int cols, int rows) {
  final Uint16List out = Uint16List(cols * rows * 6);
  int k = 0;
  final int stride = cols + 1;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final int i0 = r * stride + c;
      final int i1 = i0 + 1;
      final int i2 = i0 + stride;
      final int i3 = i2 + 1;
      out[k++] = i0;
      out[k++] = i1;
      out[k++] = i2;
      out[k++] = i1;
      out[k++] = i3;
      out[k++] = i2;
    }
  }
  return out;
}

double _smoothstep(double edge0, double edge1, double x) {
  final double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

/// Studio-grade 60 FPS Seamless Character Locomotion & 3-Hit Class Combat Rig.
///
/// Uses 100% INTACT hand-drawn walk/stance cells from the 9-column character
/// atlas (`0` = front idle, `1..4` = front walk, `6` = back idle, `5..8` = back walk)
/// deformed through a continuous connected 2D triangle mesh (`ui.Vertices`) with
/// optical sub-frame transitions — ZERO horizontal slicing, ZERO torn weapons/capes,
/// and silky-smooth 60Hz stride & combat motion!
void paintSegmentedCharacterRig({
  required Canvas canvas,
  required Size size,
  required ui.Image atlas,
  required String classKey,
  required bool facingRight,
  required bool facingBack,
  required bool isMoving,
  required double walkPhase,
  required double idlePhase,
  required Color glowColor,
  required int glowLevel,
  required MoradonWeaponVisual weaponVisual,
  double attackProgress = 0.0,
  int comboStage = 0,
  bool fastSpriteQuad = false,
}) {
  final double w = size.width;
  final double h = size.height;
  if (w <= 1.0 || h <= 1.0) return;
  final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
  final bool useFastQuad = gfx.useFastSpriteQuad || fastSpriteQuad;

  final double cx = w * 0.5;
  final double groundY = h - 4.0;
  final double cellW = atlas.width / 9.0;
  final double cellH = atlas.height.toDouble();

  final bool isAttacking = attackProgress > 0.001 && attackProgress < 0.999;
  final double atkT = attackProgress.clamp(0.0, 1.0);

  // Normalize radian phase into [0, 2*pi)
  const double twoPi = math.pi * 2.0;
  final double normWalk = ((walkPhase % twoPi) + twoPi) % twoPi;
  final double strideSin = isMoving ? math.sin(normWalk) : 0.0;
  final double idleSin = math.sin(idlePhase * twoPi);
  final double idleCos = math.cos(idlePhase * twoPi);

  // 1. Select intact full-body atlas column(s)
  const List<int> frontWalkCols = <int>[1, 2, 3, 4];
  const List<int> backWalkCols = <int>[5, 6, 7, 8];

  int primaryCol;
  int? blendCol;
  double blendAlpha = 0.0;
  double subFrameGlide = 0.0;

  if (isAttacking) {
    // Dynamic wide-stride combat cell during strike window, planted cell on coil/recover
    final bool wideStrikePose = atkT >= 0.20 && atkT <= 0.74;
    primaryCol = facingBack
        ? (wideStrikePose ? 5 : 6)
        : (wideStrikePose ? 3 : 0);
  } else if (isMoving) {
    final List<int> seq = facingBack ? backWalkCols : frontWalkCols;
    final double fPos = (normWalk / twoPi) * 4.0;
    final int idxA = fPos.floor() % 4;
    final int idxB = (idxA + 1) % 4;
    final double frac = fPos - fPos.floor();
    primaryCol = seq[idxA];
    subFrameGlide = frac - 0.5;
    // Narrow optical cross-dissolve across the frame boundary eliminates 4-FPS snapping
    // while keeping legs & silhouettes 100% crisp and opaque!
    if (frac > 0.70) {
      blendCol = seq[idxB];
      blendAlpha = _smoothstep(0.70, 1.0, frac) * 0.48;
    }
  } else {
    primaryCol = facingBack ? 6 : 0;
  }

  // 2. Continuous 60Hz whole-body gait & 3-stage combat kinematics
  double bodyBobY = isMoving
      ? (-strideSin.abs() * (h * 0.028) + math.sin(normWalk * 2.0) * 0.7)
      : (-idleSin.abs() * 0.9);
  double bodyLungeX = 0.0;
  double upperLeanX = isMoving
      ? (w * 0.036 - strideSin * w * 0.012)
      : (idleCos * w * 0.008);
  double upperWhipY = 0.0;

  if (isAttacking) {
    if (atkT < 0.24) {
      final double p = Curves.easeOutCubic.transform(atkT / 0.24);
      bodyLungeX = -6.0 * p;
      bodyBobY += 3.0 * p;
      upperLeanX = -w * 0.085 * p;
      upperWhipY = h * 0.028 * p;
    } else if (atkT < 0.60) {
      final double p = Curves.easeOutExpo.transform((atkT - 0.24) / 0.36);
      final double jump =
          comboStage == 2 ? -7.5 * math.sin(p * math.pi) : -2.2 * p;
      bodyLungeX = -6.0 + 22.0 * p;
      bodyBobY += 3.0 * (1.0 - p) + jump;
      upperLeanX = w * (-0.085 + 0.225 * p);
      upperWhipY = h * 0.028 * (1.0 - p) - h * 0.022 * math.sin(p * math.pi);
    } else {
      final double inv =
          1.0 - Curves.easeInOutCubic.transform((atkT - 0.60) / 0.40);
      bodyLungeX = 16.0 * inv;
      upperLeanX = w * 0.140 * inv;
    }
  }

  canvas.save();
  // Mirror horizontally around character centerline when facing left
  canvas.translate(cx, groundY);
  if (!facingRight) {
    canvas.scale(-1.0, 1.0);
  }
  canvas.translate(-cx + bodyLungeX, -groundY + bodyBobY);

  // Subtle dark-fantasy ground bounce & silhouette heat rim (+7..+10)
  if (glowLevel >= 7) {
    _paintEnhancementPrestigeUnderlay(
      canvas: canvas,
      w: w,
      h: h,
      glowLevel: glowLevel,
      glowColor: glowColor,
      idlePhase: idlePhase,
      isLowTier: gfx.isLow,
    );
  }

  // 60 FPS animated footstep dust motes on plaza/ward stones while moving
  if (!useFastQuad && isMoving && !isAttacking) {
    _paintFootstepDust(
      canvas: canvas,
      w: w,
      h: h,
      normWalk: normWalk,
    );
  }

  // Fast single-quad blit path for Low tier & crowd/remote characters:
  // 1 hardware drawImageRect instead of 168-triangle Vertices + ImageShader!
  if (useFastQuad) {
    final Rect fastSrc = Rect.fromLTWH(
      primaryCol * cellW + 1.5,
      1.0,
      math.max(1.0, cellW - 3.0),
      math.max(1.0, cellH - 2.0),
    );
    canvas.drawImageRect(
      atlas,
      fastSrc,
      Rect.fromLTWH(upperLeanX * 0.35, 0, w, h),
      Paint()..filterQuality = gfx.filterQuality,
    );
  } else {
    // Shadow-clone phantom afterimage during Gölge dash or Combo 3 finisher!
    if (gfx.enableSpriteCrossDissolveAndGhost &&
        isAttacking &&
        atkT > 0.20 &&
        atkT < 0.72 &&
        (classKey == 'golge' || comboStage == 2)) {
      final double ghostAlpha =
          (1.0 - ((atkT - 0.20) / 0.52)).clamp(0.0, 1.0) * 0.36;
      final Rect fullSrc =
          Rect.fromLTWH(primaryCol * cellW + 1.5, 0, cellW - 3.0, cellH);
      final Rect ghostDst = Rect.fromLTWH(-13.0, 1.5, w, h);
      canvas.drawImageRect(
        atlas,
        fullSrc,
        ghostDst,
        Paint()
          ..filterQuality = gfx.filterQuality
          ..colorFilter = ColorFilter.mode(
            glowColor.withValues(alpha: ghostAlpha),
            BlendMode.srcATop,
          ),
      );
    }

    // Draw primary intact character cell via seamless 60Hz connected mesh
    _drawConnectedAtlasCell(
      canvas: canvas,
      atlas: atlas,
      col: primaryCol,
      cellW: cellW,
      cellH: cellH,
      dstW: w,
      dstH: h,
      opacity: 1.0,
      isMoving: isMoving,
      normWalk: normWalk,
      idlePhase: idlePhase,
      idleSin: idleSin,
      upperLeanX: upperLeanX,
      upperWhipY: upperWhipY,
      subFrameGlide: subFrameGlide,
      filterQuality: gfx.filterQuality,
    );

    // Smooth sub-frame optical cross-dissolve into next walk cell
    if (gfx.enableSpriteCrossDissolveAndGhost &&
        blendCol != null &&
        blendAlpha > 0.01) {
      _drawConnectedAtlasCell(
        canvas: canvas,
        atlas: atlas,
        col: blendCol,
        cellW: cellW,
        cellH: cellH,
        dstW: w,
        dstH: h,
        opacity: blendAlpha,
        isMoving: isMoving,
        normWalk: normWalk,
        idlePhase: idlePhase,
        idleSin: idleSin,
        upperLeanX: upperLeanX,
        upperWhipY: upperWhipY,
        subFrameGlide: subFrameGlide - 0.5,
        filterQuality: gfx.filterQuality,
      );
    }
  }

  // Enchanted weapon aura follows upper body cleanly
  if (weaponVisual != MoradonWeaponVisual.none &&
      (!fastSpriteQuad || glowLevel >= 9)) {
    canvas.save();
    canvas.translate(upperLeanX * 0.45, upperWhipY * 0.45);
    drawIsometricWeapon(
      canvas: canvas,
      size: size,
      weapon: weaponVisual,
      glowColor: glowColor,
      glowLevel: glowLevel,
      isMoving: isMoving,
      facingBack: facingBack,
      walkPhase: normWalk,
      idlePhase: idlePhase,
    );
    canvas.restore();
  }

  // Pack 2: Front-wrapping +8/+9/+10 forge sparks (local hero / full rig only)
  if (glowLevel >= 8 && !gfx.isLow && !fastSpriteQuad) {
    _paintEnhancementPrestigeOverlay(
      canvas: canvas,
      w: w,
      h: h,
      glowLevel: glowLevel,
      idlePhase: idlePhase,
      upperLeanX: upperLeanX,
      upperWhipY: upperWhipY,
    );
  }

  // Class-specific 60 FPS 3-hit melee/arcane VFX
  if (isAttacking && atkT >= 0.18) {
    _paintClassCombatVfx(
      canvas: canvas,
      size: size,
      classKey: classKey,
      atkT: ((atkT - 0.18) / 0.82).clamp(0.0, 1.0),
      comboStage: comboStage,
      glowColor: glowColor,
      enableBlur: gfx.enableHeavyShadows,
    );
  }

  canvas.restore();
}

void _drawConnectedAtlasCell({
  required Canvas canvas,
  required ui.Image atlas,
  required int col,
  required double cellW,
  required double cellH,
  required double dstW,
  required double dstH,
  required double opacity,
  required bool isMoving,
  required double normWalk,
  required double idlePhase,
  required double idleSin,
  required double upperLeanX,
  required double upperWhipY,
  required double subFrameGlide,
  FilterQuality filterQuality = FilterQuality.medium,
}) {
  final Float32List positions = _kScratchPositions;
  final Float32List texCoords = _kScratchTexCoords;

  // Inset by 1.5px inside cell bounds so bilinear filtering never samples neighbor columns
  final double uvLeft = col * cellW + 1.5;
  final double uvSpanW = math.max(1.0, cellW - 3.0);
  final double uvTop = 1.0;
  final double uvSpanH = math.max(1.0, cellH - 2.0);

  int idx = 0;
  for (int r = 0; r <= _kCharRows; r++) {
    final double v = r / _kCharRows;
    final double wUpper = 1.0 - _smoothstep(0.32, 0.94, v);
    final double wHem = _smoothstep(0.42, 0.90, v);
    final double wFoot = _smoothstep(0.62, 1.0, v);
    final double ribBreath = math.sin(v * math.pi) * idleSin;

    for (int c = 0; c <= _kCharCols; c++) {
      final double u = c / _kCharCols;
      final double side = (u - 0.5) * 2.0;

      // Connected whole-body deformation: zero cuts, zero disconnected limbs!
      double dx = upperLeanX * wUpper + (side * dstW * 0.011 * ribBreath);
      double dy = upperWhipY * wUpper;

      if (isMoving) {
        // Subtle 60Hz cape/coat flow + sub-frame stride glide across lower silhouette
        dx += subFrameGlide * dstW * 0.018 * wFoot;
        dy += math.sin(normWalk * 2.0 - u * 2.6) * dstH * 0.010 * wHem * (1.0 - wFoot * 0.6);
      } else {
        // Gentle idle breeze along cape/coat hem while boots stay locked at v=1
        dy += math.sin(idlePhase * math.pi * 4.0 + u * 2.8) *
            dstH *
            0.006 *
            wHem *
            (1.0 - wFoot);
      }

      positions[idx] = u * dstW + dx;
      positions[idx + 1] = v * dstH + dy;
      texCoords[idx] = uvLeft + u * uvSpanW;
      texCoords[idx + 1] = uvTop + v * uvSpanH;
      idx += 2;
    }
  }

  final ui.Vertices vertices = ui.Vertices.raw(
    ui.VertexMode.triangles,
    positions,
    textureCoordinates: texCoords,
    indices: _kCharMeshIndices,
  );

  final Paint paint = Paint()
    ..shader = _shaderForAtlas(atlas)
    ..filterQuality = filterQuality
    ..isAntiAlias = filterQuality != FilterQuality.none;

  if (opacity < 0.999) {
    paint.colorFilter = ColorFilter.matrix(<double>[
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, opacity.clamp(0.0, 1.0), 0,
    ]);
  }

  canvas.drawVertices(vertices, BlendMode.dst, paint);
}

void _paintFootstepDust({
  required Canvas canvas,
  required double w,
  required double h,
  required double normWalk,
}) {
  final Paint dustPaint = Paint()..style = PaintingStyle.fill;
  for (int i = 0; i < 2; i++) {
    final double stepT =
        (((normWalk / math.pi) + i * 1.0) % 1.0).clamp(0.0, 1.0);
    final double alpha = (1.0 - stepT) * 0.28;
    if (alpha <= 0.02) continue;
    final double puffX = (w * 0.44) - stepT * (w * 0.20) - i * 3.0;
    final double puffY = (h - 5.0) - math.sin(stepT * math.pi) * 4.5;
    final double radius = 2.6 + stepT * 4.2;
    dustPaint.color = const Color(0xFFD6C7B2).withValues(alpha: alpha);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(puffX, puffY),
        width: radius * 2.1,
        height: radius * 1.15,
      ),
      dustPaint,
    );
  }
}

void _paintClassCombatVfx({
  required Canvas canvas,
  required Size size,
  required String classKey,
  required double atkT,
  required int comboStage,
  required Color glowColor,
  bool enableBlur = true,
}) {
  final double w = size.width;
  final double h = size.height;
  final double fade = (1.0 - Curves.easeInQuad.transform(atkT)).clamp(0.0, 1.0);
  if (fade <= 0.01) return;

  final Color primary = switch (classKey) {
    'golge' => const Color(0xFFC084FC),
    'simyaci' => const Color(0xFF34D399),
    _ => const Color(0xFFF97316),
  };
  final Color hotCore = switch (classKey) {
    'golge' => const Color(0xFF7DD3FC),
    'simyaci' => const Color(0xFFA7F3D0),
    _ => const Color(0xFFFEF08A),
  };

  if (classKey == 'simyaci') {
    final Offset origin = Offset(w * 0.68, h * 0.48);
    final Offset target = Offset(w * (0.82 + atkT * 0.58), h * 0.50);
    final double orbR = (comboStage == 2 ? 24.0 : 16.0) * (0.7 + atkT * 0.5);

    canvas.drawCircle(
      origin,
      14.0 + atkT * 10.0,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = primary.withValues(alpha: fade * 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final Path beam = Path()..moveTo(origin.dx, origin.dy);
    for (int i = 1; i <= 8; i++) {
      final double f = i / 8.0;
      final double bx = ui.lerpDouble(origin.dx, target.dx, f)!;
      final double wave =
          math.sin(f * math.pi * 3 + atkT * 10) * (comboStage == 1 ? 9.0 : 4.5);
      beam.lineTo(bx, origin.dy + wave);
    }
    canvas.drawPath(
      beam,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = primary.withValues(alpha: fade * 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = comboStage == 2 ? 7.5 : 4.8
        ..strokeCap = StrokeCap.round
        ..maskFilter =
            enableBlur ? const MaskFilter.blur(BlurStyle.normal, 4.5) : null,
    );

    final Rect novaRect = Rect.fromCenter(
      center: target,
      width: orbR * 2.5,
      height: orbR * 2.5,
    );
    canvas.drawOval(
      novaRect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: fade * 0.95),
            hotCore.withValues(alpha: fade * 0.72),
            primary.withValues(alpha: fade * 0.35),
            Colors.transparent,
          ],
        ).createShader(novaRect),
    );
    return;
  }

  final Offset arcCenter = Offset(w * 0.56, h * 0.52);
  final double radius =
      w * (comboStage == 2 ? 0.62 : 0.52) * (0.86 + atkT * 0.22);
  final double startAng = comboStage == 1 ? 0.85 : -1.25;
  final double sweepAng = (comboStage == 1 ? -2.35 : 2.45) *
      Curves.easeOutCubic.transform((atkT * 1.35).clamp(0.0, 1.0));

  void drawCrescent(double rScale, double rotOffset, Color col, Color core) {
    final Rect arcRect = Rect.fromCircle(
      center: arcCenter,
      radius: radius * rScale,
    );
    canvas.drawArc(
      arcRect,
      startAng + rotOffset,
      sweepAng,
      false,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = col.withValues(alpha: fade * 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = comboStage == 2 ? 18.0 : 13.0
        ..strokeCap = StrokeCap.round
        ..maskFilter =
            enableBlur ? const MaskFilter.blur(BlurStyle.normal, 6.5) : null,
    );
    canvas.drawArc(
      arcRect,
      startAng + rotOffset + sweepAng * 0.08,
      sweepAng * 0.92,
      false,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = core.withValues(alpha: fade * 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = comboStage == 2 ? 5.2 : 3.6
        ..strokeCap = StrokeCap.round,
    );
  }

  drawCrescent(1.0, 0.0, primary, hotCore);
  if (classKey == 'golge') {
    drawCrescent(0.84, 0.55, glowColor, Colors.white);
  }

  if (comboStage == 2) {
    final Rect shock = Rect.fromCenter(
      center: Offset(w * 0.86, h - 5.0),
      width: 44.0 + atkT * 78.0,
      height: 15.0 + atkT * 26.0,
    );
    canvas.drawOval(
      shock,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = hotCore.withValues(alpha: fade * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * fade,
    );
  }

  final Paint sparkPaint = Paint()..blendMode = BlendMode.plus;
  for (int i = 0; i < 7; i++) {
    final double ang = startAng + sweepAng * ((i + 1) / 7.5);
    final double dist = radius * (0.85 + (i % 3) * 0.14) + atkT * 18.0;
    final Offset sp = Offset(
      arcCenter.dx + math.cos(ang) * dist,
      arcCenter.dy + math.sin(ang) * dist,
    );
    sparkPaint.color =
        (i.isEven ? hotCore : primary).withValues(alpha: fade * 0.90);
    canvas.drawCircle(sp, 2.3 * fade, sparkPaint);
  }
}

void _paintEnhancementPrestigeUnderlay({
  required Canvas canvas,
  required double w,
  required double h,
  required int glowLevel,
  required Color glowColor,
  required double idlePhase,
  required bool isLowTier,
}) {
  final double cx = w * 0.5;
  final double footY = h - 4.5;
  final double pulse = 0.5 + 0.5 * math.sin(idlePhase * math.pi * 2.0);

  // Authentic dark-fantasy metallic/forge palette (no neon pink or cartoon strokes)
  final Color forgeTint = glowLevel >= 10
      ? const Color(0xFFEA580C) // +10 Hellfire Molten Ember
      : (glowLevel == 9
            ? const Color(0xFFF59E0B) // +9 Sovereign Gold
            : (glowLevel == 8
                  ? const Color(0xFFD97706) // +8 Tempered Amber
                  : const Color(0xFF93C5FD))); // +7 Cold Steel

  final Rect groundPool = Rect.fromCenter(
    center: Offset(cx, footY),
    width: w * (glowLevel >= 9 ? 0.78 : 0.66),
    height: h * 0.15,
  );

  if (isLowTier) {
    canvas.drawOval(
      groundPool,
      Paint()
        ..color = forgeTint.withValues(alpha: glowLevel >= 9 ? 0.16 : 0.10),
    );
    return;
  }

  // Soft feathered ground light bounce on cobblestones (zero wireframe strokes)
  canvas.drawOval(
    groundPool,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: <Color>[
          forgeTint.withValues(
            alpha: (glowLevel >= 10 ? 0.24 : 0.16) + pulse * 0.05,
          ),
          glowColor.withValues(alpha: 0.07),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(groundPool),
  );

  // Subtle backlit forge heat behind armor torso (+9 / +10)
  if (glowLevel >= 9) {
    final Rect backHeat = Rect.fromCenter(
      center: Offset(cx, h * 0.52),
      width: w * 0.62,
      height: h * 0.58,
    );
    canvas.drawOval(
      backHeat,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: <Color>[
            forgeTint.withValues(
              alpha: (glowLevel >= 10 ? 0.14 : 0.09) + pulse * 0.03,
            ),
            Colors.transparent,
          ],
        ).createShader(backHeat),
    );
  }
}

void _paintEnhancementPrestigeOverlay({
  required Canvas canvas,
  required double w,
  required double h,
  required int glowLevel,
  required double idlePhase,
  required double upperLeanX,
  required double upperWhipY,
}) {
  final double cx = w * 0.5 + upperLeanX * 0.45;
  final Color emberCore = glowLevel >= 9
      ? const Color(0xFFFEF08A)
      : const Color(0xFFE0F2FE);
  final Color emberHalo = glowLevel >= 10
      ? const Color(0xFFF97316)
      : (glowLevel == 9 ? const Color(0xFFF59E0B) : const Color(0xFF93C5FD));

  // Delicate rising forge micro-embers (zero cartoon halos, wings, or lines)
  final Paint corePaint = Paint()..blendMode = BlendMode.plus;
  final int count = glowLevel >= 10 ? 6 : 4;
  for (int i = 0; i < count; i++) {
    final double p = (idlePhase + i * (1.0 / count)) % 1.0;
    final double fade = math.sin(p * math.pi).clamp(0.0, 1.0);
    if (fade <= 0.04) continue;
    final double y = (h - 12.0) - p * (h * 0.62) + upperWhipY * 0.25;
    final double x = cx + math.sin(p * math.pi * 2.4 + i * 1.9) * (w * 0.20);
    final Offset pt = Offset(x, y);

    final Rect softGlow = Rect.fromCenter(center: pt, width: 7.0, height: 7.0);
    canvas.drawOval(
      softGlow,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: <Color>[
            emberHalo.withValues(alpha: fade * 0.32),
            Colors.transparent,
          ],
        ).createShader(softGlow),
    );
    corePaint.color = emberCore.withValues(alpha: fade * 0.72);
    canvas.drawCircle(pt, i.isEven ? 1.25 : 0.95, corePaint);
  }
}
