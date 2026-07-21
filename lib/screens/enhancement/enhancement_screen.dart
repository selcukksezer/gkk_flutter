import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/item_icon_view.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/services/supabase_service.dart';
import '../../models/enhancement_config_model.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../repositories/enhancement_repository.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
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

// KO hissi: bronz/altın çerçeve tonu
const Color _kFrameGold = Color(0xFFB08D4A);
const Color _kSlotBg = Color(0xFF10141F);
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

  /// Güçlendirme nabzı + sonuç sarsıntısı/pop'u.
  late final AnimationController _pulseCtrl;
  late final AnimationController _resultCtrl;
  late final AnimationController _borderGlowCtrl;
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(inventoryProvider.notifier).loadInventory();
      await ref.read(playerProvider.notifier).loadProfile();
      final EnhancementConfig config = await enhancementRepository.fetchConfig();
      if (!mounted) return;
      setState(() => _config = config);
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.enhancement);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _resultCtrl.dispose();
    _borderGlowCtrl.dispose();
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

    HapticFeedback.mediumImpact();
    setState(() {
      _isEnhancing = true;
      _forgePhase = _ForgeVisualPhase.enhancing;
      _animType = null;
      _enhanceBaseLevel = item.enhancementLevel;
    });
    _pulseCtrl.repeat();
    _borderGlowCtrl.repeat();

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
        _pulseCtrl.stop();
        _pulseCtrl.value = 0;
        _borderGlowCtrl.stop();
        _borderGlowCtrl.value = 0;
        switch (resultType) {
          case _EnhanceResultType.success:
            HapticFeedback.heavyImpact();
          case _EnhanceResultType.failure:
            HapticFeedback.vibrate();
          case _EnhanceResultType.destroyed:
            HapticFeedback.heavyImpact();
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
      if (mounted && _forgePhase == _ForgeVisualPhase.enhancing) {
        _pulseCtrl.stop();
        _pulseCtrl.value = 0;
        _borderGlowCtrl.stop();
        _borderGlowCtrl.value = 0;
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildAnvilPanel(
                  successChance: successChance,
                  nextCost: nextCost,
                  gold: gold,
                  currentLevel: currentLevel,
                  canEnhance: canEnhance,
                  config: _config,
                ),
                const SizedBox(height: 10),
                Expanded(child: _buildInventoryPanel()),
              ],
            ),
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
    final Color chanceC = _successColor(successChance);
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

    Widget panel = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: _kSlotBg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _forgePhase == _ForgeVisualPhase.idle
              ? _kFrameGold.withValues(alpha: 0.45)
              : _forgeGlowColor().withValues(alpha: 0.35),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          if (_forgePhase != _ForgeVisualPhase.idle)
            BoxShadow(
              color: _forgeGlowColor().withValues(alpha: 0.22),
              blurRadius: 22,
              spreadRadius: -2,
            ),
        ],
      ),
      child: Column(
        children: <Widget>[
          // Başlık
          Row(
            children: <Widget>[
              const Text('⚒️', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'GÜÇLENDİRME OCAĞI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: _kFrameGold,
                  ),
                ),
              ),
              EnhIconChipButton(
                icon: Icons.table_chart_outlined,
                label: 'Tablo',
                onTap: _openUpgradeTable,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Yuvalar: eşya + parşömen + rune → önizleme
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              TutorialAnchorScope(
                id: TutorialAnchorId.enhanceItemSlot,
                child: _anvilSlot(
                  size: 66,
                  label: 'Eşya',
                  accent: _selectedItem != null ? accent : null,
                  onClear: _selectedItem != null && !_isEnhancing
                      ? () => setState(() => _selectedItem = null)
                      : null,
                  child: _selectedItem != null
                    ? AnimatedBuilder(
                        animation: Listenable.merge(<Listenable>[
                          _pulseCtrl,
                          _resultCtrl,
                        ]),
                        builder: (BuildContext context, Widget? child) {
                          final (double scale, Offset offset) =
                              _heroTransform();
                          return Transform.translate(
                            offset: offset,
                            child: Transform.scale(scale: scale, child: child),
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: ItemIconView(
                                iconValue: _selectedItem!.icon,
                                itemId: _selectedItem!.itemId,
                                itemType: _selectedItem!.itemType,
                                size: 50,
                                expand: true,
                                fallback: '⚔️',
                              ),
                            ),
                            Positioned(
                              left: 3,
                              top: 3,
                              child: _levelBadge('+$currentLevel'),
                            ),
                          ],
                        ),
                      )
                    : null,
                ),
              ),
              _anvilPlus(),
              _anvilSlot(
                size: 54,
                label: 'Parşömen',
                accent: _selectedScroll != null
                    ? (scrollOk ? AppColors.liquidGold : AppColors.mysticRuby)
                    : null,
                onTap: _isEnhancing ? null : _openScrollPicker,
                onClear: _selectedScroll != null && !_isEnhancing
                    ? () => setState(() => _selectedScroll = null)
                    : null,
                child: _selectedScroll != null
                    ? Padding(
                        padding: const EdgeInsets.all(5),
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
              _anvilPlus(),
              _anvilSlot(
                size: 54,
                label: 'Rune',
                accent: _selectedRune != 'none' ? AppColors.accentPurple : null,
                onTap: _isEnhancing ? null : _openRunePicker,
                onClear: _selectedRune != 'none' && !_isEnhancing
                    ? () => setState(() => _selectedRune = 'none')
                    : null,
                child: _selectedRune != 'none'
                    ? (runeItem != null
                          ? Padding(
                              padding: const EdgeInsets.all(5),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: _kFrameGold.withValues(alpha: 0.7),
                ),
              ),
              _anvilSlot(
                size: 66,
                label: 'Sonuç',
                accent: _selectedItem != null ? resultAccent : null,
                child: _selectedItem != null
                    ? AnimatedBuilder(
                        animation: _borderGlowCtrl,
                        builder: (BuildContext context, Widget? child) => child!,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Opacity(
                                opacity: _forgePhase == _ForgeVisualPhase.destroyed
                                    ? 0.35
                                    : (_forgePhase == _ForgeVisualPhase.idle ? 0.85 : 1),
                                child: ItemIconView(
                                  iconValue: _selectedItem!.icon,
                                  itemId: _selectedItem!.itemId,
                                  itemType: _selectedItem!.itemType,
                                  size: 50,
                                  expand: true,
                                  fallback: '⚔️',
                                ),
                              ),
                            ),
                            if (_forgePhase == _ForgeVisualPhase.destroyed)
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.black.withValues(alpha: 0.5),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 34,
                                        color: AppColors.mysticRuby,
                                        weight: 700,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else if (resultLevel != null)
                              Positioned(
                                left: 3,
                                top: 3,
                                child: _levelBadge('+$resultLevel', color: resultAccent),
                              ),
                          ],
                        ),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Seçili eşya adı / yönlendirme
          Text(
            _selectedItem != null
                ? '${_selectedItem!.name}  ·  ${getRarityLabel(_selectedItem!.rarity)}'
                : 'Envanterden eşya seç — gerekli parşömen otomatik önerilir.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _selectedItem != null ? accent : AppColors.mutedTitanium,
            ),
          ),
          const SizedBox(height: 8),
          // Bilgi şeridi — tek satır
          Row(
            children: <Widget>[
              Expanded(child: _statChip('Şans', '%$successChance', chanceC)),
              const SizedBox(width: 6),
              Expanded(
                child: _statChip(
                  'Maliyet',
                  _formatGold(nextCost),
                  gold >= nextCost
                      ? AppColors.liquidGold
                      : AppColors.mysticRuby,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statChip(
                  'Risk',
                  _riskLabel(currentLevel),
                  _riskColor(currentLevel),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statChip('Altın', _formatGold(gold), _kFrameGold),
              ),
            ],
          ),
          if (config.goldDiscountPct > 0 && _selectedItem != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Lonca anıtı Lv${config.monumentLevel} — maliyet %${config.goldDiscountPct} indirimli: ${_formatGold(nextCost)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.toxicNeon,
                ),
              ),
            ),
          if (_selectedItem != null && _selectedScroll != null && !scrollOk)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Parşömen uyumsuz — gereken: ${_scrollLabelForRarity(_selectedItem!.rarity)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.mysticRuby,
                ),
              ),
            ),
          const SizedBox(height: 10),
          // CTA
          Row(
            children: <Widget>[
              SizedBox(
                width: 84,
                child: EnhGhostButton(
                  label: 'İptal',
                  onTap: _isEnhancing || _forgePhase != _ForgeVisualPhase.idle
                      ? null
                      : _resetSelection,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TutorialAnchorScope(
                  id: TutorialAnchorId.enhanceForgeBtn,
                  child: EnhGoldButton(
                    label: _isEnhancing ? 'Güçlendiriliyor...' : 'GÜÇLENDİR',
                    icon: Icons.auto_fix_high_rounded,
                    enabled: canEnhance,
                    loading: _isEnhancing,
                    onTap: canEnhance
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

    if (_forgePhase == _ForgeVisualPhase.idle) return panel;

    if (_forgePhase == _ForgeVisualPhase.enhancing) {
      return AnimatedBuilder(
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
    }

    return ForgeStaticBorderGlow(
      color: _forgeGlowColor(),
      borderRadius: 14,
      child: panel,
    );
  }

  Widget _anvilPlus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.add_rounded,
        size: 13,
        color: AppColors.mutedTitanium.withValues(alpha: 0.5),
      ),
    );
  }

  /// KO stili kare yuva: koyu iç, ince bronz çerçeve, altında minik etiket.
  Widget _anvilSlot({
    required double size,
    required String label,
    Widget? child,
    Color? accent,
    VoidCallback? onTap,
    VoidCallback? onClear,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            GestureDetector(
              key: label == 'Parşömen'
                  ? const Key('enhancement_scroll_slot')
                  : null,
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: _kSlotBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (accent ?? _kFrameGold).withValues(
                      alpha: accent != null ? 0.8 : 0.35,
                    ),
                    width: accent != null ? 1.6 : 1,
                  ),
                  boxShadow: accent != null
                      ? <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 10,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child:
                    child ??
                    Center(
                      child: Icon(
                        onTap != null ? Icons.touch_app_outlined : Icons.add,
                        size: 16,
                        color: AppColors.mutedTitanium.withValues(alpha: 0.35),
                      ),
                    ),
              ),
            ),
            if (onClear != null)
              Positioned(
                right: -4,
                top: -4,
                child: GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: AppColors.carbonVoid,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 9,
                      color: AppColors.mutedTitanium,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedTitanium,
          ),
        ),
      ],
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
        style: TextStyle(
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
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
    final List<InventoryItem> allItems = inventoryState.items;
    final List<InventoryItem> items = _filteredInventory(allItems);
    final double bottomPad = MediaQuery.of(context).padding.bottom + 96;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        color: _kSlotBg.withValues(alpha: 0.7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border.all(color: _kFrameGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🎒', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ENVANTER (${allItems.length})',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: _kFrameGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInvTabs(allItems),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: inventoryState.status == InventoryStatus.loading
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.liquidGold,
                          )
                        : const Text(
                            'Bu kategoride eşya yok.',
                            style: TextStyle(
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
                        _buildInventoryTile(items[idx]),
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

    return SizedBox(
      height: 26,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, int i) => const SizedBox(width: 5),
        itemBuilder: (BuildContext context, int i) {
          final (_InvTab tab, String label, int count) = tabs[i];
          final bool sel = _invTab == tab;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _invTab = tab);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: sel
                    ? _kFrameGold.withValues(alpha: 0.16)
                    : Colors.black26,
                border: Border.all(
                  color: sel
                      ? _kFrameGold.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: sel ? _kFrameGold : AppColors.mutedTitanium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// KO stili envanter hücresi: kare, koyu iç, rarity çerçeve, +seviye rozeti.
  Widget _buildInventoryTile(InventoryItem item) {
    final bool usable = _isForgeUsable(item);
    final bool isSelected =
        (_selectedItem?.rowId == item.rowId) ||
        (_selectedScroll?.rowId == item.rowId) ||
        (_selectedRune != 'none' && item.itemId == 'rune_$_selectedRune');
    final Color rarityC = _rarityColor(item.rarity);

    return GestureDetector(
      onTap: () => _handleInventoryItemTap(item),
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
                    style: TextStyle(
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
  }

  void _handleInventoryItemTap(InventoryItem item) {
    if (_isEnhancing) return;
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
      unawaited(
        TutorialTriggers.onAnchorTap(ref, TutorialAnchorId.enhanceItemSlot),
      );
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
