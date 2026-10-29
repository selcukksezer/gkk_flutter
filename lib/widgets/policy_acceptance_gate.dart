import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/legal/legal_document_content.dart';
import '../core/tutorial/tutorial_modal_suppress.dart';
import '../models/policy_model.dart';
import '../providers/auth_provider.dart';
import '../providers/policy_provider.dart';
import '../screens/legal/legal_document_reader_overlay.dart';
import '../theme/app_text_styles.dart';

/// 2027 Aion 2 Obsidian-Glass & Celestial Color Tokens
abstract final class _GateColors {
  // Obsidian Foundation
  static const Color voidDark = Color(0xFF04060A);
  static const Color obsidianDeep = Color(0xFF07090E);
  static const Color obsidianCard = Color(0xFF0B101B);
  static const Color obsidianSurface = Color(0xFF0F1524);
  static const Color obsidianElevated = Color(0xFF141C30);
  static const Color obsidianBorder = Color(0xFF1E2838);

  // Celestial Gold (#E5C158)
  static const Color celestialGold = Color(0xFFE5C158);
  static const Color goldBright = Color(0xFFFFDF7A);
  static const Color goldMuted = Color(0xFFB89230);
  static const Color goldDeep = Color(0xFF7A5F19);
  static const Color goldGlow = Color(0x33E5C158);

  // Ether Cyan (#00E5FF)
  static const Color etherCyan = Color(0xFF00E5FF);
  static const Color cyanBright = Color(0xFF70FFFF);
  static const Color cyanDim = Color(0xFF00A2B8);
  static const Color cyanGlow = Color(0x3300E5FF);

  // Semantic & Text
  static const Color rubyRed = Color(0xFFFF3B5C);
  static const Color rubyGlow = Color(0x33FF3B5C);
  static const Color textHigh = Color(0xFFF3F6FD);
  static const Color textMid = Color(0xFFA6B7D4);
  static const Color textMuted = Color(0xFF677694);
}


/// Blocks gameplay until active legal docs are accepted.
/// Upgraded to 2027 Aion 2 Obsidian-Glass aesthetic with full SafeArea,
/// frosted blur (sigma 16), celestial gold/cyan accents, and tactile haptic feedback.
class PolicyAcceptanceGate extends ConsumerStatefulWidget {
  const PolicyAcceptanceGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PolicyAcceptanceGate> createState() =>
      _PolicyAcceptanceGateState();
}

class _PolicyAcceptanceGateState extends ConsumerState<PolicyAcceptanceGate> {
  final Set<String> _readTypes = <String>{};
  LegalDocument? _readingDoc;
  bool _accepting = false;
  String? _acceptError;

  @override
  void initState() {
    super.initState();
    // Heal stale Riverpod state after register/hot-reload.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(policyProvider.notifier).refresh());
    });
  }

  Future<void> _acceptAll() async {
    if (_accepting) return;
    await HapticFeedback.mediumImpact();
    setState(() {
      _accepting = true;
      _acceptError = null;
    });
    final String? err = await ref.read(policyProvider.notifier).acceptAll();
    if (!mounted) return;
    setState(() => _accepting = false);
    if (err != null) {
      await HapticFeedback.heavyImpact();
      setState(() => _acceptError = err);
      return;
    }
    await HapticFeedback.selectionClick();
    setState(() {
      _readTypes.clear();
      _acceptError = null;
    });
  }

  void _onDocumentFinished(String type) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _readTypes.add(type);
      _readingDoc = null;
      _acceptError = null;
    });
  }

  bool _canAccept(List<LegalDocument> missingDocs) {
    if (missingDocs.isEmpty) return false;
    for (final LegalDocument doc in missingDocs) {
      if (!_readTypes.contains(doc.type)) return false;
    }
    return true;
  }

  Future<void> _handleDecline() async {
    await HapticFeedback.selectionClick();
    if (!mounted) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (BuildContext ctx) => _DeclineConfirmDialog(
        onConfirm: () async {
          await HapticFeedback.mediumImpact();
          if (ctx.mounted) Navigator.of(ctx).pop(true);
        },
        onCancel: () async {
          await HapticFeedback.selectionClick();
          if (ctx.mounted) Navigator.of(ctx).pop(false);
        },
      ),
    );

    if (confirm == true && mounted) {
      await HapticFeedback.mediumImpact();
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final PolicyState policy = ref.watch(policyProvider);
    if (policy.isLoading || !policy.needsAcceptance) {
      return widget.child;
    }

    final List<String> missing =
        (policy.status?.missingForGameplay ?? <String>[]);
    final List<LegalDocument> missingDocs = missing
        .where((String type) => !kRegisterOnlyLegalDocTypes.contains(type))
        .map((String type) {
          for (final LegalDocument doc in policy.documents) {
            if (doc.type == type) return doc;
          }
          return LegalDocument(
            type: type,
            version: 1,
            title: LegalDocumentContent.resolve(
              LegalDocument(type: type, version: 1, title: '', bodyMd: ''),
            ).title,
            bodyMd: '',
          );
        })
        .toList(growable: false);

    if (missingDocs.isEmpty) {
      return widget.child;
    }

    final int readCount = missingDocs
        .where((LegalDocument d) => _readTypes.contains(d.type))
        .length;
    final bool canAccept = _canAccept(missingDocs);
    final double progress = missingDocs.isEmpty
        ? 1.0
        : (readCount / missingDocs.length).clamp(0.0, 1.0);

    return TutorialSuppressScope(
      active: true,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,

          // 2027 Obsidian Frosted Scrim with sigma 16 blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.2),
                    radius: 1.35,
                    colors: <Color>[
                      _GateColors.obsidianSurface.withValues(alpha: 0.88),
                      _GateColors.obsidianDeep.withValues(alpha: 0.94),
                      _GateColors.voidDark.withValues(alpha: 0.98),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Dialog Gate Container with full SafeArea & MediaQuery Insets Protection
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final EdgeInsets insets = MediaQuery.viewInsetsOf(context);
                final double availableHeight =
                    constraints.maxHeight - insets.bottom;
                final bool isCompact = availableHeight < 620.0;
                final double cardWidth =
                    math.min(440.0, constraints.maxWidth - 28.0);
                final double cardHeight =
                    math.min(640.0, availableHeight - 20.0);

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: cardWidth,
                      maxHeight: cardHeight,
                    ),
                    child: _ObsidianGlassCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Header with Celestial Seal & Accents
                          _GateHeader(
                            totalDocs: missingDocs.length,
                            readDocs: readCount,
                            progress: progress,
                            compact: isCompact,
                          ),
                          SizedBox(height: isCompact ? 10 : 14),

                          // Scrollable Document List
                          Flexible(
                            child: Scrollbar(
                              radius: const Radius.circular(8),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                physics: const BouncingScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: missingDocs.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: isCompact ? 8 : 10),
                                itemBuilder: (BuildContext context, int index) {
                                  final LegalDocument doc = missingDocs[index];
                                  final LegalDocument resolved =
                                      LegalDocumentContent.resolve(doc);
                                  final bool isRead =
                                      _readTypes.contains(doc.type);

                                  return _DocumentTile(
                                    title: resolved.title,
                                    isRead: isRead,
                                    compact: isCompact,
                                    onTap: () async {
                                      await HapticFeedback.selectionClick();
                                      setState(() => _readingDoc = resolved);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),

                          // Error Display
                          if (_acceptError != null) ...<Widget>[
                            const SizedBox(height: 10),
                            _ErrorBanner(message: _acceptError!),
                          ],

                          SizedBox(height: isCompact ? 12 : 16),

                          // Footer Actions: Accept & Decline
                          _FooterActions(
                            canAccept: canAccept,
                            isAccepting: _accepting,
                            onAccept: canAccept && !_accepting
                                ? _acceptAll
                                : () async {
                                    await HapticFeedback.selectionClick();
                                  },
                            onDecline: _handleDecline,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // In-App Fullscreen Reader Overlay
          if (_readingDoc != null)
            LegalDocumentReaderOverlay(
              document: _readingDoc!,
              onFinished: _onDocumentFinished,
              onDismiss: () async {
                await HapticFeedback.selectionClick();
                setState(() => _readingDoc = null);
              },
            ),
        ],
      ),
    );
  }
}

/// 2027 Aion 2 Obsidian-Glass Card Container with High-Definition Specular Highlights
class _ObsidianGlassCard extends StatelessWidget {
  const _ObsidianGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: _GateColors.goldGlow,
            blurRadius: 28,
            spreadRadius: -8,
          ),
          BoxShadow(
            color: _GateColors.cyanGlow,
            blurRadius: 40,
            spreadRadius: -14,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xF2121A2C),
                  Color(0xF60C111E),
                  Color(0xFA080B13),
                  Color(0xFC05070B),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                width: 1.2,
                color: _GateColors.celestialGold.withValues(alpha: 0.35),
              ),
            ),
            child: Stack(
              children: <Widget>[
                // Top Specular Highlight
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 1.2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          _GateColors.celestialGold.withValues(alpha: 0.75),
                          _GateColors.etherCyan.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom Subtle Backlight
                Positioned(
                  bottom: 0,
                  left: 36,
                  right: 36,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          _GateColors.etherCyan.withValues(alpha: 0.25),
                          _GateColors.celestialGold.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Celestial Seal & Protocol Header with Responsive Height Adaptations
class _GateHeader extends StatelessWidget {
  const _GateHeader({
    required this.totalDocs,
    required this.readDocs,
    required this.progress,
    this.compact = false,
  });

  final int totalDocs;
  final int readDocs;
  final double progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double sealSize = compact ? 46.0 : 56.0;
    final double sealIconSize = compact ? 22.0 : 26.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Celestial Seal Emblem with Layered Rings
        Container(
          width: sealSize,
          height: sealSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                _GateColors.goldBright,
                _GateColors.celestialGold,
                _GateColors.goldDeep,
              ],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: _GateColors.goldGlow,
                blurRadius: 18,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: _GateColors.cyanGlow,
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.5),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _GateColors.obsidianDeep,
              ),
              child: Center(
                child: Icon(
                  Icons.shield_rounded,
                  color: _GateColors.celestialGold,
                  size: sealIconSize,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 8 : 12),

        // Protocol Badge
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: compact ? 2 : 3.5,
          ),
          decoration: BoxDecoration(
            color: _GateColors.etherCyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _GateColors.etherCyan.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _GateColors.etherCyan,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _GateColors.cyanGlow,
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'GÖLGE KRALLIĞI PROTOKOLÜ',
                style: AppTextStyles.label.copyWith(
                  color: _GateColors.cyanBright,
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 6 : 8),

        // Main Title
        Text(
          'Sözleşmeler ve Kurallar',
          textAlign: TextAlign.center,
          style: (compact ? AppTextStyles.h3 : AppTextStyles.h2).copyWith(
            color: _GateColors.textHigh,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 3),

        // Subtitle
        Text(
          'Oyuna katılmak için lütfen kuralları inceleyip onaylayın.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: _GateColors.textMid,
            fontSize: compact ? 11.5 : 12,
            height: 1.35,
          ),
        ),
        SizedBox(height: compact ? 10 : 12),

        // Animated Smooth Progress Track
        Row(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 6,
                  color: _GateColors.obsidianBorder,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            _GateColors.etherCyan,
                            _GateColors.celestialGold,
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: _GateColors.cyanGlow,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$readDocs / $totalDocs',
              style: AppTextStyles.captionBold.copyWith(
                color: progress >= 1.0
                    ? _GateColors.cyanBright
                    : _GateColors.celestialGold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Document Item Tile with Dynamic Read State and Tactile Micro-Interactions
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.title,
    required this.isRead,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final bool isRead;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isRead
        ? _GateColors.etherCyan.withValues(alpha: 0.5)
        : _GateColors.celestialGold.withValues(alpha: 0.32);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _GateColors.etherCyan.withValues(alpha: 0.12),
        highlightColor: _GateColors.celestialGold.withValues(alpha: 0.08),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                isRead
                    ? const Color(0xFF0F1B2C).withValues(alpha: 0.82)
                    : const Color(0xFF111726).withValues(alpha: 0.72),
                const Color(0xFF090D16).withValues(alpha: 0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.1),
            boxShadow: <BoxShadow>[
              if (isRead)
                BoxShadow(
                  color: _GateColors.etherCyan.withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: Row(
            children: <Widget>[
              // Check / Status Emblem
              Container(
                width: compact ? 28 : 32,
                height: compact ? 28 : 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRead
                      ? _GateColors.etherCyan.withValues(alpha: 0.15)
                      : _GateColors.obsidianElevated,
                  border: Border.all(
                    color: isRead
                        ? _GateColors.etherCyan
                        : _GateColors.textMuted.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isRead
                        ? Icons.check_rounded
                        : Icons.menu_book_rounded,
                    color: isRead
                        ? _GateColors.etherCyan
                        : _GateColors.textMuted,
                    size: compact ? 14 : 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Status Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: _GateColors.textHigh,
                        fontSize: compact ? 13 : 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRead ? 'İncelendi ve okundu' : 'İnceleme zorunludur',
                      style: AppTextStyles.caption.copyWith(
                        color: isRead
                            ? _GateColors.cyanDim
                            : _GateColors.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Action CTA Pill
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: compact ? 4 : 5,
                ),
                decoration: BoxDecoration(
                  gradient: isRead
                      ? null
                      : const LinearGradient(
                          colors: <Color>[
                            _GateColors.goldBright,
                            _GateColors.celestialGold,
                          ],
                        ),
                  color: isRead
                      ? _GateColors.etherCyan.withValues(alpha: 0.1)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  border: isRead
                      ? Border.all(
                          color: _GateColors.etherCyan.withValues(alpha: 0.35),
                          width: 1,
                        )
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      isRead ? 'Tekrar Oku' : 'Oku',
                      style: AppTextStyles.label.copyWith(
                        color: isRead
                            ? _GateColors.cyanBright
                            : _GateColors.obsidianDeep,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isRead
                          ? Icons.refresh_rounded
                          : Icons.arrow_forward_rounded,
                      size: 13,
                      color: isRead
                          ? _GateColors.cyanBright
                          : _GateColors.obsidianDeep,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error Banner with High-Visibility Semantic Alert
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _GateColors.rubyRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _GateColors.rubyRed.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: _GateColors.rubyRed,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                color: _GateColors.rubyRed,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer Actions: Radiant Accept All and Elegant Ghost Glass Decline
class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.canAccept,
    required this.isAccepting,
    required this.onAccept,
    required this.onDecline,
  });

  final bool canAccept;
  final bool isAccepting;
  final VoidCallback? onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Primary Radiant Accept Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onAccept,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: canAccept
                    ? const LinearGradient(
                        colors: <Color>[
                          _GateColors.goldBright,
                          _GateColors.celestialGold,
                          _GateColors.goldMuted,
                        ],
                      )
                    : LinearGradient(
                        colors: <Color>[
                          _GateColors.obsidianElevated,
                          _GateColors.obsidianSurface,
                        ],
                      ),
                border: Border.all(
                  color: canAccept
                      ? _GateColors.goldBright.withValues(alpha: 0.8)
                      : _GateColors.obsidianBorder,
                  width: 1,
                ),
                boxShadow: canAccept
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: _GateColors.goldGlow,
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isAccepting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _GateColors.obsidianDeep,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            canAccept
                                ? Icons.verified_rounded
                                : Icons.lock_outline_rounded,
                            size: 18,
                            color: canAccept
                                ? _GateColors.obsidianDeep
                                : _GateColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            canAccept
                                ? 'Kabul Et ve Devam Et'
                                : 'Tüm Belgeleri Okumalısınız',
                            style: AppTextStyles.titleBold.copyWith(
                              color: canAccept
                                  ? _GateColors.obsidianDeep
                                  : _GateColors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Ghost Glass Decline Pill Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onDecline,
            borderRadius: BorderRadius.circular(12),
            splashColor: _GateColors.rubyRed.withValues(alpha: 0.12),
            highlightColor: _GateColors.rubyRed.withValues(alpha: 0.06),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _GateColors.obsidianBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.logout_rounded,
                    size: 14,
                    color: _GateColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sözleşmeleri Reddet & Çıkış Yap',
                    style: AppTextStyles.caption.copyWith(
                      color: _GateColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Frosted Decline Confirmation Modal
class _DeclineConfirmDialog extends StatelessWidget {
  const _DeclineConfirmDialog({
    required this.onConfirm,
    required this.onCancel,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xF0181A28),
                  Color(0xF50D111C),
                  Color(0xF8080A12),
                ],
              ),
              border: Border.all(
                color: _GateColors.rubyRed.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: _GateColors.rubyGlow,
                  blurRadius: 28,
                  spreadRadius: -4,
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _GateColors.rubyRed.withValues(alpha: 0.15),
                    border: Border.all(
                      color: _GateColors.rubyRed.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: _GateColors.rubyRed,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Sözleşmeleri Reddet?',
                  style: AppTextStyles.h3.copyWith(
                    color: _GateColors.textHigh,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gölge Krallığı Klansı protokollerini kabul etmeden oyuna devam edemezsiniz. Hesabınızdan çıkış yapılacaktır.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: _GateColors.textMid,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: _GateColors.obsidianBorder,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Vazgeç',
                          style: AppTextStyles.captionBold.copyWith(
                            color: _GateColors.textMid,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _GateColors.rubyRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: Text(
                          'Çıkış Yap',
                          style: AppTextStyles.captionBold.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

