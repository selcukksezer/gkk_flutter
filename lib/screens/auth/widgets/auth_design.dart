import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

/// Auth screens — /tasarim: Carbon Void, dot doku, Liquid Gold, Cyber Fuchsia.
abstract final class AuthDesign {
  static const Color void_ = AppColors.carbonVoid;
  static const Color navy = AppColors.spaceNavy;
  static const Color obsidian = AppColors.darkObsidian;
  static const Color titanium = AppColors.mutedTitanium;
  static const Color gold = AppColors.liquidGold;
  static const Color fuchsia = AppColors.cyberFuchsia;
  static const Color textHi = AppColors.textPrimary;
  static const Color textMid = Color(0xFFA9B7D0);
  static const Color textLow = Color(0xFF5C6B86);

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFD64A), AppColors.liquidGold, Color(0xFFE08A00)],
    stops: <double>[0.0, 0.52, 1.0],
  );

  static const LinearGradient fuchsiaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF4D8D), AppColors.cyberFuchsia, Color(0xFF9B1440)],
    stops: <double>[0.0, 0.5, 1.0],
  );

  static TextStyle heroTitle({Color color = textHi}) => GoogleFonts.urbanist(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        height: 1.1,
        color: color,
      );

  static TextStyle sectionCaps({Color color = titanium}) => GoogleFonts.urbanist(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: color,
      );

  static TextStyle bodyMuted({Color color = textMid}) => GoogleFonts.urbanist(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: color,
      );
}

class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({
    super.key,
    required this.child,
    this.accent = AuthDesign.gold,
    this.secondaryAccent = AuthDesign.fuchsia,
  });

  final Widget child;
  final Color accent;
  final Color secondaryAccent;

  @override
  Widget build(BuildContext context) {
    return GameScreenBackground(
      showAmbientGlow: false,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -100,
            right: -70,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      accent.withValues(alpha: 0.20),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: IgnorePointer(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      secondaryAccent.withValues(alpha: 0.14),
                      secondaryAccent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.35,
            left: MediaQuery.sizeOf(context).width * 0.5 - 1,
            child: IgnorePointer(
              child: Container(
                width: 2,
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      accent.withValues(alpha: 0),
                      accent.withValues(alpha: 0.35),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class AuthPressable extends StatefulWidget {
  const AuthPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<AuthPressable> createState() => _AuthPressableState();
}

class _AuthPressableState extends State<AuthPressable> {
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
        scale: _pressed ? 0.965 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class AuthGlassPanel extends StatelessWidget {
  const AuthGlassPanel({
    super.key,
    required this.child,
    this.accent = AuthDesign.gold,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.28), width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AuthDesign.navy.withValues(alpha: 0.88),
                AuthDesign.void_.withValues(alpha: 0.94),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 28,
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(
                  painter: DotGridPainter(spacing: 14, dotOpacity: 0.06),
                ),
              ),
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          accent.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthBadge extends StatelessWidget {
  const AuthBadge({
    super.key,
    required this.label,
    this.accent = AuthDesign.gold,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 10),
        ],
      ),
      child: Text(
        label.toUpperCase(),
        style: AuthDesign.sectionCaps(color: accent),
      ),
    );
  }
}

class AuthHeroHeader extends StatelessWidget {
  const AuthHeroHeader({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.sectionLabel,
    this.accent = AuthDesign.gold,
    this.icon = Icons.castle_rounded,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String sectionLabel;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    accent.withValues(alpha: 0.28),
                    AuthDesign.obsidian.withValues(alpha: 0.95),
                  ],
                ),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 16),
                ],
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(width: AppSpacing.base),
            AuthBadge(label: badge, accent: accent),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        Text(title.toUpperCase(), style: AuthDesign.heroTitle()),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle, style: AuthDesign.bodyMuted()),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[accent, accent.withValues(alpha: 0.2)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(sectionLabel.toUpperCase(), style: AuthDesign.sectionCaps(color: AuthDesign.textMid)),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
      ],
    );
  }
}

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autocorrect = false,
    this.enableSuggestions = true,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.suffix,
    this.accent = AuthDesign.gold,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final bool enableSuggestions;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffix;
  final Color accent;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor = _focus.hasFocus
        ? widget.accent.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            widget.label.toUpperCase(),
            style: AuthDesign.sectionCaps(color: AuthDesign.textLow),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: _focus.hasFocus ? 1.4 : 1),
            color: AuthDesign.obsidian.withValues(alpha: 0.72),
            boxShadow: _focus.hasFocus
                ? <BoxShadow>[
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.18),
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: <Widget>[
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: widget.accent.withValues(alpha: 0.12),
                  border: Border.all(color: widget.accent.withValues(alpha: 0.22)),
                ),
                child: Icon(widget.icon, size: 18, color: widget.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  autofillHints: widget.autofillHints,
                  autocorrect: widget.autocorrect,
                  enableSuggestions: widget.enableSuggestions,
                  validator: widget.validator,
                  onChanged: widget.onChanged,
                  onFieldSubmitted: widget.onFieldSubmitted,
                  style: GoogleFonts.urbanist(
                    color: AuthDesign.textHi,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: widget.accent,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                    isDense: true,
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
              const SizedBox(width: 6),
            ],
          ),
        ),
      ],
    );
  }
}

class AuthGoldButton extends StatelessWidget {
  const AuthGoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon = Icons.login_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;

    return AuthPressable(
      enabled: enabled,
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.55,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: enabled ? AuthDesign.goldGradient : null,
            color: enabled ? null : AuthDesign.obsidian,
            border: enabled ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: AuthDesign.gold.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AuthDesign.void_.withValues(alpha: 0.9),
                  ),
                )
              else
                Icon(icon, color: AuthDesign.void_, size: 20),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.urbanist(
                  color: AuthDesign.void_,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthGhostLink extends StatelessWidget {
  const AuthGhostLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.accent = AuthDesign.fuchsia,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AuthPressable(
      enabled: enabled,
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          color: accent.withValues(alpha: 0.06),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(
            color: accent.withValues(alpha: enabled ? 1 : 0.45),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: accent.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class AuthFadeSlide extends StatefulWidget {
  const AuthFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<AuthFadeSlide> createState() => _AuthFadeSlideState();
}

class _AuthFadeSlideState extends State<AuthFadeSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
