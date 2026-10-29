import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../models/announcement_models.dart';
import '../services/announcements_repository.dart';

/// Modal dialog displaying high-fidelity reward claim presentation and celebratory feedback.
class EventGiftClaimSheet extends StatefulWidget {
  const EventGiftClaimSheet({
    super.key,
    required this.item,
  });

  final AnnouncementItem item;

  static Future<void> show({
    required BuildContext context,
    required AnnouncementItem item,
    required WidgetRef ref,
  }) async {
    // Multi-tier haptic feedback: medium impact on claim reward action
    HapticFeedback.mediumImpact();
    final bool claimed = await ref
        .read(announcementsControllerProvider.notifier)
        .claimGift(item.id);

    if (!context.mounted) return;

    if (claimed) {
      await HapticFeedback.heavyImpact();
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useRootNavigator: true,
        barrierColor: Colors.black.withValues(alpha: 0.82),
        builder: (BuildContext ctx) => EventGiftClaimSheet(item: item),
      );
    } else {
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.title} ödülü zaten daha önce alındı!'),
          backgroundColor: AppColors.spaceNavy,
        ),
      );
    }
  }

  @override
  State<EventGiftClaimSheet> createState() => _EventGiftClaimSheetState();
}

class _EventGiftClaimSheetState extends State<EventGiftClaimSheet>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _ambientController;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _confettiAnim;
  final ScrollController _scrollController = ScrollController();
  final List<_ConfettiParticle> _particles = <_ConfettiParticle>[];

  @override
  void initState() {
    super.initState();
    _initParticles();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _scaleAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    );

    _confettiAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutQuad,
    );

    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOutSine),
    );

    _floatAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOutSine),
    );

    _entranceController.forward();
    // Tactile presentation feedback on celebratory gift presentation
    HapticFeedback.heavyImpact();
  }

  void _initParticles() {
    final math.Random random = math.Random(1337);
    final List<Color> palette = <Color>[
      AppColors.liquidGold,
      AppColors.goldLight,
      AppColors.accentCyan,
      AppColors.cyberFuchsia,
      Colors.white,
      const Color(0xFFFFD54F),
      const Color(0xFF80DEEA),
    ];

    const int count = 46;
    for (int i = 0; i < count; i++) {
      // Upward burst bias
      final double angle =
          -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 1.5;
      final double speed = 0.6 + random.nextDouble() * 1.2;
      final double gravity = 0.6 + random.nextDouble() * 0.8;
      final double size = 4.0 + random.nextDouble() * 6.5;
      final Color color = palette[random.nextInt(palette.length)];
      final double rotationSpeed = (random.nextDouble() - 0.5) * 4.0;
      final int type = random.nextInt(4);
      final double delay = random.nextDouble() * 0.22;

      _particles.add(
        _ConfettiParticle(
          angle: angle,
          speed: speed,
          gravity: gravity,
          size: size,
          color: color,
          rotationSpeed: rotationSpeed,
          type: type,
          delay: delay,
        ),
      );
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static String _rarityName(String rarity) {
    return switch (rarity.toLowerCase()) {
      'mythic' => 'MİTİK',
      'legendary' => 'EFSANEVİ',
      'epic' => 'DESTANSI',
      'rare' => 'NADİR',
      'uncommon' => 'SIRA DIŞI',
      _ => 'YAYGIN',
    };
  }

  @override
  Widget build(BuildContext context) {
    final AnnouncementItem item = widget.item;
    final Size screenSize = MediaQuery.of(context).size;
    final double maxSheetHeight = screenSize.height * 0.88;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: maxSheetHeight,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFA0E1528),
                    Color(0xF80A0F1F),
                    Color(0xFD05070E),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(
                  color: AppColors.liquidGold.withValues(alpha: 0.50),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.22),
                    blurRadius: 40,
                    spreadRadius: 2,
                    offset: const Offset(0, -6),
                  ),
                  BoxShadow(
                    color: AppColors.accentCyan.withValues(alpha: 0.10),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, -3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.88),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  // 1. Procedural Corner Filigree Accents
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ModalCornerFiligreePainter(
                          accentColor: AppColors.liquidGold,
                        ),
                      ),
                    ),
                  ),

                  // 2. Celebration Confetti Explosion Layer
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _confettiAnim,
                        builder: (BuildContext context, Widget? child) {
                          return CustomPaint(
                            painter: _CelebrationConfettiPainter(
                              progress: _confettiAnim.value,
                              particles: _particles,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 3. Main Modal Foreground Content
                  SafeArea(
                    top: false,
                    bottom: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // Specular Gold Handle
                            Container(
                              width: 44,
                              height: 4.5,
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    AppColors.liquidGold.withValues(alpha: 0.35),
                                    Colors.white70,
                                    AppColors.liquidGold.withValues(alpha: 0.35),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: AppColors.liquidGold.withValues(alpha: 0.35),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),

                            // Luminous Reliquary / Reward Chest Presentation
                            SizedBox(
                              width: 130,
                              height: 130,
                              child: Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  // Rotating Celestial Sunburst Rays
                                  AnimatedBuilder(
                                    animation: _ambientController,
                                    builder: (BuildContext context, Widget? child) {
                                      return CustomPaint(
                                        size: const Size(130, 130),
                                        painter: _CelestialSunburstPainter(
                                          rotation: _ambientController.value,
                                          color: AppColors.liquidGold,
                                        ),
                                      );
                                    },
                                  ),

                                  // Celestial Sigil Ornament Rings
                                  AnimatedBuilder(
                                    animation: _glowAnim,
                                    builder: (BuildContext context, Widget? child) {
                                      return CustomPaint(
                                        size: const Size(122, 122),
                                        painter: _CelestialOrnamentPainter(
                                          accentColor: AppColors.liquidGold,
                                          pulse: _glowAnim.value,
                                        ),
                                      );
                                    },
                                  ),

                                  // Floating Luminous Reliquary Chest Orb
                                  AnimatedBuilder(
                                    animation: _floatAnim,
                                    builder: (BuildContext context, Widget? child) {
                                      return Transform.translate(
                                        offset: Offset(0, _floatAnim.value),
                                        child: Container(
                                          width: 76,
                                          height: 76,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const RadialGradient(
                                              colors: <Color>[
                                                Color(0xFFFFF8E1),
                                                Color(0xFFFFD54F),
                                                Color(0xFFFF8F00),
                                                Color(0xFFE65100),
                                                Color(0xFF261805),
                                              ],
                                              stops: <double>[0.0, 0.35, 0.65, 0.88, 1.0],
                                            ),
                                            border: Border.all(
                                              color: AppColors.liquidGold,
                                              width: 2.4,
                                            ),
                                            boxShadow: <BoxShadow>[
                                              BoxShadow(
                                                color: AppColors.liquidGold.withValues(alpha: 0.55),
                                                blurRadius: 24,
                                                spreadRadius: 2,
                                              ),
                                              BoxShadow(
                                                color: AppColors.accentCyan.withValues(alpha: 0.30),
                                                blurRadius: 14,
                                                spreadRadius: -2,
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: <Widget>[
                                              // Inner specular highlight
                                              Positioned(
                                                top: 6,
                                                child: Container(
                                                  width: 32,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(10),
                                                    color: Colors.white.withValues(alpha: 0.40),
                                                  ),
                                                ),
                                              ),
                                              const Icon(
                                                Icons.card_giftcard_rounded,
                                                size: 38,
                                                color: Color(0xFF231405),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Title Banner Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    AppColors.liquidGold.withValues(alpha: 0.22),
                                    AppColors.liquidGold.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: AppColors.liquidGold.withValues(alpha: 0.45),
                                  width: 0.9,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: AppColors.liquidGold.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Text(
                                '✦ ETKİNLİK ÖDÜLÜ ALINDI ✦',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.liquidGold,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: Colors.black54,
                                    offset: Offset(0, 1.5),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),

                            const Text(
                              'Kazanılan eşyalar başarıyla envanterinize aktarıldı.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Rewards List with Staggered Animations & Bento Card Presentation
                            Flexible(
                              child: ListView.separated(
                                controller: _scrollController,
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: item.rewards.length,
                                separatorBuilder: (_, int index) => const SizedBox(height: 10),
                                itemBuilder: (BuildContext context, int index) {
                                  final EventRewardItem reward = item.rewards[index];
                                  final double start = (0.2 + (index * 0.08)).clamp(0.0, 0.7);
                                  final double end = (start + 0.35).clamp(0.0, 1.0);
                                  final Animation<double> itemAnim = CurvedAnimation(
                                    parent: _entranceController,
                                    curve: Interval(start, end, curve: Curves.easeOutCubic),
                                  );

                                  return AnimatedBuilder(
                                    animation: itemAnim,
                                    builder: (BuildContext context, Widget? child) {
                                      return Transform.translate(
                                        offset: Offset(0, (1.0 - itemAnim.value) * 20),
                                        child: Opacity(
                                          opacity: itemAnim.value,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => HapticFeedback.selectionClick(),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: <Color>[
                                                const Color(0xF0141D30),
                                                const Color(0xDC0F1524),
                                                reward.rarityColor.withValues(alpha: 0.08),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: reward.rarityColor.withValues(alpha: 0.65),
                                              width: 1.2,
                                            ),
                                            boxShadow: <BoxShadow>[
                                              BoxShadow(
                                                color: reward.rarityColor.withValues(alpha: 0.20),
                                                blurRadius: 12,
                                                offset: const Offset(0, 3),
                                              ),
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.55),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: <Widget>[
                                              // Rarity Icon Vault with Jewel Rim
                                              Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  gradient: RadialGradient(
                                                    colors: <Color>[
                                                      reward.rarityColor.withValues(alpha: 0.32),
                                                      reward.rarityColor.withValues(alpha: 0.12),
                                                      const Color(0x33000000),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: reward.rarityColor.withValues(alpha: 0.75),
                                                    width: 1.5,
                                                  ),
                                                  boxShadow: <BoxShadow>[
                                                    BoxShadow(
                                                      color: reward.rarityColor.withValues(alpha: 0.30),
                                                      blurRadius: 10,
                                                    ),
                                                  ],
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  reward.icon,
                                                  style: const TextStyle(fontSize: 26),
                                                ),
                                              ),
                                              const SizedBox(width: 14),

                                              // Item name, rarity tag & description
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    Row(
                                                      children: <Widget>[
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                          margin: const EdgeInsets.only(right: 6),
                                                          decoration: BoxDecoration(
                                                            color: reward.rarityColor.withValues(alpha: 0.20),
                                                            borderRadius: BorderRadius.circular(5),
                                                            border: Border.all(
                                                              color: reward.rarityColor.withValues(alpha: 0.60),
                                                              width: 0.8,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            _rarityName(reward.rarity),
                                                            style: TextStyle(
                                                              color: reward.rarityColor,
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.w900,
                                                              letterSpacing: 0.6,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            reward.name,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(
                                                              color: AppColors.textPrimary,
                                                              fontSize: 14.5,
                                                              fontWeight: FontWeight.w700,
                                                              letterSpacing: 0.2,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (reward.description.isNotEmpty) ...<Widget>[
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        reward.description,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: AppColors.textSecondary,
                                                          fontSize: 11.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),

                                              // Quantity Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 11,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: <Color>[
                                                      AppColors.liquidGold.withValues(alpha: 0.28),
                                                      AppColors.goldLight.withValues(alpha: 0.15),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: AppColors.liquidGold.withValues(alpha: 0.70),
                                                    width: 1.0,
                                                  ),
                                                  boxShadow: <BoxShadow>[
                                                    BoxShadow(
                                                      color: AppColors.liquidGold.withValues(alpha: 0.25),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  'x${reward.quantity}',
                                                  style: const TextStyle(
                                                    color: AppColors.goldLight,
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Luminous Claim Confirmation Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.liquidGold,
                                  foregroundColor: const Color(0xFF0C101A),
                                  elevation: 8,
                                  shadowColor: AppColors.liquidGold.withValues(alpha: 0.55),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.45),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(Icons.check_circle_rounded, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'Ödülleri Topla ve Kapat',
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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

/// Dynamic particle data container for celebratory confetti explosion.
class _ConfettiParticle {
  _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.gravity,
    required this.size,
    required this.color,
    required this.rotationSpeed,
    required this.type,
    required this.delay,
  });

  final double angle;
  final double speed;
  final double gravity;
  final double size;
  final Color color;
  final double rotationSpeed;
  final int type; // 0: diamond, 1: 4-point star, 2: circle mote, 3: ribbon flake
  final double delay;
}

/// Custom painter rendering 46+ celebratory confetti particles (stars, diamonds, motes, ribbons)
/// bursting upwards and cascading downwards across the modal.
class _CelebrationConfettiPainter extends CustomPainter {
  const _CelebrationConfettiPainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return;

    final Offset center = Offset(size.width / 2, size.height * 0.28);

    for (final _ConfettiParticle p in particles) {
      if (progress < p.delay) continue;
      final double effectiveT = (progress - p.delay) / (1.0 - p.delay);
      if (effectiveT > 1.0) continue;

      // Distance and trajectory physics
      final double distance = p.speed * effectiveT * 135.0;
      final double x = center.dx + math.cos(p.angle) * distance;
      final double y = center.dy +
          math.sin(p.angle) * distance +
          (p.gravity * effectiveT * effectiveT * 110.0);

      // Smooth alpha fadeout
      final double alpha = (1.0 - math.pow(effectiveT, 1.8)).clamp(0.0, 1.0);
      if (alpha <= 0.0) continue;

      final Paint paint = Paint()
        ..color = p.color.withValues(alpha: alpha * 0.92)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * effectiveT * math.pi * 2);

      final double s = p.size * (1.0 - (effectiveT * 0.30));

      if (p.type == 0) {
        // Diamond
        final Path path = Path()
          ..moveTo(0, -s)
          ..lineTo(s * 0.7, 0)
          ..lineTo(0, s)
          ..lineTo(-s * 0.7, 0)
          ..close();
        canvas.drawPath(path, paint);
      } else if (p.type == 1) {
        // 4-point star
        final Path path = Path()
          ..moveTo(0, -s * 1.3)
          ..quadraticBezierTo(0, 0, s * 1.3, 0)
          ..quadraticBezierTo(0, 0, 0, s * 1.3)
          ..quadraticBezierTo(0, 0, -s * 1.3, 0)
          ..quadraticBezierTo(0, 0, 0, -s * 1.3)
          ..close();
        canvas.drawPath(path, paint);
      } else if (p.type == 2) {
        // Glowing circle mote
        canvas.drawCircle(Offset.zero, s * 0.8, paint);
      } else {
        // Flutter ribbon flake
        final Rect rect = Rect.fromCenter(
          center: Offset.zero,
          width: s * 1.6,
          height: s * 0.65,
        );
        canvas.drawRect(rect, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Custom painter rendering rotating celestial sunburst light beams radiating from chest.
class _CelestialSunburstPainter extends CustomPainter {
  const _CelestialSunburstPainter({
    required this.rotation,
    required this.color,
    this.rayCount = 16,
  });

  final double rotation;
  final Color color;
  final int rayCount;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;

    final Paint rayPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * 2 * math.pi);

    final double step = (2 * math.pi) / rayCount;
    final double halfStep = step * 0.32;

    for (int i = 0; i < rayCount; i++) {
      final double angle = i * step;
      final Path path = Path()
        ..moveTo(0, 0)
        ..lineTo(math.cos(angle - halfStep) * radius, math.sin(angle - halfStep) * radius)
        ..lineTo(math.cos(angle + halfStep) * radius, math.sin(angle + halfStep) * radius)
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CelestialSunburstPainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.color != color;
  }
}

/// Modal corner filigree brackets painter for Aion 2 dark fantasy aesthetic.
class _ModalCornerFiligreePainter extends CustomPainter {
  const _ModalCornerFiligreePainter({
    required this.accentColor,
  });

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;

    final Paint bracketPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final Paint dotPaint = Paint()
      ..color = AppColors.goldLight.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    const double inset = 12.0;
    const double arm = 16.0;

    // Top-Left corner bracket
    final Path tlPath = Path()
      ..moveTo(inset + arm, inset)
      ..lineTo(inset, inset)
      ..lineTo(inset, inset + arm);
    canvas.drawPath(tlPath, bracketPaint);
    canvas.drawCircle(const Offset(inset, inset), 2.0, dotPaint);

    // Top-Right corner bracket
    final Path trPath = Path()
      ..moveTo(w - inset - arm, inset)
      ..lineTo(w - inset, inset)
      ..lineTo(w - inset, inset + arm);
    canvas.drawPath(trPath, bracketPaint);
    canvas.drawCircle(Offset(w - inset, inset), 2.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ModalCornerFiligreePainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}

/// Custom painter rendering celestial gold filigree rings and arcane cardinal ticks
/// for Aion 2 Dark Fantasy celebration presentation.
class _CelestialOrnamentPainter extends CustomPainter {
  const _CelestialOrnamentPainter({
    required this.accentColor,
    required this.pulse,
  });

  final Color accentColor;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;

    // 1. Soft celestial halo glow
    final Paint glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15 + (pulse * 0.15))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(center, radius - 6, glowPaint);

    // 2. Outer celestial ring
    final Paint ringPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.35 + (pulse * 0.25))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius - 6, ringPaint);

    // 3. Inner concentric ring
    final Paint innerRingPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, radius - 16, innerRingPaint);

    // 4. Arcane Cardinal and Ordinal Ticks (12 ticks)
    final Paint tickPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.50 + (pulse * 0.35))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    const int tickCount = 12;
    for (int i = 0; i < tickCount; i++) {
      final double angle = (i * 2 * math.pi) / tickCount;
      final bool isCardinal = i % 3 == 0;
      final double innerDist = radius - (isCardinal ? 13 : 9);
      final double outerDist = radius - 3;
      final Offset p1 = Offset(
        center.dx + math.cos(angle) * innerDist,
        center.dy + math.sin(angle) * innerDist,
      );
      final Offset p2 = Offset(
        center.dx + math.cos(angle) * outerDist,
        center.dy + math.sin(angle) * outerDist,
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 5. Filigree Diamond Accents on 4 quadrants
    final Paint diamondPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.45 + (pulse * 0.35))
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final double angle = (i * math.pi) / 2;
      final double dist = radius - 6;
      final Offset diamondCenter = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      final Path path = Path()
        ..moveTo(diamondCenter.dx, diamondCenter.dy - 3.5)
        ..lineTo(diamondCenter.dx + 3.5, diamondCenter.dy)
        ..lineTo(diamondCenter.dx, diamondCenter.dy + 3.5)
        ..lineTo(diamondCenter.dx - 3.5, diamondCenter.dy)
        ..close();
      canvas.drawPath(path, diamondPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CelestialOrnamentPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.accentColor != accentColor;
  }
}

