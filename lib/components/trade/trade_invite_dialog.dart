import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../providers/trade_invite_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../common/app_messenger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 2027 Aion 2 Obsidian-Glass Design Language Tokens
// ─────────────────────────────────────────────────────────────────────────────
const Color _kObsidianVoid = Color(0xFF07090E);
const Color _kObsidianAbyss = Color(0xFF0F141F);
const Color _kArcaneAmethyst = Color(0xFF9D4EDD);
const Color _kCelestialGold = Color(0xFFE5C158);
const Color _kCelestialGoldLight = Color(0xFFFFF2B2);
const Color _kAmethystGlow = Color(0x339D4EDD);

/// 2027 Aion 2 Mobile — Ornate Obsidian-Glass Arcane Trade Contract Invite Dialog.
///
/// Supreme dark-fantasy visual identity featuring:
/// - Bilateral trade contract modal with frosted obsidian glass (0xFF07090E - 0xFF0F141F).
/// - Multi-layered frosted blur (BackdropFilter sigma 16.0).
/// - Arcane Amethyst (#9D4EDD) & Celestial Gold (#E5C158) luminescent seal & 4-corner filigree.
/// - Two-way participant cards (Initiator <---> You) with bilateral exchange nexus conduit.
/// - Full SafeArea & MediaQuery insets adaptive viewport protection against notch/overflow.
/// - Tactile HapticFeedback (mediumImpact) on accept / decline micro-interactions.
/// - Fully preserved contract callbacks, error handling, and routing.
Future<bool> showTradeInviteDialog(
  BuildContext context, {
  required TradeInvite invite,
  required Future<Map<String, dynamic>> Function(bool accept, bool block) onRespond,
}) async {
  bool blockSender = false;
  bool responded = false;
  _TradeActionState actionState = _TradeActionState.idle;

  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: _kObsidianVoid.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (BuildContext ctx, Animation<double> a1, Animation<double> a2) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> _, Widget child) {
      final double t = Curves.easeOutBack.transform(anim.value.clamp(0.0, 1.0));
      final Size screenSize = MediaQuery.sizeOf(ctx);
      final double maxHeight = math.min(680.0, screenSize.height * 0.92);

      return PopScope(
        canPop: false,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 16.0 * anim.value,
            sigmaY: 16.0 * anim.value,
          ),
          child: Opacity(
            opacity: anim.value,
            child: Transform.scale(
              scale: 0.88 + (0.12 * t),
              child: SafeArea(
                minimum: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 410,
                        maxHeight: maxHeight,
                      ),
                      child: StatefulBuilder(
                        builder: (BuildContext context, StateSetter setLocal) {
                          final bool isBusy = actionState != _TradeActionState.idle;

                          return _ObsidianTradeContractCard(
                            invite: invite,
                            blockSender: blockSender,
                            actionState: actionState,
                            onToggleBlock: () {
                              HapticFeedback.selectionClick();
                              setLocal(() => blockSender = !blockSender);
                            },
                            onDecline: isBusy
                                ? null
                                : () async {
                                    HapticFeedback.mediumImpact();
                                    setLocal(() => actionState = _TradeActionState.declining);
                                    responded = true;
                                    final Map<String, dynamic> res =
                                        await onRespond(false, blockSender);
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                      if (res['success'] != true) {
                                        AppMessenger.showError(
                                          context,
                                          (res['error'] as String?) ?? 'Reddedilemedi',
                                        );
                                      }
                                    }
                                  },
                            onAccept: isBusy
                                ? null
                                : () async {
                                    HapticFeedback.mediumImpact();
                                    setLocal(() => actionState = _TradeActionState.accepting);
                                    responded = true;
                                    final Map<String, dynamic> res =
                                        await onRespond(true, false);
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                    if (res['success'] == true) {
                                      context.push(AppRoutes.trade);
                                      AppMessenger.showSuccess(
                                        context,
                                        'Ticaret sözleşmesi aktifleştirildi',
                                      );
                                    } else {
                                      AppMessenger.showError(
                                        context,
                                        (res['error'] as String?) ?? 'Kabul edilemedi',
                                      );
                                    }
                                  },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  return responded;
}

enum _TradeActionState { idle, accepting, declining }

// ─────────────────────────────────────────────────────────────────────────────
// Modal Card: Frosted Obsidian Glass Frame & Atmospheric Backdrop
// ─────────────────────────────────────────────────────────────────────────────
class _ObsidianTradeContractCard extends StatelessWidget {
  const _ObsidianTradeContractCard({
    required this.invite,
    required this.blockSender,
    required this.actionState,
    required this.onToggleBlock,
    required this.onDecline,
    required this.onAccept,
  });

  final TradeInvite invite;
  final bool blockSender;
  final _TradeActionState actionState;
  final VoidCallback onToggleBlock;
  final VoidCallback? onDecline;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _ObsidianFiligreeBorderPainter(
        goldColor: _kCelestialGold,
        amethystColor: _kArcaneAmethyst,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xF507090E),
                  Color(0xFC0B0E17),
                  Color(0xF50F141F),
                ],
                stops: <double>[0.0, 0.52, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _kArcaneAmethyst.withValues(alpha: 0.22),
                  blurRadius: 32,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: _kCelestialGold.withValues(alpha: 0.16),
                  blurRadius: 18,
                  spreadRadius: -2,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                // Atmospheric arcane nebula background glow
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ArcaneNebulaGlowPainter(),
                  ),
                ),

                // Scrollable main content
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // 1. Arcane Contract Seal Header with 8-Point Celestial Ring
                      const Center(
                        child: _ArcaneContractSealHeader(),
                      ),
                      const SizedBox(height: 14),

                      // 2. Ornate Header Typography
                      Center(
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              colors: <Color>[
                                _kCelestialGold,
                                _kCelestialGoldLight,
                                _kCelestialGold,
                              ],
                            ).createShader(bounds);
                          },
                          child: const Text(
                            '⚔️ TİCARET SÖZLEŞMESİ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                              shadows: <Shadow>[
                                Shadow(
                                  color: Color(0x99E5C158),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 18,
                              height: 1,
                              color: _kArcaneAmethyst.withValues(alpha: 0.6),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'Bilateral Arcane Exchange Pact',
                                style: TextStyle(
                                  color: _kArcaneAmethyst,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              width: 18,
                              height: 1,
                              color: _kArcaneAmethyst.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 3. Bilateral Two-Way Participant Cards (Initiator <---> You)
                      _TwoWayParticipantCards(
                        initiatorName: invite.initiatorName,
                        sessionId: invite.sessionId,
                      ),
                      const SizedBox(height: 14),

                      // 4. Secure Escrow Protocol Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _kObsidianAbyss.withValues(alpha: 0.8),
                          border: Border.all(
                            color: _kArcaneAmethyst.withValues(alpha: 0.28),
                            width: 0.9,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: _kObsidianVoid.withValues(alpha: 0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _kCelestialGold.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: _kCelestialGold.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                size: 15,
                                color: _kCelestialGold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Aion Güvenli Takas: İki aşamalı kilit ve onaylama protokolü ile koruma altındadır.',
                                style: TextStyle(
                                  color: AppColors.mutedTitanium,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 5. Dual Action Buttons (Decline vs Accept)
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _ContractDeclineButton(
                              label: context.l10n.reddet,
                              onPressed: onDecline,
                              isLoading: actionState == _TradeActionState.declining,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ContractAcceptButton(
                              label: context.l10n.kabul_et,
                              onPressed: onAccept,
                              isLoading: actionState == _TradeActionState.accepting,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 6. Block Sender Option
                      InkWell(
                        onTap: actionState != _TradeActionState.idle ? null : onToggleBlock,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: blockSender
                                ? AppColors.mysticRuby.withValues(alpha: 0.14)
                                : Colors.transparent,
                            border: Border.all(
                              color: blockSender
                                  ? AppColors.mysticRuby.withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.04),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: blockSender,
                                  onChanged: actionState != _TradeActionState.idle
                                      ? null
                                      : (_) => onToggleBlock(),
                                  activeColor: AppColors.mysticRuby,
                                  checkColor: Colors.white,
                                  side: BorderSide(
                                    color: blockSender
                                        ? AppColors.mysticRuby
                                        : AppColors.mutedTitanium.withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Bu kişiden gelen ticaret isteklerini 4 saat engelle',
                                  style: TextStyle(
                                    color: AppColors.mutedTitanium,
                                    fontSize: 11.5,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Arcane Contract Seal Header with 8-Point Celestial Star Dial
// ─────────────────────────────────────────────────────────────────────────────
class _ArcaneContractSealHeader extends StatelessWidget {
  const _ArcaneContractSealHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // 8-point radial celestial star dial
          Positioned.fill(
            child: CustomPaint(
              painter: _CelestialSealDialPainter(),
            ),
          ),

          // Core illuminated orb
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  _kArcaneAmethyst.withValues(alpha: 0.4),
                  _kCelestialGold.withValues(alpha: 0.18),
                  _kObsidianVoid,
                ],
                stops: const <double>[0.0, 0.65, 1.0],
              ),
              border: Border.all(
                color: _kCelestialGold.withValues(alpha: 0.85),
                width: 1.6,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _kArcaneAmethyst.withValues(alpha: 0.45),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: _kCelestialGold.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Inner dashed arcane rune circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kArcaneAmethyst.withValues(alpha: 0.65),
                      width: 1.1,
                    ),
                  ),
                ),
                const Icon(
                  Icons.handshake_rounded,
                  color: _kCelestialGold,
                  size: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CelestialSealDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 2;

    final Paint rayPaint = Paint()
      ..color = _kCelestialGold.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final Paint dotPaint = Paint()
      ..color = _kArcaneAmethyst.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    // Draw 8 celestial ray notches and points
    for (int i = 0; i < 8; i++) {
      final double angle = (i * math.pi) / 4;
      final double cosA = math.cos(angle);
      final double sinA = math.sin(angle);

      final Offset p1 = Offset(center.dx + (radius - 5) * cosA, center.dy + (radius - 5) * sinA);
      final Offset p2 = Offset(center.dx + radius * cosA, center.dy + radius * sinA);
      canvas.drawLine(p1, p2, rayPaint);

      // Micro dots on diagonal intersections
      if (i % 2 == 1) {
        final Offset dotP = Offset(center.dx + (radius - 2.5) * cosA, center.dy + (radius - 2.5) * sinA);
        canvas.drawCircle(dotP, 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Two-Way Participant Cards: Initiator <--- Bilateral Nexus ---> You
// ─────────────────────────────────────────────────────────────────────────────
class _TwoWayParticipantCards extends StatelessWidget {
  const _TwoWayParticipantCards({
    required this.initiatorName,
    required this.sessionId,
  });

  final String initiatorName;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final String cleanSessionId =
        sessionId.length > 6 ? sessionId.substring(0, 6).toUpperCase() : sessionId.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x80080B13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _kArcaneAmethyst.withValues(alpha: 0.24),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // 1. Initiator Card
          Expanded(
            child: _ParticipantTile(
              title: 'TEKLİF EDEN',
              name: initiatorName,
              accentColor: _kArcaneAmethyst,
              icon: Icons.person_outline_rounded,
              statusLabel: 'Çevrimiçi',
              statusDotColor: AppColors.toxicNeon,
            ),
          ),

          // 2. Bilateral Exchange Nexus Conduit
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[_kArcaneAmethyst, _kCelestialGold],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _kCelestialGold.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: _kObsidianVoid,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kObsidianVoid.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _kCelestialGold.withValues(alpha: 0.35),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    '#$cleanSessionId',
                    style: const TextStyle(
                      color: _kCelestialGold,
                      fontSize: 8.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Receiver Card (You)
          const Expanded(
            child: _ParticipantTile(
              title: 'SÖZLEŞME TARAFINIZ',
              name: 'Sen',
              accentColor: _kCelestialGold,
              icon: Icons.verified_user_rounded,
              statusLabel: 'Onay Bekliyor',
              statusDotColor: _kCelestialGold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.title,
    required this.name,
    required this.accentColor,
    required this.icon,
    required this.statusLabel,
    required this.statusDotColor,
  });

  final String title;
  final String name;
  final Color accentColor;
  final IconData icon;
  final String statusLabel;
  final Color statusDotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _kObsidianVoid.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.32),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Role header tag
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accentColor.withValues(alpha: 0.95),
              fontSize: 9.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),

          // Avatar glyph
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.16),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.55),
                width: 1.1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(height: 6),

          // Participant Name
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),

          // Status indicator
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusDotColor,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: statusDotColor.withValues(alpha: 0.7),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.mutedTitanium.withValues(alpha: 0.9),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Buttons: Specular Polish & Tactile Feedback
// ─────────────────────────────────────────────────────────────────────────────
class _ContractDeclineButton extends StatelessWidget {
  const _ContractDeclineButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: disabled
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.mysticRuby.withValues(alpha: 0.4),
                      _kObsidianVoid.withValues(alpha: 0.85),
                    ],
                  ),
            color: disabled ? _kObsidianVoid.withValues(alpha: 0.5) : null,
            border: Border.all(
              color: disabled
                  ? AppColors.mutedTitanium.withValues(alpha: 0.2)
                  : AppColors.mysticRuby.withValues(alpha: 0.7),
              width: 1.1,
            ),
            boxShadow: disabled
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: AppColors.mysticRuby.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.mysticRuby),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.close_rounded,
                      size: 19,
                      color: AppColors.mysticRuby,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ContractAcceptButton extends StatelessWidget {
  const _ContractAcceptButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: disabled
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      _kCelestialGoldLight,
                      _kCelestialGold,
                      Color(0xFFC99525),
                    ],
                    stops: <double>[0.0, 0.45, 1.0],
                  ),
            color: disabled ? _kObsidianVoid.withValues(alpha: 0.5) : null,
            border: Border.all(
              color: disabled
                  ? AppColors.mutedTitanium.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.75),
              width: 1.1,
            ),
            boxShadow: disabled
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: _kCelestialGold.withValues(alpha: 0.42),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(_kObsidianVoid),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.check_rounded,
                      size: 21,
                      color: _kObsidianVoid,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: _kObsidianVoid,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Atmospheric Custom Painters: Nebula Glow & 4-Corner Arcane Filigree
// ─────────────────────────────────────────────────────────────────────────────
class _ArcaneNebulaGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Amethyst core glow behind seal
    final Paint amethystOrb = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          _kArcaneAmethyst.withValues(alpha: 0.18),
          _kArcaneAmethyst.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.5, 60),
        radius: 120,
      ));
    canvas.drawCircle(Offset(size.width * 0.5, 60), 120, amethystOrb);

    // 2. Celestial gold bottom-right reflection
    final Paint goldOrb = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          _kCelestialGold.withValues(alpha: 0.10),
          _kCelestialGold.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.85, size.height * 0.85),
        radius: 140,
      ));
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.85), 140, goldOrb);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ObsidianFiligreeBorderPainter extends CustomPainter {
  const _ObsidianFiligreeBorderPainter({
    required this.goldColor,
    required this.amethystColor,
  });

  final Color goldColor;
  final Color amethystColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(22));

    // Outer luminescent border gradient
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          goldColor.withValues(alpha: 0.88),
          amethystColor.withValues(alpha: 0.8),
          goldColor.withValues(alpha: 0.45),
          amethystColor.withValues(alpha: 0.88),
        ],
        stops: const <double>[0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, borderPaint);

    // Specular top highlight (crystal sheen at upper rim)
    final Paint specularPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Colors.transparent,
          Colors.white.withValues(alpha: 0.65),
          goldColor.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.65),
          Colors.transparent,
        ],
        stops: const <double>[0.1, 0.35, 0.5, 0.65, 0.9],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2));

    final Path topPath = Path()
      ..moveTo(26, 0)
      ..lineTo(size.width - 26, 0);
    canvas.drawPath(topPath, specularPaint);

    // 4-Corner Arcane Filigree Brackets with Diamond Glyphs
    final Paint bracketPaint = Paint()
      ..color = goldColor.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Paint diamondPaint = Paint()
      ..color = amethystColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    const double bLen = 10.0;
    const double m = 7.0;

    // Top-Left Bracket
    canvas.drawLine(const Offset(m, m + 14), Offset(m, m + 14 + bLen), bracketPaint);
    canvas.drawLine(const Offset(m + 14, m), Offset(m + 14 + bLen, m), bracketPaint);
    _drawDiamond(canvas, Offset(m + 5, m + 5), 2.5, diamondPaint);

    // Top-Right Bracket
    canvas.drawLine(Offset(size.width - m, m + 14), Offset(size.width - m, m + 14 + bLen), bracketPaint);
    canvas.drawLine(Offset(size.width - m - 14, m), Offset(size.width - m - 14 - bLen, m), bracketPaint);
    _drawDiamond(canvas, Offset(size.width - m - 5, m + 5), 2.5, diamondPaint);

    // Bottom-Left Bracket
    canvas.drawLine(Offset(m, size.height - m - 14), Offset(m, size.height - m - 14 - bLen), bracketPaint);
    canvas.drawLine(Offset(m + 14, size.height - m), Offset(m + 14 + bLen, size.height - m), bracketPaint);
    _drawDiamond(canvas, Offset(m + 5, size.height - m - 5), 2.5, diamondPaint);

    // Bottom-Right Bracket
    canvas.drawLine(Offset(size.width - m, size.height - m - 14), Offset(size.width - m, size.height - m - 14 - bLen), bracketPaint);
    canvas.drawLine(Offset(size.width - m - 14, size.height - m), Offset(size.width - m - 14 - bLen, size.height - m), bracketPaint);
    _drawDiamond(canvas, Offset(size.width - m - 5, size.height - m - 5), 2.5, diamondPaint);
  }

  void _drawDiamond(Canvas canvas, Offset center, double radius, Paint paint) {
    final Path path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ObsidianFiligreeBorderPainter oldDelegate) =>
      oldDelegate.goldColor != goldColor ||
      oldDelegate.amethystColor != amethystColor;
}
