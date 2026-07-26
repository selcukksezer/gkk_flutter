import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/debug/staff_hub_debug_log.dart';
import '../../core/utils/staff_audit_labels.dart';
import '../../components/common/app_messenger.dart';
import '../../core/services/supabase_service.dart';
import '../../core/staff/staff_player_entry.dart';
import '../../components/player/player_action_sheet.dart';
import '../../components/player/staff_player_card.dart';
import '../../models/staff_model.dart';
import '../../models/support_detail_model.dart';
import '../../models/support_model.dart';
import '../../providers/staff_provider.dart';
import '../../providers/support_provider.dart';
import '../../repositories/staff_repository.dart';
import '../../routing/app_router.dart';
import '../../theme/app_text_styles.dart';
import '../../components/layout/game_screen_background.dart';
import '../support/widgets/support_design.dart';
import '../support/widgets/support_screen_shell.dart';
import 'widgets/staff_design.dart';

class StaffHubScreen extends ConsumerStatefulWidget {
  const StaffHubScreen({super.key});

  @override
  ConsumerState<StaffHubScreen> createState() => _StaffHubScreenState();
}

class _StaffHubScreenState extends ConsumerState<StaffHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final TextEditingController _playerSearch = TextEditingController();
  final TextEditingController _gmSearch = TextEditingController();
  final TextEditingController _auditActorSearch = TextEditingController();
  final TextEditingController _auditTargetSearch = TextEditingController();
  final TextEditingController _dashboardAuditSearch = TextEditingController();
  final TextEditingController _ticketSearch = TextEditingController();
  final TextEditingController _bugSearch = TextEditingController();
  final TextEditingController _chatReportSearch = TextEditingController();
  final TextEditingController _gmRosterFilter = TextEditingController();
  List<StaffPlayerBrief> _players = <StaffPlayerBrief>[];
  List<StaffPlayerBrief> _gmSearchResults = <StaffPlayerBrief>[];
  List<SupportTicketSummary> _tickets = <SupportTicketSummary>[];
  List<BugReportSummary> _bugs = <BugReportSummary>[];
  List<PermissionCatalogItem> _permCatalog = <PermissionCatalogItem>[];
  final Set<String> _selectedPerms = <String>{};
  final StaffRepository _staffRepo = StaffRepository();
  List<ChatReportEntry> _chatReports = <ChatReportEntry>[];
  List<GmRosterEntry> _gmRoster = <GmRosterEntry>[];
  String? _ticketStatusFilter;
  String? _ticketCategoryFilter;
  String? _bugStatusFilter;
  String? _chatReportStatusFilter = 'open';
  String? _auditActorRoleFilter;
  String? _auditActionFilter;
  String? _auditTargetTypeFilter;
  String? _playerBanFilter;
  int _auditOffset = 0;
  bool _auditHasMore = false;
  String? _resolvingChatReportId;
  String? _editingGmAuthId;
  List<StaffAuditEntry>? _auditItems;
  String? _auditError;
  bool _auditLoading = false;
  bool _ticketsLoading = false;
  String? _ticketsError;
  bool _bugsLoading = false;
  String? _bugsError;
  bool _chatReportsLoading = false;
  String? _chatReportsError;
  String? _permCatalogError;
  bool _playersSearching = false;
  String? _playersError;
  bool _playersHasSearched = false;
  bool _chatWatchActive = false;
  RealtimeChannel? _chatReportsChannel;
  Timer? _chatReportsPoll;

  static const int _chatTabIndex = 4;
  static const int _auditTabIndex = 5;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    _tabs.addListener(_onTabChanged);
    _tabs.addListener(_onTabVisualChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  void _onTabVisualChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onTabChanged() {
    if (!mounted || _tabs.indexIsChanging) return;
    if (_tabs.index == _chatTabIndex) {
      _ensureChatReportsWatch();
      unawaited(_loadChatReports());
    } else {
      _teardownChatReportsWatch();
    }
    if (_tabs.index == _auditTabIndex) {
      unawaited(_loadAudit());
    }
  }

  void _ensureChatReportsWatch() {
    final StaffProfile profile = ref.read(staffProvider).profile;
    if (!profile.has('chat.view_reports') && !profile.isAdmin) return;
    if (_chatWatchActive) return;
    _chatWatchActive = true;
    // #region agent log
    StaffHubDebugLog.log(
      'H4',
      'staff_hub_screen.dart:_ensureChatReportsWatch',
      'chat_watch_start',
      data: <String, Object?>{'tabIndex': _tabs.index},
    );
    // #endregion
    _subscribeChatReports();
    _startChatReportsPoll();
  }

  void _teardownChatReportsWatch() {
    if (!_chatWatchActive) return;
    _chatWatchActive = false;
    // #region agent log
    StaffHubDebugLog.log(
      'H4',
      'staff_hub_screen.dart:_teardownChatReportsWatch',
      'chat_watch_stop',
      data: <String, Object?>{'tabIndex': _tabs.index},
    );
    // #endregion
    _chatReportsPoll?.cancel();
    _chatReportsPoll = null;
    _chatReportsChannel?.unsubscribe();
    _chatReportsChannel = null;
  }

  @override
  void dispose() {
    _chatReportsPoll?.cancel();
    _chatReportsChannel?.unsubscribe();
    _tabs.removeListener(_onTabChanged);
    _tabs.removeListener(_onTabVisualChanged);
    _tabs.dispose();
    _playerSearch.dispose();
    _gmSearch.dispose();
    _auditActorSearch.dispose();
    _auditTargetSearch.dispose();
    _dashboardAuditSearch.dispose();
    _ticketSearch.dispose();
    _bugSearch.dispose();
    _chatReportSearch.dispose();
    _gmRosterFilter.dispose();
    super.dispose();
  }

  Future<void> _refreshDashboard() async {
    await ref.read(staffProvider.notifier).load(silent: true);
  }

  Future<void> _refreshAll() async {
    await ref.read(staffProvider.notifier).load(silent: true);
    if (ref.read(staffProvider).profile.has('ticket.view_all')) {
      await _loadTickets();
    }
    if (ref.read(staffProvider).profile.has('bug.view')) {
      await _loadBugs();
    }
    if (ref.read(staffProvider).profile.has('staff.manage_gm')) {
      await _loadPermCatalog();
      await _loadGmRoster();
    }
    if (ref.read(staffProvider).profile.has('chat.view_reports') ||
        ref.read(staffProvider).profile.isAdmin) {
      if (_tabs.index == _chatTabIndex) {
        await _loadChatReports();
        _ensureChatReportsWatch();
      }
    }
    if (ref.read(staffProvider).profile.has('staff.view_audit')) {
      await _loadAudit();
    }
  }

  Future<void> _loadAudit({bool append = false}) async {
    if (!append) {
      setState(() {
        _auditLoading = true;
        _auditError = null;
        _auditOffset = 0;
      });
    } else {
      setState(() => _auditLoading = true);
    }
    final int offset = append ? _auditOffset : 0;
    final result = await _staffRepo.listAuditResult(
      limit: 50,
      offset: offset,
      action: _auditActionFilter,
      targetType: _auditTargetTypeFilter,
      actorQuery: _auditActorSearch.text.trim().isEmpty ? null : _auditActorSearch.text.trim(),
      targetQuery: _auditTargetSearch.text.trim().isEmpty ? null : _auditTargetSearch.text.trim(),
      actorRole: _auditActorRoleFilter,
    );
    if (!mounted) return;
    setState(() {
      _auditLoading = false;
      _auditError = result.error;
      if (append && _auditItems != null) {
        _auditItems = <StaffAuditEntry>[..._auditItems!, ...result.items];
      } else {
        _auditItems = result.items;
      }
      _auditOffset = (_auditItems ?? <StaffAuditEntry>[]).length;
      _auditHasMore = result.items.length >= 50;
    });
  }

  void _openAuditTab({String? actorQuery}) {
    if (actorQuery != null && actorQuery.isNotEmpty) {
      _auditActorSearch.text = actorQuery;
    }
    _tabs.animateTo(_auditTabIndex);
    unawaited(_loadAudit());
  }

  Future<StaffPlayerBrief?> _pickPlayer(List<StaffPlayerBrief> players, {required String emptyMessage}) async {
    if (players.isEmpty) {
      if (mounted) AppMessenger.showError(context, emptyMessage);
      return null;
    }
    if (players.length == 1) return players.first;
    return showModalBottomSheet<StaffPlayerBrief>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SettingsGlassCard(
            accent: SettingsPalette.neon,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Oyuncu seç', style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi)),
                const SizedBox(height: 8),
                ...players.map(
                  (StaffPlayerBrief p) => ListTile(
                    title: Text(p.displayName ?? p.username, style: supportBodyStyle),
                    subtitle: Text('@${p.username}', style: supportCaptionStyle),
                    onTap: () => Navigator.pop(ctx, p),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _resolveGmAuthId() {
    if (_editingGmAuthId != null && _editingGmAuthId!.isNotEmpty) return _editingGmAuthId;
    final String raw = _gmSearch.text.trim();
    if (raw.isEmpty) return null;
    for (final GmRosterEntry gm in _gmRoster) {
      if (gm.authId == raw || gm.username.toLowerCase() == raw.toLowerCase()) return gm.authId;
    }
    if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(raw)) return raw;
    return null;
  }

  void _subscribeChatReports() {
    if (!SupabaseService.isInitialized) return;
    _chatReportsChannel?.unsubscribe();
    _chatReportsChannel = SupabaseService.client
        .channel('staff_chat_reports_${SupabaseService.client.auth.currentUser?.id ?? 'anon'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_reports',
          callback: (_) {
            if (!mounted) return;
            unawaited(_loadChatReports());
            unawaited(ref.read(staffProvider.notifier).load(silent: true));
          },
        )
        .subscribe();
  }

  void _startChatReportsPoll() {
    _chatReportsPoll?.cancel();
    _chatReportsPoll = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted || _tabs.index != _chatTabIndex) return;
      unawaited(_loadChatReports());
    });
  }

  Future<void> _resolveChatReport(ChatReportEntry report, String action, {String? note, required String success}) async {
    if (_resolvingChatReportId != null) return;
    setState(() => _resolvingChatReportId = report.id);
    final String? err = await _staffRepo.resolveChatReport(report.id, action, note: note);
    if (!mounted) return;
    setState(() => _resolvingChatReportId = null);
    if (err != null) {
      AppMessenger.showError(context, err);
      return;
    }
    AppMessenger.showSuccess(context, success);
    await _loadChatReports();
    await ref.read(staffProvider.notifier).load(silent: true);
  }

  Future<void> _loadPermCatalog() async {
    final ({List<PermissionCatalogItem> items, String? error}) result =
        await _staffRepo.getPermissionCatalogResult();
    if (!mounted) return;
    setState(() {
      _permCatalog = result.items;
      _permCatalogError = result.error;
    });
  }

  Future<void> _loadGmRoster() async {
    final ({List<GmRosterEntry> items, String? error}) result = await _staffRepo.listActiveGmsResult();
    if (!mounted) return;
    if (result.error != null) {
      AppMessenger.showError(context, result.error!);
    }
    setState(() => _gmRoster = result.items);
  }

  Future<void> _loadChatReports() async {
    setState(() {
      _chatReportsLoading = true;
      _chatReportsError = null;
    });
    final ({List<ChatReportEntry> items, String? error}) result = await _staffRepo.listChatReportsResult(
      status: _chatReportStatusFilter,
      senderQuery: _chatReportSearch.text.trim().isEmpty ? null : _chatReportSearch.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _chatReportsLoading = false;
      _chatReportsError = result.error;
      _chatReports = result.items;
    });
  }

  Future<void> _loadTickets() async {
    setState(() {
      _ticketsLoading = true;
      _ticketsError = null;
    });
    final ({List<SupportTicketSummary> items, String? error}) result = await _staffRepo.listTicketsResult(
      status: _ticketStatusFilter,
      category: _ticketCategoryFilter,
      playerQuery: _ticketSearch.text.trim().isEmpty ? null : _ticketSearch.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _ticketsLoading = false;
      _ticketsError = result.error;
      _tickets = result.items;
    });
  }

  Future<void> _loadBugs() async {
    setState(() {
      _bugsLoading = true;
      _bugsError = null;
    });
    final ({List<BugReportSummary> items, String? error}) result = await _staffRepo.listBugReportsResult(
      status: _bugStatusFilter,
      playerQuery: _bugSearch.text.trim().isEmpty ? null : _bugSearch.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _bugsLoading = false;
      _bugsError = result.error;
      _bugs = result.items;
    });
  }

  Future<void> _searchPlayers() async {
    if (_playerSearch.text.trim().length < 2) {
      AppMessenger.showError(context, 'En az 2 karakter girin.');
      return;
    }
    setState(() {
      _playersSearching = true;
      _playersError = null;
    });
    final result = await _staffRepo.searchPlayersResult(
      _playerSearch.text.trim(),
      bannedFilter: _playerBanFilter,
    );
    if (!mounted) return;
    setState(() {
      _playersSearching = false;
      _playersHasSearched = true;
      _players = result.items;
      _playersError = result.error;
    });
  }

  Future<void> _searchGmPlayers() async {
    if (_gmSearch.text.trim().length < 2) {
      AppMessenger.showError(context, 'En az 2 karakter girin.');
      return;
    }
    final result = await _staffRepo.searchPlayersResult(_gmSearch.text.trim());
    if (!mounted) return;
    setState(() {
      _gmSearchResults = result.items
          .where((StaffPlayerBrief p) => p.staffBadge != 'admin')
          .toList(growable: false);
    });
    if (result.error != null) {
      AppMessenger.showError(context, result.error!);
    }
  }

  Future<void> _toggleGmPermission(String key, bool value) async {
    if (value) {
      PermissionCatalogItem? meta;
      for (final PermissionCatalogItem p in _permCatalog) {
        if (p.key == key) {
          meta = p;
          break;
        }
      }
      if (meta != null && meta.isDangerous) {
        final bool? ok = await showStaffConfirmDialog(
          context: context,
          title: 'Tehlikeli izin',
          message: '${meta.labelTr.isEmpty ? key : meta.labelTr}\n\nBu izni eklemek istiyor musunuz?',
          confirmLabel: 'Ekle',
          danger: true,
        );
        if (ok != true || !mounted) return;
      }
      setState(() => _selectedPerms.add(key));
    } else {
      setState(() => _selectedPerms.remove(key));
    }
  }

  Future<void> _resolveChatReportWithNote(ChatReportEntry report) async {
    final Map<String, String>? values = await showStaffFormDialog(
      context: context,
      title: 'Mesaj sil + mute',
      confirmLabel: 'Uygula',
      fields: const <StaffFormFieldSpec>[
        StaffFormFieldSpec(key: 'note', label: 'Moderasyon notu', initial: 'moderation', maxLines: 2),
      ],
    );
    if (values == null || !mounted) return;
    await _resolveChatReport(
      report,
      'action_taken',
      note: values['note']?.trim().isEmpty == true ? 'moderation' : values['note']!.trim(),
      success: 'Mesaj silindi, rapor kapatıldı',
    );
  }

  Widget _listErrorBanner(String? error, VoidCallback onRetry) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SettingsGlassCard(
        accent: SettingsPalette.ruby,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(error, style: supportCaptionStyle.copyWith(color: SettingsPalette.ruby)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Tekrar')),
          ],
        ),
      ),
    );
  }

  Future<void> _openPlayerDetail(StaffPlayerBrief p) async {
    final ({StaffPlayerDetail? player, String? error}) result = await _staffRepo.getPlayerDetailResult(p.authId);
    if (!mounted) return;
    if (result.error != null || result.player == null) {
      AppMessenger.showError(context, result.error ?? 'Detay yüklenemedi.');
      return;
    }
    final StaffPlayerDetail player = result.player!;
    await showStaffBottomSheet<void>(
      context: context,
      accent: SettingsPalette.neon,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StaffPlayerCard(player: player),
            const SizedBox(height: 14),
            StaffActionButton(
              label: 'Staff işlemleri',
              onPressed: () {
                Navigator.pop(context);
                showPlayerActionSheet(
                  context,
                  ref,
                  authId: p.authId,
                  username: p.username,
                  displayName: p.displayName ?? player.displayName,
                  staffBadge: player.staffBadge ?? p.staffBadge,
                  kingBadge: player.kingBadge,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBugDetail(BugReportSummary b) async {
    final BugReportDetail? detail = await ref.read(supportProvider.notifier).loadBugDetail(b.id);
    if (!mounted || detail == null) {
      AppMessenger.showError(context, 'Bug detayı yüklenemedi.');
      return;
    }
    await showStaffBottomSheet<void>(
      context: context,
      accent: StaffDesign.statusAccent(detail.status),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SettingsSectionHeader(
              icon: Icons.bug_report_rounded,
              title: detail.title,
              subtitle: '@${detail.username ?? '?'}',
              accent: SettingsPalette.coral,
            ),
            const SizedBox(height: 8),
            StaffStatusPill(status: detail.status),
            if (detail.suggestedGems != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Önerilen: ${detail.suggestedGems}💎',
                style: supportBodyStyle.copyWith(color: SettingsPalette.gold),
              ),
            ],
            const SizedBox(height: 12),
            SettingsGlassCard(
              accent: SettingsPalette.obsidian,
              child: Text(detail.description, style: supportBodyStyle),
            ),
            if (detail.reproSteps != null && detail.reproSteps!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('Adımlar: ${detail.reproSteps}', style: supportCaptionStyle),
            ],
            if (detail.followups.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('Ek mesajlar', style: supportBodyStyle.copyWith(fontWeight: FontWeight.w700)),
              ...detail.followups.map(
                (BugReportFollowup f) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SettingsGlassCard(
                    accent: f.isStaff ? SettingsPalette.gold : SettingsPalette.neon,
                    padding: const EdgeInsets.all(10),
                    child: Text(f.body, style: supportBodyStyle),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (ref.read(staffProvider).profile.has('bug.triage'))
              StaffActionButton(
                label: 'Triage',
                outlined: true,
                accent: SettingsPalette.gold,
                onPressed: () async {
                  final String? err = await ref.read(supportProvider.notifier).staffUpdateBug(detail.id, 'triaged');
                  if (!mounted) return;
                  if (err != null) {
                    AppMessenger.showError(context, err);
                    return;
                  }
                  Navigator.pop(context);
                  AppMessenger.showSuccess(context, 'Triage kaydedildi.');
                  await _loadBugs();
                  await _refreshDashboard();
                },
              ),
            if (ref.read(staffProvider).profile.has('bug.triage')) ...<Widget>[
              const SizedBox(height: 8),
              StaffActionButton(
                label: 'Bilgi iste',
                outlined: true,
                accent: SettingsPalette.titanium,
                onPressed: () async {
                  final Map<String, String>? values = await showStaffFormDialog(
                    context: context,
                    title: 'Ek bilgi iste',
                    confirmLabel: 'Gönder',
                    fields: <StaffFormFieldSpec>[
                      StaffFormFieldSpec(
                        key: 'note',
                        label: 'Oyuncuya not',
                        initial: 'Lütfen ekran görüntüsü veya tekrar adımları ekleyin.',
                        maxLines: 4,
                      ),
                    ],
                  );
                  if (values == null || !mounted) return;
                  final String? err = await ref.read(supportProvider.notifier).staffUpdateBug(
                        detail.id,
                        'needs_info',
                        note: values['note']?.trim(),
                      );
                  // #region agent log
                  StaffHubDebugLog.log(
                    'H5',
                    'staff_hub_screen.dart:bug_needs_info',
                    'needs_info_result',
                    data: <String, Object?>{'bugId': detail.id, 'err': err},
                  );
                  // #endregion
                  if (!mounted) return;
                  if (err != null) {
                    AppMessenger.showError(context, err);
                    return;
                  }
                  Navigator.pop(context);
                  AppMessenger.showSuccess(context, 'Bilgi talebi gönderildi.');
                  await _loadBugs();
                  await _refreshDashboard();
                },
              ),
            ],
            if (ref.read(staffProvider).profile.has('bug.triage')) ...<Widget>[
              const SizedBox(height: 8),
              StaffActionButton(
                label: 'Reddet',
                outlined: true,
                danger: true,
                onPressed: () async {
                  final String? err = await ref
                      .read(supportProvider.notifier)
                      .staffUpdateBug(detail.id, 'rejected', note: 'Reddedildi');
                  if (!mounted) return;
                  if (err != null) {
                    AppMessenger.showError(context, err);
                    return;
                  }
                  Navigator.pop(context);
                  AppMessenger.showSuccess(context, 'Bug reddedildi.');
                  await _loadBugs();
                  await _refreshDashboard();
                },
              ),
            ],
            if (ref.read(staffProvider).profile.has('bug.triage')) ...<Widget>[
              const SizedBox(height: 8),
              StaffActionButton(
                label: 'Elmas öner (100–5000)',
                accent: SettingsPalette.fuchsia,
                onPressed: () async {
                  final Map<String, String>? values = await showStaffFormDialog(
                    context: context,
                    title: 'Elmas öner',
                    confirmLabel: 'Öner',
                    fields: const <StaffFormFieldSpec>[
                      StaffFormFieldSpec(
                        key: 'gems',
                        label: 'Elmas (100–5000)',
                        initial: '100',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  );
                  if (values == null || !mounted) return;
                  final int amount = int.tryParse(values['gems'] ?? '') ?? 0;
                  if (amount < 100 || amount > 5000) {
                    AppMessenger.showError(context, 'Elmas 100–5000 arası olmalı.');
                    return;
                  }
                  final String? err = await _staffRepo.suggestBugReward(detail.id, amount);
                  if (!mounted) return;
                  if (err != null) {
                    AppMessenger.showError(context, err);
                    return;
                  }
                  Navigator.pop(context);
                  AppMessenger.showSuccess(context, 'Elmas önerisi kaydedildi.');
                  await _loadBugs();
                  await _refreshDashboard();
                },
              ),
            ],
            if (ref.read(staffProvider).profile.isAdmin) ...<Widget>[
              const SizedBox(height: 8),
              if (detail.suggestedGems == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Onay için önce GM elmas önerisi gerekli.',
                    style: supportCaptionStyle.copyWith(color: SettingsPalette.gold),
                  ),
                )
              else
                StaffActionButton(
                  label: 'Elmas onay kuyruğuna git (${detail.suggestedGems}💎)',
                  accent: SettingsPalette.gold,
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.staffGemRewards);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StaffState staff = ref.watch(staffProvider);
    // #region agent log
    StaffHubDebugLog.log(
      'H0',
      'staff_hub_screen.dart:build',
      'hub_build',
      data: <String, Object?>{
        'isStaff': staff.profile.isStaff,
        'isLoading': staff.isLoading,
        'tabIndex': _tabs.index,
      },
    );
    // #endregion
    if (!staff.profile.isStaff) {
      return const SupportScreenShell(
        title: 'Staff',
        body: Center(child: Text('Yetkisiz', style: TextStyle(color: SettingsPalette.textMid))),
      );
    }

    final StaffDashboard? dash = staff.dashboard;

    return SupportScreenShell(
      title: staff.profile.isAdmin ? 'ADMIN Hub' : 'GM Hub',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (staff.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SettingsGlassCard(
                accent: SettingsPalette.ruby,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(staff.error!, style: supportCaptionStyle.copyWith(color: SettingsPalette.ruby)),
                    ),
                    TextButton(
                      onPressed: () => unawaited(_refreshAll()),
                      child: const Text('Yenile'),
                    ),
                  ],
                ),
              ),
            ),
          StaffTabStrip(
            tabs: StaffDesign.hubTabs,
            selectedIndex: _tabs.index,
            accent: staff.profile.isAdmin ? SettingsPalette.gold : SettingsPalette.neon,
            onSelected: (int i) => _tabs.animateTo(i),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _dashboardTab(dash, staff.profile.isAdmin, staff.profile),
                _playersTab(staff),
                _ticketsTab(staff),
                _bugsTab(staff),
                _chatTab(staff),
                _auditTab(staff),
                _gmTab(staff),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardTab(StaffDashboard? dash, bool isAdmin, StaffProfile profile) {
    if (!profile.has('staff.view_hub')) {
      return ListView(
        padding: GameScrollLayout.padding(context),
        children: const <Widget>[
          StaffEmptyState(
            icon: Icons.lock_outline,
            message: 'Hub özeti için staff.view_hub gerekli. Diğer sekmelerden işlem yapabilirsiniz.',
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: SettingsPalette.gold,
      onRefresh: _refreshAll,
      child: ListView(
      padding: GameScrollLayout.padding(context),
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        StaffHeroBanner(
          isAdmin: isAdmin,
          openTickets: dash?.openTickets ?? 0,
          pendingBugs: dash?.pendingBugs ?? 0,
          openChatReports: dash?.openChatReports ?? 0,
        ),
        if (profile.isAdmin) ...<Widget>[
          const SizedBox(height: 12),
          SettingsGlassCard(
            accent: SettingsPalette.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SettingsSectionHeader(
                  icon: Icons.diamond_outlined,
                  title: 'Elmas Ödülü Onay Talepleri',
                  subtitle: 'GM önerisi → admin onayı · geçmiş kayıtlar',
                  accent: SettingsPalette.gold,
                ),
                const SizedBox(height: 8),
                StaffActionButton(
                  label: dash != null && dash.pendingGemRewards > 0
                      ? 'Onay kuyruğu (${dash.pendingGemRewards})'
                      : 'Onay kuyruğu',
                  accent: SettingsPalette.gold,
                  onPressed: () => context.push(AppRoutes.staffGemRewards),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SettingsGlassCard(
            accent: SettingsPalette.fuchsia,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SettingsSectionHeader(
                  icon: Icons.tune_rounded,
                  title: 'LiveOps',
                  subtitle: 'BP/GW tarih · gece pazarı aç/kapa · ödüller',
                  accent: SettingsPalette.fuchsia,
                ),
                const SizedBox(height: 8),
                StaffActionButton(
                  label: 'LiveOps konsolu',
                  accent: SettingsPalette.fuchsia,
                  onPressed: () => context.push(AppRoutes.staffLiveOps),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const SettingsSectionHeader(
          icon: Icons.history_rounded,
          title: 'Son işlemler',
          accent: SettingsPalette.titanium,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _dashboardAuditSearch,
                style: supportBodyStyle,
                decoration: supportInputDecoration(label: 'Staff / oyuncu ara', hint: 'kullanıcı adı'),
                onSubmitted: (_) => _openAuditTab(actorQuery: _dashboardAuditSearch.text.trim()),
              ),
            ),
            const SizedBox(width: 8),
            StaffActionButton(
              label: 'Audit',
              onPressed: () => _openAuditTab(actorQuery: _dashboardAuditSearch.text.trim()),
              accent: SettingsPalette.gold,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if ((dash?.recentAudit ?? const <StaffAuditBrief>[]).isEmpty)
          const StaffEmptyState(
            icon: Icons.inbox_outlined,
            message: 'Henüz audit kaydı yok.',
          )
        else
          ...(dash?.recentAudit ?? const <StaffAuditBrief>[]).map(
            (StaffAuditBrief a) => SupportListTileCard(
              title: StaffAuditLabels.actionTitle(a.action),
              subtitle: StaffAuditLabels.buildSubtitle(
                actorUsername: a.actorUsername,
                targetType: a.targetType,
                createdAt: a.createdAt,
              ),
              accent: SettingsPalette.gold,
              onTap: () => _openAuditTab(actorQuery: a.actorUsername),
            ),
          ),
      ],
      ),
    );
  }

  Widget _playersTab(StaffState staff) {
    if (!staff.profile.has('player.view_detail')) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: StaffEmptyState(icon: Icons.lock_outline, message: 'Oyuncu detay yetkisi yok.'),
        ),
      );
    }
    final List<StaffPlayerBrief> visible = _players;
    Widget? emptyChild;
    if (_playersError != null) {
      emptyChild = const SizedBox(height: 48);
    } else if (!_playersHasSearched && !_playersSearching) {
      emptyChild = const StaffEmptyState(
        icon: Icons.person_search_outlined,
        message: 'Aramak için en az 2 karakter yazın.',
      );
    } else if (visible.isEmpty && !_playersSearching) {
      emptyChild = const StaffEmptyState(icon: Icons.search_off_outlined, message: 'Oyuncu bulunamadı.');
    }

    return StaffScrollTab(
      accent: SettingsPalette.neon,
      onRefresh: _searchPlayers,
      header: <Widget>[
        StaffQueryToolbar(
          controller: _playerSearch,
          hint: 'Kullanıcı adı (min 2)',
          onSearch: _searchPlayers,
          filter: StaffFilterChipRow(
            options: const <String?>[null, 'active', 'banned'],
            labels: const <String?, String>{
              null: 'Tümü',
              'active': 'Aktif',
              'banned': 'Banlı',
            },
            selected: _playerBanFilter,
            onSelected: (String? v) {
              setState(() => _playerBanFilter = v);
              if (_playerSearch.text.trim().length >= 2) {
                unawaited(_searchPlayers());
              }
            },
            accent: SettingsPalette.neon,
          ),
        ),
        _listErrorBanner(_playersError, _searchPlayers),
        if (_playersSearching)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(color: SettingsPalette.neon, strokeWidth: 2)),
          ),
      ],
      itemCount: emptyChild == null ? visible.length : 0,
      itemBuilder: emptyChild == null
          ? (BuildContext context, int i) {
              final StaffPlayerBrief p = visible[i];
              return SupportListTileCard(
                title: p.displayName ?? p.username,
                subtitle: '@${p.username} · Lv${p.level ?? 0}${p.staffBadge != null ? ' · ${p.staffBadge!.toUpperCase()}' : ''}',
                accent: p.isBanned ? SettingsPalette.ruby : SettingsPalette.neon,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (p.isBanned)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.block, color: SettingsPalette.ruby, size: 18),
                      ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 18, color: Colors.white38),
                      tooltip: 'Detay',
                      onPressed: () => unawaited(_openPlayerDetail(p)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                onTap: () {
                  // #region agent log
                  StaffHubDebugLog.log(
                    'F1',
                    'staff_hub_screen.dart:_playersTab',
                    'player_tap_action_sheet',
                    data: <String, Object?>{'authIdLen': p.authId.length},
                  );
                  // #endregion
                  unawaited(openStaffPlayerActions(
                    context,
                    ref,
                    authId: p.authId,
                    username: p.username,
                    displayName: p.displayName,
                    staffBadge: p.staffBadge,
                  ));
                },
              );
            }
          : null,
      emptyChild: emptyChild,
    );
  }

  Widget _ticketsTab(StaffState staff) {
    if (!staff.profile.has('ticket.view_all')) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: StaffEmptyState(icon: Icons.lock_outline, message: 'Ticket görüntüleme yetkisi yok.'),
        ),
      );
    }
    Widget? emptyChild;
    if (_ticketsError != null) {
      emptyChild = const SizedBox(height: 48);
    } else if (_tickets.isEmpty && !_ticketsLoading) {
      emptyChild = const StaffEmptyState(icon: Icons.inbox_outlined, message: 'Ticket yok.');
    }

    return StaffScrollTab(
      accent: SettingsPalette.gold,
      onRefresh: _loadTickets,
      header: <Widget>[
        StaffQueryToolbar(
          controller: _ticketSearch,
          hint: 'Oyuncu / konu ara',
          onSearch: _loadTickets,
          filter: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              StaffFilterChipRow(
                options: const <String?>[null, 'open', 'staff_reply', 'waiting_player', 'resolved'],
                labels: const <String?, String>{
                  null: 'Tümü',
                  'open': 'Açık',
                  'staff_reply': 'Yanıtlandı',
                  'waiting_player': 'Oyuncu bekliyor',
                  'resolved': 'Kapalı',
                },
                selected: _ticketStatusFilter,
                onSelected: (String? v) {
                  setState(() => _ticketStatusFilter = v);
                  unawaited(_loadTickets());
                },
              ),
              StaffFilterChipRow(
                options: const <String?>[null, 'account', 'payment', 'abuse', 'bug', 'other'],
                labels: const <String?, String>{
                  null: 'Kategori: tümü',
                  'account': 'Hesap',
                  'payment': 'Ödeme',
                  'abuse': 'Kötüye kullanım',
                  'bug': 'Bug',
                  'other': 'Diğer',
                },
                selected: _ticketCategoryFilter,
                onSelected: (String? v) {
                  setState(() => _ticketCategoryFilter = v);
                  unawaited(_loadTickets());
                },
                accent: SettingsPalette.gold,
              ),
            ],
          ),
        ),
        _listErrorBanner(_ticketsError, _loadTickets),
        if (_ticketsLoading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(color: SettingsPalette.gold, strokeWidth: 2)),
          ),
      ],
      itemCount: emptyChild == null ? _tickets.length : 0,
      itemBuilder: emptyChild == null
          ? (BuildContext context, int i) {
              final SupportTicketSummary t = _tickets[i];
              return SupportListTileCard(
                title: t.subject,
                subtitle: '${t.username != null ? '@${t.username} · ' : ''}${t.category} · ${StaffAuditLabels.formatDateTime(t.updatedAt)}',
                accent: StaffDesign.statusAccent(t.status),
                trailing: StaffStatusPill(status: t.status),
                onTap: () => context.push('${AppRoutes.supportTickets}/${t.id}'),
              );
            }
          : null,
      emptyChild: emptyChild,
    );
  }

  Widget _bugsTab(StaffState staff) {
    if (!staff.profile.has('bug.view')) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: StaffEmptyState(icon: Icons.lock_outline, message: 'Bug görüntüleme yetkisi yok.'),
        ),
      );
    }
    Widget? emptyChild;
    if (_bugsError != null) {
      emptyChild = const SizedBox(height: 48);
    } else if (_bugs.isEmpty && !_bugsLoading) {
      emptyChild = const StaffEmptyState(icon: Icons.bug_report_outlined, message: 'Bekleyen bug yok.');
    }

    return StaffScrollTab(
      accent: SettingsPalette.gold,
      onRefresh: _loadBugs,
      header: <Widget>[
        StaffQueryToolbar(
          controller: _bugSearch,
          hint: 'Oyuncu / başlık ara',
          onSearch: _loadBugs,
          filter: StaffFilterChipRow(
            options: const <String?>[null, 'submitted', 'triaged', 'needs_info', 'approved', 'rejected'],
            labels: const <String?, String>{
              null: 'Tümü',
              'submitted': 'Yeni',
              'triaged': 'Triaged',
              'needs_info': 'Bilgi lazım',
              'approved': 'Onaylı',
              'rejected': 'Red',
            },
            selected: _bugStatusFilter,
            onSelected: (String? v) {
              setState(() => _bugStatusFilter = v);
              unawaited(_loadBugs());
            },
            accent: SettingsPalette.gold,
          ),
        ),
        _listErrorBanner(_bugsError, _loadBugs),
        if (_bugsLoading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(color: SettingsPalette.gold, strokeWidth: 2)),
          ),
      ],
      itemCount: emptyChild == null ? _bugs.length : 0,
      itemBuilder: emptyChild == null
          ? (BuildContext context, int i) {
              final BugReportSummary b = _bugs[i];
              return SupportListTileCard(
                title: b.title,
                subtitle: '${b.username != null ? '@${b.username} · ' : ''}${b.category} · ${StaffAuditLabels.formatDateTime(b.createdAt)}',
                accent: StaffDesign.statusAccent(b.status),
                trailing: StaffStatusPill(status: b.status),
                onTap: () => _openBugDetail(b),
              );
            }
          : null,
      emptyChild: emptyChild,
    );
  }

  Widget _chatTab(StaffState staff) {
    final bool canViewReports = staff.profile.has('chat.view_reports') || staff.profile.isAdmin;
    final bool canDeleteMessage = staff.profile.has('chat.delete_message') || staff.profile.isAdmin;
    if (canViewReports) {
      Widget? emptyChild;
      if (_chatReportsError != null) {
        emptyChild = const SizedBox(height: 48);
      } else if (_chatReports.isEmpty && !_chatReportsLoading) {
        emptyChild = const StaffEmptyState(icon: Icons.flag_outlined, message: 'Chat raporu yok.');
      }

      return StaffScrollTab(
        accent: SettingsPalette.fuchsia,
        onRefresh: _loadChatReports,
        header: <Widget>[
          StaffQueryToolbar(
            controller: _chatReportSearch,
            hint: 'Gönderen / raporlayan ara',
            onSearch: _loadChatReports,
            filter: StaffFilterChipRow(
              options: const <String?>[null, 'open', 'reviewed', 'action_taken', 'dismissed'],
              labels: const <String?, String>{
                null: 'Tümü',
                'open': 'Açık',
                'reviewed': 'İncelendi',
                'action_taken': 'İşlem yapıldı',
                'dismissed': 'Reddedildi',
              },
              selected: _chatReportStatusFilter,
              onSelected: (String? v) {
                setState(() => _chatReportStatusFilter = v);
                unawaited(_loadChatReports());
              },
              accent: SettingsPalette.fuchsia,
            ),
          ),
          _listErrorBanner(_chatReportsError, _loadChatReports),
          if (_chatReportsLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(color: SettingsPalette.fuchsia, strokeWidth: 2)),
            ),
        ],
        itemCount: emptyChild == null ? _chatReports.length : 0,
        itemBuilder: emptyChild == null
            ? (BuildContext context, int i) {
                final ChatReportEntry r = _chatReports[i];
                final bool busy = _resolvingChatReportId == r.id;
                return StaffChatReportCard(
                  sender: r.senderUsername ?? '?',
                  reporter: r.reporterUsername,
                  reason: r.reason,
                  preview: r.messagePreview ?? '',
                  busy: busy,
                  onReviewed: busy
                      ? null
                      : () => _resolveChatReport(r, 'reviewed', success: 'Rapor incelendi'),
                  onAction: !canDeleteMessage || busy
                      ? null
                      : () => _resolveChatReportWithNote(r),
                  onDismiss: busy
                      ? null
                      : () => _resolveChatReport(r, 'dismissed', success: 'Rapor reddedildi'),
                );
              }
            : null,
        emptyChild: emptyChild,
      );
    }
    final bool canMod = staff.profile.has('chat.manage_filters') ||
        staff.profile.has('chat.delete_message') ||
        staff.profile.isAdmin;
    if (!canMod) {
      return const Center(
        child: StaffEmptyState(icon: Icons.chat_bubble_outline, message: 'Chat moderasyon yetkisi yok.'),
      );
    }
    return RefreshIndicator(
      color: SettingsPalette.fuchsia,
      onRefresh: () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: GameScrollLayout.padding(context),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(24),
            child: SettingsGlassCard(
              accent: SettingsPalette.fuchsia,
              glow: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SettingsSectionHeader(
                    icon: Icons.chat_rounded,
                    title: 'Sohbet moderasyonu',
                    subtitle: 'Filtre ve mesaj silme chat ekranında',
                    accent: SettingsPalette.fuchsia,
                  ),
                  const SizedBox(height: 14),
                  StaffActionButton(
                    label: 'Sohbete git',
                    accent: SettingsPalette.fuchsia,
                    onPressed: () => context.push(AppRoutes.chat),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditTab(StaffState staff) {
    if (!staff.profile.has('staff.view_audit')) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: StaffEmptyState(icon: Icons.lock_outline, message: 'Audit görüntüleme yetkisi yok.'),
        ),
      );
    }

    final List<StaffAuditEntry> items = _auditItems ?? <StaffAuditEntry>[];
    Widget? emptyChild;
    if (_auditLoading && items.isEmpty) {
      emptyChild = const Center(child: CircularProgressIndicator(color: SettingsPalette.gold));
    } else if (_auditError != null) {
      emptyChild = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(_auditError!, style: supportBodyStyle.copyWith(color: SettingsPalette.ruby)),
          const SizedBox(height: 12),
          StaffActionButton(label: 'Tekrar dene', outlined: true, onPressed: _loadAudit),
        ],
      );
    } else if (items.isEmpty && !_auditLoading) {
      emptyChild = const StaffEmptyState(icon: Icons.history, message: 'Audit kaydı yok.');
    }

    final List<Widget> footer = <Widget>[
      if (_auditHasMore)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: StaffActionButton(
            label: _auditLoading ? 'Yükleniyor...' : 'Daha fazla yükle',
            outlined: true,
            onPressed: _auditLoading ? null : () => _loadAudit(append: true),
          ),
        ),
    ];

    return StaffScrollTab(
      accent: SettingsPalette.gold,
      onRefresh: _loadAudit,
      header: <Widget>[
        _auditToolbar(),
        if (items.isNotEmpty && emptyChild == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('${items.length} kayıt', style: supportCaptionStyle),
          ),
      ],
      itemCount: emptyChild == null ? items.length : 0,
      itemBuilder: emptyChild == null
          ? (BuildContext context, int i) {
              final StaffAuditEntry row = items[i];
              return StaffAuditExpansionTile(
                action: StaffAuditLabels.actionTitle(row.action, payload: row.payload),
                subtitle: StaffAuditLabels.buildSubtitle(
                  actorUsername: row.actorUsername,
                  actorRole: row.actorRole,
                  targetType: row.targetType,
                  targetId: row.targetId,
                  targetUsername: row.targetUsername,
                  createdAt: row.createdAt,
                  payload: row.payload,
                ),
                detailLines: StaffAuditLabels.detailLines(
                  action: row.action,
                  payload: row.payload,
                  result: row.result,
                  targetType: row.targetType,
                  targetId: row.targetId,
                  permissionKey: row.permissionKey,
                ),
                accent: row.actorRole == 'admin'
                    ? SettingsPalette.gold
                    : row.actorRole == 'gm'
                    ? SettingsPalette.neon
                    : SettingsPalette.titanium,
              );
            }
          : null,
      emptyChild: emptyChild,
      footer: footer,
    );
  }

  Widget _auditToolbar() {
    return StaffQueryToolbar(
      controller: _auditActorSearch,
      hint: 'Staff kullanıcı adı',
      secondaryController: _auditTargetSearch,
      secondaryHint: 'Hedef oyuncu adı',
      onSearch: _loadAudit,
      filter: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StaffFilterChipRow(
            options: const <String?>[null, 'admin', 'gm'],
            labels: const <String?, String>{null: 'Tüm staff', 'admin': 'Admin', 'gm': 'GM'},
            selected: _auditActorRoleFilter,
            onSelected: (String? v) {
              setState(() => _auditActorRoleFilter = v);
              unawaited(_loadAudit());
            },
            accent: SettingsPalette.gold,
          ),
          StaffFilterChipRow(
            options: const <String?>[null, 'user', 'ticket', 'bug_report', 'chat_report'],
            labels: const <String?, String>{
              null: 'Hedef: tümü',
              'user': 'Oyuncu',
              'ticket': 'Ticket',
              'bug_report': 'Bug',
              'chat_report': 'Chat',
            },
            selected: _auditTargetTypeFilter,
            onSelected: (String? v) {
              setState(() => _auditTargetTypeFilter = v);
              unawaited(_loadAudit());
            },
            accent: SettingsPalette.fuchsia,
          ),
          StaffFilterChipRow(
            options: StaffAuditLabels.auditActionFilterKeys,
            labels: Map<String?, String>.fromEntries(
              StaffAuditLabels.auditActionFilterKeys.map(
                (String? key) => MapEntry<String?, String>(key, StaffAuditLabels.auditActionFilterLabel(key)),
              ),
            ),
            selected: _auditActionFilter,
            onSelected: (String? v) {
              setState(() => _auditActionFilter = v);
              unawaited(_loadAudit());
            },
            accent: SettingsPalette.titanium,
          ),
        ],
      ),
    );
  }

  Widget _gmTab(StaffState staff) {
    if (!staff.profile.has('staff.manage_gm')) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: StaffEmptyState(icon: Icons.admin_panel_settings, message: 'Sadece ADMIN'),
        ),
      );
    }
    final Map<String, List<PermissionCatalogItem>> grouped = <String, List<PermissionCatalogItem>>{};
    for (final PermissionCatalogItem item in _permCatalog) {
      grouped.putIfAbsent(item.category, () => <PermissionCatalogItem>[]).add(item);
    }
    final String rosterQ = _gmRosterFilter.text.trim().toLowerCase();
    final List<GmRosterEntry> visibleGm = _gmRoster.where((GmRosterEntry gm) {
      if (rosterQ.isEmpty) return true;
      return gm.username.toLowerCase().contains(rosterQ);
    }).toList(growable: false);
    return ListView(
      padding: GameScrollLayout.padding(context, horizontal: 12, top: 12),
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const SettingsSectionHeader(
          icon: Icons.manage_accounts_rounded,
          title: 'GM yönetimi',
          subtitle: 'Roster · izin ata · kaydet',
          accent: SettingsPalette.gold,
        ),
        const SizedBox(height: 10),
        if (_permCatalogError != null) ...<Widget>[
          SettingsGlassCard(
            accent: SettingsPalette.ruby,
            child: Row(
              children: <Widget>[
                Expanded(child: Text(_permCatalogError!, style: supportCaptionStyle.copyWith(color: SettingsPalette.ruby))),
                TextButton(onPressed: _loadPermCatalog, child: const Text('Tekrar')),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _gmSearch,
          style: supportBodyStyle,
          decoration: supportInputDecoration(label: 'Yeni GM ara', hint: 'min 2 karakter'),
          onSubmitted: (_) => _searchGmPlayers(),
        ),
        const SizedBox(height: 8),
        StaffActionButton(label: 'Oyuncu ara', onPressed: _searchGmPlayers),
        if (_gmRoster.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: _gmRosterFilter,
            style: supportBodyStyle,
            decoration: supportInputDecoration(label: 'Aktif GM filtrele', hint: 'kullanıcı adı'),
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (_gmRoster.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Text('Aktif GM (${visibleGm.length})', style: AppTextStyles.captionBold.copyWith(color: SettingsPalette.textMid)),
          const SizedBox(height: 8),
          ...visibleGm.map(
            (GmRosterEntry gm) => StaffGmRosterTile(
              username: gm.username,
              permCount: gm.permissions.length,
              selected: _editingGmAuthId == gm.authId,
              onTap: () {
                setState(() {
                  _editingGmAuthId = gm.authId;
                  _selectedPerms
                    ..clear()
                    ..addAll(gm.permissions.where((String p) => p != 'staff.view_hub'));
                });
              },
              onSave: () async {
                if (_editingGmAuthId != gm.authId) {
                  AppMessenger.showError(context, 'Önce bu GM satırına dokunup seçin.');
                  return;
                }
                final String? err = await _staffRepo.setGmPermissions(gm.authId, _selectedPerms.toList());
                if (!mounted) return;
                if (err != null) {
                  AppMessenger.showError(context, err);
                } else {
                  AppMessenger.showSuccess(context, 'GM izinleri güncellendi.');
                  await _loadGmRoster();
                  await _refreshDashboard();
                }
              },
            ),
          ),
        ],
        if (_editingGmAuthId != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Düzenlenen: ${_gmRoster.where((GmRosterEntry g) => g.authId == _editingGmAuthId).map((GmRosterEntry g) => '@${g.username}').join(', ').isEmpty ? _editingGmAuthId! : _gmRoster.where((GmRosterEntry g) => g.authId == _editingGmAuthId).map((GmRosterEntry g) => '@${g.username}').first}',
            style: supportCaptionStyle.copyWith(color: SettingsPalette.gold),
          ),
        ],
        if (_selectedPerms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedPerms.map((String k) {
              return Chip(
                label: Text(k, style: supportCaptionStyle.copyWith(color: SettingsPalette.textHi)),
                backgroundColor: SettingsPalette.obsidian.withValues(alpha: 0.7),
                side: BorderSide(color: SettingsPalette.gold.withValues(alpha: 0.4)),
                deleteIconColor: SettingsPalette.gold,
                onDeleted: () => setState(() => _selectedPerms.remove(k)),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        ...grouped.entries.map((MapEntry<String, List<PermissionCatalogItem>> e) {
          final List<({String key, String label, bool dangerous})> items = e.value
              .where((PermissionCatalogItem p) => p.minRole == 'gm')
              .map(
                (PermissionCatalogItem p) => (
                  key: p.key,
                  label: p.labelTr.isEmpty ? p.key : p.labelTr,
                  dangerous: p.isDangerous,
                ),
              )
              .toList();
          if (items.isEmpty) return const SizedBox.shrink();
          return StaffPermissionGroup(
            category: e.key,
            items: items,
            selected: _selectedPerms,
            onToggle: _toggleGmPermission,
          );
        }),
        const SizedBox(height: 12),
        StaffActionButton(
          label: 'GM ata',
          accent: SettingsPalette.fuchsia,
          onPressed: () async {
            if (_gmSearchResults.isEmpty) await _searchGmPlayers();
            final StaffPlayerBrief? picked = await _pickPlayer(
              _gmSearchResults,
              emptyMessage: 'Önce kullanıcı arayın (min 2 karakter).',
            );
            if (picked == null || !mounted) return;
            final String? err = await _staffRepo.assignGm(picked.authId, _selectedPerms.toList());
            // #region agent log
            StaffHubDebugLog.log(
              'H1',
              'staff_hub_screen.dart:gm_assign',
              'assign_gm_result',
              data: <String, Object?>{'target': picked.username, 'err': err, 'permCount': _selectedPerms.length},
            );
            // #endregion
            if (!mounted) return;
            if (err != null) {
              AppMessenger.showError(context, err);
            } else {
              AppMessenger.showSuccess(context, '@${picked.username} GM atandı.');
              _editingGmAuthId = picked.authId;
              await _loadGmRoster();
              await _refreshDashboard();
            }
          },
        ),
        const SizedBox(height: 8),
        StaffActionButton(
          label: 'GM kaldır',
          outlined: true,
          danger: true,
          onPressed: () async {
            final String? target = _resolveGmAuthId();
            if (target == null) {
              AppMessenger.showError(context, 'GM seçin veya geçerli auth_id girin.');
              return;
            }
            final bool? ok = await showStaffConfirmDialog(
              context: context,
              title: 'GM kaldır',
              message: 'Bu kullanıcının GM yetkisi kaldırılacak.',
              confirmLabel: 'Kaldır',
              danger: true,
            );
            if (ok != true || !mounted) return;
            final String? err = await _staffRepo.revokeGm(target, 'admin revoke');
            if (!mounted) return;
            if (err != null) {
              AppMessenger.showError(context, err);
            } else {
              AppMessenger.showSuccess(context, 'GM kaldırıldı.');
              if (_editingGmAuthId == target) _editingGmAuthId = null;
              await _loadGmRoster();
              await _refreshDashboard();
            }
          },
        ),
        if (staff.profile.isAdmin) ...<Widget>[
          const SizedBox(height: 8),
          StaffActionButton(
            label: 'theking bootstrap',
            outlined: true,
            accent: SettingsPalette.gold,
            onPressed: () async {
              final String? err = await _staffRepo.ensureThekingAdmin();
              if (!mounted) return;
              if (err != null) {
                AppMessenger.showError(context, err);
              } else {
                AppMessenger.showSuccess(context, 'theking admin kontrol edildi.');
                await _refreshDashboard();
              }
            },
          ),
        ],
      ],
    );
  }
}
