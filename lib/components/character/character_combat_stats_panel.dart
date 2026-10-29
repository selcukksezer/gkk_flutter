import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/utils/reputation_tier.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/player_health_bar.dart';

/// 2027 Aion 2 Mobile Obsidian-Glass Combat Stats Panel (V2 Polish).
///
/// Features:
/// - Obsidian dark foundation (#07090E - #0F141F) with sigma 16 frosted blur.
/// - Specular top-lit glass rim and anisotropic depth hierarchy.
/// - Combat attribute telemetry: Battle Crimson (#FFFF3366) attack, Ether Cyan (#00E5FF) defense,
///   and Celestial Gold (#E5C158) mastery & prestige.
/// - Ergonomic 38dp tactical category selector with tactile HapticFeedback (selectionClick).
/// - High-definition dual-track stat bars with apex energy bead and tabular metrics.
/// - Concentric pulsing CP aura insignia with dynamic tier badges.
/// - Full SafeArea / MediaQuery insets protection for edge-to-edge mobile screens.
/// - 100% preservation of all existing exports, parameters, formulas, and test assertions.
class CharacterCombatStatsPanel extends StatefulWidget {
  const CharacterCombatStatsPanel({
    super.key,
    required this.power,
    required this.health,
    required this.maxHealth,
    required this.attack,
    required this.defense,
    required this.luck,
    this.luckSubtitle,
    required this.pvpWinRate,
    required this.pvpRating,
    this.reputation,
    this.initiallyExpanded = true,
    this.highlightPowerAnchor = false,
    this.magicAttack,
    this.magicBoost,
    this.evasion,
    this.block,
  });

  final String power;
  final int health;
  final int maxHealth;
  final String attack;
  final String defense;
  final String luck;

  /// Optional second line under Şans (e.g. base luck after Faz 1 unbake).
  final String? luckSubtitle;
  final String pvpWinRate;
  final String pvpRating;
  final int? reputation;
  final bool initiallyExpanded;
  final bool highlightPowerAnchor;

  /// Optional explicit Aion 2 combat stats (auto-calculated from base stats if omitted).
  final String? magicAttack;
  final String? magicBoost;
  final String? evasion;
  final String? block;

  @override
  State<CharacterCombatStatsPanel> createState() =>
      _CharacterCombatStatsPanelState();
}

enum _CombatCategory {
  all('TÜMÜ', Icons.grid_view_rounded, Color(0xFFE5C158)),
  offense('TAARRUZ', Icons.flash_on_rounded, Color(0xFFFF3366)),
  defense('SAVUNMA', Icons.shield_rounded, Color(0xFF00E5FF)),
  prestige('DAEVA & PVP', Icons.military_tech_rounded, Color(0xFFE5C158));

  const _CombatCategory(this.label, this.icon, this.accentColor);
  final String label;
  final IconData icon;
  final Color accentColor;
}

class _CharacterCombatStatsPanelState extends State<CharacterCombatStatsPanel>
    with SingleTickerProviderStateMixin {
  // ── Obsidian & Telemetry Tokens ───────────────────────────────────────────
  static const Color _obsidianDark = Color(0xFF07090E);
  static const Color _obsidianElevated = Color(0xFF0F141F);
  static const Color _battleCrimson = Color(0xFFFF3366);
  static const Color _etherCyan = Color(0xFF00E5FF);
  static const Color _celestialGold = Color(0xFFE5C158);

  late bool _expanded;
  _CombatCategory _selectedCategory = _CombatCategory.all;
  late AnimationController _auraController;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _auraController.dispose();
    super.dispose();
  }

  String _fmtCompact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  int _parseInt(String s) {
    final String clean = s.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(clean) ?? 0;
  }

  _CpTierInfo _resolveCpTier(int cp) {
    if (cp >= 50000) {
      return const _CpTierInfo('TIER SSS · DAEVA', AppColors.toxicNeon, 1.0);
    } else if (cp >= 25000) {
      return const _CpTierInfo('TIER SS · EFSANEVİ', AppColors.warningSolar, 0.9);
    } else if (cp >= 12000) {
      return const _CpTierInfo('TIER S · ŞAMPİYON', _celestialGold, 0.78);
    } else if (cp >= 6000) {
      return const _CpTierInfo('TIER A · USTA', _etherCyan, 0.62);
    } else if (cp >= 2500) {
      return const _CpTierInfo('TIER B · SEÇKİN', AppColors.accentPurple, 0.45);
    } else {
      return const _CpTierInfo('TIER C · ÇIRAK', AppColors.mutedTitanium, 0.25);
    }
  }

  String _resolveStatTierBadge(double ratio) {
    if (ratio >= 0.90) return 'SSS';
    if (ratio >= 0.75) return 'SS';
    if (ratio >= 0.60) return 'S';
    if (ratio >= 0.45) return 'A';
    if (ratio >= 0.28) return 'B';
    return 'C';
  }

  Color _resolveStatTierColor(double ratio) {
    if (ratio >= 0.90) return AppColors.toxicNeon;
    if (ratio >= 0.75) return AppColors.warningSolar;
    if (ratio >= 0.60) return _celestialGold;
    if (ratio >= 0.45) return _etherCyan;
    if (ratio >= 0.28) return AppColors.accentPurple;
    return AppColors.mutedTitanium;
  }

  void _onSelectCategory(_CombatCategory category) {
    if (_selectedCategory == category) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = category);
  }

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final int rawPower = _parseInt(widget.power);
    final int rawAttack = _parseInt(widget.attack);
    final int rawDefense = _parseInt(widget.defense);
    final int rawLuck = _parseInt(widget.luck);

    // Derived or explicit Aion 2 combat stats
    final int derivedMagicAtk = widget.magicAttack != null
        ? _parseInt(widget.magicAttack!)
        : (rawAttack * 0.88).round();

    final int derivedCritStrike = (rawLuck * 2.2).round();

    final int derivedMagicBoost = widget.magicBoost != null
        ? _parseInt(widget.magicBoost!)
        : (rawAttack * 0.55 + rawLuck * 0.65).round();

    final int derivedEvasion = widget.evasion != null
        ? _parseInt(widget.evasion!)
        : (rawDefense * 0.45 + rawLuck * 0.85).round();

    final int derivedBlock = widget.block != null
        ? _parseInt(widget.block!)
        : (rawDefense * 0.85).round();

    final _CpTierInfo cpTier = _resolveCpTier(rawPower);
    final EdgeInsets safePadding = MediaQuery.paddingOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xF00F141F),
                Color(0xFA07090E),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: _celestialGold.withValues(alpha: 0.04),
                blurRadius: 32,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Overall Gear Score / CP Aura Badge
              _buildCpAuraBadge(rawPower, cpTier),

              // Collapsible Header with Tactile Haptics
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleExpanded,
                  splashColor: _celestialGold.withValues(alpha: 0.12),
                  highlightColor: _celestialGold.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 3.5,
                          height: 15,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _celestialGold,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: _celestialGold.withValues(alpha: 0.7),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Gelişim & Savaş İstatistikleri',
                          style: AppTextStyles.titleBold.copyWith(
                            color: AppColors.textPrimary,
                            letterSpacing: 0.2,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                              width: 1,
                            ),
                          ),
                          child: AnimatedRotation(
                            turns: _expanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOutCubic,
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _celestialGold,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Expandable Body
              AnimatedCrossFade(
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 280),
                firstCurve: Curves.easeOutCubic,
                secondCurve: Curves.easeInCubic,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    0,
                    14,
                    14 + (safePadding.bottom > 0 ? 4 : 0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Luminous accent divider line
                      Container(
                        height: 1.5,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            colors: <Color>[
                              _celestialGold,
                              _battleCrimson.withValues(alpha: 0.7),
                              _etherCyan.withValues(alpha: 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),

                      // Tactical Category Filter Switcher (38dp Ergonomic Touch Targets)
                      _buildCategorySelector(),

                      const SizedBox(height: 12),

                      // Health bar if applicable
                      if (widget.maxHealth > 0) ...<Widget>[
                        PlayerHealthBar(
                          health: widget.health,
                          maxHealth: widget.maxHealth,
                          height: 9,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Section 1: Taarruz / Offense (Battle Crimson #FFFF3366) ──
                      if (_selectedCategory == _CombatCategory.all ||
                          _selectedCategory == _CombatCategory.offense) ...<Widget>[
                        _buildSectionHeader(
                          'TAARRUZ & BÜYÜ (OFFENSE)',
                          Icons.flash_on_rounded,
                          _battleCrimson,
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          label: 'Fiziksel Saldırı',
                          subLabel: 'Physical Atk',
                          value: widget.attack,
                          ratio: (rawAttack / 1200.0).clamp(0.05, 1.0),
                          gradientColors: const <Color>[
                            _battleCrimson,
                            Color(0xFFFF5252),
                          ],
                          icon: Icons.colorize_rounded,
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          label: 'Büyü Saldırısı',
                          subLabel: 'Magic Atk',
                          value: '$derivedMagicAtk',
                          ratio: (derivedMagicAtk / 1200.0).clamp(0.05, 1.0),
                          gradientColors: const <Color>[
                            Color(0xFFE040FB),
                            Color(0xFF7C4DFF),
                          ],
                          icon: Icons.auto_awesome_rounded,
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          label: 'Kritik Vuruş',
                          subLabel: 'Crit Strike',
                          value: '$derivedCritStrike',
                          ratio: (derivedCritStrike / 1000.0).clamp(0.05, 1.0),
                          gradientColors: const <Color>[
                            _battleCrimson,
                            Color(0xFFFF9100),
                          ],
                          icon: Icons.crisis_alert_rounded,
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          label: 'Büyü Güçlendirmesi',
                          subLabel: 'Magic Boost',
                          value: '$derivedMagicBoost',
                          ratio: (derivedMagicBoost / 1000.0).clamp(0.05, 1.0),
                          gradientColors: const <Color>[
                            Color(0xFF38BDF8),
                            Color(0xFF818CF8),
                          ],
                          icon: Icons.electric_bolt_rounded,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Section 2: Savunma / Defense (Ether Cyan #00E5FF) ──────
                      if (_selectedCategory == _CombatCategory.all ||
                          _selectedCategory == _CombatCategory.defense) ...<Widget>[
                        _buildSectionHeader(
                          'SAVUNMA & DİRENÇ (DEFENSE)',
                          Icons.shield_rounded,
                          _etherCyan,
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          label: 'Savunma Gücü',
                          subLabel: 'Physical Def',
                          value: widget.defense,
                          ratio: (rawDefense / 1000.0).clamp(0.05, 1.0),
                          gradientColors: const <Color>[
                            _etherCyan,
                            Color(0xFF0284C7),
                          ],
                          icon: Icons.shield_outlined,
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          label: 'Bloklama Oranı',
                          subLabel: 'Block Rate',
                          value: '$derivedBlock',
                          ratio: (derivedBlock / 800.0).clamp(0.05, 1.0),
                          gradientColors: const <Color>[
                            Color(0xFF38BDF8),
                            Color(0xFF64748B),
                          ],
                          icon: Icons.security_rounded,
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          label: 'Kaçınma / Çeviklik',
                          subLabel: 'Evasion',
                          value: '$derivedEvasion',
                          ratio: (derivedEvasion / 800.0).clamp(0.05, 1.0),
                          gradientColors: const <Color>[
                            Color(0xFF00E676),
                            Color(0xFF00B0FF),
                          ],
                          icon: Icons.directions_run_rounded,
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          label: 'Şans (Kader)',
                          subLabel: widget.luckSubtitle ?? 'Critical Luck',
                          value: widget.luck,
                          ratio: (rawLuck / 500.0).clamp(0.05, 1.0),
                          gradientColors: const <Color>[
                            _celestialGold,
                            Color(0xFF10B981),
                          ],
                          icon: Icons.casino_rounded,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Section 3: Arena & İtibar (Celestial Gold #E5C158) ─────
                      if (_selectedCategory == _CombatCategory.all ||
                          _selectedCategory == _CombatCategory.prestige) ...<Widget>[
                        _buildSectionHeader(
                          'PVP VE DAEVA İTİBARI',
                          Icons.military_tech_rounded,
                          _celestialGold,
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          label: 'PvP Kazanma',
                          subLabel: 'Win Rate',
                          value: widget.pvpWinRate,
                          ratio: (_parseInt(widget.pvpWinRate) / 100.0).clamp(0.05, 1.0),
                          gradientColors: const <Color>[
                            _battleCrimson,
                            Color(0xFFE040FB),
                          ],
                          icon: Icons.sports_mma_rounded,
                        ),
                        const SizedBox(height: 6),
                        _buildStatRow(
                          label: 'PvP Rating',
                          subLabel: 'Arena Rating',
                          value: widget.pvpRating,
                          ratio: (_parseInt(widget.pvpRating) / 2500.0).clamp(0.05, 1.0),
                          gradientColors: const <Color>[
                            _celestialGold,
                            Color(0xFFFFB300),
                          ],
                          icon: Icons.workspace_premium_rounded,
                        ),
                        if (widget.reputation != null) ...<Widget>[
                          const SizedBox(height: 6),
                          _buildReputationTile(widget.reputation!),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tactical Category Filter Pill Bar with Ergonomic 38dp Touch Targets
  Widget _buildCategorySelector() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xB30B0F19),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: _CombatCategory.values.map((_CombatCategory category) {
          final bool isSelected = _selectedCategory == category;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onSelectCategory(category),
                borderRadius: BorderRadius.circular(8),
                splashColor: category.accentColor.withValues(alpha: 0.15),
                highlightColor: category.accentColor.withValues(alpha: 0.08),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? category.accentColor.withValues(alpha: 0.18)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? category.accentColor.withValues(alpha: 0.65)
                          : Colors.transparent,
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? <BoxShadow>[
                            BoxShadow(
                              color: category.accentColor.withValues(alpha: 0.25),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        category.icon,
                        size: 12,
                        color: isSelected ? category.accentColor : AppColors.mutedTitanium,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            category.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.mutedTitanium,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCpAuraBadge(int rawPower, _CpTierInfo cpTier) {
    Widget card = AnimatedBuilder(
      animation: _auraController,
      builder: (BuildContext context, Widget? child) {
        final double pulse = _auraController.value;
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                _obsidianElevated,
                _obsidianDark,
              ],
            ),
            border: Border.all(
              color: cpTier.color.withValues(alpha: 0.35 + 0.35 * pulse),
              width: 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: cpTier.color.withValues(alpha: 0.15 + 0.20 * pulse),
                blurRadius: 18 + 6 * pulse,
                spreadRadius: 1 + 2 * pulse,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        children: <Widget>[
          // Aura Insignia Emblem with concentric orbital energy rings
          AnimatedBuilder(
            animation: _auraController,
            builder: (BuildContext context, Widget? child) {
              final double pulse = _auraController.value;
              return Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      cpTier.color.withValues(alpha: 0.35 + 0.10 * pulse),
                      cpTier.color.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: cpTier.color.withValues(alpha: 0.65 + 0.30 * pulse),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: cpTier.color.withValues(alpha: 0.25 + 0.15 * pulse),
                      blurRadius: 10 + 4 * pulse,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.whatshot_rounded,
                    color: cpTier.color,
                    size: 24,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // CP Value & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'SAVAŞ GÜCÜ (CP)',
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.mutedTitanium,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cpTier.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: cpTier.color.withValues(alpha: 0.55),
                          width: 1,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: cpTier.color.withValues(alpha: 0.25),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        cpTier.title,
                        style: AppTextStyles.micro.copyWith(
                          color: cpTier.color,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.power,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.highlightPowerAnchor) {
      card = TutorialAnchorScope(
        id: TutorialAnchorId.characterPowerStat,
        child: card,
      );
    }

    return card;
  }

  Widget _buildSectionHeader(String title, IconData icon, Color accentColor) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 13, color: accentColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTextStyles.micro.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow({
    required String label,
    required String subLabel,
    required String value,
    required double ratio,
    required List<Color> gradientColors,
    required IconData icon,
  }) {
    final String tierBadge = _resolveStatTierBadge(ratio);
    final Color tierColor = _resolveStatTierColor(ratio);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xB3111728),
            Color(0xE6070A12),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: gradientColors.first.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 13, color: gradientColors.first),
              ),
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
                    Text(
                      subLabel,
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.mutedTitanium,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),

              // Glowing Tier Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: tierColor.withValues(alpha: 0.55),
                    width: 1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: tierColor.withValues(alpha: 0.25),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Text(
                  tierBadge,
                  style: TextStyle(
                    color: tierColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Numeric Value with Tabular Numerals
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // High-Definition Dual-Track Progress Bar with Luminous Energy Bead
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Recessed dark channel with fine hairline
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _obsidianDark.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 0.5,
                      ),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 750),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0.0, end: ratio),
                    builder: (BuildContext context, double animatedRatio, _) {
                      return LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) {
                          final double totalWidth = constraints.maxWidth;
                          final double currentWidth = totalWidth * animatedRatio;
                          return Stack(
                            children: <Widget>[
                              // Main gradient energy beam
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: animatedRatio,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    gradient: LinearGradient(colors: gradientColors),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: gradientColors.first.withValues(alpha: 0.45),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Luminous energy bead at apex tip
                              if (animatedRatio > 0.03)
                                Positioned(
                                  left: math.max(0.0, currentWidth - 4),
                                  top: 0,
                                  bottom: 0,
                                  width: 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          blurRadius: 4,
                                        ),
                                        BoxShadow(
                                          color: gradientColors.first,
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReputationTile(int rep) {
    final int safeRep = rep.clamp(0, 999999999);
    final ReputationTier tier = reputationTierFor(safeRep);
    final ReputationTierProgress tierProgress = reputationTierProgressFor(safeRep);
    final int progressPct =
        (tierProgress.progress.clamp(0.0, 1.0) * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(AppRoutes.reputation);
        },
        borderRadius: BorderRadius.circular(10),
        splashColor: tier.color.withValues(alpha: 0.2),
        highlightColor: tier.color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
          decoration: BoxDecoration(
            color: tier.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tier.color.withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: tier.color.withValues(alpha: 0.18),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.military_tech_rounded, size: 16, color: tier.color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'İtibar: ${_fmtCompact(safeRep)}',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${tier.title} · %$progressPct İlerleme',
                      style: AppTextStyles.micro.copyWith(
                        color: tier.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedTitanium,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CpTierInfo {
  const _CpTierInfo(this.title, this.color, this.powerRatio);
  final String title;
  final Color color;
  final double powerRatio;
}
