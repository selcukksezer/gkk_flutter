import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/player/staff_inventory_editor.dart';
import '../../core/debug/staff_hub_debug_log.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/keyboard_dismiss.dart';
import '../../core/utils/staff_audit_labels.dart';
import '../../components/player/staff_player_card.dart';
import '../../models/staff_model.dart';
import '../../providers/staff_provider.dart';
import '../../repositories/staff_repository.dart';
import '../../screens/staff/widgets/staff_design.dart';
import '../../screens/support/widgets/support_design.dart';
import '../../theme/app_text_styles.dart';
import 'staff_badge.dart';

Future<void> showPlayerActionSheet(
  BuildContext context,
  WidgetRef ref, {
  required String authId,
  required String username,
  String? displayName,
  String? staffBadge,
  String? kingBadge,
}) async {
  await showStaffBottomSheet<void>(
    context: context,
    accent: SettingsPalette.fuchsia,
    child: _PlayerActionSheet(
      authId: authId,
      username: username,
      displayName: displayName,
      staffBadge: staffBadge,
      kingBadge: kingBadge,
    ),
  );
}

class _StaffActionItem {
  const _StaffActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = SettingsPalette.gold,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color accent;
  final bool danger;
}

/// cancelled=true → sessiz çık. error set → hata toast. ikisi de yok → başarı.
class _StaffRunOutcome {
  const _StaffRunOutcome.cancelled() : cancelled = true, error = null;
  const _StaffRunOutcome.ok() : cancelled = false, error = null;
  const _StaffRunOutcome.fail(this.error) : cancelled = false;

  final bool cancelled;
  final String? error;
}

class _PlayerActionSheet extends ConsumerStatefulWidget {
  const _PlayerActionSheet({
    required this.authId,
    required this.username,
    this.displayName,
    this.staffBadge,
    this.kingBadge,
  });

  final String authId;
  final String username;
  final String? displayName;
  final String? staffBadge;
  final String? kingBadge;

  @override
  ConsumerState<_PlayerActionSheet> createState() => _PlayerActionSheetState();
}

class _PlayerActionSheetState extends ConsumerState<_PlayerActionSheet> {
  final TextEditingController _reason = TextEditingController();
  final StaffRepository _staffRepo = StaffRepository();
  bool _busy = false;
  bool _loadingEnforcement = true;
  bool _loadingDetail = true;
  bool _detailLoadedOnce = false;
  bool _enforcementLoadedOnce = false;
  bool _enforcementFailed = false;
  bool _isProtectedAdmin = false;
  StaffPlayerDetail? _playerDetail;
  bool _historyExpanded = false;
  static const int _historyPreviewCount = 2;
  List<Map<String, dynamic>> _active = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _isProtectedAdmin = widget.staffBadge == 'admin';
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_bootstrap()));
  }

  Future<void> _bootstrap() async {
    await _ensureStaffProfile();
    await _loadAll();
  }

  Future<void> _ensureStaffProfile() async {
    final StaffState staff = ref.read(staffProvider);
    if (!staff.isLoading && staff.profile.isStaff) return;
    await ref.read(staffProvider.notifier).load(silent: true);
    if (mounted) setState(() {});
  }

  Future<void> _loadAll({bool silent = false}) async {
    await Future.wait(<Future<void>>[
      _loadDetail(silent: silent || _detailLoadedOnce),
      _loadEnforcement(silent: silent || _enforcementLoadedOnce),
    ]);
  }

  Future<void> _loadDetail({bool silent = false}) async {
    if (!silent) setState(() => _loadingDetail = true);
    final result = await _staffRepo.getPlayerDetailResult(widget.authId);
    if (!mounted) return;
    setState(() {
      _loadingDetail = false;
      _detailLoadedOnce = true;
      if (result.player != null) {
        _playerDetail = result.player;
        _isProtectedAdmin = result.player!.isProtectedAdmin || widget.staffBadge == 'admin';
      }
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadEnforcement({bool silent = false}) async {
    if (!silent) setState(() => _loadingEnforcement = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'staff_get_player_enforcement',
        params: <String, dynamic>{'p_target_user_id': widget.authId},
      );
      if (!mounted) return;
      if (raw is Map && raw['success'] == true) {
        setState(() {
          _active = _parseList(raw['active']);
          _history = _parseList(raw['history']);
          _isProtectedAdmin =
              raw['is_protected_admin'] == true || widget.staffBadge == 'admin';
          _loadingEnforcement = false;
          _enforcementLoadedOnce = true;
          _enforcementFailed = false;
        });
      } else {
        setState(() {
          _loadingEnforcement = false;
          _enforcementLoadedOnce = true;
          _enforcementFailed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingEnforcement = false;
          _enforcementLoadedOnce = true;
          _enforcementFailed = true;
        });
      }
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map m) => Map<String, dynamic>.from(m))
        .toList(growable: false);
  }

  String _formatUntil(dynamic raw) => StaffAuditLabels.formatUntil(raw);

  String _historyLabel(Map<String, dynamic> row) => StaffAuditLabels.historyLine(row);

  Future<void> _run(Future<_StaffRunOutcome> Function() action, String success) async {
    setState(() => _busy = true);
    final _StaffRunOutcome outcome = await action();
    if (!mounted) return;
    if (outcome.cancelled) {
      setState(() => _busy = false);
      return;
    }
    if (outcome.error != null) {
      setState(() => _busy = false);
      AppMessenger.showError(context, outcome.error!);
      return;
    }
    await _loadAll(silent: true);
    if (!mounted) return;
    setState(() => _busy = false);
    AppMessenger.showSuccess(context, success);
  }

  Future<String?> _rpc(String fn, Map<String, dynamic> params) async {
    try {
      final dynamic raw = await SupabaseService.client.rpc(fn, params: params);
      if (raw is Map && raw['success'] == false) return raw['error']?.toString();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<_StaffRunOutcome> _rpcOk(String fn, Map<String, dynamic> params) async {
    final String? err = await _rpc(fn, params);
    if (err != null) return _StaffRunOutcome.fail(err);
    return const _StaffRunOutcome.ok();
  }

  Future<bool> _confirmDangerous(String title) async {
    return await showStaffConfirmDialog(
          context: context,
          title: title,
          message: '@${widget.username} — emin misiniz?\nSebep: ${_reason.text.trim()}',
          confirmLabel: 'Onayla',
          danger: true,
        ) ==
        true;
  }

  Future<StaffDurationPick?> _pickDuration({
    required String title,
    bool allowPermanent = false,
  }) {
    return showStaffDurationPicker(
      context: context,
      title: title,
      allowPermanent: allowPermanent,
    );
  }

  Future<_StaffRunOutcome> _ban() async {
    if (_reason.text.trim().length < 3) {
      return const _StaffRunOutcome.fail('Sebep gerekli (min 3 karakter).');
    }
    final StaffDurationPick? pick = await _pickDuration(title: 'Ban süresi', allowPermanent: true);
    if (pick == null) return const _StaffRunOutcome.cancelled();
    if (!await _confirmDangerous('Hesap ban')) return const _StaffRunOutcome.cancelled();
    final Map<String, dynamic> params = <String, dynamic>{
      'p_target_user_id': widget.authId,
      'p_reason': _reason.text.trim(),
    };
    if (pick.until != null) {
      params['p_until'] = pick.until!.toIso8601String();
    }
    return _rpcOk('staff_ban_player', params);
  }

  Future<_StaffRunOutcome> _unban() async {
    return _rpcOk('staff_unban_player', <String, dynamic>{
      'p_target_user_id': widget.authId,
      'p_note': _reason.text.trim(),
    });
  }

  Future<_StaffRunOutcome> _liftRestriction(String key) async {
    return _rpcOk('staff_clear_restriction', <String, dynamic>{
      'p_target_user_id': widget.authId,
      'p_restriction': key,
      'p_note': _reason.text.trim().isEmpty ? 'Kısıt kaldırıldı' : _reason.text.trim(),
    });
  }

  Future<_StaffRunOutcome> _rename() async {
    final Map<String, String>? values = await showStaffFormDialog(
      context: context,
      title: 'İsim değiştir',
      fields: <StaffFormFieldSpec>[
        StaffFormFieldSpec(
          key: 'name',
          label: 'Görünen ad',
          initial: widget.displayName ?? widget.username,
        ),
      ],
    );
    if (values == null) return const _StaffRunOutcome.cancelled();
    final String name = values['name'] ?? '';
    if (name.length < 3) return const _StaffRunOutcome.fail('Geçersiz isim.');
    return _rpcOk('staff_rename_player', <String, dynamic>{
      'p_target_user_id': widget.authId,
      'p_display_name': name,
      'p_reason': _reason.text.trim().isEmpty ? 'Staff rename' : _reason.text.trim(),
    });
  }

  Future<_StaffRunOutcome> _adjustStat(String stat, {required bool deduct}) async {
    if (_reason.text.trim().length < 3) {
      return const _StaffRunOutcome.fail('Sebep gerekli.');
    }
    final String title = switch ((stat, deduct)) {
      ('energy', true) => 'Enerji eksilt',
      ('energy', false) => 'Enerji ver',
      ('xp', true) => 'XP eksilt',
      ('xp', false) => 'XP ver',
      ('reputation', true) => 'İtibar eksilt',
      ('reputation', false) => 'İtibar ver',
      ('health', true) => 'Can eksilt',
      ('health', false) => 'Can ver',
      _ => 'Stat düzenle',
    };
    final Map<String, String>? values = await showStaffFormDialog(
      context: context,
      title: title,
      fields: <StaffFormFieldSpec>[
        StaffFormFieldSpec(
          key: 'amount',
          label: 'Miktar',
          initial: stat == 'xp' ? '500' : '10',
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null) return const _StaffRunOutcome.cancelled();
    final int amount = int.tryParse(values['amount'] ?? '') ?? 0;
    if (amount <= 0) return const _StaffRunOutcome.fail('Geçerli miktar gir.');
    if (!await _confirmDangerous(title)) return const _StaffRunOutcome.cancelled();
    final String? err = await _staffRepo.adjustPlayerStat(
      widget.authId,
      stat,
      deduct ? -amount : amount,
      reason: _reason.text.trim(),
    );
    if (err != null) return _StaffRunOutcome.fail(err);
    return const _StaffRunOutcome.ok();
  }

  Future<_StaffRunOutcome> _adjustCurrency(String currency, {required bool deduct}) async {
    if (_reason.text.trim().length < 3) {
      return const _StaffRunOutcome.fail('Sebep gerekli.');
    }
    final String title = switch ((currency, deduct)) {
      ('gems', true) => 'Elmas eksilt',
      ('gems', false) => 'Elmas ver',
      (_, true) => 'Altın eksilt',
      (_, false) => 'Altın ver',
    };
    final Map<String, String>? values = await showStaffFormDialog(
      context: context,
      title: title,
      fields: <StaffFormFieldSpec>[
        StaffFormFieldSpec(
          key: 'amount',
          label: 'Miktar',
          initial: currency == 'gems' ? '50' : '1000',
          keyboardType: TextInputType.number,
        ),
      ],
    );
    if (values == null) return const _StaffRunOutcome.cancelled();
    final int amount = int.tryParse(values['amount'] ?? '') ?? 0;
    if (amount <= 0) return const _StaffRunOutcome.fail('Geçerli miktar gir.');
    if (!deduct && currency == 'gems' && !await _confirmDangerous('Elmas ver')) {
      return const _StaffRunOutcome.cancelled();
    }
    if (deduct && !await _confirmDangerous(title)) {
      return const _StaffRunOutcome.cancelled();
    }
    return _rpcOk(
      deduct ? 'staff_deduct_currency' : 'staff_grant_currency',
      <String, dynamic>{
        'p_target_user_id': widget.authId,
        'p_currency': currency,
        'p_amount': amount,
        'p_reason': _reason.text.trim(),
      },
    );
  }

  Future<_StaffRunOutcome> _setRestriction(String restriction, String title) async {
    if (_reason.text.trim().length < 3) {
      return const _StaffRunOutcome.fail('Sebep gerekli.');
    }
    final StaffDurationPick? pick = await _pickDuration(title: title);
    if (pick == null) return const _StaffRunOutcome.cancelled();
    final DateTime? until = pick.until;
    if (until == null) return const _StaffRunOutcome.fail('Geçersiz süre.');
    return _rpcOk('staff_set_restriction', <String, dynamic>{
      'p_target_user_id': widget.authId,
      'p_restriction': restriction,
      'p_until': until.toIso8601String(),
      'p_reason': _reason.text.trim(),
    });
  }

  DateTime? _restrictionUntil(String restriction) {
    final StaffPlayerDetail? detail = _playerDetail;
    if (detail == null) return null;
    return switch (restriction) {
      'hospital' => detail.hospitalUntil,
      'prison' => detail.prisonUntil,
      _ => null,
    };
  }

  Future<Duration?> _pickDurationDelta(String title) async {
    final StaffDurationPick? pick = await _pickDuration(title: title);
    if (pick == null || pick.until == null) return null;
    final DateTime now = DateTime.now().toUtc();
    final Duration delta = pick.until!.toUtc().difference(now);
    if (delta.inMinutes <= 0) {
      return null;
    }
    return delta;
  }

  Future<_StaffRunOutcome> _adjustRestrictionDuration(
    String restriction, {
    required bool extend,
  }) async {
    if (_reason.text.trim().length < 3) {
      return const _StaffRunOutcome.fail('Sebep gerekli.');
    }
    final DateTime? current = _restrictionUntil(restriction);
    if (current == null || !current.isAfter(DateTime.now())) {
      return const _StaffRunOutcome.fail('Aktif kısıt bulunamadı.');
    }
    final String title = extend ? 'Eklenecek süre' : 'Kısaltılacak süre';
    final Duration? delta = await _pickDurationDelta(title);
    if (delta == null) return const _StaffRunOutcome.cancelled();

    final DateTime now = DateTime.now().toUtc();
    final DateTime currentUtc = current.toUtc();
    if (extend) {
      final DateTime base = currentUtc.isAfter(now) ? currentUtc : now;
      final DateTime newUntil = base.add(delta);
      return _rpcOk('staff_set_restriction', <String, dynamic>{
        'p_target_user_id': widget.authId,
        'p_restriction': restriction,
        'p_until': newUntil.toIso8601String(),
        'p_reason': _reason.text.trim(),
      });
    }

    final DateTime newUntil = currentUtc.subtract(delta);
    if (!newUntil.isAfter(now)) {
      return _liftRestriction(restriction);
    }
    return _rpcOk('staff_set_restriction', <String, dynamic>{
      'p_target_user_id': widget.authId,
      'p_restriction': restriction,
      'p_until': newUntil.toIso8601String(),
      'p_reason': _reason.text.trim(),
    });
  }

  void _addHospitalPrisonActions(
    List<_StaffActionItem> items,
    StaffState staff, {
    required String permission,
    required String restriction,
    required IconData sendIcon,
    required String sendLabel,
    required String extendLabel,
    required String shortenLabel,
    required String releaseLabel,
    required String sendSuccess,
    required String extendSuccess,
    required String shortenSuccess,
    required String releaseSuccess,
    required String durationTitle,
    required bool inRestriction,
  }) {
    if (!staff.profile.has(permission)) return;
    final bool ready = _restrictionActionsReady && !_isProtectedAdmin;
    items.add(
      _StaffActionItem(
        icon: sendIcon,
        label: sendLabel,
        accent: SettingsPalette.coral,
        onTap: ready && !inRestriction
            ? () => _run(() => _setRestriction(restriction, durationTitle), sendSuccess)
            : null,
      ),
    );
    items.add(
      _StaffActionItem(
        icon: Icons.add_alarm_rounded,
        label: extendLabel,
        accent: SettingsPalette.coral,
        onTap: ready && inRestriction
            ? () => _run(() => _adjustRestrictionDuration(restriction, extend: true), extendSuccess)
            : null,
      ),
    );
    items.add(
      _StaffActionItem(
        icon: Icons.timer_off_outlined,
        label: shortenLabel,
        accent: SettingsPalette.coral,
        onTap: ready && inRestriction
            ? () => _run(() => _adjustRestrictionDuration(restriction, extend: false), shortenSuccess)
            : null,
      ),
    );
    items.add(
      _StaffActionItem(
        icon: Icons.exit_to_app_rounded,
        label: releaseLabel,
        accent: SettingsPalette.neon,
        onTap: ready && inRestriction
            ? () => _run(() => _liftRestriction(restriction), releaseSuccess)
            : null,
      ),
    );
  }

  Future<String?> _openInventoryEditor() async {
    if (_reason.text.trim().length < 3) return 'Sebep gerekli (min 3 karakter).';
    final bool changed = await showStaffInventoryEditor(
      context: context,
      authId: widget.authId,
      username: widget.username,
      reason: _reason.text.trim(),
    );
    if (changed) await _loadAll(silent: true);
    return null;
  }

  bool _hasActiveRestriction(String key) =>
      _active.any((Map<String, dynamic> row) => row['key']?.toString() == key);

  bool _canLift(String key, StaffState staff) {
    switch (key) {
      case 'account_ban':
        return staff.profile.has('player.unban');
      case 'chat':
        return staff.profile.has('player.chat_mute');
      case 'hospital':
        return staff.profile.has('player.restrict_hospital');
      case 'prison':
        return staff.profile.has('player.restrict_prison');
      case 'trade':
        return staff.profile.has('player.restrict_trade');
      default:
        return false;
    }
  }

  Widget _actionCell(_StaffActionItem item) {
    final Color c = item.danger ? SettingsPalette.ruby : item.accent;
    final bool disabled = _busy || item.onTap == null;
    return Opacity(
      opacity: disabled ? 0.38 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : item.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SettingsGlassCard(
                  accent: c,
                  padding: const EdgeInsets.all(10),
                  child: Icon(item.icon, color: c, size: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  item.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.micro.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionGrid(List<_StaffActionItem> items, double maxWidth) {
    if (items.isEmpty) return const SizedBox.shrink();
    const int cols = 4;
    const double gap = 8;
    final double cellWidth = maxWidth > 0 ? (maxWidth - gap * (cols - 1)) / cols : 72;
    // #region agent log
    StaffHubDebugLog.log(
      'H1',
      'player_action_sheet.dart:_actionGrid',
      'action_grid_layout',
      data: <String, Object?>{'maxWidth': maxWidth, 'cellWidth': cellWidth, 'itemCount': items.length},
    );
    // #endregion
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: <Widget>[
        for (final _StaffActionItem item in items)
          SizedBox(width: cellWidth, child: _actionCell(item)),
      ],
    );
  }

  Widget _historySection() {
    if (_enforcementFailed) {
      return Text(
        'İşlem geçmişi yüklenemedi.',
        style: supportCaptionStyle.copyWith(color: SettingsPalette.coral),
      );
    }
    if (_history.isEmpty) {
      return Text('Kayıt yok.', style: supportCaptionStyle);
    }

    final bool canExpand = _history.length > _historyPreviewCount;
    final Iterable<Map<String, dynamic>> visible = _historyExpanded || !canExpand
        ? _history
        : _history.take(_historyPreviewCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (canExpand)
          InkWell(
            onTap: () => setState(() => _historyExpanded = !_historyExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'İşlem geçmişi${_historyExpanded ? '' : ' · ${_history.length} kayıt'}',
                      style: AppTextStyles.caption.copyWith(color: SettingsPalette.gold),
                    ),
                  ),
                  Icon(
                    _historyExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: SettingsPalette.gold,
                    size: 22,
                  ),
                ],
              ),
            ),
          )
        else
          Text(
            'İşlem geçmişi · ${_history.length} kayıt',
            style: AppTextStyles.caption.copyWith(color: SettingsPalette.gold),
          ),
        const SizedBox(height: 8),
        ...visible.map((Map<String, dynamic> row) {
          final String actor = row['actor_username']?.toString() ?? 'staff';
          final String when = _formatUntil(row['created_at']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SettingsGlassCard(
              accent: SettingsPalette.obsidian,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_historyLabel(row), style: supportBodyStyle.copyWith(fontSize: 12)),
                  Text('@$actor · $when', style: supportCaptionStyle.copyWith(fontSize: 10)),
                ],
              ),
            ),
          );
        }),
        if (canExpand && !_historyExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+ ${_history.length - _historyPreviewCount} kayıt daha',
              style: supportCaptionStyle.copyWith(color: SettingsPalette.gold),
            ),
          ),
      ],
    );
  }

  Widget _enforcementSection(StaffState staff) {
    if (_loadingEnforcement) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(color: SettingsPalette.gold, strokeWidth: 2)),
      );
    }

    if (_enforcementFailed) {
      return Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Kısıt bilgisi yüklenemedi.',
              style: supportCaptionStyle.copyWith(color: SettingsPalette.coral),
            ),
          ),
          StaffActionButton(
            label: 'Tekrar Dene',
            outlined: true,
            accent: SettingsPalette.gold,
            onPressed: () => _loadEnforcement(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Aktif kısıtlar', style: AppTextStyles.caption.copyWith(color: SettingsPalette.gold)),
        const SizedBox(height: 8),
        if (_active.isEmpty)
          Text('Aktif kısıt yok.', style: supportCaptionStyle)
        else
          ..._active.map((Map<String, dynamic> row) {
            final String key = row['key']?.toString() ?? '';
            final String label = row['label']?.toString() ?? key;
            final String until = _formatUntil(row['until']);
            final String? reason = row['reason']?.toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SettingsGlassCard(
                accent: SettingsPalette.coral,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: AppTextStyles.bodyBold.copyWith(color: SettingsPalette.textHi, fontSize: 13)),
                    Text('Süre: $until', style: supportCaptionStyle),
                    if (reason != null && reason.isNotEmpty)
                      Text('Sebep: $reason', style: supportCaptionStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (_canLift(key, staff) && !_isProtectedAdmin) ...<Widget>[
                      const SizedBox(height: 8),
                      StaffActionButton(
                        label: 'Kaldır',
                        outlined: true,
                        accent: SettingsPalette.neon,
                        onPressed: _busy
                            ? null
                            : () => _run(() => _liftRestriction(key), '$label kaldırıldı.'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _staffActionsSection(
    List<_StaffActionItem> actionItems, {
    required bool hasStaffActions,
    required double contentWidth,
  }) {
    if (!hasStaffActions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _actionGrid(actionItems, contentWidth),
          if (!_isProtectedAdmin)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Staff işlemi için yetkiniz yok.', style: supportCaptionStyle),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _reason,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          onEditingComplete: dismissKeyboard,
          style: supportBodyStyle,
          decoration: supportInputDecoration(label: 'Sebep / not'),
        ),
        const SizedBox(height: 12),
        Text('İşlemler', style: AppTextStyles.caption.copyWith(color: SettingsPalette.gold)),
        const SizedBox(height: 8),
        _actionGrid(actionItems, contentWidth),
      ],
    );
  }

  bool get _isAccountBanned =>
      (_playerDetail?.isAccountBanned ?? false) || _hasActiveRestriction('account_ban');

  bool get _banActionsReady => _detailLoadedOnce && !_loadingDetail;

  bool get _restrictionActionsReady => _banActionsReady && !_busy;

  bool get _inHospital => (_playerDetail?.inHospital ?? false) || _hasActiveRestriction('hospital');

  bool get _inPrison => (_playerDetail?.inPrison ?? false) || _hasActiveRestriction('prison');

  VoidCallback? _restrictionQuickAction(
    StaffState staff,
    String restriction, {
    bool extend = false,
    bool release = false,
  }) {
    if (_isProtectedAdmin || !_restrictionActionsReady) return null;
    if (!_canLift(restriction, staff)) return null;
    final bool active = switch (restriction) {
      'hospital' => _inHospital,
      'prison' => _inPrison,
      _ => false,
    };
    if (!active) return null;
    if (release) {
      return () => _run(
            () => _liftRestriction(restriction),
            restriction == 'hospital' ? 'Hastaneden çıkarıldı.' : 'Hapishaneden çıkarıldı.',
          );
    }
    return () => _run(
          () => _adjustRestrictionDuration(restriction, extend: extend),
          extend
              ? (restriction == 'hospital' ? 'Hastane süresi uzatıldı.' : 'Hapishane süresi uzatıldı.')
              : (restriction == 'hospital' ? 'Hastane süresi kısaltıldı.' : 'Hapishane süresi kısaltıldı.'),
        );
  }

  List<_StaffActionItem> _buildActionItems(StaffState staff) {
    if (_isProtectedAdmin) {
      return <_StaffActionItem>[
        _StaffActionItem(
          icon: Icons.copy_rounded,
          label: 'Kopyala',
          accent: SettingsPalette.titanium,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: widget.username));
            if (context.mounted) AppMessenger.showSuccess(context, 'Kopyalandı');
          },
        ),
      ];
    }

    final List<_StaffActionItem> items = <_StaffActionItem>[
      _StaffActionItem(
        icon: Icons.copy_rounded,
        label: 'Kopyala',
        accent: SettingsPalette.titanium,
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: widget.username));
          if (context.mounted) AppMessenger.showSuccess(context, 'Kopyalandı');
        },
      ),
    ];

    if (staff.profile.has('player.rename')) {
      items.add(
        _StaffActionItem(
          icon: Icons.edit_rounded,
          label: 'İsim',
          onTap: () => _run(_rename, 'İsim güncellendi.'),
        ),
      );
    }
    if (staff.profile.has('player.grant_gold')) {
      items.add(
        _StaffActionItem(
          icon: Icons.add_circle_outline_rounded,
          label: 'Altın ver',
          accent: SettingsPalette.gold,
          onTap: () => _run(() => _adjustCurrency('gold', deduct: false), 'Altın verildi.'),
        ),
      );
    }
    if (staff.profile.has('player.deduct_gold')) {
      items.add(
        _StaffActionItem(
          icon: Icons.remove_circle_outline_rounded,
          label: 'Altın eksilt',
          accent: SettingsPalette.gold,
          danger: true,
          onTap: () => _run(() => _adjustCurrency('gold', deduct: true), 'Altın düşürüldü.'),
        ),
      );
    }
    if (staff.profile.has('player.grant_gems')) {
      items.add(
        _StaffActionItem(
          icon: Icons.diamond_outlined,
          label: 'Elmas ver',
          accent: SettingsPalette.fuchsia,
          onTap: () => _run(() => _adjustCurrency('gems', deduct: false), 'Elmas verildi.'),
        ),
      );
    }
    if (staff.profile.has('player.deduct_gems')) {
      items.add(
        _StaffActionItem(
          icon: Icons.diamond_rounded,
          label: 'Elmas eksilt',
          accent: SettingsPalette.fuchsia,
          danger: true,
          onTap: () => _run(() => _adjustCurrency('gems', deduct: true), 'Elmas düşürüldü.'),
        ),
      );
    }
    if (staff.profile.has('player.adjust_energy')) {
      items.add(
        _StaffActionItem(
          icon: Icons.bolt_rounded,
          label: 'Enerji ver',
          accent: SettingsPalette.coral,
          onTap: () => _run(() => _adjustStat('energy', deduct: false), 'Enerji verildi.'),
        ),
      );
      items.add(
        _StaffActionItem(
          icon: Icons.bolt_outlined,
          label: 'Enerji eksilt',
          accent: SettingsPalette.coral,
          danger: true,
          onTap: () => _run(() => _adjustStat('energy', deduct: true), 'Enerji düşürüldü.'),
        ),
      );
    }
    if (staff.profile.has('player.adjust_xp')) {
      items.add(
        _StaffActionItem(
          icon: Icons.trending_up_rounded,
          label: 'XP ver',
          accent: SettingsPalette.titanium,
          onTap: () => _run(() => _adjustStat('xp', deduct: false), 'XP verildi.'),
        ),
      );
      items.add(
        _StaffActionItem(
          icon: Icons.trending_down_rounded,
          label: 'XP eksilt',
          accent: SettingsPalette.titanium,
          danger: true,
          onTap: () => _run(() => _adjustStat('xp', deduct: true), 'XP düşürüldü.'),
        ),
      );
    }
    if (staff.profile.has('player.adjust_reputation')) {
      items.add(
        _StaffActionItem(
          icon: Icons.military_tech_outlined,
          label: 'İtibar ver',
          accent: SettingsPalette.neon,
          onTap: () => _run(() => _adjustStat('reputation', deduct: false), 'İtibar verildi.'),
        ),
      );
      items.add(
        _StaffActionItem(
          icon: Icons.military_tech_rounded,
          label: 'İtibar eksilt',
          accent: SettingsPalette.neon,
          danger: true,
          onTap: () => _run(() => _adjustStat('reputation', deduct: true), 'İtibar düşürüldü.'),
        ),
      );
    }
    if (staff.profile.has('player.adjust_health')) {
      items.add(
        _StaffActionItem(
          icon: Icons.favorite_border_rounded,
          label: 'Can ver',
          accent: SettingsPalette.ruby,
          onTap: () => _run(() => _adjustStat('health', deduct: false), 'Can verildi.'),
        ),
      );
      items.add(
        _StaffActionItem(
          icon: Icons.heart_broken_rounded,
          label: 'Can eksilt',
          accent: SettingsPalette.ruby,
          danger: true,
          onTap: () => _run(() => _adjustStat('health', deduct: true), 'Can düşürüldü.'),
        ),
      );
    }
    if (staff.profile.has('player.adjust_inventory')) {
      items.add(
        _StaffActionItem(
          icon: Icons.inventory_2_rounded,
          label: 'Envanter',
          onTap: _busy
              ? null
              : () async {
                  final String? err = await _openInventoryEditor();
                  if (!mounted) return;
                  if (err != null) AppMessenger.showError(context, err);
                },
        ),
      );
    }
    _addHospitalPrisonActions(
      items,
      staff,
      permission: 'player.restrict_hospital',
      restriction: 'hospital',
      sendIcon: Icons.local_hospital_rounded,
      sendLabel: 'Hastane gönder',
      extendLabel: 'Hast +süre',
      shortenLabel: 'Hast -süre',
      releaseLabel: 'Hast. çıkar',
      sendSuccess: 'Hastaneye gönderildi.',
      extendSuccess: 'Hastane süresi uzatıldı.',
      shortenSuccess: 'Hastane süresi kısaltıldı.',
      releaseSuccess: 'Hastaneden çıkarıldı.',
      durationTitle: 'Hastane süresi',
      inRestriction: _inHospital,
    );
    _addHospitalPrisonActions(
      items,
      staff,
      permission: 'player.restrict_prison',
      restriction: 'prison',
      sendIcon: Icons.gavel_rounded,
      sendLabel: 'Hapishane gönder',
      extendLabel: 'Hap +süre',
      shortenLabel: 'Hap -süre',
      releaseLabel: 'Hap. çıkar',
      sendSuccess: 'Hapishaneye gönderildi.',
      extendSuccess: 'Hapishane süresi uzatıldı.',
      shortenSuccess: 'Hapishane süresi kısaltıldı.',
      releaseSuccess: 'Hapishaneden çıkarıldı.',
      durationTitle: 'Hapishane süresi',
      inRestriction: _inPrison,
    );
    if (staff.profile.has('player.restrict_trade')) {
      items.add(
        _StaffActionItem(
          icon: Icons.block_flipped,
          label: 'Ticaret',
          accent: SettingsPalette.coral,
          onTap: () => _run(() => _setRestriction('trade', 'Ticaret yasağı süresi'), 'Kısıt uygulandı.'),
        ),
      );
    }
    if (staff.profile.has('player.chat_mute')) {
      items.add(
        _StaffActionItem(
          icon: Icons.volume_off_rounded,
          label: 'Chat mute',
          onTap: () => _run(() => _setRestriction('chat', 'Chat mute süresi'), 'Chat mute uygulandı.'),
        ),
      );
    }
    if (staff.profile.has('player.ban')) {
      final bool canBan = _banActionsReady && !_isProtectedAdmin && !_isAccountBanned;
      items.add(
        _StaffActionItem(
          icon: Icons.block_rounded,
          label: 'Banla',
          danger: true,
          onTap: canBan ? () => _run(_ban, 'Oyuncu banlandı.') : null,
        ),
      );
    }
    if (staff.profile.has('player.unban')) {
      final bool canUnban = _banActionsReady && !_isProtectedAdmin && _isAccountBanned;
      items.add(
        _StaffActionItem(
          icon: Icons.check_circle_rounded,
          label: 'Ban kaldır',
          accent: SettingsPalette.neon,
          onTap: canUnban ? () => _run(_unban, 'Ban kaldırıldı.') : null,
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StaffState>(staffProvider, (StaffState? previous, StaffState next) {
      if (previous?.profile.isStaff != true && next.profile.isStaff && mounted) {
        setState(() {});
      }
    });

    final StaffState staff = ref.watch(staffProvider);
    final bool hasStaffActions = !_isProtectedAdmin &&
        (staff.profile.has('player.ban') ||
        staff.profile.has('player.unban') ||
        staff.profile.has('player.rename') ||
        staff.profile.has('player.grant_gold') ||
        staff.profile.has('player.deduct_gold') ||
        staff.profile.has('player.grant_gems') ||
        staff.profile.has('player.deduct_gems') ||
        staff.profile.has('player.adjust_energy') ||
        staff.profile.has('player.adjust_xp') ||
        staff.profile.has('player.adjust_reputation') ||
        staff.profile.has('player.adjust_health') ||
        staff.profile.has('player.restrict_hospital') ||
        staff.profile.has('player.restrict_prison') ||
        staff.profile.has('player.restrict_trade') ||
        staff.profile.has('player.chat_mute') ||
        staff.profile.has('player.adjust_inventory'));
    final bool canViewEnforcement = staff.profile.has('player.view_detail');
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double contentWidth = MediaQuery.sizeOf(context).width - 56;
    final List<_StaffActionItem> actionItems = _buildActionItems(staff);

    // #region agent log
    StaffHubDebugLog.log(
      'H2',
      'player_action_sheet.dart:build',
      'sheet_constraints',
      data: <String, Object?>{
        'contentWidth': contentWidth,
        'maxHeight': maxHeight,
        'actionCount': actionItems.length,
      },
    );
    // #endregion

    final StaffPlayerDetail? detail = _playerDetail;
    final bool showDetail = staff.profile.has('player.view_detail');

    return DismissKeyboard(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: keyboardInset + 24),
          child: SizedBox(
            width: contentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.displayName ?? widget.username,
                          style: AppTextStyles.h3.copyWith(color: SettingsPalette.textHi, fontSize: 18),
                        ),
                        Text('@${widget.username}', style: supportCaptionStyle),
                      ],
                    ),
                  ),
                  if (widget.staffBadge != null) StaffBadge(badge: widget.staffBadge),
                  if (widget.kingBadge != null) StaffBadge(badge: widget.kingBadge),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: SettingsPalette.textMid, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (showDetail)
                StaffPlayerCard(
                  player: detail ??
                      StaffPlayerDetail(
                        authId: widget.authId,
                        username: widget.username,
                        displayName: widget.displayName,
                      ),
                  loading: _loadingDetail,
                  onExtendHospital: _restrictionQuickAction(staff, 'hospital', extend: true),
                  onShortenHospital: _restrictionQuickAction(staff, 'hospital', extend: false),
                  onReleaseHospital: _restrictionQuickAction(staff, 'hospital', release: true),
                  onExtendPrison: _restrictionQuickAction(staff, 'prison', extend: true),
                  onShortenPrison: _restrictionQuickAction(staff, 'prison', extend: false),
                  onReleasePrison: _restrictionQuickAction(staff, 'prison', release: true),
                  onReleaseTradeBan: !_isProtectedAdmin && _canLift('trade', staff) &&
                          ((detail?.isTradeBanned ?? false) || _hasActiveRestriction('trade'))
                      ? () => _run(() => _liftRestriction('trade'), 'Ticaret yasağı kaldırıldı.')
                      : null,
                  onUnban: !_isProtectedAdmin && _canLift('account_ban', staff) && _isAccountBanned
                      ? () => _run(_unban, 'Ban kaldırıldı.')
                      : null,
                  onReleaseChatMute: !_isProtectedAdmin && _canLift('chat', staff) &&
                          ((detail?.isChatMuted ?? false) || _hasActiveRestriction('chat'))
                      ? () => _run(() => _liftRestriction('chat'), 'Chat susturma kaldırıldı.')
                      : null,
                ),
              if (_isProtectedAdmin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SettingsGlassCard(
                    accent: SettingsPalette.gold,
                    child: Text(
                      'Admin hesabına staff işlemi uygulanamaz.',
                      style: supportBodyStyle.copyWith(color: SettingsPalette.textHi),
                    ),
                  ),
                ),
              if (canViewEnforcement) _enforcementSection(staff),
              const SizedBox(height: 12),
              _staffActionsSection(
                actionItems,
                hasStaffActions: hasStaffActions || actionItems.isNotEmpty,
                contentWidth: contentWidth,
              ),
              if (canViewEnforcement && (_enforcementLoadedOnce || !_loadingEnforcement)) ...<Widget>[
                const SizedBox(height: 14),
                _historySection(),
              ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
