import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../market/widgets/market_item_pedestal.dart';

/// 2027 Aion 2 Mobile — Ornate Dark Fantasy Metallic Filigree Frame & Panel.
/// Features multi-layered metallic bevels, corner flourishes, and rune ticks.
class TradeFiligreePanel extends StatelessWidget {
  const TradeFiligreePanel({
    super.key,
    required this.child,
    this.accent = AppColors.liquidGold,
    this.secondaryAccent,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.glowRadius = 16.0,
    this.glowOpacity = 0.16,
    this.showCornerGems = true,
    this.showRunicTicks = true,
    this.fillGradient,
  });

  final Widget child;
  final Color accent;
  final Color? secondaryAccent;
  final EdgeInsetsGeometry padding;
  final double glowRadius;
  final double glowOpacity;
  final bool showCornerGems;
  final bool showRunicTicks;
  final Gradient? fillGradient;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FiligreeFramePainter(
        accent: accent,
        secondaryAccent: secondaryAccent ?? accent.withValues(alpha: 0.6),
        glowRadius: glowRadius,
        glowOpacity: glowOpacity,
        showCornerGems: showCornerGems,
        showRunicTicks: showRunicTicks,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: fillGradient ??
              LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.spaceNavy.withValues(alpha: 0.94),
                  AppColors.carbonVoid.withValues(alpha: 0.96),
                  AppColors.darkObsidian.withValues(alpha: 0.92),
                ],
                stops: const <double>[0.0, 0.6, 1.0],
              ),
        ),
        child: child,
      ),
    );
  }
}

class _FiligreeFramePainter extends CustomPainter {
  const _FiligreeFramePainter({
    required this.accent,
    required this.secondaryAccent,
    required this.glowRadius,
    required this.glowOpacity,
    required this.showCornerGems,
    required this.showRunicTicks,
  });

  final Color accent;
  final Color secondaryAccent;
  final double glowRadius;
  final double glowOpacity;
  final bool showCornerGems;
  final bool showRunicTicks;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );

    // 1. Subtle Outer Glow
    if (glowOpacity > 0.01) {
      final Paint glowPaint = Paint()
        ..color = accent.withValues(alpha: glowOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, glowRadius);
      canvas.drawRRect(rrect, glowPaint);
    }

    // 2. Base Border with Metallic Gradient
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accent.withValues(alpha: 0.8),
          secondaryAccent.withValues(alpha: 0.45),
          accent.withValues(alpha: 0.7),
          AppColors.darkObsidian.withValues(alpha: 0.6),
        ],
        stops: const <double>[0.0, 0.35, 0.7, 1.0],
      ).createShader(rrect.outerRect);
    canvas.drawRRect(rrect, borderPaint);

    // 3. Inner Specular Highlight Line at the Top
    final Path topHighlight = Path()
      ..moveTo(16, 1)
      ..lineTo(size.width - 16, 1);
    final Paint topHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        colors: <Color>[
          accent.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.35),
          accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(16, 1, size.width - 32, 1));
    canvas.drawPath(topHighlight, topHighlightPaint);

    // 4. Ornate Filigree Corners
    const double cornerLen = 14.0;
    final Paint cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = accent;

    final Paint gemPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accent;

    // Top-Left Corner
    _drawCornerFiligree(canvas, cornerPaint, gemPaint, 0, 0, cornerLen, 1, 1);
    // Top-Right Corner
    _drawCornerFiligree(canvas, cornerPaint, gemPaint, size.width, 0, cornerLen, -1, 1);
    // Bottom-Left Corner
    _drawCornerFiligree(canvas, cornerPaint, gemPaint, 0, size.height, cornerLen, 1, -1);
    // Bottom-Right Corner
    _drawCornerFiligree(canvas, cornerPaint, gemPaint, size.width, size.height, cornerLen, -1, -1);

    // 5. Runic Ticks at Edge Midpoints
    if (showRunicTicks) {
      final Paint tickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = secondaryAccent.withValues(alpha: 0.65);

      final double midX = size.width / 2;
      final double midY = size.height / 2;

      // Top Center Rune Diamond
      _drawRunicDiamond(canvas, midX, 1, 3.0, gemPaint);
      // Bottom Center Rune Diamond
      _drawRunicDiamond(canvas, midX, size.height - 1, 3.0, gemPaint);

      // Left & Right Minor Ticks
      canvas.drawLine(Offset(1, midY - 6), Offset(1, midY + 6), tickPaint);
      canvas.drawLine(Offset(size.width - 1, midY - 6), Offset(size.width - 1, midY + 6), tickPaint);
    }
  }

  void _drawCornerFiligree(
    Canvas canvas,
    Paint cornerPaint,
    Paint gemPaint,
    double ox,
    double oy,
    double len,
    double dx,
    double dy,
  ) {
    final Path path = Path();
    // Primary bracket
    path.moveTo(ox + (dx * 3), oy + (dy * len));
    path.lineTo(ox + (dx * 3), oy + (dy * 3));
    path.lineTo(ox + (dx * len), oy + (dy * 3));

    // Secondary decorative tendril
    path.moveTo(ox + (dx * 6), oy + (dy * (len - 4)));
    path.quadraticBezierTo(
      ox + (dx * 6),
      oy + (dy * 6),
      ox + (dx * (len - 4)),
      oy + (dy * 6),
    );
    canvas.drawPath(path, cornerPaint);

    if (showCornerGems) {
      _drawRunicDiamond(canvas, ox + (dx * 5), oy + (dy * 5), 2.2, gemPaint);
    }
  }

  void _drawRunicDiamond(Canvas canvas, double cx, double cy, double radius, Paint paint) {
    final Path dPath = Path()
      ..moveTo(cx, cy - radius)
      ..lineTo(cx + radius, cy)
      ..lineTo(cx, cy + radius)
      ..lineTo(cx - radius, cy)
      ..close();
    canvas.drawPath(dPath, paint);
  }

  @override
  bool shouldRepaint(covariant _FiligreeFramePainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.secondaryAccent != secondaryAccent ||
        oldDelegate.glowRadius != glowRadius ||
        oldDelegate.glowOpacity != glowOpacity ||
        oldDelegate.showCornerGems != showCornerGems ||
        oldDelegate.showRunicTicks != showRunicTicks;
  }
}

/// Aion 2 Mobile — Ornate Metallic Item Offer Slot.
/// Handles both empty slot (mystic runic watermark) and occupied state (pedestal, rarity jewel, filigree badge).
class TradeFiligreeSlot extends StatelessWidget {
  const TradeFiligreeSlot({
    super.key,
    this.offer,
    this.isMine = false,
    this.allowRemove = true,
    this.onTap,
    this.onRemove,
    this.accentColor,
    this.size = 62.0,
  });

  final Map<String, dynamic>? offer;
  final bool isMine;
  final bool allowRemove;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final Color? accentColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = offer == null;
    final String rarity = (offer?['rarity'] as String?) ?? 'common';
    final Color rarityColor = accentColor ?? AppColors.forRarity(rarity);
    final String name = (offer?['name'] as String?) ?? '';
    final String icon = (offer?['icon'] as String?) ?? '';
    final String? itemId = offer?['item_id']?.toString();
    final int qty = (offer?['quantity'] as num?)?.toInt() ?? 1;

    ItemType? itemType;
    final String? rawType = offer?['item_type']?.toString();
    if (rawType != null && rawType.isNotEmpty) {
      for (final ItemType type in ItemType.values) {
        if (type.name == rawType.toLowerCase()) {
          itemType = type;
          break;
        }
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!isEmpty) {
          HapticFeedback.selectionClick();
          if (onTap != null) {
            onTap!();
          } else {
            MarketPedestalInspectionSheet.show(
              context,
              itemName: name,
              rarity: rarity,
              price: 0,
              itemId: itemId,
              iconValue: icon,
              itemType: itemType,
              stockLabel: 'Takas Teklifi • x$qty Adet',
              canBuy: false,
            );
          }
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isEmpty
                ? <Color>[
                    AppColors.carbonVoid.withValues(alpha: 0.7),
                    AppColors.spaceNavy.withValues(alpha: 0.5),
                  ]
                : <Color>[
                    AppColors.spaceNavy.withValues(alpha: 0.95),
                    AppColors.carbonVoid.withValues(alpha: 0.9),
                  ],
          ),
          border: Border.all(
            color: isEmpty
                ? AppColors.darkObsidian.withValues(alpha: 0.8)
                : rarityColor.withValues(alpha: 0.65),
            width: isEmpty ? 1.0 : 1.4,
          ),
          boxShadow: isEmpty
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: rarityColor.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Filigree Corner Brackets
            Positioned.fill(
              child: CustomPaint(
                painter: _SlotCornerFiligreePainter(
                  accent: isEmpty ? AppColors.mutedTitanium.withValues(alpha: 0.25) : rarityColor,
                ),
              ),
            ),

            if (isEmpty)
              // Empty Slot Rune Watermark
              Center(
                child: Icon(
                  Icons.shield_outlined,
                  size: size * 0.38,
                  color: AppColors.mutedTitanium.withValues(alpha: 0.22),
                ),
              )
            else ...<Widget>[
              // Rotating 3D Item Pedestal
              Center(
                child: MarketItemPedestal(
                  rarity: rarity,
                  iconValue: icon,
                  itemId: itemId,
                  itemType: itemType,
                  itemName: name,
                  size: size * 0.78,
                  interactive: false,
                  autoRotate: true,
                  showLightBeam: false,
                ),
              ),

              // Quantity Badge in Metallic Capsule
              if (qty > 1)
                Positioned(
                  bottom: 2,
                  right: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.carbonVoid.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: rarityColor.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'x$qty',
                      style: TextStyle(
                        color: rarityColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),

              // Remove Button for Owner
              if (isMine && allowRemove && onRemove != null)
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onRemove!();
                    },
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.mysticRuby.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 0.8),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.mysticRuby.withValues(alpha: 0.45),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.close, size: 11, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotCornerFiligreePainter extends CustomPainter {
  const _SlotCornerFiligreePainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withValues(alpha: 0.75);

    const double cl = 6.0;

    // Top-left
    canvas.drawLine(const Offset(2, 2 + cl), const Offset(2, 2), p);
    canvas.drawLine(const Offset(2, 2), const Offset(2 + cl, 2), p);

    // Top-right
    canvas.drawLine(Offset(size.width - 2 - cl, 2), Offset(size.width - 2, 2), p);
    canvas.drawLine(Offset(size.width - 2, 2), Offset(size.width - 2, 2 + cl), p);

    // Bottom-left
    canvas.drawLine(Offset(2, size.height - 2 - cl), Offset(2, size.height - 2), p);
    canvas.drawLine(Offset(2, size.height - 2), Offset(2 + cl, size.height - 2), p);

    // Bottom-right
    canvas.drawLine(Offset(size.width - 2 - cl, size.height - 2), Offset(size.width - 2, size.height - 2), p);
    canvas.drawLine(Offset(size.width - 2, size.height - 2 - cl), Offset(size.width - 2, size.height - 2), p);
  }

  @override
  bool shouldRepaint(covariant _SlotCornerFiligreePainter oldDelegate) =>
      oldDelegate.accent != accent;
}
