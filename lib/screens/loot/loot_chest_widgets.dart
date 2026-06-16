import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/item_icon_view.dart';
import 'loot_chest_theme.dart';

class LootChestGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    const double cell = 20;
    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LootBannerLayout {
  const _LootBannerLayout({
    required this.bannerWidth,
    required this.textScale,
    this.heightOverride,
  });

  final double bannerWidth;
  final double textScale;
  final double? heightOverride;

  bool get tight => bannerWidth < 360;
  bool get compact => bannerWidth < 390;

  double get horizontalInset => tight ? 14 : 18;
  double get verticalInset => tight ? 12 : (compact ? 16 : 20);
  double get contentRight => tight ? 120 : (compact ? 138 : 168);
  double get imageWidth => tight ? 200 : (compact ? 220 : 260);
  double get imageRight => tight ? -24 : (compact ? -28 : -42);
  double get imageTopBottom => tight ? -28 : (compact ? -32 : -44);
  double get titleSize => tight ? 18 : (compact ? 20 : 24);
  double get subtitleSize => tight ? 10 : (compact ? 11 : 12);
  double get priceInset => tight ? 12 : (compact ? 14 : 16);

  double get bannerHeight {
    if (heightOverride != null) return heightOverride!;
    final double scaleBoost = (textScale.clamp(1.0, 1.4) - 1.0) * 36;
    if (tight) return 224 + scaleBoost;
    if (compact) return 220 + scaleBoost;
    return 232 + scaleBoost;
  }
}

class LootChestBanner extends StatelessWidget {
  const LootChestBanner({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.priceIcon,
    required this.priceColor,
    required this.footer,
    this.height,
  });

  final LootChestTheme theme;
  final String title;
  final String subtitle;
  final String priceLabel;
  final IconData priceIcon;
  final Color priceColor;
  final Widget footer;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _LootBannerLayout layout = _LootBannerLayout(
          bannerWidth: constraints.maxWidth,
          textScale: textScale,
          heightOverride: height,
        );

        return SizedBox(
          width: double.infinity,
          height: layout.bannerHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: RadialGradient(
                      center: const Alignment(0.6, 0.0),
                      radius: 1.5,
                      colors: <Color>[theme.radialCenter, theme.radialEdge],
                    ),
                    border: Border.all(color: theme.borderColor, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(painter: LootChestGridPainter()),
                  ),
                ),
              ),
              Positioned(
                right: layout.imageRight,
                top: layout.imageTopBottom,
                bottom: layout.imageTopBottom,
                width: layout.imageWidth,
                child: Image.asset(
                  theme.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
              Positioned(
                left: layout.horizontalInset,
                top: layout.verticalInset,
                bottom: layout.verticalInset,
                right: layout.contentRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: GoogleFonts.urbanist(
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: layout.titleSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: layout.tight ? 2 : 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          subtitle,
                          maxLines: layout.tight ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.urbanist(
                            textStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: layout.subtitleSize,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: layout.tight ? 6 : 8),
                    footer,
                  ],
                ),
              ),
              Positioned(
                top: layout.priceInset,
                right: layout.priceInset,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.tight ? 8 : 10,
                    vertical: layout.tight ? 5 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: priceColor.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(priceIcon, size: layout.tight ? 12 : 14, color: priceColor),
                      const SizedBox(width: 4),
                      Text(
                        priceLabel,
                        style: TextStyle(
                          color: priceColor,
                          fontWeight: FontWeight.w800,
                          fontSize: layout.tight ? 11 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LootDropPreviewDialog extends StatelessWidget {
  const LootDropPreviewDialog({super.key, required this.drop});

  final LootDropPreviewData drop;

  static Future<void> show(BuildContext context, LootDropPreviewData drop) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 338),
            child: LootDropPreviewDialog(drop: drop),
          ),
        );
      },
    );
  }

  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _actionYellow = Color(0xFFF2D74C);
  static const Color _textPrimary = Color(0xFF111111);
  static const Color _textMuted = Color(0xFF999999);
  static const Color _textBody = Color(0xFF888888);
  static const Color _borderLight = Color(0xFFD4D4D4);

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: isPrimary ? _actionYellow : _cardBg,
            border: isPrimary ? null : Border.all(color: _borderLight, width: 1),
            boxShadow: isPrimary
                ? <BoxShadow>[
                    BoxShadow(
                      color: _actionYellow.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemIconWithShadow() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            bottom: 18,
            child: Container(
              width: 72,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ItemIconView(
              iconValue: drop.icon,
              itemId: drop.itemId,
              size: 88,
              expand: true,
              fallback: '◻',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<(String, String)> stats) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: stats.map((stat) {
        return Text(
          '${stat.$1}: ${stat.$2}',
          style: const TextStyle(
            color: _textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = drop.rarityColor;
    final List<(String, String)> stats = <(String, String)>[
      ('DROP ORANI', '%${drop.dropRate.toStringAsFixed(2)}'),
      ('MIKTAR', 'x${drop.minQuantity}-${drop.maxQuantity}'),
      ('NADIRLIK', drop.rarity.toUpperCase()),
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 40,
              offset: const Offset(0, 16),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildItemIconWithShadow(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Builder(
                          builder: (BuildContext context) {
                            return _buildActionButton(
                              label: 'DROP ÖNİZLEME',
                              onPressed: () => Navigator.of(context).pop(),
                              isPrimary: true,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          label: 'KAPAT',
                          onPressed: () => Navigator.of(context).pop(),
                          isPrimary: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: rarityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'EŞYA ADI',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                drop.itemName.toUpperCase(),
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${drop.rarity.toUpperCase()} · ${lootDropCategoryLabel(drop.itemId)}',
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bu eşya kasa açılışında drop havuzundan çıkabilir.',
                style: TextStyle(
                  color: _textBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 14),
              _buildStatsRow(stats),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Text(
                    'x${drop.minQuantity}-${drop.maxQuantity}',
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '%${drop.dropRate.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LootDropPreviewData {
  const LootDropPreviewData({
    required this.itemId,
    required this.itemName,
    required this.icon,
    required this.rarity,
    required this.dropRate,
    required this.minQuantity,
    required this.maxQuantity,
    required this.rarityColor,
  });

  final String itemId;
  final String itemName;
  final String icon;
  final String rarity;
  final double dropRate;
  final int minQuantity;
  final int maxQuantity;
  final Color rarityColor;
}
