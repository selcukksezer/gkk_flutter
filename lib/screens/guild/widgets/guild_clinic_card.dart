import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/common/gkk_progress_bar.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/gold_format.dart';
import '../../../l10n/l10n.dart';
import '../../../models/guild_model.dart';
import '../../../repositories/guild_monument_repository.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_text_styles.dart';
import 'guild_design.dart';
import 'monument_donate_amount_dialog.dart';

/// Lonca kliniği — anıt kaynakları (structural/mystical/critical/gold).
///
/// [GuildClinicCardMode.full] → Lonca sekmesi (ana yönetim).
/// [GuildClinicCardMode.compact] → Anıt özeti / deep-link.
enum GuildClinicCardMode { full, compact }

class GuildClinicCard extends ConsumerStatefulWidget {
  const GuildClinicCard({
    super.key,
    required this.canUpgrade,
    this.mode = GuildClinicCardMode.full,
  });

  final bool canUpgrade;
  final GuildClinicCardMode mode;

  @override
  ConsumerState<GuildClinicCard> createState() => _GuildClinicCardState();
}

class _GuildClinicCardState extends ConsumerState<GuildClinicCard> {
  bool _loading = true;
  bool _busy = false;
  int _level = 0;
  double _cutPct = 0;
  bool _dailyAvailable = true;
  String? _dailyUseKind;
  int _poolStructural = 0;
  int _poolMystical = 0;
  int _poolCritical = 0;
  int _vaultGold = 0;
  int _monumentLevel = 0;
  Map<String, dynamic>? _nextCost;
  MonumentResourceSnapshot _wallet = MonumentResourceSnapshot.zero();
  MonumentResourceSnapshot _today = MonumentResourceSnapshot.zero();
  MonumentResourceSnapshot _dailyLimits = const MonumentResourceSnapshot(
    structural: MonumentDailyLimits.structural,
    mystical: MonumentDailyLimits.mystical,
    critical: MonumentDailyLimits.critical,
    gold: MonumentDailyLimits.gold,
  );
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static double cutPctForLevel(int level) {
    if (level < 1) return 0;
    if (level >= 100) return 0.18;
    return 0.05 + ((level - 1) / 99.0) * 0.13;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dynamic raw =
          await SupabaseService.client.rpc('get_clinic_dashboard');
      if (!mounted) return;
      if (raw is Map && raw['success'] == true) {
        final Map<String, dynamic>? walletJson = raw['my_wallet'] is Map
            ? Map<String, dynamic>.from(raw['my_wallet'] as Map)
            : null;
        final Map<String, dynamic>? todayJson = raw['my_today'] is Map
            ? Map<String, dynamic>.from(raw['my_today'] as Map)
            : null;
        final Map<String, dynamic>? limitsJson = raw['daily_limits'] is Map
            ? Map<String, dynamic>.from(raw['daily_limits'] as Map)
            : null;
        final MonumentResourceSnapshot parsedLimits =
            MonumentResourceSnapshot.fromJson(limitsJson);
        setState(() {
          _level = (raw['clinic_level'] as num?)?.toInt() ?? 0;
          _cutPct = (raw['cut_pct'] as num?)?.toDouble() ?? 0;
          _dailyAvailable = raw['daily_available'] != false;
          _dailyUseKind = raw['daily_use_kind']?.toString();
          _poolStructural = (raw['clinic_structural'] as num?)?.toInt() ?? 0;
          _poolMystical = (raw['clinic_mystical'] as num?)?.toInt() ?? 0;
          _poolCritical = (raw['clinic_critical'] as num?)?.toInt() ?? 0;
          _vaultGold = (raw['vault_gold'] as num?)?.toInt() ?? 0;
          _monumentLevel = (raw['monument_level'] as num?)?.toInt() ?? 0;
          _nextCost = raw['next_cost'] is Map
              ? Map<String, dynamic>.from(raw['next_cost'] as Map)
              : null;
          _wallet = MonumentResourceSnapshot.fromJson(walletJson);
          _today = MonumentResourceSnapshot.fromJson(todayJson);
          _dailyLimits = (parsedLimits.structural > 0 ||
                  parsedLimits.mystical > 0 ||
                  parsedLimits.critical > 0 ||
                  parsedLimits.gold > 0)
              ? parsedLimits
              : const MonumentResourceSnapshot(
                  structural: MonumentDailyLimits.structural,
                  mystical: MonumentDailyLimits.mystical,
                  critical: MonumentDailyLimits.critical,
                  gold: MonumentDailyLimits.gold,
                );
          _loading = false;
          _busy = false;
        });
      } else {
        setState(() {
          _error = (raw is Map ? raw['error'] : null)?.toString() ??
              'Klinik yüklenemedi';
          _loading = false;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Klinik yüklenemedi';
          _loading = false;
          _busy = false;
        });
      }
    }
  }

  MonumentMyStats _clinicDonateStats() {
    // Anıt + klinik ortak günlük limit (guild_daily_donations).
    return MonumentMyStats(
      totals: MonumentResourceSnapshot.zero(),
      today: _today,
      wallet: _wallet,
      dailyLimits: _dailyLimits,
      contributionScore: 0,
    );
  }

  Color _kindAccent(MonumentResourceKind kind) => switch (kind) {
        MonumentResourceKind.structural => GuildPalette.fuchsia,
        MonumentResourceKind.mystical => GuildPalette.gold,
        MonumentResourceKind.critical => GuildPalette.coral,
        MonumentResourceKind.gold => GuildPalette.solar,
      };

  int _poolFor(MonumentResourceKind kind) => switch (kind) {
        MonumentResourceKind.structural => _poolStructural,
        MonumentResourceKind.mystical => _poolMystical,
        MonumentResourceKind.critical => _poolCritical,
        MonumentResourceKind.gold => _vaultGold,
      };

  int _needFor(MonumentResourceKind kind) {
    if (_nextCost == null) return 0;
    return switch (kind) {
      MonumentResourceKind.structural =>
        (_nextCost!['structural'] as num?)?.toInt() ?? 0,
      MonumentResourceKind.mystical =>
        (_nextCost!['mystical'] as num?)?.toInt() ?? 0,
      MonumentResourceKind.critical =>
        (_nextCost!['critical'] as num?)?.toInt() ?? 0,
      MonumentResourceKind.gold => (_nextCost!['gold'] as num?)?.toInt() ?? 0,
    };
  }

  bool get _poolReady {
    if (_nextCost == null) return false;
    for (final MonumentResourceKind kind in MonumentResourceKind.values) {
      final int need = _needFor(kind);
      if (need > 0 && _poolFor(kind) < need) return false;
    }
    return true;
  }

  double get _softCut {
    final double base = _level < 1 ? 0 : _cutPct;
    return _monumentLevel >= 60 ? base * 0.9 : base;
  }

  String _pctLabel(double pct) => (pct * 100).toStringAsFixed(1);

  Future<void> _donateKind(MonumentResourceKind kind) async {
    final MonumentMyStats stats = _clinicDonateStats();
    if (stats.maxDonatable(kind) <= 0) {
      AppMessenger.show(context, '${kind.shortLabel}: elinde yok');
      return;
    }
    final int? amount = await MonumentDonateAmountDialog.show(
      context,
      kind: kind,
      stats: stats,
      accent: _kindAccent(kind),
    );
    if (!mounted || amount == null || amount <= 0) return;

    setState(() => _busy = true);
    try {
      final Map<String, int> amounts = monumentAmountsForKind(kind, amount);
      final dynamic raw = await SupabaseService.client.rpc(
        'donate_to_clinic',
        params: <String, dynamic>{
          'p_structural': amounts['structural'],
          'p_mystical': amounts['mystical'],
          'p_critical': amounts['critical'],
          'p_gold': amounts['gold'],
        },
      );
      if (!mounted) return;
      if (raw is Map && raw['success'] == true) {
        AppMessenger.showSuccess(
          context,
          context.l10n.sys2_clinic_donate_ok(kind.shortLabel, amount),
        );
        await _load();
      } else {
        AppMessenger.showError(
          context,
          (raw is Map ? raw['error'] : 'Bağış başarısız').toString(),
        );
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Bağış başarısız');
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _upgrade() async {
    setState(() => _busy = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc('upgrade_clinic');
      if (!mounted) return;
      if (raw is Map && raw['success'] == true) {
        AppMessenger.showSuccess(
          context,
          context.l10n.sys2_clinic_level(
            (raw['clinic_level'] as num?)?.toInt() ?? (_level + 1),
          ),
        );
        await _load();
      } else {
        AppMessenger.showError(
          context,
          (raw is Map
                  ? (raw['error'] ?? 'Yükseltme başarısız')
                  : 'Yükseltme başarısız')
              .toString(),
        );
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Yükseltme başarısız');
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == GuildClinicCardMode.compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    return GuildPressable(
      onTap: () => context.go(AppRoutes.guild),
      child: GuildNeonPanel(
        accent: GuildPalette.neon,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: GuildPalette.neon.withValues(alpha: 0.16),
                    border: Border.all(
                      color: GuildPalette.neon.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text('🏥', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.sys2_clinic_title,
                        style: AppTextStyles.label.copyWith(
                          color: GuildPalette.textHi,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.sys2_clinic_compact_hint,
                        style: AppTextStyles.caption.copyWith(
                          color: GuildPalette.titanium,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: GuildPalette.neon,
                    ),
                  )
                else
                  Text(
                    'Lv $_level',
                    style: const TextStyle(
                      color: GuildPalette.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: GuildPalette.titanium,
                  size: 20,
                ),
              ],
            ),
            if (!_loading && _error == null) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  GuildStatPill(
                    icon: Icons.content_cut_rounded,
                    label: _level < 1
                        ? context.l10n.sys2_clinic_cut_none_short
                        : '~${_pctLabel(_softCut)}%',
                    accent: GuildPalette.coral,
                    filled: _level >= 1,
                  ),
                  GuildStatPill(
                    icon: _dailyAvailable
                        ? Icons.check_circle_outline
                        : Icons.event_busy_rounded,
                    label: _dailyAvailable
                        ? context.l10n.sys2_clinic_daily_ready_short
                        : context.l10n.sys2_clinic_daily_used_short(
                            _dailyUseKind ?? '—',
                          ),
                    accent: _dailyAvailable
                        ? GuildPalette.neon
                        : GuildPalette.titanium,
                    filled: _dailyAvailable,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  context.l10n.sys2_clinic_open_on_guild,
                  style: AppTextStyles.caption.copyWith(
                    color: GuildPalette.neon,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    final double lv1 = cutPctForLevel(1);
    final double lv50 = cutPctForLevel(50);
    final double lv100 = cutPctForLevel(100);
    final double softNow = _softCut;

    return GuildNeonPanel(
      accent: GuildPalette.neon,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GuildPalette.neon.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: GuildPalette.neon.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  context.l10n.sys2_clinic_eyebrow,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: GuildPalette.neon,
                  ),
                ),
              ),
              const Spacer(),
              if (!_loading)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: GuildPalette.goldGrad,
                  ),
                  child: Text(
                    'Lv $_level',
                    style: const TextStyle(
                      color: GuildPalette.void_,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Text('🏥', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.sys2_clinic_title,
                  style: AppTextStyles.h3.copyWith(
                    color: GuildPalette.textHi,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.sys2_clinic_flavor,
            style: AppTextStyles.caption.copyWith(
              color: GuildPalette.titanium,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: GuildPalette.neon,
              backgroundColor: GuildPalette.obsidian,
            )
          else if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: GuildPalette.coral),
            )
          else ...<Widget>[
            // Daily + cut status strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: GuildPalette.obsidian.withValues(alpha: 0.55),
                border: Border.all(
                  color: (_dailyAvailable ? GuildPalette.neon : GuildPalette.titanium)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        _dailyAvailable
                            ? Icons.medical_services_outlined
                            : Icons.hourglass_bottom_rounded,
                        size: 18,
                        color: _dailyAvailable
                            ? GuildPalette.neon
                            : GuildPalette.titanium,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _dailyAvailable
                              ? context.l10n.sys2_clinic_daily_ready
                              : context.l10n.sys2_clinic_daily_used(
                                  _dailyUseKind ?? '—',
                                ),
                          style: AppTextStyles.label.copyWith(
                            color: GuildPalette.textHi,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        _dailyAvailable ? '1/1' : '0/1',
                        style: TextStyle(
                          color: _dailyAvailable
                              ? GuildPalette.neon
                              : GuildPalette.titanium,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _level < 1
                        ? context.l10n.sys2_clinic_cut_none
                        : context.l10n.sys2_clinic_cut_preview(
                            _pctLabel(softNow),
                          ),
                    style: AppTextStyles.caption.copyWith(
                      color: GuildPalette.titanium,
                      height: 1.3,
                    ),
                  ),
                  if (_monumentLevel >= 60) ...<Widget>[
                    const SizedBox(height: 6),
                    GuildStatPill(
                      icon: Icons.auto_awesome,
                      label: context.l10n.sys2_clinic_monument_soft,
                      accent: GuildPalette.gold,
                      filled: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Cut bands
            Text(
              context.l10n.sys2_clinic_bands_title,
              style: AppTextStyles.caption.copyWith(
                color: GuildPalette.titanium,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _BandChip(
                    label: context.l10n.sys2_clinic_band_lv(
                      1,
                      _pctLabel(lv1),
                    ),
                    active: _level >= 1 && _level < 50,
                    accent: GuildPalette.coral,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _BandChip(
                    label: context.l10n.sys2_clinic_band_lv(
                      50,
                      _pctLabel(lv50),
                    ),
                    active: _level >= 50 && _level < 100,
                    accent: GuildPalette.solar,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _BandChip(
                    label: context.l10n.sys2_clinic_band_lv(
                      100,
                      _pctLabel(lv100),
                    ),
                    active: _level >= 100,
                    accent: GuildPalette.gold,
                  ),
                ),
              ],
            ),
            if (_level >= 1) ...<Widget>[
              const SizedBox(height: 8),
              GuildStatPill(
                icon: Icons.trending_up_rounded,
                label: context.l10n.sys2_clinic_band_now(_pctLabel(softNow)),
                accent: GuildPalette.neon,
                filled: true,
              ),
            ],
            const SizedBox(height: 12),
            // Services
            Text(
              context.l10n.sys2_clinic_services_title,
              style: AppTextStyles.caption.copyWith(
                color: GuildPalette.titanium,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ServiceTile(
                    emoji: '🩺',
                    title: context.l10n.sys2_clinic_service_doctor,
                    subtitle: context.l10n.sys2_clinic_service_doctor_sub,
                    accent: GuildPalette.neon,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ServiceTile(
                    emoji: '⚖️',
                    title: context.l10n.sys2_clinic_service_lawyer,
                    subtitle: context.l10n.sys2_clinic_service_lawyer_sub,
                    accent: GuildPalette.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Pool
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.l10n.sys2_clinic_pool_title,
                    style: AppTextStyles.caption.copyWith(
                      color: GuildPalette.titanium,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (_nextCost == null && _level > 0)
                  GuildStatPill(
                    icon: Icons.verified_rounded,
                    label: context.l10n.sys2_clinic_maxed,
                    accent: GuildPalette.gold,
                    filled: true,
                  )
                else if (_poolReady)
                  GuildStatPill(
                    icon: Icons.bolt_rounded,
                    label: context.l10n.sys2_clinic_pool_ready,
                    accent: GuildPalette.neon,
                    filled: true,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.sys2_clinic_shared_limit_hint,
              style: AppTextStyles.caption.copyWith(
                color: GuildPalette.titanium,
                height: 1.3,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 8),
            for (final MonumentResourceKind kind
                in MonumentResourceKind.values) ...<Widget>[
              _PoolBar(
                kind: kind,
                current: _poolFor(kind),
                need: _needFor(kind),
                owned: _wallet.forKind(kind),
                dailyLeft: _clinicDonateStats().dailyLeft(kind),
                accent: _kindAccent(kind),
                onDonate: _busy ? null : () => _donateKind(kind),
              ),
              const SizedBox(height: 6),
            ],
            if (_nextCost != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                context.l10n.sys2_clinic_upgrade_cost_hint,
                style: AppTextStyles.caption.copyWith(
                  color: GuildPalette.titanium,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: GuildPressable(
                  enabled: widget.canUpgrade && !_busy && _poolReady,
                  onTap: widget.canUpgrade && !_busy && _poolReady
                      ? _upgrade
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: widget.canUpgrade && _poolReady
                          ? LinearGradient(
                              colors: <Color>[
                                GuildPalette.neon.withValues(alpha: 0.95),
                                GuildPalette.neon.withValues(alpha: 0.65),
                              ],
                            )
                          : null,
                      color: widget.canUpgrade && _poolReady
                          ? null
                          : GuildPalette.obsidian.withValues(alpha: 0.7),
                      border: Border.all(
                        color: GuildPalette.neon.withValues(
                          alpha: widget.canUpgrade && _poolReady ? 0.0 : 0.25,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.upgrade_rounded,
                          size: 18,
                          color: widget.canUpgrade && _poolReady
                              ? GuildPalette.void_
                              : GuildPalette.titanium,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.sys2_clinic_upgrade,
                          style: TextStyle(
                            color: widget.canUpgrade && _poolReady
                                ? GuildPalette.void_
                                : GuildPalette.titanium,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!widget.canUpgrade)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    context.l10n.sys2_clinic_upgrade_role,
                    style: AppTextStyles.caption.copyWith(
                      color: GuildPalette.titanium,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({
    required this.label,
    required this.active,
    required this.accent,
  });

  final String label;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: accent.withValues(alpha: active ? 0.22 : 0.08),
        border: Border.all(
          color: accent.withValues(alpha: active ? 0.7 : 0.28),
          width: active ? 1.4 : 1,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active ? accent : GuildPalette.titanium,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          height: 1.2,
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: GuildPalette.obsidian.withValues(alpha: 0.5),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              color: GuildPalette.titanium,
              fontSize: 10,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoolBar extends StatelessWidget {
  const _PoolBar({
    required this.kind,
    required this.current,
    required this.need,
    required this.owned,
    required this.dailyLeft,
    required this.accent,
    required this.onDonate,
  });

  final MonumentResourceKind kind;
  final int current;
  final int need;
  final int owned;
  final int dailyLeft;
  final Color accent;
  final VoidCallback? onDonate;

  @override
  Widget build(BuildContext context) {
    final double progress =
        need <= 0 ? 1.0 : (current / need).clamp(0.0, 1.0);
    final String currentLabel = kind == MonumentResourceKind.gold
        ? formatCompactGold(current)
        : '$current';
    final String needLabel = kind == MonumentResourceKind.gold
        ? formatCompactGold(need)
        : '$need';
    return GuildPressable(
      onTap: onDonate,
      enabled: onDonate != null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          color: GuildPalette.obsidian.withValues(alpha: 0.55),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    kind.shortLabel,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  need > 0 ? '$currentLabel / $needLabel' : currentLabel,
                  style: const TextStyle(
                    color: GuildPalette.textHi,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.sys2_clinic_owned_left(owned, dailyLeft),
                  style: TextStyle(
                    color: dailyLeft > 0 && owned > 0
                        ? GuildPalette.neon
                        : GuildPalette.titanium,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.add_circle_outline, size: 16, color: accent),
              ],
            ),
            const SizedBox(height: 6),
            GkkProgressBar(
              value: progress,
              color: accent,
              height: 5,
              glow: progress >= 1.0 && need > 0,
            ),
          ],
        ),
      ),
    );
  }
}
