import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';
import 'market_design.dart';
import 'market_helpers.dart';

/// 3D Item Pedestal with rotating highlight, hovering levitation,
/// concentric runic rings, and optional touch-drag inspection.
class MarketItemPedestal extends StatefulWidget {
  const MarketItemPedestal({
    super.key,
    required this.rarity,
    this.iconValue = '',
    this.itemId,
    this.itemType,
    this.itemName = '',
    this.size = 140,
    this.interactive = true,
    this.autoRotate = true,
    this.showLightBeam = true,
    this.showRunicRings = true,
  });

  final String rarity;
  final String iconValue;
  final String? itemId;
  final ItemType? itemType;
  final String itemName;
  final double size;
  final bool interactive;
  final bool autoRotate;
  final bool showLightBeam;
  final bool showRunicRings;

  @override
  State<MarketItemPedestal> createState() => _MarketItemPedestalState();
}

class _MarketItemPedestalState extends State<MarketItemPedestal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  double _manualYaw = 0.0;
  double _manualPitch = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    if (widget.autoRotate) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MarketItemPedestal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoRotate != oldWidget.autoRotate) {
      if (widget.autoRotate) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.interactive) return;
    HapticFeedback.selectionClick();
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.interactive) return;
    setState(() {
      _manualYaw += details.delta.dx * 0.015;
      _manualPitch = (_manualPitch - details.delta.dy * 0.01).clamp(-0.25, 0.25);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.interactive) return;
    setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = marketRarityColor(widget.rarity);
    final Color glowColor = marketRarityGlowColor(widget.rarity);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: AnimatedBuilder(
          animation: _rotationController,
          builder: (BuildContext context, Widget? child) {
            final double autoAngle = _rotationController.value * 2 * math.pi;
            final double currentYaw = autoAngle + _manualYaw;
            final double bob = math.sin(_rotationController.value * 2 * math.pi) * 4.5;
            final double itemIconSize = widget.size * 0.44;

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: <Widget>[
                // 3D Pedestal Base & Rotating Highlight
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PedestalPainter(
                      highlightAngle: currentYaw,
                      pitch: _manualPitch,
                      rarityColor: rarityColor,
                      glowColor: glowColor,
                      showLightBeam: widget.showLightBeam,
                      showRunicRings: widget.showRunicRings,
                      isDragging: _isDragging,
                    ),
                  ),
                ),

                // Floating 3D Item with levitation bob & perspective
                Positioned(
                  top: (widget.size * 0.18) + bob,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateY(math.sin(currentYaw * 0.5) * 0.18)
                      ..rotateX(_manualPitch * 0.6),
                    alignment: Alignment.center,
                    child: Container(
                      width: itemIconSize,
                      height: itemIconSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: glowColor.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: ItemIconView(
                          iconValue: widget.iconValue,
                          itemId: widget.itemId,
                          itemType: widget.itemType,
                          size: itemIconSize,
                          expand: true,
                        ),
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
}

class _PedestalPainter extends CustomPainter {
  const _PedestalPainter({
    required this.highlightAngle,
    required this.pitch,
    required this.rarityColor,
    required this.glowColor,
    required this.showLightBeam,
    required this.showRunicRings,
    required this.isDragging,
  });

  final double highlightAngle;
  final double pitch;
  final Color rarityColor;
  final Color glowColor;
  final bool showLightBeam;
  final bool showRunicRings;
  final bool isDragging;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height * 0.72 + (pitch * 20);
    final double radiusX = size.width * 0.40;
    final double radiusY = radiusX * 0.34;
    final double pedestalHeight = size.height * 0.14;

    // 1. Ambient Radial Floor Glow
    final Rect floorRect = Rect.fromCenter(
      center: Offset(cx, cy + pedestalHeight * 0.4),
      width: radiusX * 2.5,
      height: radiusY * 2.6,
    );
    final Paint floorGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          glowColor.withValues(alpha: 0.30),
          glowColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(floorRect);
    canvas.drawOval(floorRect, floorGlow);

    // 2. Vertical Ethereal Light Beam
    if (showLightBeam) {
      final Path beamPath = Path()
        ..moveTo(cx - radiusX * 0.65, cy)
        ..lineTo(cx + radiusX * 0.65, cy)
        ..lineTo(cx + radiusX * 0.45, size.height * 0.08)
        ..lineTo(cx - radiusX * 0.45, size.height * 0.08)
        ..close();

      final Paint beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            glowColor.withValues(alpha: 0.22),
            glowColor.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(beamPath, beamPaint);
    }

    // 3. Lower Tier Pedestal Extrusion (Cylinder depth)
    final Path cylinderPath = Path()
      ..moveTo(cx - radiusX, cy)
      ..lineTo(cx - radiusX, cy + pedestalHeight)
      ..arcTo(
        Rect.fromCenter(
          center: Offset(cx, cy + pedestalHeight),
          width: radiusX * 2,
          height: radiusY * 2,
        ),
        math.pi,
        -math.pi,
        false,
      )
      ..lineTo(cx + radiusX, cy)
      ..arcTo(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: radiusX * 2,
          height: radiusY * 2,
        ),
        0,
        math.pi,
        false,
      )
      ..close();

    final Paint cylinderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          const Color(0xFF0C101B),
          const Color(0xFF1E2638),
          const Color(0xFF101624),
        ],
      ).createShader(Rect.fromLTWH(cx - radiusX, cy, radiusX * 2, pedestalHeight));
    canvas.drawPath(cylinderPath, cylinderPaint);

    // Rim border for cylinder
    final Paint cylinderBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.liquidGold.withValues(alpha: 0.35);
    canvas.drawPath(cylinderPath, cylinderBorder);

    // 4. Concentric Runic Rings on Platform Top
    final Rect topRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: radiusX * 2,
      height: radiusY * 2,
    );

    // Top Platform Base Fill
    final Paint topPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF28344D),
          const Color(0xFF141A28),
          const Color(0xFF0A0E17),
        ],
      ).createShader(topRect);
    canvas.drawOval(topRect, topPaint);

    if (showRunicRings) {
      // Outer Runic Disc
      final Paint runicRingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = glowColor.withValues(alpha: 0.65);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: radiusX * 1.7,
          height: radiusY * 1.7,
        ),
        runicRingPaint,
      );

      // Inner Runic Core
      final Paint innerCorePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = rarityColor.withValues(alpha: 0.50);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: radiusX * 1.1,
          height: radiusY * 1.1,
        ),
        innerCorePaint,
      );

      // Runic Tick Marks around the circle
      final Paint tickPaint = Paint()
        ..color = rarityColor.withValues(alpha: 0.70)
        ..strokeWidth = 1.5;
      const int ticks = 12;
      for (int i = 0; i < ticks; i++) {
        final double theta = (i * 2 * math.pi / ticks) + (highlightAngle * 0.4);
        final double rx1 = cx + math.cos(theta) * (radiusX * 0.78);
        final double ry1 = cy + math.sin(theta) * (radiusY * 0.78);
        final double rx2 = cx + math.cos(theta) * (radiusX * 0.85);
        final double ry2 = cy + math.sin(theta) * (radiusY * 0.85);
        canvas.drawLine(Offset(rx1, ry1), Offset(rx2, ry2), tickPaint);
      }
    }

    // 5. Rotating Dynamic Highlight / Specular Light Sweep
    final double sweepX = cx + math.cos(highlightAngle) * (radiusX * 0.90);
    final double sweepY = cy + math.sin(highlightAngle) * (radiusY * 0.90);

    final Paint rotatingHighlight = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.85),
          rarityColor.withValues(alpha: 0.60),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.35, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset(sweepX, sweepY), radius: radiusX * 0.35),
      );
    canvas.drawCircle(Offset(sweepX, sweepY), radiusX * 0.35, rotatingHighlight);

    // 6. Glowing Top Rim Arc
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: <Color>[
          AppColors.liquidGold.withValues(alpha: 0.9),
          glowColor.withValues(alpha: 0.3),
          AppColors.liquidGold.withValues(alpha: 0.9),
        ],
        transform: GradientRotation(highlightAngle),
      ).createShader(topRect);
    canvas.drawOval(topRect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _PedestalPainter oldDelegate) {
    return oldDelegate.highlightAngle != highlightAngle ||
        oldDelegate.pitch != pitch ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.isDragging != isDragging;
  }
}

/// Mobile inspection bottom sheet displaying the 3D pedestal, item stats, and thumb buttons.
class MarketPedestalInspectionSheet extends StatelessWidget {
  const MarketPedestalInspectionSheet({
    super.key,
    required this.itemName,
    required this.rarity,
    required this.price,
    this.itemId,
    this.iconValue = '',
    this.itemType,
    this.stockLabel = '',
    this.onBuy,
    this.canBuy = true,
  });

  final String itemName;
  final String rarity;
  final int price;
  final String? itemId;
  final String iconValue;
  final ItemType? itemType;
  final String stockLabel;
  final VoidCallback? onBuy;
  final bool canBuy;

  static Future<void> show(
    BuildContext context, {
    required String itemName,
    required String rarity,
    required int price,
    String? itemId,
    String iconValue = '',
    ItemType? itemType,
    String stockLabel = '',
    VoidCallback? onBuy,
    bool canBuy = true,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => MarketPedestalInspectionSheet(
        itemName: itemName,
        rarity: rarity,
        price: price,
        itemId: itemId,
        iconValue: iconValue,
        itemType: itemType,
        stockLabel: stockLabel,
        onBuy: onBuy,
        canBuy: canBuy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = marketRarityColor(rarity);

    return MarketSheetShell(
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.mutedTitanium.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),

            // 3D Pedestal Preview with Touch Drag
            Center(
              child: MarketItemPedestal(
                itemName: itemName,
                rarity: rarity,
                iconValue: iconValue,
                itemId: itemId,
                itemType: itemType,
                size: 190,
                interactive: true,
              ),
            ),
            const SizedBox(height: 12),

            // Item Name & Rarity
            Text(
              itemName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rarityColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),

            // Stock / Type details
            if (stockLabel.isNotEmpty)
              Text(
                stockLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedTitanium,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 14),

            // Price Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.carbonVoid.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.liquidGold.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'Pazar Fiyatı',
                    style: TextStyle(
                      color: AppColors.mutedTitanium,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: AppColors.liquidGold,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${formatMarketGold(price)} Altın',
                        style: const TextStyle(
                          color: AppColors.liquidGold,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Thumb-accessible buttons
            Row(
              children: <Widget>[
                Expanded(
                  child: MarketSecondaryButton(
                    label: 'Kapat',
                    accent: AppColors.mutedTitanium,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                  ),
                ),
                if (canBuy && onBuy != null) ...<Widget>[
                  const SizedBox(width: 10),
                  Expanded(
                    child: MarketPrimaryButton(
                      label: 'Satın Al',
                      icon: Icons.shopping_cart_checkout_rounded,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                        onBuy!();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
