import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/legal/legal_document_content.dart';
import '../../core/services/app_haptics.dart';
import '../../models/policy_model.dart';
import '../../providers/policy_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_text_styles.dart';
import '../settings/graphics_settings_provider.dart';
import '../settings/graphics_settings_service.dart';
import '../support/widgets/support_design.dart';

/// AAA Frosted Glassmorphism Legal Document Viewer Screen.
///
/// Features:
/// - Frosted glassmorphism app bar with dynamic blur adapting to [AdaptiveQualityScaler] tier
/// - Interactive reading progress tracker (percentage & linear progress indicator)
/// - AAA markdown typography styling with high-contrast tokens and dark obsidian themes
/// - Accept terms flow wired directly to [PolicyNotifier.acceptAll]
/// - Form control integrity (proper activeColor & thumb styling)
/// - Seamless theme integration with [GameScreenBackground]
class LegalDocumentScreen extends ConsumerStatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.document,
    this.requireAcceptance = false,
    this.onAccept,
    this.fallbackRoute = AppRoutes.settings,
    this.bottomNavRoute,
  });

  final LegalDocument document;
  final bool requireAcceptance;
  final ValueChanged<String>? onAccept;
  final String fallbackRoute;
  final String? bottomNavRoute;

  @override
  ConsumerState<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends ConsumerState<LegalDocumentScreen> {
  late final ScrollController _scrollController = ScrollController()..addListener(_onScroll);
  double _readingProgress = 0.0;
  bool _reachedBottom = false;
  bool _termsAcceptedChecked = false;
  bool _isAccepting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkInitialScrollExtent();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double max = _scrollController.position.maxScrollExtent;
    final double offset = _scrollController.offset;

    final double progress = max <= 0 ? 1.0 : (offset / max).clamp(0.0, 1.0);
    final bool atBottom = max <= 20 || offset >= max - 48;

    if ((progress - _readingProgress).abs() > 0.01 || atBottom != _reachedBottom) {
      setState(() {
        _readingProgress = progress;
        _reachedBottom = atBottom;
      });
    }
  }

  void _checkInitialScrollExtent() {
    if (!_scrollController.hasClients) return;
    final double max = _scrollController.position.maxScrollExtent;
    if (max <= 20) {
      setState(() {
        _readingProgress = 1.0;
        _reachedBottom = true;
      });
    }
  }

  void _scrollToTop() {
    AppHaptics.selection();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToBottom() {
    AppHaptics.selection();
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleAccept(String docType) async {
    if (_isAccepting) return;
    AppHaptics.selection();

    setState(() {
      _isAccepting = true;
      _errorMessage = null;
    });

    try {
      final String? err = await ref.read(policyProvider.notifier).acceptAll();
      if (!mounted) return;

      if (err != null) {
        setState(() {
          _isAccepting = false;
          _errorMessage = err;
        });
        AppMessenger.show(context, err, type: AppMessageType.error);
        return;
      }

      widget.onAccept?.call(docType);
      AppHaptics.success();

      setState(() {
        _isAccepting = false;
        _termsAcceptedChecked = true;
      });

      if (mounted) {
        AppMessenger.show(
          context,
          'Sözleşme başarıyla onaylandı.',
          type: AppMessageType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAccepting = false;
        _errorMessage = e.toString();
      });
      AppMessenger.show(context, e.toString(), type: AppMessageType.error);
    }
  }

  void _goBack() {
    AppHaptics.selection();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.fallbackRoute);
    }
  }

  IconData _documentIcon(String type) {
    final String lower = type.toLowerCase();
    if (lower.contains('privacy') || lower.contains('gizlilik') || lower.contains('kvkk')) {
      return Icons.shield_rounded;
    }
    if (lower.contains('community') || lower.contains('topluluk') || lower.contains('kurallar')) {
      return Icons.groups_rounded;
    }
    return Icons.gavel_rounded;
  }

  String _documentCategoryLabel(String type) {
    final String lower = type.toLowerCase();
    if (lower.contains('privacy') || lower.contains('gizlilik')) {
      return 'GİZLİLİK POLİTİKASI';
    }
    if (lower.contains('kvkk')) {
      return 'KVKK AYDINLATMA METNİ';
    }
    if (lower.contains('community') || lower.contains('topluluk')) {
      return 'TOPLULUK KURALLARI PROTOKOLÜ';
    }
    return 'KULLANICI SÖZLEŞMESİ';
  }

  @override
  Widget build(BuildContext context) {
    final LegalDocument resolved = LegalDocumentContent.resolve(widget.document);
    final PolicyState policy = ref.watch(policyProvider);

    // Adaptive Quality Scaler wiring: optimize blur on low-spec devices for sustained 60 FPS
    final GraphicsConfigData graphics = ref.watch(graphicsSettingsProvider);
    final bool isLowTier = graphics.tier == GraphicsQualityTier.low;
    final double glassBlur = isLowTier ? 6.0 : 16.0;
    final bool glowActive = !isLowTier;

    // Acceptance state determination
    final bool isAlreadyAccepted = policy.status != null &&
        !policy.status!.missing.contains(resolved.type);
    final bool needsAcceptance = widget.requireAcceptance ||
        (policy.status != null && policy.status!.missing.contains(resolved.type));

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) {
          context.go(widget.fallbackRoute);
        }
      },
      child: Scaffold(
        backgroundColor: SettingsPalette.void_,
        body: GameScreenBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                // AAA Frosted Glassmorphism App Bar
                _buildGlassmorphismAppBar(
                  resolved: resolved,
                  glassBlur: glassBlur,
                  glowActive: glowActive,
                  isAccepted: isAlreadyAccepted,
                ),

                // Main Markdown Document Viewer
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      ListView(
                        controller: _scrollController,
                        padding: GameScrollLayout.padding(
                          context,
                          bottomExtra: needsAcceptance ? 130 : 60,
                        ),
                        children: <Widget>[
                          const SizedBox(height: 8),

                          // Document Header Meta Card
                          _buildDocumentHeaderCard(
                            resolved: resolved,
                            glowActive: glowActive,
                            isAccepted: isAlreadyAccepted,
                          ),
                          const SizedBox(height: 14),

                          // Document Content Card (AAA Styled Markdown Viewer)
                          _buildMarkdownViewerCard(
                            resolved: resolved,
                            glowActive: glowActive,
                          ),
                          const SizedBox(height: 14),

                          // Trust Registry & Legal Footer Card
                          _buildLegalFooterCard(),
                          const SizedBox(height: 14),
                        ],
                      ),

                      // Quick Jump Floating Control
                      if (_readingProgress > 0.15 && !_reachedBottom)
                        Positioned(
                          right: 18,
                          bottom: needsAcceptance ? 140 : 24,
                          child: _buildQuickScrollButton(
                            icon: Icons.keyboard_double_arrow_down_rounded,
                            label: 'Sonuna Git',
                            onTap: _scrollToBottom,
                          ),
                        )
                      else if (_reachedBottom && _readingProgress >= 0.95)
                        Positioned(
                          right: 18,
                          bottom: needsAcceptance ? 140 : 24,
                          child: _buildQuickScrollButton(
                            icon: Icons.keyboard_double_arrow_up_rounded,
                            label: 'Başa Dön',
                            onTap: _scrollToTop,
                          ),
                        ),
                    ],
                  ),
                ),

                // Accept Terms Flow Docked Footer
                _buildAcceptTermsFooter(
                  resolved: resolved,
                  needsAcceptance: needsAcceptance,
                  isAccepted: isAlreadyAccepted,
                  glassBlur: glassBlur,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassmorphismAppBar({
    required LegalDocument resolved,
    required double glassBlur,
    required bool glowActive,
    required bool isAccepted,
  }) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                SettingsPalette.navy.withValues(alpha: 0.88),
                SettingsPalette.void_.withValues(alpha: 0.94),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: SettingsPalette.gold.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: <Widget>[
                    // Back button with pressable scale & haptics
                    SettingsPressable(
                      onTap: _goBack,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SettingsPalette.obsidian.withValues(alpha: 0.7),
                          border: Border.all(
                            color: SettingsPalette.gold.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 17,
                          color: SettingsPalette.textHi,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Document identity & title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                _documentCategoryLabel(resolved.type),
                                style: AppTextStyles.captionBold.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 1.1,
                                  color: SettingsPalette.gold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: SettingsPalette.obsidian.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: SettingsPalette.titanium.withValues(alpha: 0.25),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'v${resolved.version}',
                                  style: AppTextStyles.captionBold.copyWith(
                                    fontSize: 9.5,
                                    color: SettingsPalette.titanium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            resolved.title,
                            style: AppTextStyles.bodyBold.copyWith(
                              color: SettingsPalette.textHi,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Reading progress indicator pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: SettingsPalette.obsidian.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_reachedBottom ? SettingsPalette.neon : SettingsPalette.gold)
                              .withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _reachedBottom
                                ? Icons.check_circle_rounded
                                : Icons.chrome_reader_mode_outlined,
                            size: 13,
                            color: _reachedBottom
                                ? SettingsPalette.neon
                                : SettingsPalette.gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(_readingProgress * 100).toInt()}%',
                            style: AppTextStyles.captionBold.copyWith(
                              fontSize: 11,
                              color: _reachedBottom
                                  ? SettingsPalette.neon
                                  : SettingsPalette.textHi,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Attached animated reading progress line
              LinearProgressIndicator(
                value: _readingProgress,
                minHeight: 2.5,
                backgroundColor: SettingsPalette.obsidian.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _reachedBottom ? SettingsPalette.neon : SettingsPalette.gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentHeaderCard({
    required LegalDocument resolved,
    required bool glowActive,
    required bool isAccepted,
  }) {
    return SettingsGlassCard(
      accent: SettingsPalette.gold,
      glow: glowActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: <Color>[
                      SettingsPalette.gold.withValues(alpha: 0.25),
                      SettingsPalette.void_.withValues(alpha: 0.8),
                    ],
                  ),
                  border: Border.all(
                    color: SettingsPalette.gold.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _documentIcon(resolved.type),
                  color: SettingsPalette.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      resolved.title,
                      style: AppTextStyles.h3.copyWith(
                        color: SettingsPalette.textHi,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Resmi Hukuki Metin · Versiyon ${resolved.version}',
                      style: AppTextStyles.caption.copyWith(
                        color: SettingsPalette.titanium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isAccepted
                  ? SettingsPalette.neon.withValues(alpha: 0.1)
                  : SettingsPalette.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isAccepted
                    ? SettingsPalette.neon.withValues(alpha: 0.35)
                    : SettingsPalette.gold.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  isAccepted ? Icons.verified_rounded : Icons.pending_actions_rounded,
                  size: 16,
                  color: isAccepted ? SettingsPalette.neon : SettingsPalette.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAccepted
                        ? 'Bu sözleşme hesabınız tarafından onaylanmıştır.'
                        : 'Lütfen sözleşmeyi sonuna kadar okuyarak inceleyiniz.',
                    style: AppTextStyles.captionBold.copyWith(
                      fontSize: 11.5,
                      color: isAccepted ? SettingsPalette.neon : SettingsPalette.textHi,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownViewerCard({
    required LegalDocument resolved,
    required bool glowActive,
  }) {
    return SettingsGlassCard(
      accent: SettingsPalette.gold,
      glow: false,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'SÖZLEŞME METNİ',
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.gold,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),
              Text(
                'Sürüm ${resolved.version}',
                style: AppTextStyles.caption.copyWith(
                  color: SettingsPalette.titanium,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MarkdownBody(
            data: resolved.bodyMd.replaceAll('\\n', '\n'),
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: AppTextStyles.body.copyWith(
                color: SettingsPalette.textHi,
                fontSize: 14.5,
                height: 1.55,
              ),
              h1: AppTextStyles.h2.copyWith(
                color: SettingsPalette.gold,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
              h2: AppTextStyles.h3.copyWith(
                color: SettingsPalette.gold,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              h3: AppTextStyles.bodyBold.copyWith(
                color: SettingsPalette.textHi,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
              strong: AppTextStyles.bodyBold.copyWith(
                color: SettingsPalette.gold,
              ),
              em: AppTextStyles.body.copyWith(
                fontStyle: FontStyle.italic,
                color: SettingsPalette.titanium,
              ),
              listBullet: AppTextStyles.bodyBold.copyWith(
                color: SettingsPalette.gold,
                fontSize: 14,
              ),
              blockquote: AppTextStyles.body.copyWith(
                color: SettingsPalette.textMid,
                fontSize: 13.5,
                height: 1.45,
              ),
              blockquoteDecoration: BoxDecoration(
                color: SettingsPalette.obsidian.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: SettingsPalette.gold, width: 3.5),
                ),
              ),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: SettingsPalette.gold.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
              ),
              tableHead: AppTextStyles.captionBold.copyWith(
                color: SettingsPalette.gold,
                fontSize: 12.5,
              ),
              tableBody: AppTextStyles.caption.copyWith(
                color: SettingsPalette.textHi,
                fontSize: 12.5,
              ),
              tableBorder: TableBorder.all(
                color: SettingsPalette.gold.withValues(alpha: 0.3),
                width: 0.8,
              ),
              tableHeadAlign: TextAlign.left,
              tableCellsPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalFooterCard() {
    return SettingsGlassCard(
      accent: SettingsPalette.neon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.verified_user_outlined,
                color: SettingsPalette.neon,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'GKK Hukuk ve Uyumluluk Çerçevesi',
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.neon,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Destek ve bildirim: support@gkk.game · Uygulama içi Destek Talepleri üzerinden 7/24 resmi bildirim yapabilirsiniz.',
            style: supportCaptionStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickScrollButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SettingsPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: SettingsPalette.obsidian.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SettingsPalette.gold.withValues(alpha: 0.45),
                width: 1.1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16, color: SettingsPalette.gold),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.captionBold.copyWith(
                    color: SettingsPalette.gold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptTermsFooter({
    required LegalDocument resolved,
    required bool needsAcceptance,
    required bool isAccepted,
    required double glassBlur,
  }) {
    if (!needsAcceptance && isAccepted) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: SettingsPalette.navy.withValues(alpha: 0.92),
              border: Border(
                top: BorderSide(
                  color: SettingsPalette.neon.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.check_circle_rounded,
                  color: SettingsPalette.neon,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bu belge onaylanmıştır (v${resolved.version})',
                    style: AppTextStyles.captionBold.copyWith(
                      color: SettingsPalette.neon,
                    ),
                  ),
                ),
                SettingsPressable(
                  onTap: _goBack,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: SettingsPalette.obsidian.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: SettingsPalette.titanium.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Kapat',
                      style: AppTextStyles.captionBold.copyWith(
                        color: SettingsPalette.textHi,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!needsAcceptance) {
      return const SizedBox.shrink();
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                SettingsPalette.navy.withValues(alpha: 0.94),
                SettingsPalette.void_.withValues(alpha: 0.98),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: SettingsPalette.gold.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_errorMessage != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: SettingsPalette.ruby.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SettingsPalette.ruby.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.error_outline_rounded, size: 16, color: SettingsPalette.ruby),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.caption.copyWith(color: SettingsPalette.ruby),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!_reachedBottom) ...<Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline_rounded,
                      color: SettingsPalette.gold,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Onaylamak için metnin sonuna kaydırın (%${(_readingProgress * 100).toInt()})',
                        style: supportCaptionStyle,
                      ),
                    ),
                    TextButton(
                      onPressed: _scrollToBottom,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Sonuna Git',
                        style: AppTextStyles.captionBold.copyWith(
                          color: SettingsPalette.gold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ] else ...<Widget>[
                Row(
                  children: <Widget>[
                    Checkbox(
                      value: _termsAcceptedChecked,
                      onChanged: (bool? val) {
                        AppHaptics.selection();
                        setState(() => _termsAcceptedChecked = val ?? false);
                      },
                      activeColor: SettingsPalette.gold,
                      checkColor: SettingsPalette.void_,
                      side: BorderSide(
                        color: SettingsPalette.gold.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          AppHaptics.selection();
                          setState(() => _termsAcceptedChecked = !_termsAcceptedChecked);
                        },
                        child: Text(
                          'Sözleşme şartlarını okudum, anladım ve kabul ediyorum.',
                          style: AppTextStyles.caption.copyWith(
                            color: SettingsPalette.textHi,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              SettingsPrimaryButton(
                label: 'Sözleşmeyi Onayla ve Kabul Et',
                loading: _isAccepting,
                icon: Icons.verified_user_rounded,
                accent: SettingsPalette.gold,
                onPressed: _reachedBottom && _termsAcceptedChecked
                    ? () => _handleAccept(resolved.type)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

