import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/gkk_tab_bar.dart';
import '../../components/common/app_messenger.dart';
import '../../components/common/item_icon_view.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/enhancement_stats.dart';
import '../../models/enhancement_config_model.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../repositories/enhancement_repository.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_anchor_registry.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_inventory_target.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../l10n/l10n.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/logout_helper.dart';
import 'enhancement_design.dart';
import 'widgets/enhancement_forge_effects.dart';
import 'widgets/enhancement_rune_picker_sheet.dart';
import 'widgets/enhancement_scroll_picker_sheet.dart';
import 'widgets/enhancement_upgrade_table_dialog.dart';

// ============================================================================
// GÜÇLENDİRME EKRANI — Knight Online tarzı kompakt örs (anvil) düzeni.

typedef RuneType = String;

enum _EnhanceResultType { success, failure, destroyed }

enum _InvTab { all, gear, scroll, rune, other }

enum _ForgeVisualPhase { idle, enhancing, success, failure, destroyed }

// ── Helpers ───────────────────────────────────────────────────────────────
String _formatGold(int amount) {
  if (amount >= 1000000000) {
    return '${(amount / 1000000000).toStringAsFixed(1)}G';
  }
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}K';
  }
  return amount.toString();
}

String _scrollIdForRarity(Rarity rarity) {
  if (rarity == Rarity.common || rarity == Rarity.uncommon) {
    return 'scroll_upgrade_low';
  }
  if (rarity == Rarity.rare || rarity == Rarity.epic) {
    return 'scroll_upgrade_middle';
  }
  return 'scroll_upgrade_high';
}

String _scrollLabelForRarity(Rarity rarity) {
  if (rarity == Rarity.common || rarity == Rarity.uncommon) {
    return 'Düşük Sınıf Parşömen';
  }
  if (rarity == Rarity.rare || rarity == Rarity.epic) {
    return 'Orta Sınıf Parşömen';
  }
  return 'Yüksek Sınıf Parşömen';
}

String _enhanceErrorMessage(String error) {
  switch (error) {
    case 'insufficient_gold':
    case 'İşlem sırasında altın yetersiz kaldı':
      return 'Yetersiz altın!';
    case 'no_scroll':
    case 'Geliştirme parşömeni yetersiz':
      return 'Parşömen yok!';
    case 'no_rune':
    case 'Seçilen rune yetersiz':
      return 'Rune yok!';
    case 'item_not_found':
      return 'Eşya bulunamadı.';
    case 'cannot_enhance':
      return 'Bu eşya güçlendirilemez.';
    case 'max_level':
      return 'Maksimum seviye (+10).';
    default:
      if (error.startsWith('Yetkisiz')) return 'Yetkisiz işlem.';
      return error;
  }
}

bool _isEquipment(InventoryItem item) {
  const Set<ItemType> equipTypes = <ItemType>{ItemType.weapon, ItemType.armor};
  return equipTypes.contains(item.itemType) || item.equipSlot != EquipSlot.none;
}

bool _isEnhanceable(InventoryItem item) =>
    _isEquipment(item) && item.enhancementLevel < 10;

Color _rarityColor(Rarity rarity) => getRarityColor(rarity);

String _riskLabel(int level) {
  if (level >= 6) return 'YOK OLMA';
  if (level >= 4) return 'Düşer';
  return 'Güvenli';
}

Color _riskColor(int level) {
  if (level >= 6) return AppColors.mysticRuby;
  if (level >= 4) return AppColors.coralFlare;
  return AppColors.toxicNeon;
}

Color _successColor(int chance) {
  if (chance >= 70) return AppColors.toxicNeon;
  if (chance >= 35) return AppColors.warningSolar;
  if (chance >= 20) return AppColors.coralFlare;
  return AppColors.mysticRuby;
}

// KO & Aion 2 ilahî ocak tasarım tonları
const Color _kFrameGold = AionForgeTokens.divineBrass;
const Color _kSlotBg = AionForgeTokens.pedestalDark;
const Duration _kForgeEnhancingMin = Duration(seconds: 6);
const Duration _kForgeResultHold = Duration(seconds: 4);

// ============================================================================
// MAIN SCREEN
// ============================================================================
class EnhancementScreen extends ConsumerStatefulWidget {
  const EnhancementScreen({super.key});

  @override
  ConsumerState<EnhancementScreen> createState() => _EnhancementScreenState();
}

class _EnhancementScreenState extends ConsumerState<EnhancementScreen>
    with TickerProviderStateMixin {
  InventoryItem? _selectedItem;
  InventoryItem? _selectedScroll;
  RuneType _selectedRune = 'none';
  bool _isEnhancing = false;
  _InvTab _invTab = _InvTab.all;
  EnhancementConfig _config = EnhancementConfig.fallback;
  _ForgeVisualPhase _forgePhase = _ForgeVisualPhase.idle;
  int? _enhanceBaseLevel;
  Timer? _strikeTimer;

  /// Güçlendirme nabzı + sonuç sarsıntısı/pop'u.
  late final AnimationController _pulseCtrl;
  late final AnimationController _resultCtrl;
  late final AnimationController _borderGlowCtrl;
  late final AnimationController _pedestalRotationCtrl;
  late final EnhancementForgeVfxController _vfxCtrl;
  _EnhanceResultType? _animType;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _borderGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pedestalRotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _vfxCtrl = EnhancementForgeVfxController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(inventoryProvider.notifier).loadInventory();
      await ref.read(playerProvider.notifier).loadProfile();
      final EnhancementConfig config = await enhancementRepository.fetchConfig();
      if (!mounted) return;
      setState(() => _config = config);
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.enhancement);
      _syncEnhanceTutorialInventoryTab();
    });
  }

  void _syncEnhanceTutorialInventoryTab() {
    final TutorialStepV2? step = ref.read(tutorialProvider).activeStep;
    if (step?.id != 'enhance_pick_item') return;
    if (_invTab == _InvTab.gear) {
      TutorialAnchorRegistry.instance.scheduleRefresh();
      return;
    }
    setState(() => _invTab = _InvTab.gear);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialAnchorRegistry.instance.scheduleRefresh();
    });
  }

  /// No gear / parchment → show Devam so coach not stuck on GÜÇLENDİR.
  void _syncEnhanceCoachBypass({required bool canEnhance}) {
    if (!mounted) return;
    final TutorialState tut = ref.read(tutorialProvider);
    final String? stepId = tut.activeStep?.id;
    final TutorialController ctrl = ref.read(tutorialProvider.notifier);

    if (stepId == 'enhance_pick_item') {
      final bool hasItem =
          ref.read(inventoryProvider).items.any(_isEnhanceable);
      if (!hasItem) {
        ctrl.setCoachBypass(
          enabled: true,
          body: context.l10n.tut_enhance_bypass_no_item_body,
        );
      } else {
        ctrl.setCoachBypass(enabled: false);
      }
      return;
    }

    if (stepId == 'enhance_tap_forge') {
      final bool missingItemOrScroll = _selectedItem == null ||
          (_autoFindScroll(_selectedItem!) == null &&
              _compatibleScroll() == null);
      if (!canEnhance && !_isEnhancing && missingItemOrScroll) {
        ctrl.setCoachBypass(
          enabled: true,
          body: context.l10n.tut_enhance_bypass_no_scroll_body,
        );
      } else {
        ctrl.setCoachBypass(enabled: false);
      }
      return;
    }

    if (tut.forceShowManualCta) {
      ctrl.setCoachBypass(enabled: false);
    }
  }

  String? _tutorialEnhanceWeaponRowId(InventoryState state) =>
      TutorialInventoryTarget.enhanceWeaponRowId(state);

  @override
  void dispose() {
    _strikeTimer?.cancel();
    _pulseCtrl.dispose();
    _resultCtrl.dispose();
    _borderGlowCtrl.dispose();
    _pedestalRotationCtrl.dispose();
    _vfxCtrl.dispose();
    super.dispose();
  }

  Color _forgeGlowColor() {
    switch (_forgePhase) {
      case _ForgeVisualPhase.enhancing:
        return AppColors.liquidGold;
      case _ForgeVisualPhase.success:
        return AppColors.toxicNeon;
      case _ForgeVisualPhase.failure:
      case _ForgeVisualPhase.destroyed:
        return AppColors.mysticRuby;
      case _ForgeVisualPhase.idle:
        return _kFrameGold;
    }
  }

  Color? _resultSlotAccent() {
    switch (_forgePhase) {
      case _ForgeVisualPhase.enhancing:
        return AppColors.liquidGold;
      case _ForgeVisualPhase.success:
        return AppColors.toxicNeon;
      case _ForgeVisualPhase.failure:
      case _ForgeVisualPhase.destroyed:
        return AppColors.mysticRuby;
      case _ForgeVisualPhase.idle:
        return _selectedItem != null
            ? AppColors.toxicNeon.withValues(alpha: 0.7)
            : null;
    }
  }

  Future<void> _clearForgeResultVisual() async {
    if (!mounted) return;
    if (_forgePhase == _ForgeVisualPhase.destroyed) {
      setState(() {
        _selectedItem = null;
        _selectedScroll = null;
      });
    }
    setState(() {
      _forgePhase = _ForgeVisualPhase.idle;
      _animType = null;
      _enhanceBaseLevel = null;
    });
    _borderGlowCtrl.stop();
    _borderGlowCtrl.value = 0;
    _resultCtrl.reset();
    _vfxCtrl.reset();
  }

  _EnhanceResultType _resolveResultType({
    required bool destroyed,
    required bool success,
    required int previousLevel,
    required int newLevel,
  }) {
    if (destroyed) return _EnhanceResultType.destroyed;
    if (success && newLevel > previousLevel) return _EnhanceResultType.success;
    return _EnhanceResultType.failure;
  }

  (double, Offset) _heroTransform() {
    if (_isEnhancing) {
      final double s = 1 + 0.06 * math.sin(_pulseCtrl.value * 2 * math.pi);
      return (s, Offset.zero);
    }
    if (_resultCtrl.isAnimating && _animType != null) {
      final double t = _resultCtrl.value;
      switch (_animType!) {
        case _EnhanceResultType.success:
          return (1 + math.sin(t * math.pi) * 0.22, Offset.zero);
        case _EnhanceResultType.failure:
          return (1.0, Offset(math.sin(t * math.pi * 8) * 6 * (1 - t), 0));
        case _EnhanceResultType.destroyed:
          return ((1 - t * 0.4).clamp(0.6, 1.0), Offset.zero);
      }
    }
    return (1.0, Offset.zero);
  }

  // ── Aksiyon ────────────────────────────────────────────────────────────────
  Future<void> _enhance() async {
    final InventoryItem? item = _selectedItem;
    if (item == null) return;
    final String? authId = SupabaseService.client.auth.currentUser?.id;
    if (authId == null || authId.isEmpty) {
      _showSnack('Oturum bulunamadı!');
      return;
    }

    final int cost = _config.goldCostForItem(item);
    final int gold = ref.read(playerProvider).profile?.gold ?? 0;
    if (gold < cost) {
      _showSnack('Yetersiz altın! Gerekli: ${_formatGold(cost)}');
      return;
    }
    if (_compatibleScroll() == null) {
      _showSnack('Uyumlu parşömen gerekli!');
      return;
    }

    AppHaptics.medium();
    setState(() {
      _isEnhancing = true;
      _forgePhase = _ForgeVisualPhase.enhancing;
      _animType = null;
      _enhanceBaseLevel = item.enhancementLevel;
    });
    _pulseCtrl.repeat();
    _borderGlowCtrl.repeat();
    _vfxCtrl.triggerAnvilStrike();

    // Çoklu örs çekiç vuruşu ve kıvılcım patlamaları
    _strikeTimer?.cancel();
    _strikeTimer = Timer.periodic(const Duration(milliseconds: 950), (Timer t) {
      if (!mounted || !_isEnhancing) {
        t.cancel();
        return;
      }
      _vfxCtrl.triggerAnvilStrike();
      AppHaptics.medium();
    });

    try {
      final List<dynamic> waited = await Future.wait<dynamic>(<Future<dynamic>>[
        SupabaseService.client.rpc(
          'enhance_item',
          params: <String, dynamic>{
            'p_player_id': authId,
            'p_row_id': item.rowId,
            'p_rune_type': _selectedRune,
          },
        ),
        Future<void>.delayed(_kForgeEnhancingMin),
      ]);
      final dynamic result = waited[0];

      if (result is! Map) {
        if (mounted) _showSnack('Güçlendirme yanıtı geçersiz.');
        return;
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(result);
      final String? error = data['error'] as String?;
      if (error != null && error.isNotEmpty) {
        if (mounted) _showSnack(_enhanceErrorMessage(error));
        return;
      }

      final bool success = data['success'] as bool? ?? false;
      final bool destroyed = data['destroyed'] as bool? ?? false;
      final int previousLevel = item.enhancementLevel;
      final int newLevel =
          (data['new_level'] as num?)?.toInt() ?? previousLevel;

      final _EnhanceResultType resultType = _resolveResultType(
        destroyed: destroyed,
        success: success,
        previousLevel: previousLevel,
        newLevel: newLevel,
      );

      if (mounted) {
        setState(() {
          if (!destroyed) {
            _selectedItem = item.copyWith(enhancementLevel: newLevel);
          }
        });
      }

      await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
      await ref.read(playerProvider.notifier).loadProfile();

      if (mounted) {
        setState(() => _selectedRune = 'none');
      }

      if (mounted && !destroyed) {
        InventoryItem? refreshed;
        for (final InventoryItem candidate
            in ref.read(inventoryProvider).items) {
          if (candidate.rowId == item.rowId) {
            refreshed = candidate;
            break;
          }
        }
        InventoryItem? scrollRefreshed;
        if (_selectedScroll != null) {
          for (final InventoryItem candidate
              in ref.read(inventoryProvider).items) {
            if (candidate.rowId == _selectedScroll!.rowId &&
                candidate.quantity > 0) {
              scrollRefreshed = candidate;
              break;
            }
          }
        }
        setState(() {
          _selectedItem = refreshed ?? _selectedItem;
          _selectedScroll =
              scrollRefreshed ??
              (_selectedItem != null ? _autoFindScroll(_selectedItem!) : null);
        });
      }

      if (mounted) {
        _strikeTimer?.cancel();
        _strikeTimer = null;
        _pulseCtrl.stop();
        _pulseCtrl.value = 0;
        _borderGlowCtrl.stop();
        _borderGlowCtrl.value = 0;
        switch (resultType) {
          case _EnhanceResultType.success:
            AppHaptics.heavy();
            _vfxCtrl.triggerSuccess(newLevel: newLevel);
          case _EnhanceResultType.failure:
            AppHaptics.vibrate();
            _vfxCtrl.triggerFailure(isDestroyed: false);
          case _EnhanceResultType.destroyed:
            AppHaptics.heavy();
            _vfxCtrl.triggerFailure(isDestroyed: true);
        }
        setState(() {
          _isEnhancing = false;
          _animType = resultType;
          _forgePhase = switch (resultType) {
            _EnhanceResultType.success => _ForgeVisualPhase.success,
            _EnhanceResultType.failure => _ForgeVisualPhase.failure,
            _EnhanceResultType.destroyed => _ForgeVisualPhase.destroyed,
          };
        });
        _resultCtrl.forward(from: 0);
        await Future<void>.delayed(_kForgeResultHold);
        if (mounted) await _clearForgeResultVisual();
        if (mounted) {
          await TutorialTriggers.onEnhancementAttempt(ref);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Hata: $e');
    } finally {
      _strikeTimer?.cancel();
      _strikeTimer = null;
      if (mounted && _forgePhase == _ForgeVisualPhase.enhancing) {
        _pulseCtrl.stop();
        _pulseCtrl.value = 0;
        _borderGlowCtrl.stop();
        _borderGlowCtrl.value = 0;
        _vfxCtrl.reset();
        setState(() {
          _isEnhancing = false;
          _forgePhase = _ForgeVisualPhase.idle;
          _animType = null;
        });
      }
    }
  }

  InventoryItem? _compatibleScroll() {
    if (_selectedItem == null || _selectedScroll == null) return null;
    final String requiredId = _scrollIdForRarity(_selectedItem!.rarity);
    return _selectedScroll!.itemId == requiredId ? _selectedScroll : null;
  }

  bool _isScrollItem(InventoryItem item) =>
      item.itemType == ItemType.scroll || item.itemId.contains('scroll');

  bool _isRuneItem(InventoryItem item) =>
      item.itemType == ItemType.rune || item.itemId.startsWith('rune_');

  InventoryItem? _selectedRuneItem() {
    if (_selectedRune == 'none') return null;
    final String runeId = 'rune_$_selectedRune';
    for (final InventoryItem item in ref.watch(inventoryProvider).items) {
      if (item.itemId == runeId) return item;
    }
    return null;
  }

  void _resetSelection() {
    setState(() {
      _selectedItem = null;
      _selectedScroll = null;
      _selectedRune = 'none';
    });
  }

  void _openUpgradeTable() {
    showEnhancementUpgradeTableDialog(
      context: context,
      currentLevel: _selectedItem?.enhancementLevel ?? 0,
      upgradeCosts: _config.baseCosts,
      upgradeChances: _config.successRates,
      formatGold: _formatGold,
      riskLabel: _riskLabel,
      riskColor: _riskColor,
      successColor: _successColor,
    );
  }

  Future<void> _openRunePicker() async {
    if (_isEnhancing) return;
    final EnhancementRuneType? picked = await showEnhancementRunePickerSheet(
      context: context,
      ownedRunes: ref.read(inventoryProvider).items,
      selectedRune: _selectedRune,
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedRune = picked);
  }

  Future<void> _openScrollPicker() async {
    if (_isEnhancing) return;
    final String? requiredId = _selectedItem != null
        ? _scrollIdForRarity(_selectedItem!.rarity)
        : null;
    final InventoryItem? picked = await showEnhancementScrollPickerSheet(
      context: context,
      ownedScrolls: ref.read(inventoryProvider).items,
      requiredScrollId: requiredId,
      selectedScroll: _selectedScroll,
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedScroll = picked);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppMessenger.show(context, message);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD — üst sabit örs paneli + alt kaydırılabilir envanter
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final int currentLevel = _selectedItem?.enhancementLevel ?? 0;
    final int nextCost = _config.goldCostForItem(_selectedItem);
    final int successChance = _config.successChanceForLevel(currentLevel);
    final int gold = ref.watch(playerProvider).profile?.gold ?? 0;
    final bool canEnhance =
        _selectedItem != null &&
        _compatibleScroll() != null &&
        gold >= nextCost &&
        !_isEnhancing &&
        _forgePhase == _ForgeVisualPhase.idle;

    // Inventory / gold / selection → coach Devam when forge blocked.
    ref.watch(inventoryProvider);
    ref.watch(tutorialProvider.select((TutorialState s) => s.activeStep?.id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncEnhanceCoachBypass(canEnhance: canEnhance);
    });

    ref.listen<String?>(
      tutorialProvider.select((TutorialState state) => state.activeStep?.id),
      (String? previous, String? next) {
        if (next == 'enhance_pick_item' && previous != next) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncEnhanceTutorialInventoryTab();
          });
        }
      },
    );

    return PopScope(
      canPop: GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.carbonVoid,
        appBar: GameTopBar(
          title: 'Güçlendirme',
          onLogout: () async => performLogout(ref),
        ),
        extendBody: true,
        bottomNavigationBar: GameBottomBar(
          currentRoute: AppRoutes.enhancement,
          onLogout: () async => performLogout(ref),
        ),
        body: GameScreenBackground(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double anvilMaxH = constraints.maxHeight * 0.54;
              return Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: anvilMaxH),
                      child: SingleChildScrollView(
                        child: _buildAnvilPanel(
                          successChance: successChance,
                          nextCost: nextCost,
                          gold: gold,
                          currentLevel: currentLevel,
                          canEnhance: canEnhance,
                          config: _config,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    Expanded(child: _buildInventoryPanel()),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── ÖRS PANELİ (kompakt) ────────────────────────────────────────────────
  Widget _buildAnvilPanel({
    required int successChance,
    required int nextCost,
    required int gold,
    required int currentLevel,
    required bool canEnhance,
    required EnhancementConfig config,
  }) {
    final Color accent = _selectedItem != null
        ? _rarityColor(_selectedItem!.rarity)
        : _kFrameGold;
    final InventoryItem? runeItem = _selectedRuneItem();
    final bool scrollOk = _compatibleScroll() != null;
    final Color resultAccent = _resultSlotAccent() ?? AppColors.toxicNeon.withValues(alpha: 0.7);
    final int previewLevel = _selectedItem?.enhancementLevel ?? currentLevel;
    final int? resultLevel = switch (_forgePhase) {
      _ForgeVisualPhase.idle => previewLevel + 1,
      _ForgeVisualPhase.enhancing => null,
      _ForgeVisualPhase.success => _selectedItem?.enhancementLevel,
      _ForgeVisualPhase.failure => _selectedItem?.enhancementLevel,
      _ForgeVisualPhase.destroyed => _enhanceBaseLevel ?? previewLevel,
    };

    // Rün ve koruma durumu çözümlemesi
    final EnhancementRuneCatalogEntry? activeRune =
        _selectedRune != 'none' ? kEnhancementRuneCatalog[_selectedRune] : null;
    final int runeBonus = activeRune?.successBonusPercent ?? 0;
    final int effectiveSuccessChance = (successChance + runeBonus).clamp(0, 100);

    final bool hasAegisProtection = _selectedRune == 'protection';
    final bool hasBlessedProtection = _selectedRune == 'blessed';
    final bool hasPartialProtection =
        _selectedRune == 'superior' || _selectedRune == 'legendary';

    final (IconData protIcon, Color protColor, String protBadge, String protTooltip) = () {
      if (hasAegisProtection) {
        return (
          Icons.shield_rounded,
          AppColors.danger,
          'AEGIS KORUMA',
          'Aegis Koruma Mührü aktif: Başarısızlıkta eşya kesinlikle kırılmaz!',
        );
      }
      if (hasBlessedProtection) {
        return (
          Icons.verified_user_rounded,
          AppColors.gold,
          'SEVİYE KORUMA',
          'Kutsal Işık aktif: Başarısızlık halinde eşyanın seviyesi düşmez!',
        );
      }
      if (hasPartialProtection) {
        final int shieldPct = _selectedRune == 'legendary' ? 75 : 50;
        return (
          Icons.shield_moon_rounded,
          AppColors.accentPurple,
          '%$shieldPct KALKAN',
          'Kadim rün koruma kalkanı aktif: Yıkım riski %$shieldPct azaltılmıştır.',
        );
      }
      if (currentLevel < 4) {
        return (
          Icons.verified_user_rounded,
          AionForgeTokens.emeraldSafe,
          'GÜVENLİ',
          'Seviye +0..+3 güvenli bölge: Kırılma veya seviye düşüşü riski yoktur.',
        );
      }
      if (currentLevel >= 6) {
        return (
          Icons.gpp_maybe_rounded,
          AionForgeTokens.crimsonBreak,
          'YOK OLMA',
          'Kritik Seviye (+6..+10): Koruma rünü olmadan başarısızlıkta eşya parçalanır!',
        );
      }
      return (
        Icons.shield_moon_outlined,
        AionForgeTokens.amberWarning,
        'DÜŞME',
        'Seviye +4..+5: Başarısızlık halinde eşya -1 seviye geriler.',
      );
    }();

    Widget panel = Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm + 2, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: AionForgeTokens.pedestalDark.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: _forgePhase == _ForgeVisualPhase.idle
              ? AionForgeTokens.divineBrass.withValues(alpha: 0.55)
              : _forgeGlowColor().withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          if (_forgePhase != _ForgeVisualPhase.idle)
            BoxShadow(
              color: _forgeGlowColor().withValues(alpha: 0.3),
              blurRadius: 26,
              spreadRadius: -1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 1. Divine Forge Header
          Row(
            children: <Widget>[
              const Text('⚡', style: TextStyle(fontSize: 14)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'AİON İLAHÎ OCAĞI',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                    color: AionForgeTokens.celestialGold,
                  ),
                ),
              ),
              EnhIconChipButton(
                icon: Icons.table_chart_outlined,
                label: 'Oran Tablosu',
                onTap: _openUpgradeTable,
                accent: AionForgeTokens.celestialGold,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // 2. Central Mystical Sanctuary: Left Slots + Central Anvil Pedestal + Right Slots
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Sol Yuvalar (Geliştirme Taşı & Tamamlayıcı Tılsım)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ForgeSlotContainer(
                    slotKey: const Key('enhancement_scroll_slot'),
                    size: 54,
                    label: 'Geliştirme Taşı',
                    icon: Icons.auto_awesome,
                    accentColor: _selectedScroll != null
                        ? (scrollOk ? AionForgeTokens.celestialGold : AionForgeTokens.crimsonBreak)
                        : AionForgeTokens.divineBrass,
                    badgeText: _selectedScroll != null && _selectedScroll!.quantity > 1
                        ? 'x${_selectedScroll!.quantity}'
                        : null,
                    onTap: _isEnhancing ? null : _openScrollPicker,
                    onClear: _selectedScroll != null && !_isEnhancing
                        ? () => setState(() => _selectedScroll = null)
                        : null,
                    child: _selectedScroll != null
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: ItemIconView(
                              iconValue: _selectedScroll!.icon,
                              itemId: _selectedScroll!.itemId,
                              itemType: _selectedScroll!.itemType,
                              size: 40,
                              expand: true,
                              fallback: '📜',
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  ForgeSlotContainer(
                    size: 54,
                    label: 'Tılsım / Rune',
                    icon: Icons.flare_rounded,
                    accentColor: _selectedRune != 'none'
                        ? (activeRune?.glowColor ?? AionForgeTokens.arcaneViolet)
                        : AionForgeTokens.divineBrass,
                    badgeText: _selectedRune != 'none' ? _selectedRune.toUpperCase() : null,
                    onTap: _isEnhancing ? null : _openRunePicker,
                    onClear: _selectedRune != 'none' && !_isEnhancing
                        ? () => setState(() => _selectedRune = 'none')
                        : null,
                    child: _selectedRune != 'none'
                        ? (runeItem != null
                            ? Padding(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                child: ItemIconView(
                                  iconValue: runeItem.icon,
                                  itemId: runeItem.itemId,
                                  itemType: runeItem.itemType,
                                  size: 40,
                                  expand: true,
                                  fallback: '🔮',
                                ),
                              )
                            : const Center(
                                child: Text('🔮', style: TextStyle(fontSize: 20)),
                              ))
                        : null,
                  ),
                ],
              ),

              // Merkez İlahî Örs Kaidesi
              AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[
                  _pulseCtrl,
                  _resultCtrl,
                  _pedestalRotationCtrl,
                ]),
                builder: (BuildContext context, Widget? _) {
                  final (double heroScale, Offset heroOffset) = _heroTransform();

                  return AionForgePedestal(
                    rotation: _pedestalRotationCtrl.value,
                    pulse: _pulseCtrl.value,
                    size: 88,
                    accentColor: accent,
                    primaryRuneColor: _forgeGlowColor(),
                    badgeText: _selectedItem != null ? '+$currentLevel' : null,
                    badgeColor: accent,
                    isEnhancing: _isEnhancing,
                    onTap: () {
                      if (_selectedItem == null && !_isEnhancing) {
                        setState(() => _invTab = _InvTab.gear);
                      }
                    },
                    onClear: _selectedItem != null && !_isEnhancing
                        ? () => setState(() => _selectedItem = null)
                        : null,
                    child: _selectedItem != null
                        ? Transform.translate(
                            offset: heroOffset,
                            child: Transform.scale(
                              scale: heroScale,
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.xs + 2),
                                child: ItemIconView(
                                  iconValue: _selectedItem!.icon,
                                  itemId: _selectedItem!.itemId,
                                  itemType: _selectedItem!.itemType,
                                  size: 64,
                                  expand: true,
                                  fallback: '⚔️',
                                ),
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),

              // Sağ Yuvalar (Koruma Tılsımı & Kehanet / Sonuç)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ForgeSlotContainer(
                    size: 54,
                    label: 'Koruma Tılsımı',
                    icon: protIcon,
                    accentColor: protColor,
                    badgeText: protBadge,
                    onTap: () => _showFailSafeInfoDialog(
                      currentLevel: currentLevel,
                      selectedRune: _selectedRune,
                      activeRune: activeRune,
                    ),
                    child: Center(
                      child: Icon(
                        protIcon,
                        size: 24,
                        color: protColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  ForgeSlotContainer(
                    size: 54,
                    label: 'Kehanet / Sonuç',
                    icon: Icons.visibility_outlined,
                    accentColor: resultAccent,
                    badgeText: resultLevel != null
                        ? '+$resultLevel'
                        : (_forgePhase == _ForgeVisualPhase.destroyed ? 'KIRILDI' : null),
                    child: _selectedItem != null
                        ? AnimatedBuilder(
                            animation: _borderGlowCtrl,
                            builder: (BuildContext context, Widget? child) => child!,
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.all(AppSpacing.xs),
                                  child: Opacity(
                                    opacity: _forgePhase == _ForgeVisualPhase.destroyed
                                        ? 0.35
                                        : (_forgePhase == _ForgeVisualPhase.idle ? 0.85 : 1),
                                    child: ItemIconView(
                                      iconValue: _selectedItem!.icon,
                                      itemId: _selectedItem!.itemId,
                                      itemType: _selectedItem!.itemType,
                                      size: 40,
                                      expand: true,
                                      fallback: '⚔️',
                                    ),
                                  ),
                                ),
                                if (_forgePhase == _ForgeVisualPhase.destroyed)
                                  Positioned.fill(
                                    child: Center(
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 32,
                                        color: AionForgeTokens.crimsonBreak,
                                        weight: 800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // 3. Seçili Eşya Başlığı ve Stat Önizlemesi
          Text(
            _selectedItem != null
                ? '${_selectedItem!.name}  ·  ${getRarityLabel(_selectedItem!.rarity)}'
                : 'Envanterden eşya seç — kadim ilahî örste güçlendir.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.captionBold.copyWith(
              fontSize: 11,
              color: _selectedItem != null ? accent : AppColors.mutedTitanium,
            ),
          ),
          if (_selectedItem != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            _enhancementStatPreview(_selectedItem!, previewLevel),
          ],
          if (config.goldDiscountPct > 0 && _selectedItem != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Lonca anıtı Lv${config.monumentLevel} — maliyet %${config.goldDiscountPct} indirimli: ${_formatGold(nextCost)}',
                textAlign: TextAlign.center,
                style: AppTextStyles.micro.copyWith(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.toxicNeon,
                ),
              ),
            ),
          if (_selectedItem != null && _selectedScroll != null && !scrollOk)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Parşömen uyumsuz — gereken: ${_scrollLabelForRarity(_selectedItem!.rarity)}',
                textAlign: TextAlign.center,
                style: AppTextStyles.micro.copyWith(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AionForgeTokens.crimsonBreak,
                ),
              ),
            ),

          // Aktif Koruma & Rün Rozetleri
          if (_selectedItem != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs + 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: protColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: protColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(protIcon, size: 11, color: protColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            protBadge,
                            style: AppTextStyles.micro.copyWith(
                              color: protColor,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (runeBonus > 0 && activeRune != null) ...<Widget>[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: activeRune.glowColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: activeRune.glowColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.auto_awesome, size: 11, color: activeRune.glowColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '+%$runeBonus Şans',
                              style: AppTextStyles.micro.copyWith(
                                color: activeRune.glowColor,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),

          // 4. Success Rate Gauge (Risk-o-Meter)
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (BuildContext context, Widget? child) {
              return RiskMeterGauge(
                successChance: effectiveSuccessChance,
                currentLevel: currentLevel,
                pulse: _pulseCtrl.value,
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // 5. Dramatik CTA Buton Alanı
          Row(
            children: <Widget>[
              SizedBox(
                width: 76,
                child: EnhGhostButton(
                  label: 'Vazgeç',
                  onTap: _isEnhancing || _forgePhase != _ForgeVisualPhase.idle
                      ? null
                      : _resetSelection,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TutorialAnchorScope(
                  id: TutorialAnchorId.enhanceForgeBtn,
                  child: DivineForgeStrikeButton(
                    label: _isEnhancing
                        ? 'DÖVÜLÜYOR...'
                        : (_selectedItem == null
                            ? 'EŞYA SEÇ'
                            : (_compatibleScroll() == null
                                ? 'PARŞÖMEN SEÇ'
                                : (gold < nextCost ? 'YETERSİZ ALTIN' : 'İLAHÎ ÇEKİÇ VUR'))),
                    costText: _selectedItem != null
                        ? 'Maliyet: ${_formatGold(nextCost)} Altın  (Mevcut: ${_formatGold(gold)})'
                        : 'Güçlendirmek için eşya ve parşömen yerleştirin',
                    enabled: canEnhance,
                    loading: _isEnhancing,
                    onTrigger: canEnhance
                        ? () async {
                            await TutorialTriggers.onAnchorTap(
                              ref,
                              TutorialAnchorId.enhanceForgeBtn,
                            );
                            await _enhance();
                          }
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final ForgeVfxState vfxState = switch (_forgePhase) {
      _ForgeVisualPhase.idle => ForgeVfxState.idle,
      _ForgeVisualPhase.enhancing => ForgeVfxState.striking,
      _ForgeVisualPhase.success => ForgeVfxState.success,
      _ForgeVisualPhase.failure => ForgeVfxState.failure,
      _ForgeVisualPhase.destroyed => ForgeVfxState.destroyed,
    };

    Widget decoratedPanel = panel;
    if (_forgePhase == _ForgeVisualPhase.enhancing) {
      decoratedPanel = AnimatedBuilder(
        animation: _borderGlowCtrl,
        builder: (BuildContext context, Widget? child) {
          return ForgeRotatingBorderGlow(
            rotation: _borderGlowCtrl.value,
            color: _forgeGlowColor(),
            borderRadius: 14,
            child: child!,
          );
        },
        child: panel,
      );
    } else if (_forgePhase != _ForgeVisualPhase.idle) {
      decoratedPanel = ForgeStaticBorderGlow(
        color: _forgeGlowColor(),
        borderRadius: 14,
        child: panel,
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_pulseCtrl, _resultCtrl]),
      builder: (BuildContext context, Widget? child) {
        return EnhancementForgeEffectsLayer(
          vfxState: vfxState,
          strikeProgress: _forgePhase == _ForgeVisualPhase.enhancing ? _pulseCtrl.value : 0.0,
          resultProgress: (_forgePhase == _ForgeVisualPhase.success ||
                  _forgePhase == _ForgeVisualPhase.failure ||
                  _forgePhase == _ForgeVisualPhase.destroyed)
              ? _resultCtrl.value
              : 0.0,
          surgeLevel: _selectedItem?.enhancementLevel ?? 1,
          child: child,
        );
      },
      child: decoratedPanel,
    );
  }

  /// Koruma ve risk seviyesi bilgilendirme modali.
  void _showFailSafeInfoDialog({
    required int currentLevel,
    required String selectedRune,
    required EnhancementRuneCatalogEntry? activeRune,
  }) {
    showEnhBlurDialog<void>(
      context: context,
      accent: currentLevel < 4
          ? AionForgeTokens.emeraldSafe
          : (currentLevel >= 6
              ? AionForgeTokens.crimsonBreak
              : AionForgeTokens.amberWarning),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.shield_outlined, color: AionForgeTokens.celestialGold, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'KORUMA & RİSK SİSTEMİ',
                  style: AppTextStyles.titleBold.copyWith(
                    color: AionForgeTokens.celestialGold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildRiskTierRow(
            levelRange: '+0 → +3',
            title: 'Doğal Güvenli Bölge',
            description: 'Başarısızlık durumunda eşya korunur. Kırılma veya seviye düşüşü yaşanmaz.',
            color: AionForgeTokens.emeraldSafe,
            isCurrent: currentLevel < 4,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildRiskTierRow(
            levelRange: '+4 → +5',
            title: 'Seviye Gerileme Riski',
            description: 'Başarısızlık halinde eşya 1 seviye geriler (Örn: +4 → +3). Parçalanmaz.',
            color: AionForgeTokens.amberWarning,
            isCurrent: currentLevel >= 4 && currentLevel < 6,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildRiskTierRow(
            levelRange: '+6 → +10',
            title: 'Kritik Yıkım (Kırılma) Tehlikesi',
            description: 'Başarısızlık durumunda eşya tamamen yok olur! Aegis Koruma Mührü önerilir.',
            color: AionForgeTokens.crimsonBreak,
            isCurrent: currentLevel >= 6,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.bgSurface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AionForgeTokens.divineBrass.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: <Widget>[
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    selectedRune == 'protection'
                        ? 'Şu anda Aegis Koruma Mührü aktif: Eşya parçalanmaya karşı mühürlüdür.'
                        : 'Sol paneldeki Tılsım / Rune yuvasından Aegis Mührü seçerek eşyanızı kırılmaya karşı koruyabilirsiniz.',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.mutedTitanium,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          EnhGhostButton(
            label: 'Anladım',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskTierRow({
    required String levelRange,
    required String title,
    required String description,
    required Color color,
    required bool isCurrent,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isCurrent ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: isCurrent ? 0.7 : 0.2),
          width: isCurrent ? 1.4 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  levelRange,
                  style: AppTextStyles.micro.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.captionBold.copyWith(
                    color: color,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ŞU ANKİ',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.carbonVoid,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: AppTextStyles.micro.copyWith(
              color: AppColors.mutedTitanium,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelBadge(String text, {Color color = const Color(0xFFFFD700)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xE6080D1A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.7),
      ),
      child: Text(
        text,
        style: AppTextStyles.micro.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          height: 1,
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            style: AppTextStyles.micro.copyWith(
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.mutedTitanium,
            ),
          ),
        ],
      ),
    );
  }

  /// PLAN_05: current enhanced stats → next +1 preview.
  Widget _enhancementStatPreview(InventoryItem item, int currentLevel) {
    final int nextLevel = (currentLevel + 1).clamp(0, 10);
    final bool canPreviewNext = currentLevel < 10;

    String line(String label, int base) {
      if (base <= 0) return '';
      final int now = enhancedStat(base, currentLevel);
      if (!canPreviewNext) return '$label $now';
      final int next = enhancedStat(base, nextLevel);
      return '$label $now→$next';
    }

    final List<String> parts = <String>[
      if (item.attack > 0) line('ATK', item.attack),
      if (item.defense > 0) line('DEF', item.defense),
      if (item.health > 0) line('HP', item.health),
      if (item.luck > 0) line('LUCK', item.luck),
    ].where((String s) => s.isNotEmpty).toList();

    final int powerNow = enhancedItemPowerContribution(
      item,
      enhancementLevel: currentLevel,
    );
    final String powerLine = canPreviewNext
        ? 'GÜÇ $powerNow→${enhancedItemPowerContribution(item, enhancementLevel: nextLevel)}'
        : 'GÜÇ $powerNow';

    return Text(
      parts.isEmpty ? powerLine : '${parts.join('  ·  ')}  ·  $powerLine',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppTextStyles.micro.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: AppColors.toxicNeon.withValues(alpha: 0.9),
        height: 1.25,
      ),
    );
  }

  // ─── ENVANTER ────────────────────────────────────────────────────────────
  List<InventoryItem> _filteredInventory(List<InventoryItem> all) {
    switch (_invTab) {
      case _InvTab.all:
        return all;
      case _InvTab.gear:
        return all.where(_isEquipment).toList(growable: false);
      case _InvTab.scroll:
        return all.where(_isScrollItem).toList(growable: false);
      case _InvTab.rune:
        return all.where(_isRuneItem).toList(growable: false);
      case _InvTab.other:
        return all
            .where(
              (InventoryItem i) =>
                  !_isEquipment(i) && !_isScrollItem(i) && !_isRuneItem(i),
            )
            .toList(growable: false);
    }
  }

  bool _isForgeUsable(InventoryItem item) =>
      _isEnhanceable(item) || _isScrollItem(item) || _isRuneItem(item);

  Widget _buildInventoryPanel() {
    final inventoryState = ref.watch(inventoryProvider);
    final TutorialStepV2? tutorialStep = ref.watch(tutorialProvider).activeStep;
    final bool pickWeaponCoach = tutorialStep?.id == 'enhance_pick_item';
    final String? tutorialWeaponRowId =
        pickWeaponCoach ? _tutorialEnhanceWeaponRowId(inventoryState) : null;
    final List<InventoryItem> allItems = inventoryState.items;
    final List<InventoryItem> items = _filteredInventory(allItems);
    final double bottomPad = GameScrollLayout.bottomInset(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm + 2, AppSpacing.sm, AppSpacing.sm + 2, 0),
      decoration: BoxDecoration(
        color: _kSlotBg.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusMd)),
        border: Border.all(color: _kFrameGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🎒', style: TextStyle(fontSize: 12)),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  'ENVANTER (${allItems.length})',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: _kFrameGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildInvTabs(allItems),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: inventoryState.status == InventoryStatus.loading
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.liquidGold,
                          )
                        : Text(
                            'Bu kategoride eşya yok.',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.mutedTitanium,
                            ),
                          ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.only(bottom: bottomPad),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 5,
                          crossAxisSpacing: 5,
                        ),
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int idx) =>
                        _buildInventoryTile(
                          items[idx],
                          tutorialWeaponRowId: tutorialWeaponRowId,
                        ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvTabs(List<InventoryItem> allItems) {
    final List<(_InvTab, String, int)> tabs = <(_InvTab, String, int)>[
      (_InvTab.all, 'Tümü', allItems.length),
      (_InvTab.gear, 'Ekipman', allItems.where(_isEquipment).length),
      (_InvTab.scroll, 'Parşömen', allItems.where(_isScrollItem).length),
      (_InvTab.rune, 'Rune', allItems.where(_isRuneItem).length),
      (
        _InvTab.other,
        'Diğer',
        allItems
            .where(
              (InventoryItem i) =>
                  !_isEquipment(i) && !_isScrollItem(i) && !_isRuneItem(i),
            )
            .length,
      ),
    ];

    final int activeIndex = tabs.indexWhere((e) => e.$1 == _invTab);

    return GkkSegmentedTabBar(
      labels: tabs
          .map((e) => '${e.$2} (${e.$3})')
          .toList(growable: false),
      activeIndex: activeIndex >= 0 ? activeIndex : 0,
      onChanged: (int index) {
        HapticFeedback.selectionClick();
        setState(() => _invTab = tabs[index].$1);
      },
      isScrollable: true,
      height: 42,
      padding: EdgeInsets.zero,
    );
  }

  /// KO stili envanter hücresi: kare, koyu iç, rarity çerçeve, +seviye rozeti.
  Widget _buildInventoryTile(
    InventoryItem item, {
    String? tutorialWeaponRowId,
  }) {
    final bool usable = _isForgeUsable(item);
    final bool isSelected =
        (_selectedItem?.rowId == item.rowId) ||
        (_selectedScroll?.rowId == item.rowId) ||
        (_selectedRune != 'none' && item.itemId == 'rune_$_selectedRune');
    final Color rarityC = _rarityColor(item.rarity);

    final bool isTutorialWeapon =
        tutorialWeaponRowId != null && item.rowId == tutorialWeaponRowId;

    final Widget tile = GestureDetector(
      onTap: () => _handleInventoryItemTap(
        item,
        tutorialWeaponRowId: tutorialWeaponRowId,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _kSlotBg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isSelected
                ? AppColors.toxicNeon.withValues(alpha: 0.9)
                : rarityC.withValues(alpha: usable ? 0.45 : 0.18),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.toxicNeon.withValues(alpha: 0.25),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(5),
              child: Opacity(
                opacity: usable ? 1 : 0.4,
                child: ItemIconView(
                  iconValue: item.icon,
                  itemId: item.itemId,
                  itemType: item.itemType,
                  size: 36,
                  expand: true,
                ),
              ),
            ),
            if (item.enhancementLevel > 0)
              Positioned(
                top: 2,
                right: 2,
                child: _levelBadge('+${item.enhancementLevel}'),
              ),
            if (item.isStackable && item.quantity > 1)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xE6080D1A),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'x${item.quantity}',
                    style: AppTextStyles.micro.copyWith(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      color: rarityC,
                      height: 1,
                    ),
                  ),
                ),
              ),
            if (item.isEquipped)
              const Positioned(
                left: 2,
                bottom: 2,
                child: Icon(Icons.person, size: 9, color: AppColors.accentCyan),
              ),
            if (isSelected)
              const Positioned(
                top: 2,
                left: 2,
                child: Icon(
                  Icons.check_circle,
                  size: 11,
                  color: AppColors.toxicNeon,
                ),
              ),
          ],
        ),
      ),
    );

    if (!isTutorialWeapon) return tile;

    return TutorialAnchorScope(
      id: TutorialAnchorId.enhanceInventoryWeapon,
      child: tile,
    );
  }

  void _handleInventoryItemTap(
    InventoryItem item, {
    String? tutorialWeaponRowId,
  }) {
    if (_isEnhancing) return;
    if (tutorialWeaponRowId != null &&
        item.rowId != tutorialWeaponRowId &&
        _isEnhanceable(item)) {
      ref.read(tutorialProvider.notifier).registerWrongTap();
      return;
    }
    if (_isEnhanceable(item)) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedItem = item;
        _selectedRune = 'none';
        if (_selectedScroll == null ||
            _selectedScroll!.itemId != _scrollIdForRarity(item.rarity)) {
          _selectedScroll = _autoFindScroll(item);
        }
      });
      if (item.rowId == tutorialWeaponRowId) {
        unawaited(
          TutorialTriggers.onAnchorTap(
            ref,
            TutorialAnchorId.enhanceInventoryWeapon,
          ),
        );
      }
    } else if (_isScrollItem(item)) {
      HapticFeedback.selectionClick();
      setState(() => _selectedScroll = item);
    } else if (_isRuneItem(item)) {
      HapticFeedback.selectionClick();
      setState(() => _selectedRune = item.itemId.replaceFirst('rune_', ''));
    } else if (_isEquipment(item) && item.enhancementLevel >= 10) {
      _showSnack('${item.name} maksimum seviyede (+10).');
    } else {
      _showSnack('${item.name} güçlendirmede kullanılamaz.');
    }
  }

  InventoryItem? _autoFindScroll(InventoryItem gear) {
    final String requiredId = _scrollIdForRarity(gear.rarity);
    for (final InventoryItem candidate in ref.read(inventoryProvider).items) {
      if (candidate.itemId == requiredId && candidate.quantity > 0) {
        return candidate;
      }
    }
    return null;
  }
}
