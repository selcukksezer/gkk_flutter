import 'package:flutter/material.dart';

class AionLuxuryButton extends StatefulWidget {
  const AionLuxuryButton({
    super.key,
    required this.label,
    required this.subtitle,
    required this.onPressed,
    this.primaryColor = const Color(0xFFFFB300),
    this.secondaryColor = const Color(0xFFFF6D00),
    this.isLoading = false,
    this.disableAnimations = false,
  });

  final String label;
  final String subtitle;
  final VoidCallback? onPressed;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isLoading;
  final bool disableAnimations;

  @override
  State<AionLuxuryButton> createState() => _AionLuxuryButtonState();
}

class _AionLuxuryButtonState extends State<AionLuxuryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    if (!widget.disableAnimations) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AionLuxuryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disableAnimations != oldWidget.disableAnimations) {
      if (widget.disableAnimations) {
        _shimmerController.stop();
      } else {
        _shimmerController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: isEnabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: isEnabled ? 1.0 : 0.55,
          duration: const Duration(milliseconds: 180),
          child: Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  widget.primaryColor,
                  widget.secondaryColor,
                  const Color(0xFF16120E),
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 1.4,
              ),
              boxShadow: isEnabled
                  ? <BoxShadow>[
                      BoxShadow(
                        color: widget.primaryColor.withValues(alpha: 0.45),
                        blurRadius: 22,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                      const BoxShadow(
                        color: Color(0x99000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: <Widget>[
                  // Shimmer highlight sweep
                  if (!widget.disableAnimations && isEnabled)
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (BuildContext context, Widget? child) {
                        final double dx = -1.0 + 2.4 * _shimmerController.value;
                        return Positioned.fill(
                          child: FractionalTranslation(
                            translation: Offset(dx, 0),
                            child: Transform.rotate(
                              angle: 0.35,
                              child: Container(
                                width: 45,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: <Color>[
                                      Colors.white.withValues(alpha: 0.0),
                                      Colors.white.withValues(alpha: 0.32),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Button content
                  Center(
                    child: widget.isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const <Widget>[
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Aion Realm Bağlanıyor...',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.black87,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.label.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.black87,
                                    size: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle,
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Runic corner accents
                  Positioned(
                    top: 4,
                    left: 6,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 6,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
