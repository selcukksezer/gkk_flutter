import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

import '../../../core/services/app_haptics.dart';
import '../../../models/guild_model.dart';
import '../../../repositories/guild_monument_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import 'guild_design.dart';
import 'guild_monument_ui.dart';

String _formatCompactNum(int n) {
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// V3 AAA Cyber-Fantasy Luxury Guild Monument Hero Card.
///
/// Features:
/// - Frosted glassmorphism container with backdrop blur & multi-stop luminous metallic borders.
/// - Sacred Monument Artifact Sanctum emblem with anchored tier badge & cosmic radial aura.
/// - Guild War combat readiness buffs and echelon member status.
/// - Dynamic Level Progression Hub with high-fidelity glowing energy bar & resource breakdown chips.
/// - Luxury gold Tribute CTA with tactile [AppHaptics.medium] feedback.
/// - Ascended Cyber-Fuchsia Upgrade CTA with tactile [AppHaptics.heavy] feedback.
class GuildMonumentHeroCard extends StatelessWidget {
  const GuildMonumentHeroCard({
    super.key,
    required this.level,
    required this.memberCount,
    required this.upgradeProgress,
    required this.canUpgrade,
    required this.upgrading,
    required this.onDonate,
    required this.onUpgrade,
  });

  final int level;
  final int memberCount;
  final MonumentUpgradeProgress? upgradeProgress;
  final bool canUpgrade;
  final bool upgrading;
  final VoidCallback onDonate;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    const BorderRadius cardRadius = BorderRadius.all(Radius.circular(AppSpacing.radiusLg));

    return Container(
      decoration: BoxDecoration(
        borderRadius: cardRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: 0.16),
            blurRadius: 26,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: AppColors.cyberFuchsia.withValues(alpha: 0.10),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: cardRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: cardRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(0xFF161D2E).withValues(alpha: 0.90),
                  const Color(0xFF0F1524).withValues(alpha: 0.94),
                  const Color(0xFF090D18).withValues(alpha: 0.96),
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              ),
              border: Border.all(
                color: AppColors.liquidGold.withValues(alpha: 0.40),
                width: 1.3,
              ),
            ),
            child: CustomPaint(
              painter: const _MonumentAuraPainter(
                accentColor: AppColors.liquidGold,
                secondaryColor: AppColors.accentCyan,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Hero Top Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildMonumentEmblem(),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Combat buff & overline
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'KUTSAL LONCA ANITI',
                                      style: TextStyle(
                                        color: AppColors.accentCyan.withValues(alpha: 0.9),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.toxicNeon.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppColors.toxicNeon.withValues(alpha: 0.40),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '✦ +${level * 2}% SAVAŞ AURA',
                                      style: const TextStyle(
                                        color: AppColors.toxicNeon,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Seviye $level Anıt',
                                style: AppTextStyles.h2.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Lonca üyelerinin güçlerini birleştirerek yükselttiği kutsal savaş anıtı.',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.mutedTitanium,
                                  fontSize: 10.5,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _buildMemberStatusPill(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Progression Section
                    if (upgradeProgress != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _buildProgressionHub(context, upgradeProgress!),
                    ] else ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      _buildMaxLevelNotice(),
                    ],
                    // Action CTA Buttons
                    const SizedBox(height: AppSpacing.md),
                    _buildTributeButton(),
                    if (canUpgrade) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      _buildUpgradeButton(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonumentEmblem() {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        gradient: RadialGradient(
          center: const Alignment(0.0, -0.2),
          radius: 0.85,
          colors: <Color>[
            AppColors.cyberFuchsia.withValues(alpha: 0.35),
            AppColors.liquidGold.withValues(alpha: 0.18),
            const Color(0xFF090C16),
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: AppColors.cyberFuchsia.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Inner glowing sacred boundary ring
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.20),
                width: 1.0,
              ),
            ),
          ),
          // Central Monument Emblem Icon
          const Text(
            '🏛️',
            style: TextStyle(fontSize: 34),
          ),
          // Anchored Tier Badge Pill
          Positioned(
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFFFFDF6D),
                    AppColors.liquidGold,
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                'TIER $level',
                style: const TextStyle(
                  color: AppColors.carbonVoid,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.carbonVoid.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: AppColors.mutedTitanium.withValues(alpha: 0.20),
          width: 1.0,
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.people_alt_rounded, size: 12, color: AppColors.mutedTitanium),
          const SizedBox(width: 5),
          Text(
            '$memberCount / 50 Aktif Üye',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.liquidGold.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.shield_rounded, size: 12, color: AppColors.liquidGold),
          const SizedBox(width: 4),
          Text(
            guildSizeLabel(memberCount),
            style: const TextStyle(
              color: AppColors.liquidGold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionHub(BuildContext context, MonumentUpgradeProgress progress) {
    final bool isReady = progress.isReady;
    final Color accent = isReady ? AppColors.toxicNeon : AppColors.liquidGold;
    final double clampedProgress = progress.overallProgress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.carbonVoid.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.spaceNavy,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(color: AppColors.mutedTitanium.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'KADEME $level',
                      style: const TextStyle(
                        color: AppColors.mutedTitanium,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward_rounded, size: 10, color: AppColors.liquidGold),
                    ),
                    Text(
                      'KADEME ${progress.nextLevel}',
                      style: const TextStyle(
                        color: AppColors.liquidGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                  boxShadow: isReady
                      ? <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isReady ? Icons.check_circle_rounded : Icons.bolt_rounded,
                      size: 11,
                      color: accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isReady ? 'YÜKSELTME HAZIR' : '%${progress.filledPercent} TAMAMLANDI',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // High-Fidelity Energy Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: SizedBox(
              height: 9,
              child: Stack(
                children: <Widget>[
                  Container(
                    color: AppColors.darkObsidian.withValues(alpha: 0.8),
                  ),
                  FractionallySizedBox(
                    widthFactor: clampedProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isReady
                              ? <Color>[
                                  AppColors.toxicNeon.withValues(alpha: 0.85),
                                  AppColors.toxicNeon,
                                  Colors.white,
                                ]
                              : <Color>[
                                  AppColors.liquidGold,
                                  const Color(0xFFFFD64A),
                                  AppColors.accentCyan,
                                ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.55),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Specular Gloss Top Stripe
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 3,
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (progress.resources.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: progress.resources.map(_buildResourcePill).toList(),
            ),
          ],
          if (progress.blueprintRequired && !progress.blueprintComplete) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cyberFuchsia.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.cyberFuchsia.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.architecture_rounded, size: 12, color: AppColors.cyberFuchsia),
                  const SizedBox(width: 5),
                  Text(
                    'Gerekli Şema: ${progress.blueprintType ?? "Kademe Şeması"}',
                    style: const TextStyle(
                      color: AppColors.cyberFuchsia,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResourcePill(MonumentResourceProgress resource) {
    final bool isComplete = resource.isComplete;
    final String label = resource.kind.shortLabel;
    final String current = resource.kind == MonumentResourceKind.gold
        ? _formatCompactNum(resource.current)
        : '${resource.current}';
    final String req = resource.kind == MonumentResourceKind.gold
        ? _formatCompactNum(resource.required)
        : '${resource.required}';
    final String remain = resource.kind == MonumentResourceKind.gold
        ? _formatCompactNum(resource.remaining)
        : '${resource.remaining}';

    final Color statusColor = isComplete ? AppColors.toxicNeon : AppColors.liquidGold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isComplete ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: statusColor.withValues(alpha: isComplete ? 0.35 : 0.20),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isComplete ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 11,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            '$label $current/$req',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isComplete ? AppColors.textPrimary : AppColors.mutedTitanium,
            ),
          ),
          if (!isComplete && resource.remaining > 0) ...<Widget>[
            const SizedBox(width: 3),
            Text(
              '(−$remain)',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.coralFlare,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaxLevelNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.liquidGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.star_rounded, size: 14, color: AppColors.liquidGold),
          SizedBox(width: 6),
          Text(
            'ANIT MAKSİMUM KADEMEYE ULAŞTI',
            style: TextStyle(
              color: AppColors.liquidGold,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.star_rounded, size: 14, color: AppColors.liquidGold),
        ],
      ),
    );
  }

  Widget _buildTributeButton() {
    return GuildPressable(
      onTap: () {
        AppHaptics.medium();
        onDonate();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFDF6D),
              AppColors.liquidGold,
              Color(0xFFE08A00),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.liquidGold.withValues(alpha: 0.38),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.65), width: 1.2),
            left: BorderSide(color: Colors.white.withValues(alpha: 0.30), width: 0.8),
            right: BorderSide(color: Colors.black.withValues(alpha: 0.20), width: 0.8),
            bottom: BorderSide(color: Colors.black.withValues(alpha: 0.30), width: 1.2),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.volunteer_activism_rounded, size: 18, color: AppColors.carbonVoid),
            SizedBox(width: 8),
            Text(
              'ANITA ADAN (BAĞIŞ YAP)',
              style: TextStyle(
                color: AppColors.carbonVoid,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.carbonVoid),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeButton() {
    return GuildPressable(
      enabled: !upgrading,
      onTap: upgrading
          ? null
          : () {
              AppHaptics.heavy();
              onUpgrade();
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: upgrading
                ? <Color>[
                    AppColors.darkObsidian,
                    AppColors.spaceNavy,
                  ]
                : <Color>[
                    const Color(0xFFFF3377),
                    AppColors.cyberFuchsia,
                    const Color(0xFF900B36),
                  ],
          ),
          boxShadow: upgrading
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: AppColors.cyberFuchsia.withValues(alpha: 0.42),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
          border: Border(
            top: BorderSide(
              color: upgrading ? Colors.transparent : Colors.white.withValues(alpha: 0.60),
              width: 1.2,
            ),
            left: BorderSide(
              color: upgrading ? Colors.transparent : Colors.white.withValues(alpha: 0.25),
              width: 0.8,
            ),
            bottom: BorderSide(
              color: upgrading ? Colors.transparent : Colors.black.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (upgrading) ...<Widget>[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'KADEME YÜKSELTİLİYOR…',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ] else ...<Widget>[
              const Icon(Icons.upgrade_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'ANITI YÜKSELT (KADEME ${level + 1})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.bolt_rounded, size: 16, color: AppColors.liquidGold),
            ],
          ],
        ),
      ),
    );
  }
}

/// Custom painter for cyber-fantasy sacred monument aura, specular highlights,
/// corner rune brackets, and cosmic particle nodes.
class _MonumentAuraPainter extends CustomPainter {
  const _MonumentAuraPainter({
    required this.accentColor,
    required this.secondaryColor,
  });

  final Color accentColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Rect rect = Offset.zero & size;

    // 1. Subtle Radial Cosmic Aura at top-left behind monument icon
    final Paint auraPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.65, -0.65),
        radius: 0.85,
        colors: <Color>[
          accentColor.withValues(alpha: 0.14),
          secondaryColor.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, auraPaint);

    // 2. Specular Diamond Top Highlight
    final Paint topSpecularPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.transparent,
          secondaryColor.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.90),
          accentColor.withValues(alpha: 0.65),
          Colors.transparent,
        ],
        stops: const <double>[0.05, 0.25, 0.50, 0.75, 0.95],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2));

    final Path topPath = Path()
      ..moveTo(18, 0.6)
      ..lineTo(size.width - 18, 0.6);
    canvas.drawPath(topPath, topSpecularPaint);

    // 3. Cyber-Rune Corner Accents (top-right and bottom-left)
    final Paint runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accentColor.withValues(alpha: 0.35);

    // Top-right corner rune notch
    final double trX = size.width - 14;
    canvas.drawLine(Offset(trX - 8, 8), Offset(trX, 8), runePaint);
    canvas.drawLine(Offset(trX, 8), Offset(trX, 16), runePaint);

    // Bottom-left corner rune notch
    canvas.drawLine(Offset(14, size.height - 16), Offset(14, size.height - 8), runePaint);
    canvas.drawLine(Offset(14, size.height - 8), Offset(22, size.height - 8), runePaint);

    // 4. Subtle ambient celestial dust particle nodes
    final Paint particlePaint = Paint()..style = PaintingStyle.fill;
    const List<Offset> particles = <Offset>[
      Offset(30, 24),
      Offset(65, 14),
      Offset(115, 28),
      Offset(140, 16),
      Offset(85, 82),
    ];

    for (int i = 0; i < particles.length; i++) {
      final Offset p = particles[i];
      if (p.dx < size.width && p.dy < size.height) {
        final double radius = (i % 2 == 0) ? 1.2 : 0.8;
        final double opacity = (i % 2 == 0) ? 0.35 : 0.22;
        particlePaint.color = (i % 2 == 0 ? accentColor : secondaryColor).withValues(alpha: opacity);
        canvas.drawCircle(p, radius, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MonumentAuraPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

