import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/power_helpers.dart';
import '../../core/utils/stat_allocation.dart';
import '../../providers/player_provider.dart';
import '../../providers/power_change_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/app_messenger.dart';
import '../layout/game_screen_background.dart';

/// 2027 Aion 2 Obsidian-Glass Stat Allocation Panel (V2 Polish).
///
/// Features:
/// - Obsidian dark foundation (0xFF07090E - 0xFF0F141F) with frosted blur (sigma 16).
/// - Dual-layer specular top rim gleam and translucent obsidian glass card backdrops.
/// - Celestial Gold (#E5C158) unspent points badge with luminous star badge aura.
/// - Ether Cyan (#00E5FF) stat incrementer buttons (+1, +10) with active glowing borders.
/// - Refined Titanium-Obsidian aura for decrement buttons (-1, -10).
/// - Tactile mobile quick-step controls: -10, -1, +1, +10.
/// - Micro allocation ratio indicator and leading luminous accent indicator on stat cards.
/// - One-tap "Sıfırla" (Reset) button to revert pending allocations with mystic ruby glow.
/// - Real-time stat preview and projected Combat Power (CP) gain in Toxic Neon banner.
/// - Native tactile HapticFeedback: selectionClick on increment, mediumImpact on commit.
/// - Full SafeArea & MediaQuery view insets protection.
/// - 100% preservation of server math, multiplier formulas, and Supabase RPC persistence.
class StatAllocationPanel extends ConsumerStatefulWidget {
  const StatAllocationPanel({super.key, required this.availablePoints});

  final int availablePoints;

  @override
  ConsumerState<StatAllocationPanel> createState() =>
      _StatAllocationPanelState();
}

class _StatAllocationPanelState extends ConsumerState<StatAllocationPanel> {
  // ── 2027 Aion 2 Color Palette ──────────────────────────────────────────────
  static const Color _kObsidianDeep = Color(0xFF07090E);
  static const Color _kObsidianSurface = Color(0xFF0F141F);
  static const Color _kObsidianCard = Color(0xFF141A29);
  static const Color _kCelestialGold = Color(0xFFE5C158);
  static const Color _kCelestialGoldLight = Color(0xFFFDE68A);
  static const Color _kEtherCyan = Color(0xFF00E5FF);
  static const Color _kMysticRuby = Color(0xFFE52E2E);
  static const Color _kToxicNeon = Color(0xFF00FF66);
  static const Color _kCoralFlare = Color(0xFFFF6B35);
  static const Color _kTitaniumBorder = Color(0xFFB0C0D8);

  int _attack = 0;
  int _defense = 0;
  int _luck = 0;
  int _health = 0;
  bool _saving = false;

  int get _pending => _attack + _defense + _luck + _health;
  int get _remaining => widget.availablePoints - _pending;

  /// Projected Combat Power gain preview in real-time.
  int get _projectedCpGain {
    return (_attack * 25) + (_defense * 20) + (_luck * 50) + (_health * 10);
  }

  void _bump(String stat, int delta) {
    if (_saving) return;

    if (delta > 0) {
      if (_remaining <= 0) return;
      // Clamp delta to remaining available points
      final int actualDelta = delta.clamp(1, _remaining);
      HapticFeedback.selectionClick();
      setState(() {
        switch (stat) {
          case 'attack':
            _attack = (_attack + actualDelta).clamp(0, widget.availablePoints);
          case 'defense':
            _defense = (_defense + actualDelta).clamp(0, widget.availablePoints);
          case 'luck':
            _luck = (_luck + actualDelta).clamp(0, widget.availablePoints);
          case 'health':
            _health = (_health + actualDelta).clamp(0, widget.availablePoints);
        }
      });
    } else if (delta < 0) {
      HapticFeedback.selectionClick();
      setState(() {
        switch (stat) {
          case 'attack':
            _attack = (_attack + delta).clamp(0, widget.availablePoints);
          case 'defense':
            _defense = (_defense + delta).clamp(0, widget.availablePoints);
          case 'luck':
            _luck = (_luck + delta).clamp(0, widget.availablePoints);
          case 'health':
            _health = (_health + delta).clamp(0, widget.availablePoints);
        }
      });
    }
  }

  void _resetAllocation() {
    if (_pending <= 0 || _saving) return;
    HapticFeedback.selectionClick();
    setState(() {
      _attack = 0;
      _defense = 0;
      _luck = 0;
      _health = 0;
    });
  }

  Future<void> _confirm() async {
    if (_pending <= 0 || _saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final int powerBefore = readPlayerTotalPower(ref);

    try {
      final dynamic res = await SupabaseService.client.rpc(
        'allocate_stat_points',
        params: <String, dynamic>{
          'p_attack': _attack,
          'p_defense': _defense,
          'p_luck': _luck,
          'p_health': _health,
        },
      );
      final bool ok = res is Map && res['success'] == true;
      if (!mounted) return;

      if (ok) {
        HapticFeedback.heavyImpact();
        final Map<String, dynamic> data = Map<String, dynamic>.from(res);
        final int healthGain = (data['health_gain'] as num?)?.toInt() ?? 0;
        final String extra = healthGain > 0 ? ' (+$healthGain can)' : '';
        AppMessenger.showSuccess(context, '✅ $_pending puan dağıtıldı!$extra');

        setState(() {
          _attack = 0;
          _defense = 0;
          _luck = 0;
          _health = 0;
        });

        await ref.read(playerProvider.notifier).loadProfile();
        if (!mounted) return;
        ref.read(powerChangeProvider.notifier).emit(
              oldPower: powerBefore,
              newPower: readPlayerTotalPower(ref),
            );
      } else {
        AppMessenger.showError(context, 'Puan dağıtımı başarısız.');
      }
    } catch (_) {
      if (mounted) AppMessenger.showError(context, 'Puan dağıtımı başarısız.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      bottom: true,
      minimum: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xF507090E),
                  Color(0xEB0F141F),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _kCelestialGold.withValues(alpha: 0.38),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: _kCelestialGold.withValues(alpha: 0.1),
                  blurRadius: 22,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                // Specular rim light sheen across top edge
                Positioned(
                  top: 0,
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          _kCelestialGold.withValues(alpha: 0.6),
                          Colors.white.withValues(alpha: 0.8),
                          _kCelestialGold.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Main Content
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Header: Title and Remaining Points + Reset Button
                      Row(
                        children: <Widget>[
                          const Text('⬆️', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Stat Puanı Dağıt',
                              style: AppTextStyles.titleBold.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (_pending > 0)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: !_saving ? _resetAllocation : null,
                                borderRadius: BorderRadius.circular(8),
                                splashColor: _kMysticRuby.withValues(alpha: 0.25),
                                highlightColor:
                                    _kMysticRuby.withValues(alpha: 0.15),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: _kMysticRuby.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _kMysticRuby.withValues(alpha: 0.45),
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: _kMysticRuby.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.restart_alt_rounded,
                                        size: 13,
                                        color: _kMysticRuby,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Sıfırla',
                                        style: AppTextStyles.micro.copyWith(
                                          color: _kMysticRuby,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // Celestial Gold Unspent Points Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  _kCelestialGold.withValues(alpha: 0.22),
                                  _kCelestialGold.withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _kCelestialGold.withValues(alpha: 0.75),
                                width: 1.2,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: _kCelestialGold.withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.stars_rounded,
                                  size: 13,
                                  color: _kCelestialGold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$_remaining puan',
                                  style: AppTextStyles.caption.copyWith(
                                    color: _kCelestialGold,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Subtitle info
                      Text(
                        'Her level +3 puan. Can: 1 puan = +$statPointHealthMultiplier max can.',
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.mutedTitanium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      // Projected CP gain preview banner in bright green
                      if (_pending > 0) ...<Widget>[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                _kToxicNeon.withValues(alpha: 0.16),
                                _kToxicNeon.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _kToxicNeon.withValues(alpha: 0.6),
                              width: 1.1,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: _kToxicNeon.withValues(alpha: 0.2),
                                blurRadius: 12,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.bolt_rounded,
                                size: 16,
                                color: _kToxicNeon,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Tahmini Güç Artışı: +$_projectedCpGain CP',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: _kToxicNeon,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // ── Stat Rows with Tactile Controls ─────────────────────
                      _buildTactileStatRow(
                        label: 'Saldırı',
                        emoji: '⚔️',
                        value: _attack,
                        statKey: 'attack',
                        color: _kCoralFlare,
                        deltaPreview: _attack > 0
                            ? '+${_attack * 5} Saldırı Gücü'
                            : null,
                      ),
                      const SizedBox(height: 8),

                      _buildTactileStatRow(
                        label: 'Savunma',
                        emoji: '🛡️',
                        value: _defense,
                        statKey: 'defense',
                        color: _kEtherCyan,
                        deltaPreview: _defense > 0
                            ? '+${_defense * 4} Koruma Gücü'
                            : null,
                      ),
                      const SizedBox(height: 8),

                      _buildTactileStatRow(
                        label: 'Şans',
                        emoji: '🍀',
                        value: _luck,
                        statKey: 'luck',
                        color: _kToxicNeon,
                        deltaPreview:
                            _luck > 0 ? '+${_luck * 50} CP & Kritik' : null,
                      ),
                      const SizedBox(height: 8),

                      _buildTactileHealthRow(),

                      const SizedBox(height: 14),

                      // Reset scroll tip
                      Text(
                        'Yanlış dağıttın mı? Dükkan → Stat Sıfırlama Kağıdı (199 💎)',
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.mutedTitanium.withValues(alpha: 0.8),
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Confirm Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _pending > 0 && !_saving ? _confirm : null,
                            borderRadius: BorderRadius.circular(12),
                            splashColor: _pending > 0
                                ? _kCelestialGoldLight.withValues(alpha: 0.3)
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                gradient: _pending > 0
                                    ? const LinearGradient(
                                        colors: <Color>[
                                          _kCelestialGold,
                                          _kCelestialGoldLight,
                                        ],
                                      )
                                    : null,
                                color: _pending > 0
                                    ? null
                                    : _kObsidianSurface.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _pending > 0
                                      ? _kCelestialGold
                                      : Colors.white.withValues(alpha: 0.1),
                                  width: 1.2,
                                ),
                                boxShadow: _pending > 0
                                    ? <BoxShadow>[
                                        BoxShadow(
                                          color: _kCelestialGold
                                              .withValues(alpha: 0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: _kObsidianDeep,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          Icon(
                                            _pending > 0
                                                ? Icons.check_circle_rounded
                                                : Icons.touch_app_rounded,
                                            size: 18,
                                            color: _pending > 0
                                                ? _kObsidianDeep
                                                : AppColors.mutedTitanium,
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            _pending > 0
                                                ? 'Değişiklikleri Onayla (+$_pending Puan)'
                                                : 'Puan Seçimi Yapın',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.4,
                                              fontSize: 13,
                                              color: _pending > 0
                                                  ? _kObsidianDeep
                                                  : AppColors.mutedTitanium,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
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

  Widget _buildTactileStatRow({
    required String label,
    required String emoji,
    required int value,
    required String statKey,
    required Color color,
    String? deltaPreview,
  }) {
    final bool hasAllocated = value > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: hasAllocated
            ? _kObsidianCard.withValues(alpha: 0.8)
            : _kObsidianCard.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasAllocated
              ? color.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.1,
        ),
        boxShadow: hasAllocated
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        children: <Widget>[
          // Leading luminous accent indicator
          Container(
            width: 3.5,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: hasAllocated
                  ? color
                  : Colors.white.withValues(alpha: 0.12),
              boxShadow: hasAllocated
                  ? <BoxShadow>[
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),

          Text(emoji, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                if (deltaPreview != null)
                  Text(
                    deltaPreview,
                    style: AppTextStyles.micro.copyWith(
                      color: _kToxicNeon,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                if (_pending > 0 && hasAllocated) ...<Widget>[
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Container(
                      height: 2.5,
                      width: 55,
                      color: Colors.white.withValues(alpha: 0.08),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (value / _pending).clamp(0.0, 1.0),
                        child: Container(color: color),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // -10 quick button
          _stepButton(
            label: '-10',
            isIncrement: false,
            onTap: value >= 1 ? () => _bump(statKey, -10) : null,
          ),
          const SizedBox(width: 4),

          // -1 button
          _iconStepButton(
            icon: Icons.remove_rounded,
            isIncrement: false,
            onTap: value > 0 ? () => _bump(statKey, -1) : null,
          ),

          // Value Display
          SizedBox(
            width: 42,
            child: Text(
              value > 0 ? '+$value' : '0',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: value > 0 ? color : AppColors.mutedTitanium,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),

          // +1 Ether Cyan button
          _iconStepButton(
            icon: Icons.add_rounded,
            isIncrement: true,
            onTap: _remaining > 0 ? () => _bump(statKey, 1) : null,
          ),
          const SizedBox(width: 4),

          // +10 Ether Cyan quick button
          _stepButton(
            label: '+10',
            isIncrement: true,
            onTap: _remaining > 0 ? () => _bump(statKey, 10) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTactileHealthRow() {
    final bool hasAllocated = _health > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: hasAllocated
            ? _kObsidianCard.withValues(alpha: 0.8)
            : _kObsidianCard.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasAllocated
              ? _kMysticRuby.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.1,
        ),
        boxShadow: hasAllocated
            ? <BoxShadow>[
                BoxShadow(
                  color: _kMysticRuby.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        children: <Widget>[
          // Leading luminous accent indicator
          Container(
            width: 3.5,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: hasAllocated
                  ? _kMysticRuby
                  : Colors.white.withValues(alpha: 0.12),
              boxShadow: hasAllocated
                  ? <BoxShadow>[
                      BoxShadow(
                        color: _kMysticRuby.withValues(alpha: 0.45),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),

          const Text('❤️', style: TextStyle(fontSize: 17)),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Can',
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _health > 0
                      ? statPointHealthPreviewLabel(_health)
                      : 'x$statPointHealthMultiplier can / puan',
                  style: AppTextStyles.micro.copyWith(
                    color: _health > 0 ? _kToxicNeon : AppColors.mutedTitanium,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
                if (_pending > 0 && hasAllocated) ...<Widget>[
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Container(
                      height: 2.5,
                      width: 55,
                      color: Colors.white.withValues(alpha: 0.08),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (_health / _pending).clamp(0.0, 1.0),
                        child: Container(color: _kMysticRuby),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // -10 quick button
          _stepButton(
            label: '-10',
            isIncrement: false,
            onTap: _health >= 1 ? () => _bump('health', -10) : null,
          ),
          const SizedBox(width: 4),

          // -1 button
          _iconStepButton(
            icon: Icons.remove_rounded,
            isIncrement: false,
            onTap: _health > 0 ? () => _bump('health', -1) : null,
          ),

          // Value Display
          SizedBox(
            width: 42,
            child: Text(
              _health > 0 ? '+$_health' : '0',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: _health > 0 ? _kMysticRuby : AppColors.mutedTitanium,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),

          // +1 Ether Cyan button
          _iconStepButton(
            icon: Icons.add_rounded,
            isIncrement: true,
            onTap: _remaining > 0 ? () => _bump('health', 1) : null,
          ),
          const SizedBox(width: 4),

          // +10 Ether Cyan quick button
          _stepButton(
            label: '+10',
            isIncrement: true,
            onTap: _remaining > 0 ? () => _bump('health', 10) : null,
          ),
        ],
      ),
    );
  }

  Widget _stepButton({
    required String label,
    required bool isIncrement,
    required VoidCallback? onTap,
  }) {
    final bool enabled = onTap != null && !_saving;
    final Color activeColor = isIncrement ? _kEtherCyan : _kTitaniumBorder;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        splashColor: activeColor.withValues(alpha: 0.3),
        highlightColor: activeColor.withValues(alpha: 0.15),
        child: Container(
          width: 32,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: enabled
                ? activeColor.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: enabled
                  ? (isIncrement
                      ? _kEtherCyan.withValues(alpha: 0.8)
                      : _kTitaniumBorder.withValues(alpha: 0.6))
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.1,
            ),
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: isIncrement
                          ? _kEtherCyan.withValues(alpha: 0.28)
                          : _kTitaniumBorder.withValues(alpha: 0.18),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? activeColor : AppColors.mutedTitanium,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconStepButton({
    required IconData icon,
    required bool isIncrement,
    required VoidCallback? onTap,
  }) {
    final bool enabled = onTap != null && !_saving;
    final Color activeColor = isIncrement ? _kEtherCyan : _kTitaniumBorder;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        splashColor: activeColor.withValues(alpha: 0.3),
        highlightColor: activeColor.withValues(alpha: 0.15),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: enabled
                ? activeColor.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: enabled
                  ? (isIncrement
                      ? _kEtherCyan.withValues(alpha: 0.8)
                      : _kTitaniumBorder.withValues(alpha: 0.6))
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.1,
            ),
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: isIncrement
                          ? _kEtherCyan.withValues(alpha: 0.28)
                          : _kTitaniumBorder.withValues(alpha: 0.18),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: enabled ? activeColor : AppColors.mutedTitanium,
          ),
        ),
      ),
    );
  }
}
