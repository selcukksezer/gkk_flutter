import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../l10n/l10n.dart';
import '../../providers/mekan_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'widgets/mekan_design.dart';
import 'widgets/mekan_scaffold.dart';
import 'widgets/mekan_theme.dart';
import 'widgets/mekan_type_art_card.dart';

class MekanCreateScreen extends ConsumerStatefulWidget {
  const MekanCreateScreen({super.key});

  @override
  ConsumerState<MekanCreateScreen> createState() => _MekanCreateScreenState();
}

class _MekanCreateScreenState extends ConsumerState<MekanCreateScreen> {
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  String? _selectedType;
  bool _busy = false;
  List<MekanTypeInfo> _types = MekanTypeInfo.all;

  // Budget & Filter state
  double _budgetFilterLimit = 200000000.0;
  bool _onlyAffordable = false;
  bool _showBudgetPlanner = true;
  int _nameSuggestionIndex = 0;

  static const Map<String, List<String>> _thematicNames = <String, List<String>>{
    'bar': <String>[
      'Gölge Kadeh Barı',
      'Gece Kuşu Tavernası',
      'Siber Neon Bar',
      'Zümrüt İksir Kulübü',
      'Kayıp Denizci Barı',
      'Son Durak Meyhanesi',
    ],
    'kahvehane': <String>[
      'Eski Dostlar Kahvesi',
      'Reislerin Kıraathanesi',
      'Dumanaltı Nargile Hanı',
      'Çınaraltı Meclisi',
      'Gönül Sohbet Evi',
      'Bozkır Kahvehanesi',
    ],
    'dovus_kulubu': <String>[
      'Demir Yumruk Ringi',
      'Kafes & Kan Arenası',
      'Gölge Gladyatörleri',
      'Son Dövüşçü Kulübü',
      'Kızıl Halka Arenası',
      'Şampiyonlar Ocağı',
    ],
    'luks_lounge': <String>[
      'Altın Taç VIP Lounge',
      'Zümrüt Elmas Salonu',
      'Apex Aristokrat Kulüp',
      'Kristal Saray Lounge',
      'Kraliyet Hanedanı Kulüp',
      'Monark VIP Odası',
    ],
    'yeralti': <String>[
      'Kayıp Mahzen',
      'Kara Borsa Sığınağı',
      'Gölge Kripto İni',
      'Körfez Kaçakçıları',
      'Gece Korsanları Hanı',
      'Karanlık Mahzen Kulüp',
    ],
  };

  static const List<String> _generalNames = <String>[
    'Kuzey Rüzgarı Hanı',
    'Dolunay Meyhanesi',
    'Yıldız Tozu Tavernası',
    'Ejder Nefesi Han',
    'Kartal Yuvası Konağı',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTypeCatalog());
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTypeCatalog() async {
    try {
      final List<MekanTypeCatalogRow> rows =
          await ref.read(mekanRepositoryProvider).fetchTypeCatalog();
      if (!mounted || rows.isEmpty) return;
      setState(() => _types = _mergeTypeCatalog(rows));
    } catch (_) {
      // RPC yoksa veya hata olursa yerel fallback kullan.
    }
  }

  List<MekanTypeInfo> _mergeTypeCatalog(List<MekanTypeCatalogRow> rows) {
    final Map<String, MekanTypeCatalogRow> byType = <String, MekanTypeCatalogRow>{
      for (final MekanTypeCatalogRow row in rows) row.type: row,
    };
    return MekanTypeInfo.all
        .map((MekanTypeInfo base) {
          final MekanTypeCatalogRow? row = byType[base.type];
          if (row == null) return base;
          return MekanTypeInfo(
            type: base.type,
            name: base.name,
            description: base.description,
            cost: row.cost,
            reqLevel: row.reqLevel,
          );
        })
        .toList();
  }

  MekanTypeInfo? _infoFor(String? type) {
    if (type == null) return null;
    for (final MekanTypeInfo info in _types) {
      if (info.type == type) return info;
    }
    return null;
  }

  void _showLockedReason(MekanTypeInfo info, int level, int gold) {
    final List<String> missing = <String>[];
    if (level < info.reqLevel) {
      missing.add('Sv ${info.reqLevel} gerekli (sen: Sv $level)');
    }
    if (gold < info.cost) {
      missing.add('${formatMekanGold(info.cost)} altın gerekli (eksik: ${formatMekanGold(info.cost - gold)})');
    }
    AppMessenger.show(
      context,
      missing.isEmpty ? '${info.name} şu an kilitli.' : missing.join(' · '),
    );
  }

  void _rollRandomName() {
    final List<String> pool = (_selectedType != null && _thematicNames.containsKey(_selectedType))
        ? _thematicNames[_selectedType]!
        : _generalNames;
    if (pool.isEmpty) return;
    final String chosen = pool[_nameSuggestionIndex % pool.length];
    _nameSuggestionIndex++;
    _name.text = chosen;
    _name.selection = TextSelection.fromPosition(TextPosition(offset: _name.text.length));
    setState(() {});
  }

  List<String> _getCurrentSuggestions() {
    if (_selectedType != null && _thematicNames.containsKey(_selectedType)) {
      return _thematicNames[_selectedType]!.take(3).toList();
    }
    return _generalNames.take(3).toList();
  }

  String? _getNameValidationError() {
    final String trimmed = _name.text.trim();
    if (trimmed.isEmpty) {
      return 'Mekan adı boş bırakılamaz';
    }
    if (trimmed.length < 3) {
      return 'Mekan adı en az 3 karakter olmalıdır (${trimmed.length}/3)';
    }
    if (trimmed.length > 30) {
      return 'Mekan adı en fazla 30 karakter olabilir';
    }
    return null;
  }

  Future<void> _create() async {
    final String? type = _selectedType;
    if (type == null) {
      AppMessenger.show(context, 'Önce bir tür seç');
      return;
    }
    final String trimmedName = _name.text.trim();
    if (trimmedName.isEmpty) {
      AppMessenger.show(context, 'Mekan adı gerekli');
      return;
    }
    if (trimmedName.length < 3) {
      AppMessenger.show(context, 'Mekan adı en az 3 karakter olmalıdır');
      return;
    }
    final MekanTypeInfo? info = _infoFor(type);
    if (info == null) return;
    final profile = ref.read(playerProvider).profile;
    if (profile == null) return;
    if (profile.level < info.reqLevel) {
      AppMessenger.show(context, 'Sv ${info.reqLevel} gerekli');
      return;
    }
    if (profile.gold < info.cost) {
      AppMessenger.showError(context, 'Yetersiz altın (${formatMekanGold(info.cost)})');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(mekanRepositoryProvider).createMekan(type: type, name: trimmedName);
      await ref.read(playerProvider.notifier).loadProfile();
      ref.read(mekanHubRefreshProvider.notifier).touch();
      if (mounted) {
        AppMessenger.showSuccess(context, 'Mekan açıldı!');
        context.go(AppRoutes.myMekan);
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(
          context,
          userFacingErrorMessage(e, fallback: 'Mekan açılamadı.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildBudgetPresetChip(String label, double value) {
    final bool isSelected = (_budgetFilterLimit - value).abs() < 1000;
    return GestureDetector(
      onTap: () => setState(() => _budgetFilterLimit = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? MekanPalette.gold.withValues(alpha: 0.22)
              : MekanPalette.void_.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? MekanPalette.gold : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? MekanPalette.gold : MekanPalette.textMid,
          ),
        ),
      ),
    );
  }

  Widget _buildFinanceStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: MekanPalette.textLow),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialBreakdown(int gold, MekanTypeInfo selected) {
    final int remaining = gold - selected.cost;
    final bool isDeficit = remaining < 0;
    final double spentRatio = gold > 0 ? (selected.cost / gold).clamp(0.0, 1.0) : 1.0;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isDeficit) {
      statusColor = MekanPalette.ruby;
      statusText = 'Bütçe Yetersiz: ${formatMekanGold(-remaining)} altın eksik.';
      statusIcon = Icons.cancel_rounded;
    } else if (remaining >= selected.cost) {
      statusColor = MekanPalette.neon;
      statusText = 'Mükemmel Rezerv: Açılış sonrası işletme kasası güvende.';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = MekanPalette.gold;
      statusText = 'Hassas Rezerv: Açılış sonrası hemen ciro yapılması önerilir.';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MekanPalette.void_.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${selected.name} Yatırım Özeti',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: MekanPalette.textHi),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      isDeficit ? 'AÇIK VAR' : '%${(spentRatio * 100).toStringAsFixed(0)} HARCAMA',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildFinanceStatItem('Cüzdan', formatMekanGold(gold), MekanPalette.aqua, Icons.account_balance_wallet_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFinanceStatItem('Maliyet', '-${formatMekanGold(selected.cost)}', MekanPalette.gold, Icons.storefront_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFinanceStatItem(
                  isDeficit ? 'Eksik' : 'Kalan Kasa',
                  formatMekanGold(remaining.abs()),
                  statusColor,
                  isDeficit ? Icons.money_off_rounded : Icons.savings_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: spentRatio,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetPlannerCard(BuildContext context, int gold, MekanTypeInfo? selected) {
    return NeonPanel(
      accent: MekanPalette.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: MekanPalette.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: MekanPalette.gold.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: MekanPalette.gold),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'BÜTÇE & KASA REZERVİ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: MekanPalette.textHi,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _showBudgetPlanner ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: MekanPalette.textMid,
                ),
                onPressed: () => setState(() => _showBudgetPlanner = !_showBudgetPlanner),
                tooltip: _showBudgetPlanner ? 'Gizle' : 'Göster',
              ),
            ],
          ),
          if (_showBudgetPlanner) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Açılış bütçeni planla, mekanları maliyete göre filtrele ve kasa rezervini hesapla.',
              style: TextStyle(fontSize: 12, color: MekanPalette.textMid, height: 1.3),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'Bütçe Tavanı Filtresi:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MekanPalette.textMid),
                ),
                Text(
                  _budgetFilterLimit >= 200000000.0
                      ? 'Limitsiz (Tümü)'
                      : formatMekanGold(_budgetFilterLimit.round()),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: MekanPalette.gold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: MekanPalette.gold,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                thumbColor: MekanPalette.gold,
                overlayColor: MekanPalette.gold.withValues(alpha: 0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _budgetFilterLimit.clamp(5000000.0, 200000000.0),
                min: 5000000.0,
                max: 200000000.0,
                divisions: 39,
                onChanged: (double val) {
                  setState(() => _budgetFilterLimit = val);
                },
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _buildBudgetPresetChip('Starter (5M)', 5000000.0),
                _buildBudgetPresetChip('Kahvehane (8M)', 8000000.0),
                _buildBudgetPresetChip('Arena (15M)', 15000000.0),
                _buildBudgetPresetChip('VIP (50M)', 50000000.0),
                _buildBudgetPresetChip('Limitsiz', 200000000.0),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _onlyAffordable,
                    onChanged: (bool? val) => setState(() => _onlyAffordable = val ?? false),
                    activeColor: MekanPalette.gold,
                    checkColor: MekanPalette.void_,
                    side: BorderSide(color: MekanPalette.textLow.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _onlyAffordable = !_onlyAffordable),
                    child: const Text(
                      'Sadece cüzdanıma ve seviyeme yetenleri göster',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MekanPalette.textHi),
                    ),
                  ),
                ),
              ],
            ),
            if (selected != null) ...<Widget>[
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),
              _buildFinancialBreakdown(gold, selected),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusBanner({
    required MekanTypeInfo? selected,
    required bool hasName,
    required bool nameValid,
    required bool levelOk,
    required bool goldOk,
    required int level,
    required int gold,
  }) {
    if (selected == null) {
      return _buildStatusChip(
        icon: Icons.touch_app_rounded,
        text: 'Aşağıdaki listeden açmak istediğin mekan türünü seç.',
        color: MekanPalette.textMid,
      );
    }
    if (!hasName) {
      return _buildStatusChip(
        icon: Icons.edit_note_rounded,
        text: 'Mekanına bir isim ver (zar ikonuna basarak hızlı isim üretebilirsin).',
        color: MekanPalette.aqua,
      );
    }
    if (!nameValid) {
      return _buildStatusChip(
        icon: Icons.warning_amber_rounded,
        text: 'Mekan adı en az 3, en fazla 30 karakter olmalıdır.',
        color: MekanPalette.coral,
      );
    }
    if (!levelOk && !goldOk) {
      return _buildStatusChip(
        icon: Icons.lock_clock_rounded,
        text: 'Kilitli: Sv ${selected.reqLevel} ve ${formatMekanGold(selected.cost - gold)} daha altın gerekli.',
        color: MekanPalette.ruby,
      );
    }
    if (!levelOk) {
      return _buildStatusChip(
        icon: Icons.military_tech_rounded,
        text: 'Seviye Yetersiz: Sv ${selected.reqLevel} gerekiyor (Sen: Sv $level).',
        color: MekanPalette.ruby,
      );
    }
    if (!goldOk) {
      return _buildStatusChip(
        icon: Icons.paid_rounded,
        text: 'Yetersiz Altın: ${formatMekanGold(selected.cost - gold)} eksik.',
        color: MekanPalette.ruby,
      );
    }
    return _buildStatusChip(
      icon: Icons.check_circle_rounded,
      text: 'Tüm şartlar hazır! Mekanı açarak imparatorluğuna ilk adımı at.',
      color: MekanPalette.neon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final int gold = profile?.gold ?? 0;
    final int level = profile?.level ?? 0;
    final MekanTypeInfo? selected = _infoFor(_selectedType);

    final String trimmedName = _name.text.trim();
    final bool hasType = selected != null;
    final bool hasName = trimmedName.isNotEmpty;
    final bool nameValid = trimmedName.length >= 3 && trimmedName.length <= 30;
    final bool levelOk = selected != null && level >= selected.reqLevel;
    final bool goldOk = selected != null && gold >= selected.cost;
    final bool canCreate = hasType && hasName && nameValid && levelOk && goldOk && !_busy;

    final bool hasAffordableType =
        _types.any((MekanTypeInfo t) => level >= t.reqLevel && gold >= t.cost);
    final MekanTypeInfo starter = _types.first;

    final List<MekanTypeInfo> displayedTypes = _types.where((MekanTypeInfo t) {
      if (_onlyAffordable && (level < t.reqLevel || gold < t.cost)) {
        return false;
      }
      if (t.cost > _budgetFilterLimit) {
        return false;
      }
      return true;
    }).toList();

    String buttonLabel;
    IconData? buttonIcon;
    Color buttonAccent;

    if (_busy) {
      buttonLabel = 'Mekan Kuruluyor...';
      buttonIcon = null;
      buttonAccent = MekanPalette.gold;
    } else if (!hasType) {
      buttonLabel = '1. Adım: Mekan Türü Seçin';
      buttonIcon = Icons.touch_app_rounded;
      buttonAccent = MekanPalette.textLow;
    } else if (!hasName) {
      buttonLabel = '2. Adım: Mekan Adını Belirleyin';
      buttonIcon = Icons.edit_note_rounded;
      buttonAccent = MekanPalette.textLow;
    } else if (!nameValid) {
      buttonLabel = 'Mekan Adı En Az 3 Karakter Olmalı';
      buttonIcon = Icons.short_text_rounded;
      buttonAccent = MekanPalette.coral;
    } else if (!levelOk) {
      buttonLabel = 'Kilitli: Sv ${selected.reqLevel} Gerekli (Sen: Sv $level)';
      buttonIcon = Icons.lock_rounded;
      buttonAccent = MekanPalette.ruby;
    } else if (!goldOk) {
      buttonLabel = 'Yetersiz Altın (${formatMekanGold(selected.cost - gold)} Eksik)';
      buttonIcon = Icons.money_off_rounded;
      buttonAccent = MekanPalette.ruby;
    } else {
      buttonLabel = '${selected.name} Aç — ${formatMekanGold(selected.cost)}';
      buttonIcon = Icons.storefront_rounded;
      buttonAccent = MekanPalette.gold;
    }

    return MekanSubScaffold(
      title: context.l10n.mekan_ac,
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: GameScrollLayout.fromLTRB(
                context,
                left: 14,
                top: 14,
                right: 14,
                bottomExtra: kGameChatFabSize + 12,
              ),
              children: <Widget>[
                NeonPanel(
                  accent: MekanPalette.gold,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'İMPARATORLUĞUNU KUR',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: MekanPalette.textHi,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            children: <Widget>[
                              GlowChip(
                                icon: Icons.military_tech_rounded,
                                label: 'Sv $level',
                                color: MekanPalette.aqua,
                              ),
                              GlowChip(
                                icon: Icons.paid_rounded,
                                label: formatMekanGold(gold),
                                color: MekanPalette.gold,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Bir mekan türü seç, şanına layık bir isim koy ve han ticaretine başla.',
                        style: TextStyle(fontSize: 12.5, color: MekanPalette.textMid, height: 1.3),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text(
                            'Mekan Adı',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: MekanPalette.textHi),
                          ),
                          TextButton.icon(
                            onPressed: _rollRandomName,
                            icon: const Icon(Icons.auto_awesome, size: 14, color: MekanPalette.gold),
                            label: const Text(
                              'Rastgele İsim',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: MekanPalette.gold),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _name,
                        focusNode: _nameFocusNode,
                        maxLength: 30,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: MekanPalette.textHi, fontWeight: FontWeight.w700, fontSize: 14.5),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: context.l10n.orn_golge_han_bar,
                          hintStyle: const TextStyle(color: MekanPalette.textLow),
                          errorText: _name.text.isNotEmpty ? _getNameValidationError() : null,
                          errorStyle: const TextStyle(color: MekanPalette.coral, fontSize: 11, fontWeight: FontWeight.w600),
                          counterStyle: TextStyle(
                            color: _name.text.length >= 28 ? MekanPalette.coral : MekanPalette.textLow,
                            fontSize: 11,
                          ),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: MekanPalette.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.storefront_rounded, size: 18, color: MekanPalette.gold),
                          ),
                          suffixIcon: _name.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: MekanPalette.textMid),
                                  onPressed: () {
                                    _name.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: MekanPalette.void_.withValues(alpha: 0.5),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: MekanPalette.gold, width: 1.6),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: MekanPalette.coral, width: 1.4),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: MekanPalette.ruby, width: 1.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'Öneriler:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: MekanPalette.textLow),
                            ),
                          ),
                          ..._getCurrentSuggestions().map((String suggestion) {
                            final bool isSelected = _name.text.trim() == suggestion;
                            return GestureDetector(
                              onTap: () {
                                _name.text = suggestion;
                                _name.selection = TextSelection.fromPosition(TextPosition(offset: _name.text.length));
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? MekanPalette.gold.withValues(alpha: 0.2)
                                      : MekanPalette.void_.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? MekanPalette.gold : Colors.white.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  suggestion,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? MekanPalette.gold : MekanPalette.textMid,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildBudgetPlannerCard(context, gold, selected),
                const SizedBox(height: 16),
                NeonSectionHeader(
                  title: context.l10n.mekan_turu,
                  subtitle: '${_types.length} tür mevcut · ${displayedTypes.length} gösteriliyor',
                  accent: MekanPalette.gold,
                ),
                const SizedBox(height: 12),
                if (displayedTypes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: MekanPalette.void_.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: <Widget>[
                        const Icon(Icons.filter_alt_off_rounded, size: 36, color: MekanPalette.textLow),
                        const SizedBox(height: 8),
                        const Text(
                          'Seçili filtreye uygun mekan türü bulunamadı.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MekanPalette.textMid),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _budgetFilterLimit = 200000000.0;
                              _onlyAffordable = false;
                            });
                          },
                          child: const Text('Filtreleri Sıfırla', style: TextStyle(color: MekanPalette.gold)),
                        ),
                      ],
                    ),
                  )
                else
                  ...displayedTypes.map((MekanTypeInfo info) {
                    final bool locked = level < info.reqLevel || gold < info.cost;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MekanTypeArtCard(
                        info: info,
                        selected: _selectedType == info.type,
                        locked: locked,
                        affordable: gold >= info.cost,
                        levelOk: level >= info.reqLevel,
                        onTap: () => setState(() => _selectedType = info.type),
                        onLockedTap: () {
                          setState(() => _selectedType = info.type);
                          _showLockedReason(info, level, gold);
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(14, 12, 14, MediaQuery.paddingOf(context).bottom + 10),
            decoration: BoxDecoration(
              color: MekanPalette.void_.withValues(alpha: 0.95),
              border: const Border(top: BorderSide(color: Colors.white12, width: 1.2)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!hasAffordableType)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'En ucuz tür ${starter.name}: Sv ${starter.reqLevel} ve ${formatMekanGold(starter.cost)} altın gerekir.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11.5, color: MekanPalette.textMid, height: 1.3),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildLiveStatusBanner(
                      selected: selected,
                      hasName: hasName,
                      nameValid: nameValid,
                      levelOk: levelOk,
                      goldOk: goldOk,
                      level: level,
                      gold: gold,
                    ),
                  ),
                NeonButton(
                  label: buttonLabel,
                  icon: buttonIcon,
                  accent: buttonAccent,
                  busy: _busy,
                  onPressed: canCreate ? _create : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
