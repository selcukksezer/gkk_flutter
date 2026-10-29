import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'comeback_models.dart';
import 'comeback_particle_burst.dart';

/// Design tokens for 2027 Aion 2 obsidian-glass aesthetic.
const Color _kCelestialGold = Color(0xFFE5C158);
const Color _kEtherCyan = Color(0xFF00E5FF);
const Color _kObsidianVoid = Color(0xFF07090E);
const Color _kObsidianBase = Color(0xFF0B0E14);
const Color _kObsidianSurface = Color(0xFF101522);

/// Welcome-Back Gift Card Presentation widget with 2027 Aion 2 visual fidelity.
///
/// Features:
/// - Obsidian frosted glass card with BackdropFilter blur and subtle inner shadow.
/// - Dual gradient border blending Celestial Gold (#E5C158) into Ether Cyan (#00E5FF).
/// - Interactive claim button with luminous pulse and HapticFeedback.mediumImpact().
/// - Responsive SafeArea integration protecting against edge cutoffs on modern displays.
class ComebackGiftCard extends StatefulWidget {
  const ComebackGiftCard({
    super.key,
    required this.data,
    this.onClaim,
  });

  final ComebackGiftCardData data;
  final VoidCallback? onClaim;

  @override
  State<ComebackGiftCard> createState() => _ComebackGiftCardState();
}

class _ComebackGiftCardState extends State<ComebackGiftCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  final ComebackParticleBurstController _particleCtrl =
      ComebackParticleBurstController();
  bool _isClaimed = false;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _isClaimed = widget.data.isClaimed;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ComebackGiftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.isClaimed != oldWidget.data.isClaimed) {
      _isClaimed = widget.data.isClaimed;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    if (_isClaimed || _isClaiming) return;
    HapticFeedback.mediumImpact();
    setState(() => _isClaiming = true);

    _particleCtrl.burst(count: 60);

    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    setState(() {
      _isClaimed = true;
      _isClaiming = false;
    });

    widget.onClaim?.call();
  }

  String _formatOffline(double hours) {
    if (hours >= 24) {
      final int days = (hours / 24).floor();
      return '$days Gün Sonra Dönüş';
    }
    if (hours >= 1) {
      return '${hours.toStringAsFixed(1)} Saat Sonra Dönüş';
    }
    return 'Yeni Dönüş';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      minimum: const EdgeInsets.symmetric(horizontal: 2),
      child: ComebackParticleBurst(
        controller: _particleCtrl,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (BuildContext context, Widget? child) {
            final double pulse = _pulseCtrl.value;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _kCelestialGold.withValues(alpha: 0.16 * pulse + 0.08),
                    blurRadius: 20,
                    spreadRadius: -1,
                    offset: const Offset(-2, -2),
                  ),
                  BoxShadow(
                    color: _kEtherCyan.withValues(alpha: 0.18 * (1.0 - pulse) + 0.08),
                    blurRadius: 24,
                    spreadRadius: -1,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(1.4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          _kCelestialGold.withValues(alpha: 0.6 + 0.35 * pulse),
                          _kEtherCyan.withValues(alpha: 0.5 + 0.45 * (1.0 - pulse)),
                        ],
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXl - 1.4),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Color(0xEE0B0E14),
                            Color(0xF807090E),
                            Color(0xF0101522),
                          ],
                          stops: <double>[0.0, 0.45, 1.0],
                        ),
                      ),
                      child: Stack(
                        children: <Widget>[
                          // Subtle inner shadow & ambient specular sheen
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppSpacing.radiusXl - 1.4),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      Colors.white.withValues(alpha: 0.08),
                                      Colors.transparent,
                                      _kEtherCyan.withValues(alpha: 0.04),
                                    ],
                                    stops: const <double>[0.0, 0.3, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _buildHeader(pulse),
                                const SizedBox(height: 14),
                                _buildRewardsGrid(pulse),
                                const SizedBox(height: 14),
                                _buildClaimFooter(pulse),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(double pulse) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                _kCelestialGold,
                Color.lerp(_kCelestialGold, _kEtherCyan, 0.45)!,
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _kCelestialGold.withValues(alpha: 0.35 + 0.15 * pulse),
                blurRadius: 12 + 4 * pulse,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: _kEtherCyan.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.card_giftcard_rounded,
            color: _kObsidianVoid,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      widget.data.title,
                      style: GoogleFonts.urbanist(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          _kEtherCyan.withValues(alpha: 0.18),
                          _kCelestialGold.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _kEtherCyan.withValues(alpha: 0.7),
                        width: 0.9,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: _kEtherCyan.withValues(alpha: 0.25),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      'ÖZEL HEDİYE',
                      style: GoogleFonts.urbanist(
                        color: _kEtherCyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                widget.data.subtitle,
                style: GoogleFonts.urbanist(
                  color: AppColors.mutedTitanium,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kObsidianBase.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _kCelestialGold.withValues(alpha: 0.45),
              width: 0.9,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _kCelestialGold.withValues(alpha: 0.15),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            _formatOffline(widget.data.offlineHours),
            style: GoogleFonts.urbanist(
              color: _kCelestialGold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardsGrid(double pulse) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kObsidianVoid.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: _kEtherCyan.withValues(alpha: 0.18),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 10,
                decoration: BoxDecoration(
                  color: _kEtherCyan,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _kEtherCyan.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'HEDİYE İÇERİĞİ',
                style: GoogleFonts.urbanist(
                  color: _kEtherCyan.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.data.rewards.map((ComebackRewardItem item) {
              return _RewardItemTile(item: item);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimFooter(double pulse) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Uygunluk Durumu:',
                style: GoogleFonts.urbanist(
                  color: AppColors.mutedTitanium,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isClaimed
                    ? 'Hediyeniz başarıyla teslim alındı'
                    : '14 gün boyunca geçerlidir',
                style: GoogleFonts.urbanist(
                  color: _isClaimed ? _kEtherCyan : _kCelestialGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildClaimButton(pulse),
      ],
    );
  }

  Widget _buildClaimButton(double pulse) {
    final bool isInteractive = !_isClaimed && !_isClaiming;

    return AnimatedScale(
      scale: _isClaiming ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: _isClaimed
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: _kCelestialGold.withValues(alpha: 0.35 + 0.25 * pulse),
                    blurRadius: 14 + 6 * pulse,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: _kEtherCyan.withValues(alpha: 0.25 + 0.2 * (1.0 - pulse)),
                    blurRadius: 18,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: isInteractive ? _handleClaim : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: _isClaimed ? _kEtherCyan : _kObsidianVoid,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: _isClaimed ? _kEtherCyan : AppColors.mutedTitanium,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: _isClaimed
                  ? LinearGradient(
                      colors: <Color>[
                        _kObsidianSurface.withValues(alpha: 0.7),
                        _kObsidianBase.withValues(alpha: 0.8),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        _kCelestialGold,
                        Color.lerp(_kCelestialGold, _kEtherCyan, 0.35 + 0.2 * pulse)!,
                      ],
                    ),
              border: Border.all(
                color: _isClaimed
                    ? _kEtherCyan.withValues(alpha: 0.5)
                    : _kCelestialGold.withValues(alpha: 0.85),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_isClaiming) ...<Widget>[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_kObsidianVoid),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else ...<Widget>[
                    Icon(
                      _isClaimed
                          ? Icons.check_circle_rounded
                          : Icons.auto_awesome_rounded,
                      size: 16,
                      color: _isClaimed ? _kEtherCyan : _kObsidianVoid,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _isClaimed
                        ? 'Alındı ✓'
                        : _isClaiming
                            ? 'Alınıyor...'
                            : 'Paketi Al',
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: _isClaimed ? _kEtherCyan : _kObsidianVoid,
                      letterSpacing: 0.3,
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

class _RewardItemTile extends StatelessWidget {
  const _RewardItemTile({required this.item});

  final ComebackRewardItem item;

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = item.rarity.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => HapticFeedback.selectionClick(),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              rarityColor.withValues(alpha: 0.10),
              _kObsidianBase.withValues(alpha: 0.85),
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: rarityColor.withValues(alpha: 0.45),
              width: 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: rarityColor.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: rarityColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Icon(item.icon, color: rarityColor, size: 15),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    item.name,
                    style: GoogleFonts.urbanist(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    item.quantity,
                    style: GoogleFonts.urbanist(
                      color: rarityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
