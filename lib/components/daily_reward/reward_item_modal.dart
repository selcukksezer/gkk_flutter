import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/daily_reward_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../common/item_icon_view.dart';
import 'daily_reward_vfx_models.dart';

/// 2027 Aion 2 Mobile dark-fantasy floating reward presentation modal.
///
/// Upgraded with:
/// - Obsidian frosted glass modal dialog with [BackdropFilter] gaussian blur.
/// - Item pedestal with celestial gold (#E5C158) radiance and cyan ether (#00E5FF) particle halo.
/// - Dynamic rarity border glow shadows and multi-tier ambient aura.
/// - Full [SafeArea] inset preservation with responsive scroll viewport.
/// - [HapticFeedback.mediumImpact] on inspect and claim actions.
class RewardItemModal extends StatefulWidget {
  const RewardItemModal({
    super.key,
    required this.grant,
    required this.onCollect,
    this.isClaiming = false,
  });

  final DailyRewardGrant grant;
  final VoidCallback onCollect;
  final bool isClaiming;

  @override
  State<RewardItemModal> createState() => _RewardItemModalState();
}

class _RewardItemModalState extends State<RewardItemModal>
    with TickerProviderStateMixin {
  // ─── 2027 Aion 2 Color Palette ───────────────────────────────────────────
  static const Color celestialGold = Color(0xFFE5C158);
  static const Color cyanEther = Color(0xFF00E5FF);
  static const Color obsidianVoid = Color(0xFF070A10);
  static const Color obsidianSurface = Color(0xFF0F1522);
  static const Color obsidianGlass = Color(0xFF141C2E);

  // ─── Animation Controllers ───────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  late final AnimationController _ambientCtrl;
  late final AnimationController _inspectPulseCtrl;
  late final Animation<double> _inspectPulseAnim;

  // Orbiting halo particles
  late final List<_HaloParticle> _particles;

  @override
  void initState() {
    super.initState();

    // 1. Entrance modal spring
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOut,
    );

    // 2. Ambient continuous loop for pedestal radiance & cyan ether particle halo
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // 3. Tactile inspect pulse on pedestal interaction
    _inspectPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _inspectPulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(
        parent: _inspectPulseCtrl,
        curve: Curves.easeInOut,
      ),
    );

    // Generate deterministic celestial gold & cyan ether halo particles
    final math.Random rng = math.Random(widget.grant.cycleDay * 37 + 101);
    _particles = List<_HaloParticle>.generate(22, (int index) {
      final bool isGold = index % 3 == 0;
      return _HaloParticle(
        radiusX: 52.0 + rng.nextDouble() * 26.0,
        radiusY: 22.0 + rng.nextDouble() * 14.0,
        initialAngle: rng.nextDouble() * 2 * math.pi,
        speed: (rng.nextBool() ? 1.0 : -1.0) * (0.8 + rng.nextDouble() * 0.9),
        size: isGold ? (2.2 + rng.nextDouble() * 2.2) : (1.8 + rng.nextDouble() * 2.6),
        color: isGold ? celestialGold : cyanEther,
        pulseOffset: rng.nextDouble() * math.pi * 2,
      );
    });

    _entranceCtrl.forward();

    // HapticFeedback.mediumImpact() on inspect upon modal presentation
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _ambientCtrl.dispose();
    _inspectPulseCtrl.dispose();
    super.dispose();
  }

  DailyRewardRarity get rarity => DailyRewardRarity.fromGrant(widget.grant);

  void _handleInspectTap() {
    HapticFeedback.mediumImpact();
    _inspectPulseCtrl.forward(from: 0.0).then((_) {
      if (mounted) {
        _inspectPulseCtrl.reverse();
      }
    });
  }

  void _handleCollect() {
    if (widget.isClaiming) return;
    // HapticFeedback.mediumImpact() on claim action
    HapticFeedback.mediumImpact();
    widget.onCollect();
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final DailyRewardGrant grant = widget.grant;
    final DailyRewardRarity r = rarity;
    final Color rarityColor = r.primaryColor;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        maintainBottomViewPadding: true,
        minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 390,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildObsidianGlassCard(context, grant, r, rarityColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the 2027 Aion 2 Obsidian Frosted Glass card with multi-tier glow shadows.
  Widget _buildObsidianGlassCard(
    BuildContext context,
    DailyRewardGrant grant,
    DailyRewardRarity r,
    Color rarityColor,
  ) {
    // Dynamic rarity border glow shadows
    final List<BoxShadow> dialogShadows = <BoxShadow>[
      // Ambient rarity atmospheric bloom
      BoxShadow(
        color: r.glowColor.withValues(alpha: 0.40),
        blurRadius: 42,
        spreadRadius: 2,
      ),
      // Celestial gold warm underglow
      BoxShadow(
        color: celestialGold.withValues(alpha: 0.20),
        blurRadius: 26,
        spreadRadius: -2,
      ),
      // Cyan ether ethereal aura
      BoxShadow(
        color: cyanEther.withValues(alpha: 0.16),
        blurRadius: 20,
        spreadRadius: -4,
      ),
      // Deep obsidian elevation shadow
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.85),
        blurRadius: 30,
        offset: const Offset(0, 14),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        boxShadow: dialogShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: CustomPaint(
            foregroundPainter: _ObsidianGlassBorderPainter(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
              borderWidth: 1.8,
              rarityColor: rarityColor,
              celestialGold: celestialGold,
              cyanEther: cyanEther,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    obsidianGlass.withValues(alpha: 0.85),
                    obsidianSurface.withValues(alpha: 0.92),
                    obsidianVoid.withValues(alpha: 0.96),
                  ],
                  stops: const <double>[0.0, 0.45, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // 1. Rarity Badge Pill with Celestial Gold & Cyan Accents
                  _buildRarityPill(r, rarityColor),
                  const SizedBox(height: 18),

                  // 2. Item Pedestal with Celestial Gold Radiance & Cyan Ether Particle Halo
                  GestureDetector(
                    onTap: _handleInspectTap,
                    behavior: HitTestBehavior.opaque,
                    child: _buildItemPedestalWithHalo(grant, rarityColor),
                  ),
                  const SizedBox(height: 16),

                  // 3. Item Title / Name
                  Text(
                    grant.hasItem
                        ? (grant.itemName ?? grant.itemId ?? 'Kadim Eşya')
                        : grant.displayLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.urbanist(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      shadows: <Shadow>[
                        Shadow(
                          color: rarityColor.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 4. Subtitle Lore or Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _getRewardLore(grant, r),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 5. Detailed Stats / Grants Breakdown Grid
                  _buildStatsBreakdown(grant, rarityColor),
                  const SizedBox(height: 22),

                  // 6. Collect CTA Button with Celestial Luminescence
                  _buildCollectCTA(rarityColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the top Rarity Badge Pill.
  Widget _buildRarityPill(DailyRewardRarity r, Color rarityColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: obsidianVoid.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: rarityColor.withValues(alpha: 0.25),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Celestial gold star icon
          const Text(
            '★',
            style: TextStyle(
              color: celestialGold,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${r.label} ÖDÜL',
            style: GoogleFonts.urbanist(
              color: rarityColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 4),
          // Cyan ether energy spark
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: cyanEther,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: cyanEther,
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the 2027 Aion 2 Item Pedestal with Celestial Gold Radiance and Cyan Ether Particle Halo.
  Widget _buildItemPedestalWithHalo(
    DailyRewardGrant grant,
    Color rarityColor,
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_ambientCtrl, _inspectPulseCtrl]),
      builder: (BuildContext context, Widget? child) {
        final double ambientVal = _ambientCtrl.value;
        final double inspectScale = _inspectPulseAnim.value;

        return SizedBox(
          width: 200,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Animated Altar Pedestal & Particle Halo CustomPainter
              Positioned.fill(
                child: CustomPaint(
                  painter: _Aion2PedestalAndHaloPainter(
                    animationProgress: ambientVal,
                    particles: _particles,
                    rarityColor: rarityColor,
                    celestialGold: celestialGold,
                    cyanEther: cyanEther,
                  ),
                ),
              ),

              // Floating Item Icon anchored on pedestal
              Positioned(
                top: 18,
                child: Transform.scale(
                  scale: inspectScale,
                  child: _buildItemIcon(grant, rarityColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the item icon presentation with glassmorphic backing & rarity rim.
  Widget _buildItemIcon(DailyRewardGrant grant, Color rarityColor) {
    final Widget iconContent;

    if (grant.hasItem && grant.itemId != null) {
      iconContent = ItemIconView(
        iconValue: grant.itemId!,
        itemId: grant.itemId,
        size: 58,
        fallback: '📦',
      );
    } else {
      String emoji = '🪙';
      if (grant.gems >= 20) {
        emoji = '💎';
      } else if (grant.gems > 0) {
        emoji = '💠';
      } else if (grant.energy > 0) {
        emoji = '⚡';
      } else if (grant.gold >= 25000) {
        emoji = '👑';
      }

      iconContent = Text(
        emoji,
        style: const TextStyle(fontSize: 44),
      );
    }

    return Container(
      width: 86,
      height: 86,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: obsidianVoid.withValues(alpha: 0.82),
        shape: BoxShape.circle,
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.90),
          width: 2.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: rarityColor.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: celestialGold.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      child: iconContent,
    );
  }

  /// Builds the detailed Stats / Grants breakdown cards.
  Widget _buildStatsBreakdown(DailyRewardGrant grant, Color rarityColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: obsidianVoid.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.borderDefault.withValues(alpha: 0.65),
          width: 1.0,
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: <Widget>[
          if (grant.gold > 0)
            _statBadge(
              '🪙',
              '+${_formatNumber(grant.gold)} Altın',
              celestialGold,
            ),
          if (grant.gems > 0)
            _statBadge(
              '💎',
              '+${grant.gems} Elmas',
              cyanEther,
            ),
          if (grant.xp > 0)
            _statBadge(
              '⭐',
              '+${_formatNumber(grant.xp)} XP',
              AppColors.liquidGold,
            ),
          if (grant.energy > 0)
            _statBadge(
              '⚡',
              '+${grant.energy} Enerji',
              AppColors.accentCyan,
            ),
          if (grant.hasItem)
            _statBadge(
              '📦',
              'x${grant.itemQuantity} Adet',
              rarityColor,
            ),
        ],
      ),
    );
  }

  /// Stat badge with frosted glass backing and glowing border.
  Widget _statBadge(String emoji, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.45),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.urbanist(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Collect CTA Button with luminous celestial gradient.
  Widget _buildCollectCTA(Color rarityColor) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          gradient: LinearGradient(
            colors: <Color>[
              celestialGold,
              rarityColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.50),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: celestialGold.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            onTap: widget.isClaiming ? null : _handleCollect,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: widget.isClaiming
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF0F1523),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 20,
                          color: Color(0xFF0F1523),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ödülü Topla',
                          style: GoogleFonts.urbanist(
                            color: const Color(0xFF0F1523),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.8,
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

  String _getRewardLore(DailyRewardGrant grant, DailyRewardRarity r) {
    if (grant.cycleDay == 28) {
      return '28 günlük sadakat döngüsünün yüce efendisine layık efsanevi hazine sandığı lütfu.';
    }
    if (grant.cycleDay % 7 == 0 || grant.isMilestone) {
      return 'Haftalık zafer kilometre taşı sandığından fışkıran bereketli güç ve ganimetler.';
    }
    if (grant.hasItem) {
      return 'Envanterine katılmaya hazır, savaş gücünü pekiştirecek özel ekipman parçası.';
    }
    return 'Giriş serin devam ediyor! Krallığın seni ödüllendirdiği günlük lütuf payı.';
  }
}

/// Particle descriptor for the cyan ether & celestial gold particle halo.
class _HaloParticle {
  _HaloParticle({
    required this.radiusX,
    required this.radiusY,
    required this.initialAngle,
    required this.speed,
    required this.size,
    required this.color,
    required this.pulseOffset,
  });

  final double radiusX;
  final double radiusY;
  final double initialAngle;
  final double speed;
  final double size;
  final Color color;
  final double pulseOffset;
}

/// CustomPainter rendering the 2027 Aion 2 Item Pedestal and ethereal halo VFX.
class _Aion2PedestalAndHaloPainter extends CustomPainter {
  const _Aion2PedestalAndHaloPainter({
    required this.animationProgress,
    required this.particles,
    required this.rarityColor,
    required this.celestialGold,
    required this.cyanEther,
  });

  final double animationProgress;
  final List<_HaloParticle> particles;
  final Color rarityColor;
  final Color celestialGold;
  final Color cyanEther;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Offset pedestalCenter = Offset(size.width / 2, size.height * 0.72);

    // 1. Upward Celestial Gold Radiance Spotlight
    final double pulse = 0.85 + 0.15 * math.sin(animationProgress * math.pi * 2);
    final Rect radianceRect = Rect.fromCenter(
      center: Offset(pedestalCenter.dx, pedestalCenter.dy - 20),
      width: 140 * pulse,
      height: 120 * pulse,
    );

    final Paint radiancePaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          celestialGold.withValues(alpha: 0.32 * pulse),
          cyanEther.withValues(alpha: 0.14 * pulse),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(radianceRect);

    canvas.drawOval(radianceRect, radiancePaint);

    // 2. Pedestal Base Tier 2 (Lower Ellipse with Cyan Ether Inlay)
    final Rect baseRect2 = Rect.fromCenter(
      center: pedestalCenter.translate(0, 8),
      width: 130,
      height: 28,
    );
    final Paint basePaint2 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF161F30),
          const Color(0xFF080C14),
        ],
      ).createShader(baseRect2);

    canvas.drawOval(baseRect2, basePaint2);

    final Paint baseStroke2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = LinearGradient(
        colors: <Color>[
          cyanEther.withValues(alpha: 0.65),
          cyanEther.withValues(alpha: 0.15),
          cyanEther.withValues(alpha: 0.50),
        ],
      ).createShader(baseRect2);

    canvas.drawOval(baseRect2, baseStroke2);

    // 3. Pedestal Platform Tier 1 (Upper Stepped Platform with Celestial Gold Rim)
    final Rect baseRect1 = Rect.fromCenter(
      center: pedestalCenter,
      width: 104,
      height: 22,
    );
    final Paint basePaint1 = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF222E46),
          const Color(0xFF0C121D),
        ],
      ).createShader(baseRect1);

    canvas.drawOval(baseRect1, basePaint1);

    final Paint baseStroke1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.8),
          celestialGold,
          rarityColor,
          celestialGold.withValues(alpha: 0.4),
        ],
      ).createShader(baseRect1);

    canvas.drawOval(baseRect1, baseStroke1);

    // 4. Orbiting Cyan Ether & Celestial Gold Particles Halo
    for (final _HaloParticle p in particles) {
      final double currentAngle =
          p.initialAngle + (animationProgress * 2 * math.pi * p.speed);
      final double px = center.dx + math.cos(currentAngle) * p.radiusX;
      // Slight vertical perspective tilt centered on pedestal
      final double py = (pedestalCenter.dy - 24) + math.sin(currentAngle) * p.radiusY;

      final double particlePulse =
          0.45 + 0.55 * (0.5 + 0.5 * math.sin(animationProgress * 2 * math.pi + p.pulseOffset));
      final double currentSize = p.size * (0.8 + 0.3 * particlePulse);

      // Particle outer soft aura
      final Paint glowPaint = Paint()
        ..color = p.color.withValues(alpha: 0.35 * particlePulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawCircle(Offset(px, py), currentSize * 1.8, glowPaint);

      // Particle bright inner core
      final Paint corePaint = Paint()
        ..color = p.color.withValues(alpha: 0.90 * particlePulse);
      canvas.drawCircle(Offset(px, py), currentSize, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Aion2PedestalAndHaloPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.rarityColor != rarityColor;
  }
}

/// CustomPainter rendering the obsidian glass specular border and top glint highlight.
class _ObsidianGlassBorderPainter extends CustomPainter {
  const _ObsidianGlassBorderPainter({
    required this.borderRadius,
    required this.borderWidth,
    required this.rarityColor,
    required this.celestialGold,
    required this.cyanEther,
  });

  final BorderRadius borderRadius;
  final double borderWidth;
  final Color rarityColor;
  final Color celestialGold;
  final Color cyanEther;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Rect rect = Offset.zero & size;
    final RRect rrect = borderRadius.toRRect(rect).deflate(borderWidth / 2);

    // 1. Multi-tone Gradient Border (Specular White -> Celestial Gold -> Rarity -> Cyan Ether)
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.40),
          celestialGold.withValues(alpha: 0.75),
          rarityColor.withValues(alpha: 0.65),
          cyanEther.withValues(alpha: 0.40),
          Colors.white.withValues(alpha: 0.15),
        ],
        stops: const <double>[0.0, 0.22, 0.55, 0.82, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, borderPaint);

    // 2. Top Edge Specular Glint Reflection Line
    final double topY = borderWidth / 2 + 0.5;
    final double startX = borderRadius.topLeft.x + 6.0;
    final double endX = size.width - borderRadius.topRight.x - 6.0;

    if (endX > startX) {
      final Paint glintPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.55),
            celestialGold.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(Rect.fromLTWH(startX, topY, endX - startX, 1.2));

      canvas.drawLine(Offset(startX, topY), Offset(endX, topY), glintPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ObsidianGlassBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.rarityColor != rarityColor;
  }
}
