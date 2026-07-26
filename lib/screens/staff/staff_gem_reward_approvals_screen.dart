import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_screen_background.dart';
import '../../theme/app_text_styles.dart';
import '../../core/utils/keyboard_dismiss.dart';
import '../../models/staff_model.dart';
import '../../providers/staff_provider.dart';
import '../../repositories/staff_repository.dart';
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

  static const int _pageSize = 40;
  static final DateFormat _dateFmt = DateFormat('dd.MM.yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
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
    final int gems = item.suggestedGems ?? 0;
    final Map<String, String>? values = await showStaffFormDialog(
      context: context,
      title: 'Elmas onay — ${item.username ?? item.playerId}',
      confirmLabel: 'Onayla',
      fields: <StaffFormFieldSpec>[
        StaffFormFieldSpec(
          key: 'gems',
          label: 'Elmas (100–5000)',
          initial: '$gems',
          keyboardType: TextInputType.number,
        ),
        const StaffFormFieldSpec(key: 'note', label: 'Not', maxLines: 2),
      ],
    );
    if (values == null) return;
    setState(() => _actingId = item.id);
    final String? err = await _repo.approveBugReport(
      item.id,
      int.tryParse(values['gems'] ?? '') ?? 0,
      note: values['note'],
    );
    if (!mounted) return;
    setState(() => _actingId = null);
    if (err != null) {
      AppMessenger.showError(context, err);
      return;
    }
    AppMessenger.showSuccess(context, '${values['gems']}💎 verildi.');
    await _loadPending();
    if (_tabs.index == 1) {
      await _loadHistory(reset: true);
    }
  }

  Future<void> _reject(GemRewardPendingItem item) async {
    final Map<String, String>? values = await showStaffFormDialog(
      context: context,
      title: 'Elmas ödülü reddet',
      confirmLabel: 'Reddet',
      danger: true,
      fields: const <StaffFormFieldSpec>[
        StaffFormFieldSpec(
          key: 'note',
          label: 'Oyuncuya not',
          initial: 'Elmas ödülü talebi reddedildi.',
          maxLines: 3,
        ),
      ],
    );
    if (values == null) return;
    setState(() => _actingId = item.id);
    final String? err = await _repo.rejectGemRewardRequest(
      item.id,
      note: values['note']?.trim(),
    );
    if (!mounted) return;
    setState(() => _actingId = null);
    if (err != null) {
      AppMessenger.showError(context, err);
      return;
    }
    AppMessenger.showSuccess(context, 'Talep reddedildi.');
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
            TabBar(
              controller: _tabs,
              labelColor: SettingsPalette.gold,
              unselectedLabelColor: SettingsPalette.textMid,
              indicatorColor: SettingsPalette.gold,
              tabs: <Widget>[
                Tab(text: 'Bekleyen (${_pending.length})'),
                const Tab(text: 'Geçmiş'),
              ],
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
              message: 'Bekleyen elmas onay talebi yok.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: SettingsPalette.gold,
      onRefresh: _loadPending,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: GameScrollLayout.padding(context),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final GemRewardPendingItem item = _pending[index];
          final bool busy = _actingId == item.id;
          return SettingsGlassCard(
            accent: SettingsPalette.fuchsia,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StaffStatusPill(status: item.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.username ?? item.playerId} · ${item.category} · ${item.suggestedGems ?? 0}💎',
                  style: supportCaptionStyle,
                ),
                if (item.suggesterUsername != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'GM önerisi: ${item.suggesterUsername} · ${_formatDate(item.suggestedAt)}',
                    style: supportCaptionStyle.copyWith(color: SettingsPalette.gold),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StaffActionButton(
                        label: busy ? '…' : 'Onayla (${item.suggestedGems}💎)',
                        accent: SettingsPalette.neon,
                        onPressed: busy ? null : () => _approve(item),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StaffActionButton(
                        label: 'Reddet',
                        outlined: true,
                        danger: true,
                        onPressed: busy ? null : () => _reject(item),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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
                  decoration: supportInputDecoration(
                    label: 'Kullanıcı adı ara',
                    hint: 'theking',
                  ),
                  onSubmitted: (_) => _loadHistory(reset: true),
                ),
              ),
              const SizedBox(width: 8),
              StaffActionButton(
                label: 'Ara',
                accent: SettingsPalette.gold,
                onPressed: () => _loadHistory(reset: true),
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
                              icon: Icons.history_toggle_off,
                              message: 'Onaylanmış elmas ödülü kaydı yok.',
                            ),
                          ],
                        )
                      : RefreshIndicator(
                          color: SettingsPalette.gold,
                          onRefresh: () => _loadHistory(reset: true),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: GameScrollLayout.padding(context),
                            itemCount: _history.length + (_historyHasMore ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (BuildContext context, int index) {
                              if (index >= _history.length) {
                                return StaffActionButton(
                                  label: _historyLoading ? 'Yükleniyor…' : 'Daha fazla',
                                  outlined: true,
                                  onPressed: _historyLoading ? null : () => _loadHistory(),
                                );
                              }
                              final GemRewardHistoryItem item = _history[index];
                              return SupportListTileCard(
                                title: '${item.username ?? item.playerId} · ${item.rewardGemsApproved ?? 0}💎',
                                subtitle:
                                    '${item.title}\nOnay: ${item.reviewerUsername ?? '—'} · ${_formatDate(item.reviewedAt)}'
                                    '${item.suggesterUsername != null ? '\nGM: ${item.suggesterUsername}' : ''}',
                                accent: SettingsPalette.neon,
                              );
                            },
                          ),
                        ),
        ),
      ],
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
              Text(message, style: supportBodyStyle, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              StaffActionButton(label: 'Tekrar dene', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
