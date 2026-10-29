import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../providers/trade_invite_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../common/app_messenger.dart';
import 'trade_invite_dialog.dart';

export 'trade_invite_dialog.dart';

/// 2027 Aion 2 Mobile — Obsidian-Glass Floating Trade Notification Host.
///
/// Features:
/// - Floating frosted obsidian notification host for incoming/outgoing trade requests
/// - Arcane Amethyst (`#9D4EDD`) and Ether Cyan (`#00E5FF`) dual-pulse luminescence
/// - True non-blocking top overlay (`Positioned(top: 0, left: 0, right: 0)`)
/// - Dismissible floating banner with clean 30s timer & laser progress indicator
/// - Full [SafeArea] & [MediaQuery] insets protection (notch / dynamic island safe)
/// - Multi-tiered tactile [HapticFeedback] (arrival, select, accept impact)
/// - Seamless backward compatibility with [showTradeInviteDialog] for sender blocking
class TradeInviteHost extends ConsumerStatefulWidget {
  const TradeInviteHost({super.key, required this.child});

  final Widget child;

  /// Palette tokens for 2027 Aion 2 Obsidian-Glass
  static const Color arcaneAmethyst = Color(0xFF9D4EDD);
  static const Color etherCyan = Color(0xFF00E5FF);
  static const Color obsidianVoid = Color(0xF2080B12);
  static const Color obsidianSurface = Color(0xF0121826);

  /// Imperative helper to present an outgoing trade invitation banner from anywhere.
  static void showOutgoing(
    BuildContext context, {
    required String targetName,
    Duration duration = const Duration(seconds: 30),
    VoidCallback? onCancel,
  }) {
    final OverlayState? overlay =
        appRootNavigatorKey.currentState?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || !overlay.mounted) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) {
        return _TradeInviteFloatingBanner(
          title: 'GİDEN TİCARET TALEBİ',
          initiatorName: targetName,
          isOutgoing: true,
          duration: duration,
          onDismiss: () {
            if (entry.mounted) entry.remove();
          },
          onDecline: () {
            onCancel?.call();
            if (entry.mounted) entry.remove();
          },
          onAccept: () {
            if (entry.mounted) entry.remove();
          },
        );
      },
    );
    overlay.insert(entry);
  }

  @override
  ConsumerState<TradeInviteHost> createState() => _TradeInviteHostState();
}

class _TradeInviteHostState extends ConsumerState<TradeInviteHost> {
  OverlayEntry? _bannerEntry;
  String? _activeSessionId;
  bool _showingDetailedDialog = false;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<TradeInviteState>(
      tradeInviteProvider,
      (TradeInviteState? previous, TradeInviteState next) {
        _scheduleInvite(next);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _dismissBanner(removeSession: true);
    super.dispose();
  }

  void _scheduleInvite(TradeInviteState inviteState) {
    if (_showingDetailedDialog) return;

    final TradeInvite? invite = inviteState.nextPopup;
    if (invite == null) {
      _dismissBanner(removeSession: true);
      return;
    }
    if (_activeSessionId == invite.sessionId) return;

    WidgetsBinding.instance.addPostFrameCallback((_) => _presentBanner(invite));
  }

  OverlayState? _resolveOverlay() {
    final OverlayState? rootOverlay = appRootNavigatorKey.currentState?.overlay;
    if (rootOverlay != null && rootOverlay.mounted) {
      return rootOverlay;
    }
    if (mounted) {
      return Overlay.maybeOf(context, rootOverlay: true);
    }
    return null;
  }

  void _dismissBanner({bool removeSession = false}) {
    if (_bannerEntry != null) {
      if (_bannerEntry!.mounted) {
        _bannerEntry!.remove();
      }
      _bannerEntry = null;
    }
    if (removeSession) {
      _activeSessionId = null;
    }
  }

  void _presentBanner(TradeInvite invite) {
    if (!mounted || _showingDetailedDialog) return;
    if (_activeSessionId == invite.sessionId && _bannerEntry != null) return;

    final OverlayState? overlay = _resolveOverlay();
    if (overlay == null || !overlay.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_showingDetailedDialog) {
          _presentBanner(invite);
        }
      });
      return;
    }

    _dismissBanner();
    _activeSessionId = invite.sessionId;
    _isResponding = false;

    // Tactile arrival alert: subtle physical vibration when invite slides into view
    HapticFeedback.lightImpact();

    _bannerEntry = OverlayEntry(
      builder: (BuildContext ctx) {
        return _TradeInviteFloatingBanner(
          key: ValueKey<String>('trade_invite_banner_${invite.sessionId}'),
          title: 'TİCARET TALEBİ',
          initiatorName: invite.initiatorName,
          isOutgoing: false,
          duration: const Duration(seconds: 30),
          onDismiss: () {
            _handleDismiss(invite.sessionId);
          },
          onDecline: () {
            _handleDecline(invite.sessionId);
          },
          onAccept: () {
            _handleAccept(invite.sessionId);
          },
          onTapInspect: () {
            _handleInspect(invite);
          },
        );
      },
    );

    overlay.insert(_bannerEntry!);
  }

  void _handleDismiss(String sessionId) {
    if (_isResponding) return;
    _isResponding = true;
    HapticFeedback.selectionClick();
    _dismissBanner(removeSession: true);
    ref.read(tradeInviteProvider.notifier).dismissPopup(sessionId);
    _isResponding = false;
    _scheduleInvite(ref.read(tradeInviteProvider));
  }

  Future<void> _handleDecline(String sessionId) async {
    if (_isResponding) return;
    _isResponding = true;
    HapticFeedback.selectionClick();
    _dismissBanner(removeSession: true);

    try {
      final Map<String, dynamic> res = await ref
          .read(tradeInviteProvider.notifier)
          .respond(
            sessionId: sessionId,
            accept: false,
            blockSender: false,
          );

      final BuildContext? rootCtx = appRootNavigatorKey.currentContext;
      if (res['success'] != true && rootCtx != null && rootCtx.mounted) {
        AppMessenger.showError(
          rootCtx,
          (res['error'] as String?) ?? 'Ticaret talebi reddedilemedi',
        );
      }
    } finally {
      _isResponding = false;
      if (mounted) {
        _scheduleInvite(ref.read(tradeInviteProvider));
      }
    }
  }

  Future<void> _handleAccept(String sessionId) async {
    if (_isResponding) return;
    _isResponding = true;
    HapticFeedback.mediumImpact();
    _dismissBanner(removeSession: true);

    try {
      final Map<String, dynamic> res = await ref
          .read(tradeInviteProvider.notifier)
          .respond(
            sessionId: sessionId,
            accept: true,
            blockSender: false,
          );

      final BuildContext? rootCtx = appRootNavigatorKey.currentContext;
      if (!mounted || rootCtx == null || !rootCtx.mounted) return;

      if (res['success'] == true) {
        rootCtx.push(AppRoutes.trade);
        AppMessenger.showSuccess(rootCtx, 'Ticaret oturumu başladı');
      } else {
        AppMessenger.showError(
          rootCtx,
          (res['error'] as String?) ?? 'Ticaret başlatılamadı',
        );
      }
    } finally {
      _isResponding = false;
      if (mounted) {
        _scheduleInvite(ref.read(tradeInviteProvider));
      }
    }
  }

  Future<void> _handleInspect(TradeInvite invite) async {
    if (_isResponding) return;
    _isResponding = true;
    HapticFeedback.selectionClick();
    _dismissBanner();

    final BuildContext? dialogContext = appRootNavigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) {
      _isResponding = false;
      return;
    }

    _showingDetailedDialog = true;
    _activeSessionId = invite.sessionId;

    final bool responded = await showTradeInviteDialog(
      dialogContext,
      invite: invite,
      onRespond: (bool accept, bool block) {
        return ref.read(tradeInviteProvider.notifier).respond(
              sessionId: invite.sessionId,
              accept: accept,
              blockSender: block,
            );
      },
    );

    if (mounted) {
      if (!responded) {
        _activeSessionId = null;
      }
      _showingDetailedDialog = false;
      _isResponding = false;
      _scheduleInvite(ref.read(tradeInviteProvider));
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Floating Frosted Obsidian-Glass Notification Banner for Trade Invites.
class _TradeInviteFloatingBanner extends StatefulWidget {
  const _TradeInviteFloatingBanner({
    super.key,
    required this.title,
    required this.initiatorName,
    required this.isOutgoing,
    required this.duration,
    required this.onDismiss,
    required this.onDecline,
    required this.onAccept,
    this.onTapInspect,
  });

  final String title;
  final String initiatorName;
  final bool isOutgoing;
  final Duration duration;
  final VoidCallback onDismiss;
  final VoidCallback onDecline;
  final VoidCallback onAccept;
  final VoidCallback? onTapInspect;

  @override
  State<_TradeInviteFloatingBanner> createState() =>
      _TradeInviteFloatingBannerState();
}

class _TradeInviteFloatingBannerState
    extends State<_TradeInviteFloatingBanner>
    with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _pulseController;
  late final AnimationController _timerController;

  bool _isDismissed = false;
  bool _actionLocked = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _timerController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _timerController.forward();
    _timerController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted && !_isDismissed) {
        _dismissWithAnimation(widget.onDismiss);
      }
    });

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _timerController.dispose();
    super.dispose();
  }

  void _dismissWithAnimation(VoidCallback callback) {
    if (_isDismissed) return;
    _isDismissed = true;
    _slideController.reverse().then((_) {
      if (mounted) {
        callback();
      }
    });
  }

  void _triggerAction(VoidCallback action) {
    if (_actionLocked || _isDismissed) return;
    _actionLocked = true;
    _dismissWithAnimation(action);
  }

  int _currentSecondsLeft() {
    final double left = (1.0 - _timerController.value).clamp(0.0, 1.0);
    return (left * widget.duration.inSeconds).ceil();
  }

  @override
  Widget build(BuildContext context) {
    String acceptLabel = 'Kabul Et';
    String declineLabel = 'Reddet';
    try {
      acceptLabel = context.l10n.kabul_et;
      declineLabel = context.l10n.reddet;
    } catch (_) {}

    final int secondsLeft = _currentSecondsLeft();
    final bool isUrgent = secondsLeft <= 5;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: true,
        bottom: false,
        left: true,
        right: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Dismissible(
                    key: ValueKey<String>(
                      'dismiss_trade_banner_${widget.initiatorName}_${widget.title}',
                    ),
                    direction: DismissDirection.up,
                    onDismissed: (_) {
                      HapticFeedback.selectionClick();
                      widget.onDismiss();
                    },
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                        <Listenable>[_pulseController, _timerController],
                      ),
                      builder: (BuildContext context, Widget? child) {
                        final double pulse = _pulseController.value;
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.72),
                                blurRadius: 26,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: isUrgent
                                    ? AppColors.mysticRuby.withValues(
                                        alpha: 0.35 + 0.30 * pulse,
                                      )
                                    : TradeInviteHost.arcaneAmethyst.withValues(
                                        alpha: 0.22 + 0.26 * pulse,
                                      ),
                                blurRadius: 18 + (10 * pulse),
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: isUrgent
                                    ? AppColors.coralFlare.withValues(
                                        alpha: 0.22 + 0.20 * pulse,
                                      )
                                    : TradeInviteHost.etherCyan.withValues(
                                        alpha: 0.20 + 0.24 * pulse,
                                      ),
                                blurRadius: 14 + (8 * pulse),
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.onTapInspect != null &&
                                          !_actionLocked
                                      ? () {
                                          HapticFeedback.selectionClick();
                                          widget.onTapInspect!();
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: <Color>[
                                          Color(0xF5131A29),
                                          Color(0xF50D121D),
                                          Color(0xF8080B12),
                                        ],
                                        stops: <double>[0.0, 0.55, 1.0],
                                      ),
                                      border: Border.all(
                                        color: isUrgent
                                            ? Color.lerp(
                                                AppColors.mysticRuby.withValues(alpha: 0.7),
                                                AppColors.coralFlare.withValues(alpha: 0.9),
                                                pulse,
                                              )!
                                            : Color.lerp(
                                                TradeInviteHost.etherCyan.withValues(
                                                  alpha: 0.50,
                                                ),
                                                TradeInviteHost.arcaneAmethyst.withValues(
                                                  alpha: 0.80,
                                                ),
                                                pulse,
                                              )!,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        // Header Row: Sigil, Title, Timer, Dismiss
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.md,
                                            AppSpacing.md,
                                            AppSpacing.md,
                                            AppSpacing.sm,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              _buildSigil(pulse, isUrgent),
                                              const SizedBox(width: AppSpacing.md),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    Row(
                                                      children: <Widget>[
                                                        Expanded(
                                                          child: Text(
                                                            '⚔️ ${widget.title}',
                                                            style: TextStyle(
                                                              color: isUrgent
                                                                  ? AppColors.coralFlare
                                                                  : TradeInviteHost.etherCyan,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight.w900,
                                                              letterSpacing: 1.1,
                                                              shadows: <Shadow>[
                                                                Shadow(
                                                                  color: (isUrgent
                                                                          ? AppColors.mysticRuby
                                                                          : TradeInviteHost.etherCyan)
                                                                      .withValues(alpha: 0.6),
                                                                  blurRadius: 8,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        _buildTimerBadge(
                                                          secondsLeft,
                                                          isUrgent,
                                                          pulse,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        InkWell(
                                                          onTap: () {
                                                            HapticFeedback.selectionClick();
                                                            _dismissWithAnimation(widget.onDismiss);
                                                          },
                                                          borderRadius:
                                                              BorderRadius.circular(12),
                                                          child: const Padding(
                                                            padding: EdgeInsets.all(4),
                                                            child: Icon(
                                                              Icons.close,
                                                              size: 16,
                                                              color: AppColors.mutedTitanium,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 5),
                                                    RichText(
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      text: TextSpan(
                                                        style: const TextStyle(
                                                          color: AppColors.mutedTitanium,
                                                          fontSize: 12.5,
                                                          height: 1.35,
                                                        ),
                                                        children: <InlineSpan>[
                                                          TextSpan(
                                                            text: widget.initiatorName,
                                                            style: const TextStyle(
                                                              color: AppColors.textPrimary,
                                                              fontWeight: FontWeight.w800,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: widget.isOutgoing
                                                                ? ' oyuncusuna takas daveti iletildi, yanıt bekleniyor.'
                                                                : ' sizinle doğrudan takas / ticaret oturumu başlatmak istiyor.',
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Action Buttons Row
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            AppSpacing.md,
                                            0,
                                            AppSpacing.md,
                                            AppSpacing.sm,
                                          ),
                                          child: Row(
                                            children: <Widget>[
                                              if (widget.onTapInspect != null &&
                                                  !widget.isOutgoing) ...<Widget>[
                                                TextButton.icon(
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 4,
                                                    ),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  onPressed: () {
                                                    HapticFeedback.selectionClick();
                                                    widget.onTapInspect!();
                                                  },
                                                  icon: const Icon(
                                                    Icons.tune_rounded,
                                                    size: 13,
                                                    color: AppColors.mutedTitanium,
                                                  ),
                                                  label: const Text(
                                                    'Detay & Engelle',
                                                    style: TextStyle(
                                                      color: AppColors.mutedTitanium,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                              ] else ...<Widget>[
                                                const Spacer(),
                                              ],

                                              // Decline or Cancel
                                              _buildActionButton(
                                                label: widget.isOutgoing
                                                    ? 'İptal Et'
                                                    : declineLabel,
                                                icon: Icons.close_rounded,
                                                accent: AppColors.mysticRuby,
                                                isFilled: false,
                                                onTap: () {
                                                  _triggerAction(widget.onDecline);
                                                },
                                              ),
                                              if (!widget.isOutgoing) ...<Widget>[
                                                const SizedBox(width: AppSpacing.sm),
                                                // Accept Button
                                                _buildActionButton(
                                                  label: acceptLabel,
                                                  icon: Icons.check_rounded,
                                                  accent: TradeInviteHost.etherCyan,
                                                  isFilled: true,
                                                  onTap: () {
                                                    _triggerAction(widget.onAccept);
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        // Smooth Luminous Laser Countdown Fuse
                                        _buildLaserProgressBar(isUrgent),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
  }

  Widget _buildSigil(double pulse, bool isUrgent) {
    final Color primaryGlow =
        isUrgent ? AppColors.mysticRuby : TradeInviteHost.arcaneAmethyst;
    final Color secondaryGlow =
        isUrgent ? AppColors.coralFlare : TradeInviteHost.etherCyan;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            primaryGlow.withValues(alpha: 0.35 + (0.25 * pulse)),
            secondaryGlow.withValues(alpha: 0.20 + (0.15 * pulse)),
            AppColors.carbonVoid,
          ],
        ),
        border: Border.all(
          color: Color.lerp(
            primaryGlow.withValues(alpha: 0.8),
            secondaryGlow.withValues(alpha: 0.9),
            pulse,
          )!,
          width: 1.4,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: secondaryGlow.withValues(alpha: 0.30 + (0.30 * pulse)),
            blurRadius: 10 + (6 * pulse),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          widget.isOutgoing ? Icons.send_rounded : Icons.swap_horiz_rounded,
          color: secondaryGlow,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildTimerBadge(int secondsLeft, bool isUrgent, double pulse) {
    final Color badgeColor =
        isUrgent ? AppColors.mysticRuby : TradeInviteHost.arcaneAmethyst;
    final Color textColor =
        isUrgent ? AppColors.coralFlare : TradeInviteHost.etherCyan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.16 + (isUrgent ? 0.14 * pulse : 0.0)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.45 + (isUrgent ? 0.35 * pulse : 0.0)),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isUrgent ? Icons.warning_amber_rounded : Icons.timer_outlined,
            size: 11,
            color: textColor,
          ),
          const SizedBox(width: 3.5),
          Text(
            '${secondsLeft}s',
            style: TextStyle(
              color: textColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color accent,
    required bool isFilled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isFilled
                ? accent.withValues(alpha: 0.90)
                : accent.withValues(alpha: 0.14),
            border: Border.all(
              color: accent.withValues(alpha: isFilled ? 1.0 : 0.65),
              width: 1.2,
            ),
            boxShadow: isFilled
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.40),
                      blurRadius: 10,
                      spreadRadius: -1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 13,
                color: isFilled ? AppColors.carbonVoid : accent,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isFilled ? AppColors.carbonVoid : accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLaserProgressBar(bool isUrgent) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double progress =
              (1.0 - _timerController.value).clamp(0.0, 1.0);
          final double activeWidth = constraints.maxWidth * progress;

          return SizedBox(
            height: 2.8,
            width: constraints.maxWidth,
            child: Stack(
              children: <Widget>[
                // Channel background
                Container(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                // Luminous progress beam
                Container(
                  width: activeWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isUrgent
                          ? const <Color>[
                              AppColors.mysticRuby,
                              AppColors.coralFlare,
                            ]
                          : const <Color>[
                              TradeInviteHost.arcaneAmethyst,
                              TradeInviteHost.etherCyan,
                            ],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: (isUrgent
                                ? AppColors.coralFlare
                                : TradeInviteHost.etherCyan)
                            .withValues(alpha: 0.7),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                // Glowing leading spark bead
                if (activeWidth > 4)
                  Positioned(
                    left: activeWidth - 3,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 5,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: isUrgent
                                ? AppColors.coralFlare
                                : TradeInviteHost.etherCyan,
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
