import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

import '../../../theme/app_colors.dart';
import 'facility_detail_design.dart';

/// Tier bölümü — kare grid kabuk, tesisler arası net boşluk.
class FacTierSection extends StatelessWidget {
  const FacTierSection({
    super.key,
    required this.tier,
    required this.title,
    required this.trailing,
    required this.accentColor,
    required this.children,
  });

  final int tier;
  final String title;
  final String trailing;
  final Color accentColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (tier > 1) ...<Widget>[
            _FacTierDivider(accentColor: accentColor),
            const SizedBox(height: 12),
          ],
          FacGridBanner(
            borderColor: accentColor.withValues(alpha: 0.32),
            gradientColors: <Color>[
              AppColors.carbonVoid,
              AppColors.spaceNavy.withValues(alpha: 0.88),
              AppColors.carbonVoid,
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 3,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            accentColor,
                            accentColor.withValues(alpha: 0.25),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Text(
                      trailing,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FacTierDivider extends StatelessWidget {
  const _FacTierDivider({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.transparent,
                  accentColor.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 2 sütunlu satır — grid aspect-ratio taşmasını önler.
class FacFacilityCardRow extends StatelessWidget {
  const FacFacilityCardRow({super.key, required this.left, this.right});

  final Widget left;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// Tek tesis kartı — sabit yükseklik, motor spring giriş + basış.
class FacHubFacilityCard extends StatefulWidget {
  const FacHubFacilityCard({
    super.key,
    required this.animationIndex,
    required this.icon,
    required this.name,
    required this.isUnlocked,
    required this.footer,
    required this.accentColor,
    required this.onTap,
  });

  final int animationIndex;
  final String icon;
  final String name;
  final bool isUnlocked;
  final String footer;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<FacHubFacilityCard> createState() => _FacHubFacilityCardState();
}

class _FacHubFacilityCardState extends State<FacHubFacilityCard> {
  bool _visible = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    final int delayMs = 35 * widget.animationIndex;
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor = widget.isUnlocked
        ? widget.accentColor.withValues(alpha: 0.5)
        : AppColors.mutedTitanium.withValues(alpha: 0.22);

    return SingleMotionBuilder(
      value: _visible ? 1.0 : 0.0,
      motion: const Motion.smoothSpring(duration: Duration(milliseconds: 480)),
      builder: (BuildContext context, double enter, Widget? child) {
        return Opacity(
          opacity: enter.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - enter) * 14),
            child: child,
          ),
        );
      },
      child: SingleMotionBuilder(
        value: _pressed ? 0.97 : 1.0,
        motion: const Motion.snappySpring(
          duration: Duration(milliseconds: 220),
        ),
        builder: (BuildContext context, double scale, Widget? child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              height: 108,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: widget.isUnlocked ? 1.2 : 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    widget.isUnlocked
                        ? AppColors.spaceNavy.withValues(alpha: 0.95)
                        : AppColors.darkObsidian.withValues(alpha: 0.85),
                    AppColors.carbonVoid,
                  ],
                ),
                boxShadow: widget.isUnlocked
                    ? <BoxShadow>[
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  children: <Widget>[
                    if (widget.isUnlocked)
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                widget.accentColor.withValues(alpha: 0.18),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              widget.icon,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const Spacer(),
                            _FacStatusPill(
                              label: widget.isUnlocked ? 'Aktif' : 'Kilit',
                              color: widget.isUnlocked
                                  ? AppColors.toxicNeon
                                  : AppColors.mutedTitanium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.15,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.footer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedTitanium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FacStatusPill extends StatelessWidget {
  const _FacStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

Color facTierAccent(int tier) {
  switch (tier) {
    case 1:
      return AppColors.liquidGold;
    case 2:
      return AppColors.toxicNeon;
    case 3:
      return AppColors.cyberFuchsia;
    default:
      return AppColors.mutedTitanium;
  }
}

List<Widget> facBuildFacilityCardRows({
  required List<Widget Function(int index)> cardBuilder,
}) {
  final List<Widget> rows = <Widget>[];
  for (int i = 0; i < cardBuilder.length; i += 2) {
    rows.add(
      FacFacilityCardRow(
        left: cardBuilder[i](i),
        right: i + 1 < cardBuilder.length ? cardBuilder[i + 1](i + 1) : null,
      ),
    );
  }
  return rows;
}
