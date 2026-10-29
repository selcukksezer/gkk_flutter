import 'package:flutter/material.dart';
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
