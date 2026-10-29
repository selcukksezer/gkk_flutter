# Fix aion_rune_frame.dart
with open('lib/screens/auth/widgets/aion_rune_frame.dart', 'w', encoding='utf-8') as f:
    f.write('''import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';

/// Luxury Aion-2 Runic Glassmorphism Card with animated glowing borders
/// and precision vector-drawn fantasy corner brackets.
class AionRuneCard extends StatefulWidget {
  const AionRuneCard({
    super.key,
    required this.child,
    this.accentColor = const Color(0xFFD4AF37), // Aion Celestial Gold
    this.glowColor = const Color(0xFF38BDF8), // Arcane Cyan
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = 22.0,
  });

  final Widget child;
  final Color accentColor;
  final Color glowColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  State<AionRuneCard> createState() => _AionRuneCardState();
}

class _AionRuneCardState extends State<AionRuneCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (BuildContext context, Widget? _) {
        final double pulse = _pulseAnimation.value;
        return CustomPaint(
          foregroundPainter: _AionRuneBorderPainter(
            pulse: pulse,
            accentColor: widget.accentColor,
            glowColor: widget.glowColor,
            radius: widget.borderRadius,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xEE090E1D), // Obsidian Astral Navy
                      Color(0xF804060D), // Deep Celestial Void
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: 0.08 + pulse * 0.10),
                      blurRadius: 32,
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Stack(
                  children: <Widget>[
                    // Top specular highlight sheen
                    Positioned(
                      top: 0,
                      left: 20,
                      right: 20,
                      child: IgnorePointer(
                        child: Container(
                          height: 1.2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Colors.transparent,
                                widget.accentColor.withValues(alpha: 0.35 + pulse * 0.35),
                                widget.glowColor.withValues(alpha: 0.25 + pulse * 0.25),
                                Colors.transparent,
                              ],
                              stops: const <double>[0.0, 0.45, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Card contents
                    Padding(
                      padding: widget.padding,
                      child: widget.child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AionRuneBorderPainter extends CustomPainter {
  _AionRuneBorderPainter({
    required this.pulse,
    required this.accentColor,
    required this.glowColor,
    required this.radius,
  });

  final double pulse;
  final Color accentColor;
  final Color glowColor;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 1. Soft breathing ambient border glow
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..color = glowColor.withValues(alpha: 0.15 + pulse * 0.20);
    canvas.drawRRect(rrect, glowPaint);

    // 2. Crisp perimeter frame with gold-to-cyan gradient
    final Paint framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accentColor.withValues(alpha: 0.55 + pulse * 0.35),
          glowColor.withValues(alpha: 0.25 + pulse * 0.20),
          accentColor.withValues(alpha: 0.30 + pulse * 0.30),
        ],
        stops: const <double>[0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, framePaint);

    // 3. Ornate Aion-2 fantasy corner brackets & runic chevrons
    final Paint runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = accentColor.withValues(alpha: 0.75 + pulse * 0.25);

    const double cornerArm = 24.0;
    const double inset = 6.0;

    // Top-Left corner bracket
    canvas.drawLine(
      const Offset(inset, inset + cornerArm),
      const Offset(inset, inset + 8),
      runePaint,
    );
    canvas.drawLine(
      const Offset(inset + 8, inset),
      const Offset(inset + cornerArm, inset),
      runePaint,
    );
    _drawRuneDiamond(canvas, const Offset(inset + 4, inset + 4), 3.0, runePaint);

    // Top-Right corner bracket
    canvas.drawLine(
      Offset(size.width - inset, inset + cornerArm),
      Offset(size.width - inset, inset + 8),
      runePaint,
    );
    canvas.drawLine(
      Offset(size.width - inset - 8, inset),
      Offset(size.width - inset - cornerArm, inset),
      runePaint,
    );
    _drawRuneDiamond(canvas, Offset(size.width - inset - 4, inset + 4), 3.0, runePaint);

    // Bottom-Left corner bracket
    canvas.drawLine(
      Offset(inset, size.height - inset - cornerArm),
      Offset(inset, size.height - inset - 8),
      runePaint,
    );
    canvas.drawLine(
      Offset(inset + 8, size.height - inset),
      Offset(inset + cornerArm, size.height - inset),
      runePaint,
    );
    _drawRuneDiamond(canvas, Offset(inset + 4, size.height - inset - 4), 3.0, runePaint);

    // Bottom-Right corner bracket
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - cornerArm),
      Offset(size.width - inset, size.height - inset - 8),
      runePaint,
    );
    canvas.drawLine(
      Offset(size.width - inset - 8, size.height - inset),
      Offset(size.width - inset - cornerArm, size.height - inset),
      runePaint,
    );
    _drawRuneDiamond(canvas, Offset(size.width - inset - 4, size.height - inset - 4), 3.0, runePaint);

    // Center runic diamond seals along the borders
    _drawRuneDiamond(canvas, Offset(size.width * 0.5, 0), 3.5, runePaint);
    _drawRuneDiamond(canvas, Offset(size.width * 0.5, size.height), 3.5, runePaint);
  }

  void _drawRuneDiamond(Canvas canvas, Offset center, double size, Paint paint) {
    final Path path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AionRuneBorderPainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.glowColor != glowColor;
  }
}
''')

# Fix aion_guest_dialog.dart
with open('lib/screens/auth/widgets/aion_guest_dialog.dart', 'w', encoding='utf-8') as f:
    f.write('''import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_spacing.dart';
import 'aion_rune_frame.dart';
import 'auth_design.dart';

/// Aion-2 Mobile Guest Login CTA Button with glowing crystal runes.
class AionGuestLoginCta extends StatelessWidget {
  const AionGuestLoginCta({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AuthPressable(
      enabled: !loading && onPressed != null,
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0x3338BDF8), // Cyan crystal shimmer
              Color(0x1A0F172A), // Slate core
            ],
          ),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF38BDF8),
                ),
              )
            else
              const Icon(
                Icons.flash_on_rounded,
                color: Color(0xFF67E8F9),
                size: 18,
              ),
            const SizedBox(width: 8),
            Text(
              'MİSAFİR OLARAK HIZLI BAŞLA',
              style: GoogleFonts.urbanist(
                color: const Color(0xFFE2E8F0),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aion-2 Mobile Guest Confirmation Sheet/Modal.
Future<bool?> showAionGuestDialog(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.xl,
        ),
        child: AionRuneCard(
          accentColor: const Color(0xFF38BDF8),
          glowColor: const Color(0xFF67E8F9),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF38BDF8),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'MİSAFİR HÜKÜMRANLIK GİRİŞİ',
                          style: GoogleFonts.urbanist(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kayıt olmadan Aion 2 dünyasını keşfedin',
                          style: GoogleFonts.urbanist(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: const <Widget>[
                    _InfoRow(
                      icon: Icons.flash_on_rounded,
                      text: 'Tek dokunuşla hemen sunucuya bağlanın.',
                    ),
                    SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.phonelink_setup_rounded,
                      text: 'İlerlemeniz bu cihaza özel olarak saklanır.',
                    ),
                    SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.lock_outline_rounded,
                      text: 'Dilediğiniz an e-posta bağlayıp kalıcı yapabilirsiniz.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'İPTAL',
                        style: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                        shadowColor: const Color(0xFF0284C7).withValues(alpha: 0.5),
                      ),
                      child: Text(
                        'BAĞLAN',
                        style: GoogleFonts.urbanist(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: const Color(0xFF38BDF8), size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.urbanist(
              color: const Color(0xFFCBD5E1),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
''')

# Fix login_screen.dart
with open('lib/screens/auth/login_screen.dart', 'r', encoding='utf-8') as f:
    login_lines = f.readlines()

new_lines = []
for line in login_lines:
    if line.strip() == "import 'package:flutter/services.dart';":
        continue
    if "AppRoutes.emailConfirm" in line:
        line = "          '${AppRoutes.emailConfirm}?email=' + Uri.encodeComponent(email),\n"
    if "guestPass = 'Guest#" in line:
        line = "      final String guestPass = 'Guest#' + shortId.toUpperCase() + '2027!';\n"
    new_lines.append(line)

with open('lib/screens/auth/login_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print('All 3 files updated successfully')
