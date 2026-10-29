import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/character/badge_showcase_panel.dart';
import '../../../components/character/character_combat_stats_panel.dart';
import '../../../components/character/character_health_panel.dart';
import '../../../components/character/stat_allocation_panel.dart';
import '../../../components/common/app_messenger.dart';
import '../../../components/common/cosmetic_title_badge.dart';
import '../../../components/common/item_icon_view.dart';
import '../../../components/common/profile_avatar.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/utils/character_class_abilities.dart';
import '../../../core/utils/cosmetic_title.dart';
import '../../../core/utils/effective_luck.dart';
import '../../../core/utils/reputation_tier.dart';
import '../../../core/utils/xp_formula.dart';
import '../../../models/inventory_model.dart';
import '../../../models/player_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import 'equipment_socket_dock.dart';

String _fmtCompact(num n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toInt().toString();
}

/// Mobile Navigation Tabs for Character Glass Overlay
enum CharacterTab {
  stats,
  equipment,
  titles,
  codex,
}

/// Glassmorphic Stat Overlay standardized for 2027 Aion 2 Mobile visuals:
/// - Deep obsidian translucency with frosted glass backdrop blur
/// - Luminous liquid gold and arcane cyan borders & glows
/// - Fluid mobile tab transitions between Stats, Equipment, Titles, and Codex
/// - Collapsible HUD pill providing an unobstructed 3D character viewport
/// - Safe Area mobile layout optimized for 390x844 viewports
class CharacterGlassOverlay extends StatefulWidget {
  const CharacterGlassOverlay({
    super.key,
    required this.profile,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onOpenCodex,
    required this.onOpenReputation,
    required this.onCustomizeProfile,
    required this.highlightPowerTutorial,
    required this.statTutorialStep,
    required this.claimingDetox,
    required this.onClaimDetox,
    this.classAbilitiesKey,
    this.initialTab = CharacterTab.stats,
    this.equippedItems = const <String, InventoryItem?>{},
    this.onSlotTap,
    this.onTabChanged,
  });

  final PlayerProfile? profile;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onOpenCodex;
  final VoidCallback onOpenReputation;
  final VoidCallback onCustomizeProfile;
  final bool highlightPowerTutorial;
  final bool statTutorialStep;
  final bool claimingDetox;
  final VoidCallback onClaimDetox;
  final Key? classAbilitiesKey;
  final CharacterTab initialTab;
  final Map<String, InventoryItem?> equippedItems;
  final void Function(EquipmentSlotDef def, InventoryItem? item)? onSlotTap;
  final ValueChanged<CharacterTab>? onTabChanged;

  @override
  State<CharacterGlassOverlay> createState() => _CharacterGlassOverlayState();
}

class _CharacterGlassOverlayState extends State<CharacterGlassOverlay> {
  late CharacterTab _activeTab;
  bool _updatingTitle = false;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(CharacterGlassOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _activeTab = widget.initialTab;
    }
  }

  void _switchTab(CharacterTab tab) {
    if (_activeTab == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _activeTab = tab);
    widget.onTabChanged?.call(tab);
  }

  bool _isFuture(String? dateStr) {
    if (dateStr == null) return false;
    final DateTime? date = DateTime.tryParse(dateStr);
    return date != null && date.isAfter(DateTime.now());
  }

  Future<void> _equipCosmeticTitle(String? titleKey) async {
    if (_updatingTitle) return;
    setState(() => _updatingTitle = true);
    HapticFeedback.mediumImpact();
    try {
      final String? userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        await SupabaseService.client
            .from('users')
            .update(<String, Object?>{'cosmetic_title': titleKey})
            .eq('auth_id', userId);
      }
      if (mounted) {
        final String label = cosmeticTitleDisplayLabel(titleKey) ?? 'Çıkarıldı';
        AppMessenger.showSuccess(context, 'Unvan güncellendi: $label');
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Unvan güncellenemedi.');
      }
    } finally {
      if (mounted) setState(() => _updatingTitle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlayerProfile? profile = widget.profile;
    final int level = profile?.level ?? 1;
    final int xp = profile?.xp ?? 0;
    final XpProgress xpProgress = buildXpProgress(level: level, totalXp: xp);
    final int reputation = (profile?.reputation ?? 0).clamp(0, 999999999);

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 320),
      firstCurve: Curves.easeOutCubic,
      secondCurve: Curves.easeInCubic,
      crossFadeState: widget.isExpanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      // 1. Collapsed Floating Glass HUD Pill (Unobstructed View)
      firstChild: _buildCollapsedHud(profile, level, xpProgress),
      // 2. Expanded Glassmorphic Sheet with Fluid Tabs
      secondChild: _buildExpandedGlassSheet(
        profile,
        level,
        xpProgress,
        reputation,
      ),
    );
  }

  /// Compact floating frosted obsidian HUD pill at the bottom of the screen
  Widget _buildCollapsedHud(
    PlayerProfile? profile,
    int level,
    XpProgress xpProgress,
  ) {
    final String name =
        profile?.displayName ?? profile?.username ?? 'Savaşçı';
    final CharacterClass? charClass = profile?.characterClass;
    final String className = charClass == CharacterClass.warrior
        ? 'Savaşçı'
        : charClass == CharacterClass.alchemist
        ? 'Simyacı'
        : charClass == CharacterClass.shadow
        ? 'Gölge'
        : 'Gezgin';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.spaceNavy.withValues(alpha: 0.92),
                    AppColors.bgDeep.withValues(alpha: 0.96),
                    const Color(0xF2090D15),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                border: Border.all(
                  color: AppColors.liquidGold.withValues(alpha: 0.42),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  // Mini Avatar with edit badge
                  GestureDetector(
                    onTap: widget.onCustomizeProfile,
                    child: Stack(
                      children: <Widget>[
                        ProfileAvatar(
                          size: 44,
                          avatarUrl: profile?.avatarUrl,
                          backgroundColor: AppColors.bgDeep,
                          glowFrame: profile?.avatarFrame == 'glow',
                          codexFrame: profile?.avatarFrame == 'codex',
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.spaceNavy,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.liquidGold.withValues(alpha: 0.7),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.edit,
                              size: 10,
                              color: AppColors.liquidGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Character Name & Class
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleBold.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            if (hasCosmeticTitle(profile?.cosmeticTitle)) ...<Widget>[
                              const SizedBox(width: AppSpacing.xs + 2),
                              CosmeticTitleBadge(titleKey: profile!.cosmeticTitle),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Lvl $level · $className · Güç: ${_fmtCompact(profile?.power ?? 0)}',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.liquidGold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expand Stats Button (Aion 2 luminous gold action)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.liquidGold.withValues(alpha: 0.2),
                      foregroundColor: AppColors.liquidGold,
                      side: BorderSide(
                        color: AppColors.liquidGold.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      widget.onToggleExpanded();
                    },
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(
                      'Statlar',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.liquidGold,
                        fontSize: 12,
                        letterSpacing: 0.4,
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

  /// Full glassmorphic stat sheet with fluid tabs and deep obsidian translucency
  Widget _buildExpandedGlassSheet(
    PlayerProfile? profile,
    int level,
    XpProgress xpProgress,
    int reputation,
  ) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                AppColors.spaceNavy.withValues(alpha: 0.95),
                AppColors.bgDeep.withValues(alpha: 0.97),
                const Color(0xF8090D15),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(
              color: AppColors.borderBright.withValues(alpha: 0.28),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppColors.liquidGold.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Top Luminous Accent Rim Highlight
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.transparent,
                      AppColors.liquidGold.withValues(alpha: 0.7),
                      AppColors.accentCyan.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Sheet Header & Minimize Drag Handle
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onToggleExpanded();
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    AppSpacing.md,
                    AppSpacing.base,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0x80FFB800),
                              Color(0x6606D0D8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          widget.onToggleExpanded();
                        },
                        icon: const Icon(Icons.expand_more_rounded, size: 18),
                        label: Text(
                          'Modeli İncele (Kapat)',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Fluid Navigation Tabs Bar
              _buildTabBar(),
              const SizedBox(height: AppSpacing.sm + 2),

              // Animated Tab Content Switcher
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: switch (_activeTab) {
                    CharacterTab.stats => _buildStatsTab(
                        profile,
                        level,
                        xpProgress,
                        reputation,
                      ),
                    CharacterTab.equipment => _buildEquipmentTab(
                        profile,
                        widget.equippedItems,
                      ),
                    CharacterTab.titles => _buildTitlesTab(profile),
                    CharacterTab.codex => _buildCodexTab(profile),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Segmented fluid tab bar (Stats, Equipment, Titles, Codex)
  Widget _buildTabBar() {
    final List<(CharacterTab, String, IconData)> tabs = <(CharacterTab, String, IconData)>[
      (CharacterTab.stats, 'Statlar', Icons.tune_rounded),
      (CharacterTab.equipment, 'Donanım', Icons.shield_outlined),
      (CharacterTab.titles, 'Unvanlar', Icons.workspace_premium_outlined),
      (CharacterTab.codex, 'Kodex', Icons.menu_book_rounded),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.spaceNavy.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.borderDefault.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: tabs.map(((CharacterTab, String, IconData) t) {
          final CharacterTab tab = t.$1;
          final String label = t.$2;
          final IconData icon = t.$3;
          final bool isSelected = _activeTab == tab;

          return Expanded(
            child: GestureDetector(
              onTap: () => _switchTab(tab),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: <Color>[
                            AppColors.liquidGold.withValues(alpha: 0.24),
                            AppColors.goldDim.withValues(alpha: 0.14),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
                  border: isSelected
                      ? Border.all(
                          color: AppColors.liquidGold.withValues(alpha: 0.7),
                          width: 1.2,
                        )
                      : null,
                  boxShadow: isSelected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: AppColors.liquidGold.withValues(alpha: 0.18),
                            blurRadius: 10,
                            spreadRadius: -1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      icon,
                      size: 15,
                      color: isSelected ? AppColors.liquidGold : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs + 1),
                    Text(
                      label,
                      style: isSelected
                          ? AppTextStyles.captionBold.copyWith(
                              color: AppColors.liquidGold,
                              letterSpacing: 0.3,
                            )
                          : AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// ── TAB 1: STATS CONTENT ─────────────────────────────────────────────────
  Widget _buildStatsTab(
    PlayerProfile? profile,
    int level,
    XpProgress xpProgress,
    int reputation,
  ) {
    return Column(
      key: const ValueKey<String>('tab_stats'),
      children: <Widget>[
        _buildIdentitySection(
          profile,
          level,
          xpProgress,
          reputation,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildQuickResources(profile),
        const SizedBox(height: AppSpacing.md),
        _buildCodexTile(),
        const SizedBox(height: AppSpacing.md),

        // Stat Allocation Panel (if points available or tutorial)
        if (widget.statTutorialStep && (profile?.statPoints ?? 0) <= 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildStatTutorialIntro(),
          ),
        if ((profile?.statPoints ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: TutorialAnchorScope(
              id: TutorialAnchorId.characterStatPanel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 4),
                    child: Row(
                      children: <Widget>[
                        Text(
                          'Stat puanları',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.liquidGold,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs + 2,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.liquidGold.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                            border: Border.all(
                              color: AppColors.liquidGold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '${profile!.statPoints} Puan Dağıtılabilir',
                            style: AppTextStyles.micro.copyWith(
                              color: AppColors.liquidGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatAllocationPanel(
                    availablePoints: profile.statPoints,
                  ),
                ],
              ),
            ),
          ),

        // Health Panel
        if (profile != null && profile.maxHealth > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: CharacterHealthPanel(
              profile: profile,
              inHospital: _isFuture(profile.hospitalUntil),
              inPrison: _isFuture(profile.prisonUntil),
            ),
          ),

        // Combat Stats Panel
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildCombatStats(profile, level, reputation),
        ),

        // Badges
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: BadgeShowcasePanel(),
        ),

        // Class details & abilities
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildClassDetails(profile),
        ),

        // Extra abilities & criminal record
        Padding(
          key: widget.classAbilitiesKey,
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: _buildExtraInfo(profile),
        ),
      ],
    );
  }

  /// ── TAB 2: EQUIPMENT CONTENT ─────────────────────────────────────────────
  Widget _buildEquipmentTab(
    PlayerProfile? profile,
    Map<String, InventoryItem?> equippedItems,
  ) {
    final int totalPower = profile?.power ?? 0;
    final int equippedCount =
        equippedItems.values.where((InventoryItem? it) => it != null).length;

    final List<EquipmentSlotDef> allSlots = <EquipmentSlotDef>[
      ...kLeftEquipmentSlots,
      ...kRightEquipmentSlots,
    ];

    return Column(
      key: const ValueKey<String>('tab_equipment'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Equipment Power Overview Card
        _glassCard(
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.liquidGold.withValues(alpha: 0.25),
                      AppColors.accentCyan.withValues(alpha: 0.12),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.55),
                  ),
                ),
                child: const Icon(
                  Icons.shield_moon_rounded,
                  color: AppColors.liquidGold,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Toplam Ekipman Gücü',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.mutedTitanium,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmtCompact(totalPower)} CP',
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$equippedCount / 8 Yuva Kuşanıldı',
                      style: AppTextStyles.captionBold.copyWith(
                        color: equippedCount == 8
                            ? AppColors.toxicNeon
                            : AppColors.liquidGold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Quick Socket Inspection List
        Text(
          'Kuşanılan Ekipman Yuvaları',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        ...allSlots.map((EquipmentSlotDef def) {
          final InventoryItem? item = equippedItems[def.slotKey];
          final bool isEquipped = item != null;
          final Color rarityColor = isEquipped
              ? AppColors.forRarity(item.rarity.name)
              : AppColors.mutedTitanium;

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  isEquipped
                      ? rarityColor.withValues(alpha: 0.14)
                      : AppColors.bgSurface.withValues(alpha: 0.6),
                  AppColors.bgDeep.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isEquipped
                    ? rarityColor.withValues(alpha: 0.55)
                    : AppColors.borderDefault.withValues(alpha: 0.35),
                width: isEquipped ? 1.2 : 1,
              ),
              boxShadow: isEquipped
                  ? <BoxShadow>[
                      BoxShadow(
                        color: rarityColor.withValues(alpha: 0.14),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 2,
              ),
              leading: isEquipped
                  ? ItemIconView(
                      iconValue: item.icon,
                      itemId: item.itemId,
                      itemType: item.itemType,
                      size: 34,
                    )
                  : Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(
                          color: AppColors.borderDefault.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(def.icon, color: AppColors.textTertiary, size: 18),
                    ),
              title: Text(
                isEquipped ? item.name : def.name,
                style: AppTextStyles.titleBold.copyWith(
                  color: isEquipped ? rarityColor : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                isEquipped
                    ? 'Güç: ${item.power} · +${item.enhancementLevel} Güçlendirme'
                    : 'Yuva Boş',
                style: AppTextStyles.caption.copyWith(
                  color: isEquipped ? AppColors.textSecondary : AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              trailing: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: isEquipped
                      ? AppColors.spaceNavy
                      : AppColors.liquidGold.withValues(alpha: 0.18),
                  foregroundColor:
                      isEquipped ? AppColors.textPrimary : AppColors.liquidGold,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(60, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    side: BorderSide(
                      color: isEquipped
                          ? AppColors.borderBright.withValues(alpha: 0.4)
                          : AppColors.liquidGold.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.onSlotTap?.call(def, item);
                },
                child: Text(
                  isEquipped ? 'İncele' : 'Kuşan',
                  style: AppTextStyles.captionBold.copyWith(
                    color: isEquipped ? AppColors.textPrimary : AppColors.liquidGold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  /// ── TAB 3: TITLES CONTENT ────────────────────────────────────────────────
  Widget _buildTitlesTab(PlayerProfile? profile) {
    final String? currentTitle = profile?.cosmeticTitle;

    final List<(String, String, String)> catalog = <(String, String, String)>[
      (
        'onur_nisani',
        'Onur Nişanı',
        'PvP arenalarında ve meydan muharebelerinde gösterilen üstün cesaret nişanı.',
      ),
      (
        'kodex_ustasi',
        'Kodex Ustası',
        'Atreia dünyasındaki tüm kadim yazıtları ve zindanları keşfeden usta kaşif unvanı.',
      ),
    ];

    return Column(
      key: const ValueKey<String>('tab_titles'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Active Title Banner
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Aktif Kozmetik Unvan',
                style: AppTextStyles.captionBold.copyWith(
                  color: AppColors.mutedTitanium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (hasCosmeticTitle(currentTitle)) ...<Widget>[
                Row(
                  children: <Widget>[
                    CosmeticTitleBadge(titleKey: currentTitle!),
                    const Spacer(),
                    TextButton(
                      onPressed: _updatingTitle
                          ? null
                          : () => _equipCosmeticTitle(null),
                      child: Text(
                        'Unvanı Çıkar',
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.mysticRuby,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...<Widget>[
                Text(
                  'Henüz kuşanılmış unvan yok. Aşağıdaki listeden seçin.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Selectable Titles Catalog
        Text(
          'Koleksiyon Unvanları',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        ...catalog.map(((String, String, String) t) {
          final String key = t.$1;
          final String title = t.$2;
          final String desc = t.$3;
          final bool isEquipped = currentTitle == key;

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  isEquipped
                      ? AppColors.liquidGold.withValues(alpha: 0.12)
                      : AppColors.bgSurface.withValues(alpha: 0.65),
                  AppColors.bgDeep.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isEquipped
                    ? AppColors.liquidGold.withValues(alpha: 0.65)
                    : AppColors.borderDefault.withValues(alpha: 0.35),
                width: isEquipped ? 1.4 : 1,
              ),
              boxShadow: isEquipped
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.liquidGold.withValues(alpha: 0.14),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.liquidGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    color: AppColors.liquidGold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: AppTextStyles.titleBold.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: isEquipped
                        ? AppColors.toxicNeon.withValues(alpha: 0.2)
                        : AppColors.liquidGold.withValues(alpha: 0.2),
                    foregroundColor: isEquipped
                        ? AppColors.toxicNeon
                        : AppColors.liquidGold,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(64, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  onPressed: isEquipped || _updatingTitle
                      ? null
                      : () => _equipCosmeticTitle(key),
                  child: Text(
                    isEquipped ? 'Seçili' : 'Kuşan',
                    style: AppTextStyles.captionBold.copyWith(
                      color: isEquipped ? AppColors.toxicNeon : AppColors.liquidGold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: AppSpacing.md + 2),
        // Badges showcase inside Titles tab
        const BadgeShowcasePanel(),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  /// ── TAB 4: CODEX CONTENT ─────────────────────────────────────────────────
  Widget _buildCodexTab(PlayerProfile? profile) {
    return Column(
      key: const ValueKey<String>('tab_codex'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm + 2),
                    decoration: BoxDecoration(
                      color: AppColors.liquidGold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: AppColors.liquidGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.liquidGold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Koleksiyon Kodex Kaşifi',
                          style: AppTextStyles.titleBold.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Atreia zindanları, efsanevi eşyalar ve canavarlar',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.mutedTitanium,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Kodex Keşif İlerlemesi',
                style: AppTextStyles.captionBold.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                child: const SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: 0.45,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.liquidGold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Hedef: 50 Keşif Eşiği',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    'Ödül: 📖 Kodex Kaşifi Çerçevesi',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.liquidGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.liquidGold,
                    foregroundColor: AppColors.darkObsidian,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onOpenCodex();
                  },
                  icon: const Icon(Icons.auto_stories_rounded, size: 18),
                  label: Text(
                    'Koleksiyon Kodexini Aç (Tam Ekran)',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.carbonVoid,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  /// ── REUSABLE GLASS CARD ──────────────────────────────────────────────────
  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.bgCardElevated.withValues(alpha: 0.68),
                AppColors.bgSurface.withValues(alpha: 0.58),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: AppColors.borderBright.withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.liquidGold.withValues(alpha: 0.05),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  /// ── IDENTITY & LEVEL / GUILD SECTION ─────────────────────────────────────
  Widget _buildIdentitySection(
    PlayerProfile? profile,
    int level,
    XpProgress xpProgress,
    int reputation,
  ) {
    final ReputationTier tier = reputationTierFor(reputation);
    final ReputationTierProgress tierProgress =
        reputationTierProgressFor(reputation);
    final int tierProgressPct =
        (tierProgress.progress.clamp(0.0, 1.0) * 100).round();
    final String name =
        profile?.displayName ?? profile?.username ?? 'Oyuncu';
    final String guild =
        (profile?.guildName != null && profile!.guildName!.isNotEmpty)
            ? '🏰 ${profile.guildName}'
            : 'Lonca Yok';

    final CharacterClass? charClass = profile?.characterClass;
    final String className = charClass == CharacterClass.warrior
        ? '🗡️ Savaşçı'
        : charClass == CharacterClass.alchemist
        ? '⚗️ Simyacı'
        : charClass == CharacterClass.shadow
        ? '🌑 Gölge'
        : 'Sınıf Seçilmedi';

    return _glassCard(
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: widget.onCustomizeProfile,
            child: Stack(
              children: <Widget>[
                ProfileAvatar(
                  size: 58,
                  avatarUrl: profile?.avatarUrl,
                  backgroundColor: AppColors.spaceNavy,
                  glowFrame: profile?.avatarFrame == 'glow',
                  codexFrame: profile?.avatarFrame == 'codex',
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.spaceNavy,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(
                      Icons.edit,
                      size: 11,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      name,
                      style: AppTextStyles.titleBold.copyWith(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.spaceNavy.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(
                          color: AppColors.borderBright.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        className,
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasCosmeticTitle(profile?.cosmeticTitle)) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  CosmeticTitleBadge(titleKey: profile!.cosmeticTitle),
                ],
                const SizedBox(height: 3),
                Text(
                  'Seviye $level • $guild',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                GestureDetector(
                  onTap: widget.onOpenReputation,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.military_tech_rounded,
                        size: 13,
                        color: AppColors.liquidGold,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${tier.title} · %$tierProgressPct',
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.liquidGold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ColoredBox(color: Colors.white.withValues(alpha: 0.1)),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: xpProgress.percent.clamp(0.0, 1.0),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  AppColors.liquidGold,
                                  AppColors.warningSolar,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'XP: ${_fmtCompact(xpProgress.xpInLevel)} / ${_fmtCompact(xpProgress.xpNeededInLevel)}',
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ── QUICK RESOURCES (POWER, ENERGY, TOLERANCE) ───────────────────────────
  Widget _buildQuickResources(PlayerProfile? profile) {
    Widget powerCard = _miniResource(
      '⚔️ Güç',
      _fmtCompact(profile?.power ?? 0),
      AppColors.liquidGold,
    );

    if (widget.highlightPowerTutorial) {
      powerCard = TutorialAnchorScope(
        id: TutorialAnchorId.characterPowerStat,
        child: powerCard,
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: powerCard),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _miniResource(
            '⚡ Enerji',
            '${profile?.energy ?? 0}/${profile?.maxEnergy ?? 100}',
            AppColors.cyberFuchsia,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _miniResource(
            '⚖️ Tolerans',
            '${profile?.tolerance ?? 0}%',
            AppColors.toxicNeon,
          ),
        ),
      ],
    );
  }

  Widget _miniResource(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleBold.copyWith(
              color: color,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.micro.copyWith(
              color: AppColors.mutedTitanium,
            ),
          ),
        ],
      ),
    );
  }

  /// ── CODEX SHORTCUT TILE ──────────────────────────────────────────────────
  Widget _buildCodexTile() {
    return TutorialAnchorScope(
      id: TutorialAnchorId.characterCodexTile,
      child: _glassCard(
        child: InkWell(
          onTap: widget.onOpenCodex,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 1),
                decoration: BoxDecoration(
                  color: AppColors.liquidGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.liquidGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Koleksiyon Kodex',
                      style: AppTextStyles.titleBold.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Eşya, boss ve zindan keşiflerini topla.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.mutedTitanium,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedTitanium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ── STAT TUTORIAL INTRO ──────────────────────────────────────────────────
  Widget _buildStatTutorialIntro() {
    return TutorialAnchorScope(
      id: TutorialAnchorId.characterStatPanel,
      child: _glassCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.cyberFuchsia.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
                border: Border.all(
                  color: AppColors.cyberFuchsia.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.auto_graph_rounded,
                color: AppColors.cyberFuchsia,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Stat puanları',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Level atladıkça Güç, Çeviklik ve Dayanıklılık kazanırsın. Zindanda level atlayınca bu panel açılır.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.mutedTitanium,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ── COMBAT STATS ─────────────────────────────────────────────────────────
  Widget _buildCombatStats(PlayerProfile? profile, int level, int reputation) {
    final int winRate =
        (profile?.pvpWins ?? 0) + (profile?.pvpLosses ?? 0) > 0
            ? (((profile?.pvpWins ?? 0) /
                          ((profile?.pvpWins ?? 0) +
                              (profile?.pvpLosses ?? 0))) *
                      100)
                  .round()
            : 0;

    return _glassCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: CharacterCombatStatsPanel(
        power: _fmtCompact(profile?.power ?? 0),
        health: profile?.health ?? 0,
        maxHealth: profile?.maxHealth ?? 0,
        attack: '${profile?.attack ?? 0}',
        defense: '${profile?.defense ?? 0}',
        luck: profile == null
            ? '0'
            : '${effectivePlayerLuckFromProfile(profile)}',
        luckSubtitle: profile == null || profile.equipBonusLuck <= 0
            ? null
            : 'baz ${profile.luck ?? 0}',
        pvpWinRate: '%$winRate',
        pvpRating: '${profile?.pvpRating ?? 0}',
        reputation: reputation,
      ),
    );
  }

  /// ── CLASS DETAILS & TRAITS ───────────────────────────────────────────────
  Widget _buildClassDetails(PlayerProfile? profile) {
    final CharacterClass? charClass = profile?.characterClass;
    if (charClass == null) return const SizedBox.shrink();

    final bool isAlchemist = charClass == CharacterClass.alchemist;
    final String title = charClass == CharacterClass.warrior
        ? 'Savaşçı'
        : charClass == CharacterClass.alchemist
        ? 'Simyacı'
        : 'Gölge';
    final String desc = charClass == CharacterClass.warrior
        ? 'Yakın dövüşte uzmanlaşmış bir sınıf. PvP galibiyetlerinden sonra 30 dk boyunca saldırıyı %10 (üst üste 3 kazanımda %20) artırarak "Kan Hırsı" durumuna geçer.'
        : charClass == CharacterClass.alchemist
        ? 'Biyolojik toleransları daha iyidir ve her gün ücretsiz Minor Detox Drink (Toksin Atıcı) üretebilir. Craft odaklı karakterdir.'
        : 'Şüpheli faaliyetlerde ustalaşmış, gizlilik ve kaçınma oranları yüksek bir sınıftır. Rüşvet maliyetleri %25 daha düşüktür.';

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '🎭 Sınıf Özellikleri: $title',
            style: AppTextStyles.title.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            desc,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
          if (isAlchemist) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: widget.claimingDetox ? null : widget.onClaimDetox,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coralFlare.withValues(alpha: 0.14),
                  foregroundColor: AppColors.coralFlare,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  side: BorderSide(
                    color: AppColors.coralFlare.withValues(alpha: 0.35),
                  ),
                ),
                child: widget.claimingDetox
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.coralFlare,
                        ),
                      )
                    : Text(
                        'Günlük Detox Al',
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.coralFlare,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ── EXTRA INFO & CRIME RECORD ────────────────────────────────────────────
  Widget _buildExtraInfo(PlayerProfile? profile) {
    final CharacterClass? charClass = profile?.characterClass;
    final List<CharacterAbilityDef> abilities = abilitiesForClass(charClass);
    final Color accent = accentForClass(charClass);
    final bool bloodlustActive = isWarriorBloodlustActive(profile);

    return _glassCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: true,
          title: Text(
            'Yetenekler & Adli Sicil',
            style: AppTextStyles.title.copyWith(color: AppColors.textSecondary),
          ),
          iconColor: AppColors.liquidGold,
          collapsedIconColor: AppColors.mutedTitanium,
          children: <Widget>[
            if (charClass != null && abilities.isNotEmpty) ...<Widget>[
              TutorialAnchorScope(
                id: TutorialAnchorId.characterClassAbilities,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '${_classTitle(charClass)} — Sınıf Yetenekleri',
                      style: AppTextStyles.captionBold.copyWith(color: accent),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...abilities.map((CharacterAbilityDef ability) {
                      final bool isSignature =
                          ability.kind == CharacterAbilityKind.signature;
                      final bool isActive =
                          ability.name == 'Kan Hırsı' && bloodlustActive;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _abilityTile(
                          ability: ability,
                          accent: accent,
                          isSignature: isSignature,
                          isActive: isActive,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Divider(color: AppColors.mutedTitanium.withValues(alpha: 0.15)),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              'Adli Sicil',
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _infoRow(
              'Şüphe Seviyesi',
              '${effectiveSuspicionLevel(profile)}%'
              '${profile?.characterClass == CharacterClass.shadow ? ' (tavan 80)' : ''}',
            ),
            _infoRow(
              'Bağımlılık Seviyesi',
              'Lvl ${profile?.addictionLevel ?? 0}',
            ),
          ],
        ),
      ),
    );
  }

  String _classTitle(CharacterClass charClass) {
    return switch (charClass) {
      CharacterClass.warrior => 'Savaşçı',
      CharacterClass.alchemist => 'Simyacı',
      CharacterClass.shadow => 'Gölge',
    };
  }

  Widget _abilityTile({
    required CharacterAbilityDef ability,
    required Color accent,
    required bool isSignature,
    required bool isActive,
  }) {
    final Color borderColor = isActive
        ? AppColors.toxicNeon
        : isSignature
        ? AppColors.liquidGold.withValues(alpha: 0.45)
        : accent.withValues(alpha: 0.28);
    final Color bgColor = isActive
        ? AppColors.toxicNeon.withValues(alpha: 0.08)
        : isSignature
        ? AppColors.liquidGold.withValues(alpha: 0.06)
        : AppColors.darkObsidian.withValues(alpha: 0.55);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(ability.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        ability.name,
                        style: AppTextStyles.captionBold.copyWith(
                          color: isActive
                              ? AppColors.toxicNeon
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isSignature)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs + 2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.liquidGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                          border: Border.all(
                            color: AppColors.liquidGold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          isActive ? 'AKTİF' : 'ÖZEL',
                          style: AppTextStyles.micro.copyWith(
                            color: isActive
                                ? AppColors.toxicNeon
                                : AppColors.liquidGold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ability.effect,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          ),
          Text(
            value,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
