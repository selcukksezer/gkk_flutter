import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../core/services/app_haptics.dart';
import '../../core/utils/keyboard_dismiss.dart';
import '../../models/staff_model.dart';
import '../../providers/staff_provider.dart';
import '../../repositories/staff_repository.dart';
import '../../theme/app_text_styles.dart';
import '../settings/graphics_settings_service.dart';
import '../support/widgets/support_design.dart';
import '../support/widgets/support_screen_shell.dart';
import 'widgets/staff_design.dart';

class StaffGemRewardApprovalsScreen extends ConsumerStatefulWidget {
  const StaffGemRewardApprovalsScreen({super.key});

  @override
  ConsumerState<StaffGemRewardApprovalsScreen> createState() =>
      _StaffGemRewardApprovalsScreenState();
}

class _StaffGemRewardApprovalsScreenState extends ConsumerState<StaffGemRewardApprovalsScreen>
    with SingleTickerProviderStateMixin {
  final StaffRepository _repo = StaffRepository();
  final TextEditingController _historySearch = TextEditingController();
  late TabController _tabs;

  List<GemRewardPendingItem> _pending = <GemRewardPendingItem>[];
  List<GemRewardHistoryItem> _history = <GemRewardHistoryItem>[];
  bool _pendingLoading = false;
  bool _historyLoading = false;
  bool _historyHasMore = false;
  int _historyOffset = 0;
  String? _pendingError;
  String? _historyError;
  String? _actingId;

  // Form controls & filter switches
  bool _gmEndorsedOnly = false;
  bool _highValueOnly = false;

  static const int _pageSize = 40;
  static final DateFormat _dateFmt = DateFormat('dd.MM.yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);

    // Warm up staff profile state and pending items quietly via ZeroJankPreloader
    unawaited(
      ZeroJankPreloader.instance.preloadAtomic<void>(
        id: 'staff_gem_approvals_warmup',
        priority: PreloadPriority.criticalHud,
        loader: () async {
          await ref.read(staffProvider.notifier).load(silent: true);
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPending());
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _historySearch.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted || _tabs.indexIsChanging) return;
    unawaited(AppHaptics.selection());
    if (_tabs.index == 1 && _history.isEmpty && !_historyLoading) {
      unawaited(_loadHistory(reset: true));
    }
  }

  Future<void> _loadPending() async {
    setState(() {
      _pendingLoading = true;
      _pendingError = null;
    });
    final result = await _repo.listGemRewardPendingResult();
    if (!mounted) return;
    setState(() {
      _pendingLoading = false;
      _pending = result.items;
      _pendingError = result.error;
    });
    await ref.read(staffProvider.notifier).load(silent: true);
  }

  Future<void> _loadHistory({bool reset = false}) async {
    if (reset) {
      _historyOffset = 0;
      _history = <GemRewardHistoryItem>[];
    }
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    final result = await _repo.listGemRewardHistoryResult(
      usernameQuery: _historySearch.text.trim().isEmpty ? null : _historySearch.text.trim(),
      limit: _pageSize,
      offset: _historyOffset,
    );
    if (!mounted) return;
    setState(() {
      _historyLoading = false;
      _historyError = result.error;
      if (reset) {
        _history = result.items;
      } else {
        _history = <GemRewardHistoryItem>[..._history, ...result.items];
      }
      _historyHasMore = result.hasMore;
      _historyOffset = _history.length;
    });
  }

  Future<void> _approve(GemRewardPendingItem item) async {
    unawaited(AppHaptics.selection());
    final _ApprovalDialogResult? decision = await _showApprovalModal(context, item);
    if (decision == null) return;

    setState(() => _actingId = item.id);
    final String? err = await _repo.approveBugReport(
      item.id,
      decision.gems,
      note: decision.note,
    );
    if (!mounted) return;
    setState(() => _actingId = null);

    if (err != null) {
      unawaited(AppHaptics.heavy());
      AppMessenger.showError(context, err);
      return;
    }
    unawaited(AppHaptics.success());
    AppMessenger.showSuccess(context, '${decision.gems}💎 onaylandı ve aktarıldı.');
    await _loadPending();
    if (_tabs.index == 1) {
      await _loadHistory(reset: true);
    }
  }

  Future<void> _reject(GemRewardPendingItem item) async {
    unawaited(AppHaptics.selection());
    final String? reason = await _showRejectionModal(context, item);
    if (reason == null) return;

    setState(() => _actingId = item.id);
    final String? err = await _repo.rejectGemRewardRequest(
      item.id,
      note: reason.trim(),
    );
    if (!mounted) return;
    setState(() => _actingId = null);

    if (err != null) {
      unawaited(AppHaptics.heavy());
      AppMessenger.showError(context, err);
      return;
    }
    unawaited(AppHaptics.medium());
    AppMessenger.showSuccess(context, 'Talep gerekçeli olarak reddedildi.');
    await _loadPending();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return _dateFmt.format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return DismissKeyboard(
      child: SupportScreenShell(
        title: 'Elmas Ödülü Onay Talepleri',
        body: Column(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: SettingsPalette.gold.withValues(alpha: 0.25),
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabs,
                labelColor: SettingsPalette.gold,
                unselectedLabelColor: SettingsPalette.textMid,
                indicatorColor: SettingsPalette.gold,
                indicatorWeight: 2.5,
                tabs: <Widget>[
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.pending_actions_rounded, size: 16),
                        const SizedBox(width: 8),
                        Text('Bekleyen (${_pending.length})'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.history_edu_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Onay Geçmişi'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: <Widget>[
                  _pendingTab(),
                  _historyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingTab() {
    if (_pendingLoading && _pending.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: SettingsPalette.gold));
    }
    if (_pendingError != null) {
      return _errorState(_pendingError!, onRetry: _loadPending);
    }
    if (_pending.isEmpty) {
      return RefreshIndicator(
        color: SettingsPalette.gold,
        onRefresh: _loadPending,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: GameScrollLayout.padding(context),
          children: const <Widget>[
            StaffEmptyState(
              icon: Icons.diamond_outlined,
              message: 'Bekleyen elmas onay talebi bulunmuyor.',
            ),
          ],
        ),
      );
    }

    // Filter items based on active switch controls
    List<GemRewardPendingItem> items = _pending;
    if (_gmEndorsedOnly) {
      items = items.where((GemRewardPendingItem i) => i.suggesterUsername != null && i.suggesterUsername!.trim().isNotEmpty).toList();
    }
    if (_highValueOnly) {
      items = items.where((GemRewardPendingItem i) => (i.suggestedGems ?? 0) >= 50).toList();
    }

    return Column(
      children: <Widget>[
        _buildPendingFilterBar(),
        Expanded(
          child: items.isEmpty
              ? RefreshIndicator(
                  color: SettingsPalette.gold,
                  onRefresh: _loadPending,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: GameScrollLayout.padding(context),
                    children: <Widget>[
                      const StaffEmptyState(
                        icon: Icons.filter_alt_off_rounded,
                        message: 'Filtrelere uygun bekleyen elmas talebi bulunamadı.',
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: StaffActionButton(
                          label: 'Filtreleri Sıfırla',
                          accent: SettingsPalette.gold,
                          outlined: true,
                          onPressed: () {
                            unawaited(AppHaptics.selection());
                            setState(() {
                              _gmEndorsedOnly = false;
                              _highValueOnly = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    if (notification is ScrollStartNotification) {
                      ZeroJankPreloader.instance.onTouchStart();
                    } else if (notification is ScrollEndNotification) {
                      ZeroJankPreloader.instance.onTouchEnd();
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    color: SettingsPalette.gold,
                    onRefresh: _loadPending,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: GameScrollLayout.padding(context),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (BuildContext context, int index) {
                        final GemRewardPendingItem item = items[index];
                        final bool busy = _actingId == item.id;
                        return _buildPendingGlassCard(item, busy);
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPendingFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: SettingsPalette.navy.withValues(alpha: 0.50),
        border: Border(
          bottom: BorderSide(
            color: SettingsPalette.gold.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            // GM Endorsed filter switch (verified activeColor, activeTrackColor, inactiveThumbColor)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Switch(
                  value: _gmEndorsedOnly,
                  activeColor: SettingsPalette.neon,
                  activeTrackColor: SettingsPalette.neon.withValues(alpha: 0.38),
                  inactiveThumbColor: SettingsPalette.titanium,
                  inactiveTrackColor: SettingsPalette.obsidian.withValues(alpha: 0.70),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (bool val) {
                    unawaited(AppHaptics.selection());
                    setState(() => _gmEndorsedOnly = val);
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  'GM Önerileri',
                  style: supportCaptionStyle.copyWith(
                    color: _gmEndorsedOnly ? SettingsPalette.neon : SettingsPalette.titanium,
                    fontWeight: _gmEndorsedOnly ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // High Value filter switch (>= 50 gems)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Switch(
                  value: _highValueOnly,
                  activeColor: SettingsPalette.gold,
                  activeTrackColor: SettingsPalette.gold.withValues(alpha: 0.38),
                  inactiveThumbColor: SettingsPalette.titanium,
                  inactiveTrackColor: SettingsPalette.obsidian.withValues(alpha: 0.70),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (bool val) {
                    unawaited(AppHaptics.selection());
                    setState(() => _highValueOnly = val);
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  'Yüksek Ödül (≥50💎)',
                  style: supportCaptionStyle.copyWith(
                    color: _highValueOnly ? SettingsPalette.gold : SettingsPalette.titanium,
                    fontWeight: _highValueOnly ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingGlassCard(GemRewardPendingItem item, bool busy) {
    final int gems = item.suggestedGems ?? 0;
    final String playerDisplay = item.username?.isNotEmpty == true ? item.username! : item.playerId;

    final bool isLowTier = GraphicsSettingsService.instance.scaler.currentTier == HardwareTier.eco ||
        GraphicsSettingsService.instance.scaler.currentTier == HardwareTier.low;
    final double blurSigma = isLowTier ? 0.0 : 12.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF00E5FF).withValues(alpha: 0.14),
            SettingsPalette.navy.withValues(alpha: 0.88),
            SettingsPalette.void_.withValues(alpha: 0.96),
          ],
        ),
        border: Border.all(
          color: SettingsPalette.gold.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: isLowTier
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: SettingsPalette.gold.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Stack(
            children: <Widget>[
              // Specular top light reflex
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                height: 1.2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        SettingsPalette.gold.withValues(alpha: 0.70),
                        Colors.white.withValues(alpha: 0.50),
                        SettingsPalette.gold.withValues(alpha: 0.70),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
          // Header: Player identity & Status badge
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: <Color>[
                      SettingsPalette.gold.withValues(alpha: 0.35),
                      SettingsPalette.obsidian,
                    ],
                  ),
                  border: Border.all(color: SettingsPalette.gold.withValues(alpha: 0.7)),
                ),
                child: const Icon(Icons.person_rounded, color: SettingsPalette.gold, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      playerDisplay,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: SettingsPalette.textHi,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'ID: ${item.playerId}',
                      style: supportCaptionStyle.copyWith(
                        fontFamily: 'Courier',
                        fontSize: 10,
                        color: SettingsPalette.titanium,
                      ),
                    ),
                  ],
                ),
              ),
              StaffStatusPill(status: item.status),
            ],
          ),
          const SizedBox(height: 12),
          // Title & Category
          Text(
            item.title,
            style: AppTextStyles.bodyBold.copyWith(
              color: SettingsPalette.textHi,
              fontSize: 14,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: SettingsPalette.fuchsia.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SettingsPalette.fuchsia.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.label_outline_rounded, size: 11, color: SettingsPalette.fuchsia),
                    const SizedBox(width: 4),
                    Text(
                      item.category.toUpperCase(),
                      style: AppTextStyles.captionBold.copyWith(
                        color: SettingsPalette.fuchsia,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.schedule_rounded, size: 12, color: SettingsPalette.titanium),
              const SizedBox(width: 4),
              Text(
                _formatDate(item.createdAt ?? item.suggestedAt),
                style: supportCaptionStyle.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Luminous Reward Highlight Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFF00E5FF).withValues(alpha: 0.18),
                  const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                  SettingsPalette.obsidian.withValues(alpha: 0.70),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.diamond_rounded,
                  color: Color(0xFF00E5FF),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '+$gems ELMAS',
                        style: AppTextStyles.h3.copyWith(
                          color: const Color(0xFF00E5FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'ÖNERİLEN TAHKİK ÖDÜLÜ',
                        style: AppTextStyles.captionBold.copyWith(
                          color: SettingsPalette.titanium,
                          fontSize: 9,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.suggesterUsername != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SettingsPalette.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SettingsPalette.gold.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.shield_outlined, size: 12, color: SettingsPalette.gold),
                        const SizedBox(width: 4),
                        Text(
                          'GM @${item.suggesterUsername}',
                          style: AppTextStyles.captionBold.copyWith(
                            color: SettingsPalette.gold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Audit Trail Provenance Badges
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: SettingsPalette.obsidian.withValues(alpha: 0.60),
              border: Border.all(color: SettingsPalette.titanium.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.verified_user_outlined, size: 13, color: SettingsPalette.neon),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Güvenlik Denetimi: GM onaylı bildirim · Yetkili transferi bekliyor',
                    style: supportCaptionStyle.copyWith(
                      color: SettingsPalette.titanium,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Luminous Action Buttons
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _buildLuminousAcceptButton(
                  label: busy ? 'İşleniyor…' : 'Onayla ($gems💎)',
                  busy: busy,
                  onPressed: busy ? null : () => _approve(item),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildLuminousRejectButton(
                  label: 'Reddet',
                  busy: busy,
                  onPressed: busy ? null : () => _reject(item),
                ),
              ),
            ],
          ),
        ],
      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLuminousAcceptButton({
    required String label,
    required bool busy,
    required VoidCallback? onPressed,
  }) {
    return SettingsPressable(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFF00E676).withValues(alpha: 0.90),
              const Color(0xFF00B0FF).withValues(alpha: 0.85),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF00E676).withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (busy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SettingsPalette.void_,
                ),
              )
            else
              const Icon(Icons.check_circle_rounded, color: SettingsPalette.void_, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.void_,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuminousRejectButton({
    required String label,
    required bool busy,
    required VoidCallback? onPressed,
  }) {
    return SettingsPressable(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: SettingsPalette.obsidian.withValues(alpha: 0.70),
          border: Border.all(
            color: SettingsPalette.ruby.withValues(alpha: 0.75),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: SettingsPalette.ruby.withValues(alpha: 0.20),
              blurRadius: 10,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.cancel_outlined, color: SettingsPalette.ruby, size: 15),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.ruby,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTab() {
    return Column(
      children: <Widget>[
        Padding(
          padding: GameScrollLayout.padding(context).copyWith(bottom: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _historySearch,
                  style: supportBodyStyle,
                  textInputAction: TextInputAction.search,
                  decoration: supportInputDecoration(
                    label: 'Kullanıcı adı ara',
                    hint: 'theking, player_01…',
                  ).copyWith(
                    prefixIcon: const Icon(Icons.search_rounded, color: SettingsPalette.gold, size: 20),
                    suffixIcon: _historySearch.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              unawaited(AppHaptics.selection());
                              _historySearch.clear();
                              _loadHistory(reset: true);
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) {
                    unawaited(AppHaptics.selection());
                    _loadHistory(reset: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              StaffActionButton(
                label: 'Ara',
                accent: SettingsPalette.gold,
                onPressed: () {
                  unawaited(AppHaptics.selection());
                  _loadHistory(reset: true);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _historyLoading && _history.isEmpty
              ? const Center(child: CircularProgressIndicator(color: SettingsPalette.gold))
              : _historyError != null
                  ? _errorState(_historyError!, onRetry: () => _loadHistory(reset: true))
                  : _history.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: GameScrollLayout.padding(context),
                          children: const <Widget>[
                            StaffEmptyState(
                              icon: Icons.history_toggle_off_rounded,
                              message: 'Onaylanmış veya sonuçlanmış elmas ödülü kaydı bulunamadı.',
                            ),
                          ],
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification notification) {
                            if (notification is ScrollStartNotification) {
                              ZeroJankPreloader.instance.onTouchStart();
                            } else if (notification is ScrollEndNotification) {
                              ZeroJankPreloader.instance.onTouchEnd();
                            }
                            return false;
                          },
                          child: RefreshIndicator(
                            color: SettingsPalette.gold,
                            onRefresh: () => _loadHistory(reset: true),
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: GameScrollLayout.padding(context),
                              itemCount: _history.length + (_historyHasMore ? 1 : 0),
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (BuildContext context, int index) {
                                if (index >= _history.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: StaffActionButton(
                                      label: _historyLoading ? 'Kayıtlar yükleniyor…' : 'Daha fazla kayıt yükle',
                                      outlined: true,
                                      accent: SettingsPalette.gold,
                                      onPressed: _historyLoading ? null : () {
                                        unawaited(AppHaptics.selection());
                                        _loadHistory();
                                      },
                                    ),
                                  );
                                }
                                final GemRewardHistoryItem item = _history[index];
                                return _buildHistoryGlassCard(item);
                              },
                            ),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildHistoryGlassCard(GemRewardHistoryItem item) {
    final String playerDisplay = item.username?.isNotEmpty == true ? item.username! : item.playerId;
    final int gems = item.rewardGemsApproved ?? item.suggestedGems ?? 0;

    final bool isLowTier = GraphicsSettingsService.instance.scaler.currentTier == HardwareTier.eco ||
        GraphicsSettingsService.instance.scaler.currentTier == HardwareTier.low;
    final double blurSigma = isLowTier ? 0.0 : 10.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SettingsPalette.neon.withValues(alpha: 0.12),
            SettingsPalette.navy.withValues(alpha: 0.82),
            SettingsPalette.void_.withValues(alpha: 0.94),
          ],
        ),
        border: Border.all(
          color: SettingsPalette.neon.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: isLowTier
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: SettingsPalette.neon.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Stack(
            children: <Widget>[
              // Specular top highlight
              Positioned(
                top: 0,
                left: 14,
                right: 14,
                height: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        SettingsPalette.neon.withValues(alpha: 0.65),
                        Colors.white.withValues(alpha: 0.40),
                        SettingsPalette.neon.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.military_tech_rounded, size: 20, color: SettingsPalette.neon),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            playerDisplay,
                            style: AppTextStyles.bodyBold.copyWith(
                              color: SettingsPalette.textHi,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              colors: <Color>[
                                SettingsPalette.neon.withValues(alpha: 0.25),
                                const Color(0xFF00E5FF).withValues(alpha: 0.15),
                              ],
                            ),
                            border: Border.all(color: SettingsPalette.neon.withValues(alpha: 0.70)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.diamond_rounded, size: 14, color: SettingsPalette.neon),
                              const SizedBox(width: 4),
                              Text(
                                '+$gems 💎',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: SettingsPalette.neon,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: supportBodyStyle.copyWith(
                        color: SettingsPalette.textHi,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: SettingsPalette.obsidian.withValues(alpha: 0.65),
                        border: Border.all(color: SettingsPalette.titanium.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(Icons.shield_rounded, size: 12, color: SettingsPalette.gold),
                              const SizedBox(width: 5),
                              Text(
                                'Onaylayan: ${item.reviewerUsername ?? 'Admin'}',
                                style: supportCaptionStyle.copyWith(
                                  color: SettingsPalette.gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatDate(item.reviewedAt),
                                style: supportCaptionStyle.copyWith(fontSize: 10.5),
                              ),
                            ],
                          ),
                          if (item.suggesterUsername != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                const Icon(Icons.person_pin_outlined, size: 12, color: SettingsPalette.titanium),
                                const SizedBox(width: 5),
                                Text(
                                  'Öneren GM: ${item.suggesterUsername}',
                                  style: supportCaptionStyle.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                          if (item.reviewNote != null && item.reviewNote!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: SettingsPalette.navy.withValues(alpha: 0.6),
                                border: Border.all(color: SettingsPalette.titanium.withValues(alpha: 0.15)),
                              ),
                              child: Text(
                                'Not: "${item.reviewNote}"',
                                style: supportCaptionStyle.copyWith(
                                  color: SettingsPalette.textMid,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState(String message, {required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SettingsGlassCard(
          accent: SettingsPalette.ruby,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, color: SettingsPalette.ruby, size: 36),
              const SizedBox(height: 10),
              Text(message, style: supportBodyStyle, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              StaffActionButton(label: 'Tekrar dene', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }

  Future<_ApprovalDialogResult?> _showApprovalModal(
    BuildContext context,
    GemRewardPendingItem item,
  ) {
    final TextEditingController gemsCtrl =
        TextEditingController(text: '${item.suggestedGems ?? 0}');
    final TextEditingController noteCtrl = TextEditingController();

    return showDialog<_ApprovalDialogResult>(
      context: context,
      builder: (BuildContext ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: SettingsPalette.navy.withValues(alpha: 0.96),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: SettingsPalette.gold.withValues(alpha: 0.55), width: 1.5),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            title: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SettingsPalette.gold.withValues(alpha: 0.20),
                    border: Border.all(color: SettingsPalette.gold),
                  ),
                  child: const Icon(Icons.shield_moon_rounded, color: SettingsPalette.gold, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Elmas Ödül Onayı',
                        style: AppTextStyles.h3.copyWith(
                          color: SettingsPalette.textHi,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Kripto denetim ve ödül transferi',
                        style: supportCaptionStyle.copyWith(color: SettingsPalette.textMid, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: SettingsPalette.obsidian.withValues(alpha: 0.70),
                      border: Border.all(color: SettingsPalette.titanium.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Oyuncu: ${item.username ?? item.playerId}',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: SettingsPalette.gold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Bildirim: ${item.title}',
                          style: supportCaptionStyle.copyWith(color: SettingsPalette.textHi, fontSize: 11.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.suggesterUsername != null) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            'Öneren GM: ${item.suggesterUsername}',
                            style: supportCaptionStyle.copyWith(color: SettingsPalette.titanium, fontSize: 10.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: gemsCtrl,
                    keyboardType: TextInputType.number,
                    style: supportBodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                    decoration: supportInputDecoration(
                      label: 'Verilecek Elmas Miktarı 💎',
                      hint: '100',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    style: supportBodyStyle,
                    decoration: supportInputDecoration(
                      label: 'Denetim / Onay Notu (Opsiyonel)',
                      hint: 'Başarılı hata tespiti için teşekkürler.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bu işlem geri alınamaz. Onay anında elmaslar oyuncunun hesabına doğrudan aktarılır ve audit defterine işlenir.',
                            style: supportCaptionStyle.copyWith(
                              color: const Color(0xFF00E5FF),
                              fontSize: 10.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  unawaited(AppHaptics.selection());
                  Navigator.pop(ctx, null);
                },
                child: Text('Vazgeç', style: TextStyle(color: SettingsPalette.titanium)),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: SettingsPalette.void_,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final int parsed = int.tryParse(gemsCtrl.text.trim()) ?? 0;
                  if (parsed <= 0) {
                    unawaited(AppHaptics.heavy());
                    AppMessenger.showError(ctx, 'Geçerli bir elmas miktarı girin.');
                    return;
                  }
                  unawaited(AppHaptics.medium());
                  Navigator.pop(
                    ctx,
                    _ApprovalDialogResult(
                      gems: parsed,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Onayla ve Transfer Et',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _showRejectionModal(
    BuildContext context,
    GemRewardPendingItem item,
  ) {
    final TextEditingController reasonCtrl = TextEditingController(
      text: 'Elmas ödülü talebi değerlendirildi ve kriterleri karşılamadığı için reddedildi.',
    );

    const List<String> quickReasons = <String>[
      'Yetersiz Kanıt',
      'Zaten Bilinen Hata',
      'Tekrarlanan Bildirim',
      'Oyun Mekaniği / Hata Değil',
      'Geçersiz Talep',
    ];

    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: SettingsPalette.navy.withValues(alpha: 0.96),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: SettingsPalette.ruby.withValues(alpha: 0.60), width: 1.5),
                ),
                titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                title: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SettingsPalette.ruby.withValues(alpha: 0.20),
                        border: Border.all(color: SettingsPalette.ruby),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: SettingsPalette.ruby, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Ödül Talebini Reddet',
                            style: AppTextStyles.h3.copyWith(
                              color: SettingsPalette.textHi,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Gerekçe oyuncuya bildirim olarak iletilecektir',
                            style: supportCaptionStyle.copyWith(color: SettingsPalette.textMid, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: SettingsPalette.obsidian.withValues(alpha: 0.70),
                          border: Border.all(color: SettingsPalette.titanium.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          'Oyuncu: ${item.username ?? item.playerId} · ${item.title}',
                          style: supportCaptionStyle.copyWith(color: SettingsPalette.textHi, fontSize: 11.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Hızlı gerekçe seç:',
                        style: supportCaptionStyle.copyWith(color: SettingsPalette.titanium, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: quickReasons.map((String reason) {
                          return SettingsPressable(
                            onTap: () {
                              unawaited(AppHaptics.selection());
                              setDialogState(() {
                                reasonCtrl.text = 'Talep reddedildi: $reason.';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: SettingsPalette.ruby.withValues(alpha: 0.12),
                                border: Border.all(color: SettingsPalette.ruby.withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                reason,
                                style: AppTextStyles.captionBold.copyWith(
                                  color: SettingsPalette.ruby,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonCtrl,
                        maxLines: 3,
                        style: supportBodyStyle,
                        decoration: supportInputDecoration(
                          label: 'Oyuncuya İletilecek Ret Açıklaması',
                          hint: 'Reddetme nedeni...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: SettingsPalette.ruby.withValues(alpha: 0.12),
                          border: Border.all(color: SettingsPalette.ruby.withValues(alpha: 0.40)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(Icons.block_rounded, color: SettingsPalette.ruby, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bu işlem onaylandığında talep kapatılacak ve elmas tahsis edilmeyecektir.',
                                style: supportCaptionStyle.copyWith(
                                  color: SettingsPalette.ruby,
                                  fontSize: 10.5,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      unawaited(AppHaptics.selection());
                      Navigator.pop(ctx, null);
                    },
                    child: Text('Vazgeç', style: TextStyle(color: SettingsPalette.titanium)),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SettingsPalette.ruby,
                      foregroundColor: SettingsPalette.void_,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final String text = reasonCtrl.text.trim();
                      if (text.isEmpty) {
                        unawaited(AppHaptics.heavy());
                        AppMessenger.showError(ctx, 'Lütfen bir ret gerekçesi girin.');
                        return;
                      }
                      unawaited(AppHaptics.medium());
                      Navigator.pop(ctx, text);
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text(
                      'Talebi Reddet',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ApprovalDialogResult {
  const _ApprovalDialogResult({required this.gems, this.note});

  final int gems;
  final String? note;
}
