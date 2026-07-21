import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_screen_background.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';

abstract final class RestrictionScreenUi {
  static const Color hospitalAccent = AppColors.mysticRuby;
  static const Color prisonAccent = AppColors.coralFlare;
  static const Color healAccent = AppColors.toxicNeon;
  static const Color gemAccent = AppColors.accentPurple;

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFD64A), AppColors.liquidGold, Color(0xFFE08A00)],
    stops: <double>[0.0, 0.5, 1.0],
  );

  static const LinearGradient neonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF5CFFB0), AppColors.toxicNeon, Color(0xFF0A8A42)],
    stops: <double>[0.0, 0.5, 1.0],
  );

  static const LinearGradient gemGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFC084FC), AppColors.accentPurple, Color(0xFF6D28D9)],
    stops: <double>[0.0, 0.5, 1.0],
  );

  static const LinearGradient coralGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF9A62), AppColors.coralFlare, Color(0xFFBF4A16)],
    stops: <double>[0.0, 0.5, 1.0],
  );

  static LinearGradient gradientForAccent(Color accent) {
    if (accent == healAccent) return neonGradient;
    if (accent == gemAccent) return gemGradient;
    if (accent == prisonAccent) return coralGradient;
    if (accent == hospitalAccent) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFFFF6B6B),
          AppColors.mysticRuby,
          const Color(0xFF991B1B),
        ],
        stops: const <double>[0.0, 0.5, 1.0],
      );
    }
    return goldGradient;
  }
}

class RestrictionPressable extends StatefulWidget {
  const RestrictionPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<RestrictionPressable> createState() => _RestrictionPressableState();
}

class _RestrictionPressableState extends State<RestrictionPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class RestrictionScreenScaffold extends StatelessWidget {
  const RestrictionScreenScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GameScreenBackground(
      showAmbientGlow: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: GameScrollLayout.withClearance(
            context,
            const EdgeInsets.fromLTRB(16, 12, 16, 16),
          ),
          child: child,
        ),
      ),
    );
  }
}

class RestrictionNeonPanel extends StatelessWidget {
  const RestrictionNeonPanel({
    super.key,
    required this.accent,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Color accent;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.38), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.spaceNavy.withValues(alpha: 0.96),
            AppColors.carbonVoid.withValues(alpha: 0.98),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(
                painter: DotGridPainter(spacing: 14, dotOpacity: 0.06),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class RestrictionFreeCard extends StatelessWidget {
  const RestrictionFreeCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.message,
    required this.accent,
    this.detail,
  });

  final String emoji;
  final String title;
  final String message;
  final Color accent;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return RestrictionNeonPanel(
      accent: accent,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: RestrictionGoldButton(
              label: 'Ana Sayfaya Dön',
              icon: Icons.home_rounded,
              onPressed: () => context.go(AppRoutes.home),
            ),
          ),
        ],
      ),
    );
  }
}

class RestrictionActivePanel extends StatelessWidget {
  const RestrictionActivePanel({
    super.key,
    required this.accent,
    required this.emoji,
    required this.title,
    required this.reasonLabel,
    required this.reasonValue,
    required this.releaseLabel,
    required this.countdown,
    required this.progress,
    required this.footer,
    this.extraInfo,
    this.actions = const <Widget>[],
  });

  final Color accent;
  final String emoji;
  final String title;
  final String reasonLabel;
  final String reasonValue;
  final String releaseLabel;
  final String countdown;
  final double progress;
  final Widget? extraInfo;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return RestrictionNeonPanel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RestrictionInfoRow(label: reasonLabel, value: reasonValue),
          const SizedBox(height: 6),
          RestrictionInfoRow(label: 'Taburcu:', value: releaseLabel),
          const SizedBox(height: 16),
          Center(
            child: Text(
              countdown,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: accent,
                letterSpacing: 2,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.darkObsidian.withValues(alpha: 0.85),
              color: accent,
            ),
          ),
          if (extraInfo != null) ...<Widget>[
            const SizedBox(height: 14),
            extraInfo!,
          ],
          const SizedBox(height: 18),
          ...actions,
          if (footer != null) ...<Widget>[
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }
}

class RestrictionInfoRow extends StatelessWidget {
  const RestrictionInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedTitanium,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class RestrictionGoldButton extends StatelessWidget {
  const RestrictionGoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return RestrictionCtaButton(
      label: label,
      onPressed: onPressed,
      accent: AppColors.liquidGold,
      gradient: RestrictionScreenUi.goldGradient,
      icon: icon,
      loading: loading,
      textOnAccent: AppColors.carbonVoid,
    );
  }
}

class RestrictionCtaButton extends StatelessWidget {
  const RestrictionCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.accent,
    required this.gradient,
    this.icon,
    this.loading = false,
    this.textOnAccent = AppColors.carbonVoid,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final LinearGradient gradient;
  final IconData? icon;
  final bool loading;
  final Color textOnAccent;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    return RestrictionPressable(
      onTap: enabled ? onPressed : null,
      enabled: enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: enabled ? gradient : null,
          color: enabled ? null : AppColors.darkObsidian.withValues(alpha: 0.82),
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: enabled ? textOnAccent : AppColors.mutedTitanium,
                  ),
                )
              else if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: enabled ? textOnAccent : AppColors.mutedTitanium,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    height: 1.2,
                    color: enabled ? textOnAccent : AppColors.mutedTitanium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RestrictionFilledButton extends StatelessWidget {
  const RestrictionFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.color,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: RestrictionCtaButton(
        label: label,
        onPressed: loading ? null : onPressed,
        accent: color,
        gradient: RestrictionScreenUi.gradientForAccent(color),
        icon: icon,
        loading: loading,
      ),
    );
  }
}

class RestrictionOutlineButton extends StatelessWidget {
  const RestrictionOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.borderColor,
    this.loading = false,
    this.foregroundColor,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color borderColor;
  final bool loading;
  final Color? foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    final Color accent = foregroundColor ?? borderColor;
    return SizedBox(
      width: double.infinity,
      child: RestrictionPressable(
        onTap: enabled ? onPressed : null,
        enabled: enabled,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: enabled ? 0.48 : 0.22),
              width: 1.4,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.spaceNavy.withValues(alpha: 0.92),
                AppColors.carbonVoid.withValues(alpha: 0.96),
              ],
            ),
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                else if (icon != null) ...<Widget>[
                  Icon(icon, size: 17, color: accent),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      height: 1.2,
                      color: enabled ? accent : AppColors.mutedTitanium,
                    ),
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

class RestrictionSectionDivider extends StatelessWidget {
  const RestrictionSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(color: AppColors.borderDefault, height: 1),
    );
  }
}

class RestrictionLoadingCard extends StatelessWidget {
  const RestrictionLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const RestrictionNeonPanel(
      accent: AppColors.liquidGold,
      child: Center(
        child: SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

class RestrictionShopLink extends StatelessWidget {
  const RestrictionShopLink({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return RestrictionPressable(
      onTap: () => context.go(AppRoutes.shop),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: AppColors.liquidGold.withValues(alpha: 0.1),
          border: Border.all(
            color: AppColors.liquidGold.withValues(alpha: 0.38),
          ),
        ),
        child: Text(
          message.toUpperCase(),
          style: const TextStyle(
            color: AppColors.liquidGold,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
