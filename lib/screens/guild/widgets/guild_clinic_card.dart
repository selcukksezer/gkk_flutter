import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/common/gkk_progress_bar.dart';
import '../../../core/services/app_haptics.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/gold_format.dart';
import '../../../l10n/l10n.dart';
import '../../../models/guild_model.dart';
import '../../../repositories/guild_monument_repository.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
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

  double get _poolProgress {
    if (_nextCost == null) return 1.0;
    double sumProgress = 0.0;
    int count = 0;
    for (final MonumentResourceKind kind in MonumentResourceKind.values) {
      final int need = _needFor(kind);
      if (need > 0) {
        count++;
        sumProgress += (_poolFor(kind) / need).clamp(0.0, 1.0);
      }
    }
    return count > 0 ? (sumProgress / count) : 1.0;
  }

  double get _softCut {
    final double base = _level < 1 ? 0 : _cutPct;
    return _monumentLevel >= 60 ? base * 0.9 : base;
  }

  String _pctLabel(double pct) => (pct * 100).toStringAsFixed(1);

  Future<void> _donateKind(MonumentResourceKind kind) async {
    final MonumentMyStats stats = _clinicDonateStats();
    if (stats.maxDonatable(kind) <= 0) {
      await AppHaptics.light();
      if (!mounted) return;
      AppMessenger.show(context, '${kind.shortLabel}: elinde yok');
      return;
    }
    await AppHaptics.selection();
    if (!mounted) return;
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
        await AppHaptics.success();
        if (!mounted) return;
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
    await AppHaptics.heavy();
    setState(() => _busy = true);
    try {
      final dynamic raw = await SupabaseService.client.rpc('upgrade_clinic');
      if (!mounted) return;
      if (raw is Map && raw['success'] == true) {
        await AppHaptics.success();
        if (!mounted) return;
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
      onTap: () {
        AppHaptics.light();
        context.go(AppRoutes.guild);
      },
      child: GuildNeonPanel(
        accent: GuildPalette.neon,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: <Color>[
                        GuildPalette.neon.withValues(alpha: 0.24),
                        GuildPalette.iridescentCyan.withValues(alpha: 0.12),
                        GuildPalette.celestialVoid,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: GuildPalette.neon.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: GuildPalette.neon.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text('🏥', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            context.l10n.sys2_clinic_title,
                            style: AppTextStyles.label.copyWith(
                              color: GuildPalette.textHi,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (_loading)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: GuildPalette.neon,
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: GuildPalette.goldGrad,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: GuildPalette.gold.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Text(
                                'Lv $_level',
                                style: const TextStyle(
                                  color: GuildPalette.void_,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.l10n.sys2_clinic_compact_hint,
                        style: AppTextStyles.caption.copyWith(
                          color: GuildPalette.titanium,
                          height: 1.3,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: GuildPalette.neon,
                  size: 22,
                ),
              ],
            ),
            if (!_loading && _error == null) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
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
                  if (_poolReady)
                    const GuildStatPill(
                      icon: Icons.bolt_rounded,
                      label: 'Yükseltme Hazır',
                      accent: GuildPalette.gold,
                      filled: true,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      context.l10n.sys2_clinic_open_on_guild,
                      style: AppTextStyles.caption.copyWith(
                        color: GuildPalette.neon,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: GuildPalette.neon,
                    ),
                  ],
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
          // Top Eyebrow + Level Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: GuildPalette.neon.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: GuildPalette.neon.withValues(alpha: 0.45),
                    width: 1.1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: GuildPalette.neon.withValues(alpha: 0.22),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: GuildPalette.neon,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: GuildPalette.neon,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.sys2_clinic_eyebrow.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                        color: GuildPalette.neon,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (!_loading)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: GuildPalette.goldGrad,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: GuildPalette.gold.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.shield_outlined,
                        size: 13,
                        color: GuildPalette.void_,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Lv $_level',
                        style: const TextStyle(
                          color: GuildPalette.void_,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Avatar + Title & Flavor
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: <Color>[
                      GuildPalette.neon.withValues(alpha: 0.24),
                      GuildPalette.iridescentCyan.withValues(alpha: 0.12),
                      GuildPalette.celestialVoid,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: GuildPalette.neon.withValues(alpha: 0.5),
                    width: 1.3,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: GuildPalette.neon.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text('🏥', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.sys2_clinic_title,
                      style: AppTextStyles.h3.copyWith(
                        color: GuildPalette.textHi,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.sys2_clinic_flavor,
                      style: AppTextStyles.caption.copyWith(
                        color: GuildPalette.titanium,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: GuildPalette.neon,
                ),
              ),
            )
          else if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: GuildPalette.coral.withValues(alpha: 0.12),
                border: Border.all(
                  color: GuildPalette.coral.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    color: GuildPalette.coral,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: GuildPalette.coral,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...<Widget>[
            // Restful Healing Sanctuary Pod
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: <Color>[
                    GuildPalette.celestialSurface.withValues(alpha: 0.95),
                    GuildPalette.obsidian.withValues(alpha: 0.90),
                    GuildPalette.celestialVoid.withValues(alpha: 0.95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: (_dailyAvailable
                          ? GuildPalette.neon
                          : GuildPalette.titanium)
                      .withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (_dailyAvailable ? GuildPalette.neon : Colors.black)
                        .withValues(alpha: _dailyAvailable ? 0.14 : 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Restful triage status row
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_dailyAvailable
                                  ? GuildPalette.neon
                                  : GuildPalette.titanium)
                              .withValues(alpha: 0.15),
                          border: Border.all(
                            color: (_dailyAvailable
                                    ? GuildPalette.neon
                                    : GuildPalette.titanium)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        child: Icon(
                          _dailyAvailable
                              ? Icons.medical_services_rounded
                              : Icons.hourglass_bottom_rounded,
                          size: 16,
                          color: _dailyAvailable
                              ? GuildPalette.neon
                              : GuildPalette.titanium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _dailyAvailable
                                  ? context.l10n.sys2_clinic_daily_ready
                                  : context.l10n.sys2_clinic_daily_used(
                                      _dailyUseKind ?? '—',
                                    ),
                              style: AppTextStyles.label.copyWith(
                                color: GuildPalette.textHi,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _dailyAvailable
                                  ? 'Acil durum tedavisi için hazır'
                                  : 'Günlük limit doldu, yarın sıfırlanır',
                              style: AppTextStyles.caption.copyWith(
                                color: GuildPalette.titanium,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: (_dailyAvailable
                                  ? GuildPalette.neon
                                  : GuildPalette.titanium)
                              .withValues(alpha: 0.16),
                          border: Border.all(
                            color: (_dailyAvailable
                                    ? GuildPalette.neon
                                    : GuildPalette.titanium)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _dailyAvailable ? '1/1 HAZIR' : '0/1 KULLANILDI',
                          style: TextStyle(
                            color: _dailyAvailable
                                ? GuildPalette.neon
                                : GuildPalette.titanium,
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0x22FFFFFF),
                    ),
                  ),
                  // Hospital Cut stat metric row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: <Color>[
                              GuildPalette.coral.withValues(alpha: 0.22),
                              GuildPalette.fuchsia.withValues(alpha: 0.14),
                            ],
                          ),
                          border: Border.all(
                            color: GuildPalette.coral.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.content_cut_rounded,
                              size: 14,
                              color: GuildPalette.coral,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _level < 1 ? '%0.0' : '-${_pctLabel(softNow)}%',
                              style: const TextStyle(
                                color: GuildPalette.coral,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _level < 1
                              ? context.l10n.sys2_clinic_cut_none
                              : context.l10n.sys2_clinic_cut_preview(
                                  _pctLabel(softNow),
                                ),
                          style: AppTextStyles.caption.copyWith(
                            color: GuildPalette.titanium,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_monumentLevel >= 60) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: <Color>[
                            GuildPalette.gold.withValues(alpha: 0.16),
                            GuildPalette.celestialGold.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(
                          color: GuildPalette.gold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.auto_awesome,
                            size: 15,
                            color: GuildPalette.gold,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.sys2_clinic_monument_soft,
                              style: const TextStyle(
                                color: GuildPalette.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
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
                    onTap: () {
                      AppMessenger.show(
                        context,
                        'Kademe 1 (Lv 1 - 49): Temel Hastane Masrafı İndirimi %${_pctLabel(lv1)}',
                      );
                    },
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
                    onTap: () {
                      AppMessenger.show(
                        context,
                        'Kademe 2 (Lv 50 - 99): Gelişmiş Hastane Masrafı İndirimi %${_pctLabel(lv50)}',
                      );
                    },
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
                    onTap: () {
                      AppMessenger.show(
                        context,
                        'Kademe 3 (Lv 100): Maksimum Hastane Masrafı İndirimi %${_pctLabel(lv100)}',
                      );
                    },
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
            const SizedBox(height: 14),
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
                    badgeText: 'ŞİFA',
                    onTap: () {
                      AppMessenger.show(
                        context,
                        '${context.l10n.sys2_clinic_service_doctor}: ${context.l10n.sys2_clinic_service_doctor_sub}',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ServiceTile(
                    emoji: '⚖️',
                    title: context.l10n.sys2_clinic_service_lawyer,
                    subtitle: context.l10n.sys2_clinic_service_lawyer_sub,
                    accent: GuildPalette.gold,
                    badgeText: 'SAVUNMA',
                    onTap: () {
                      AppMessenger.show(
                        context,
                        '${context.l10n.sys2_clinic_service_lawyer}: ${context.l10n.sys2_clinic_service_lawyer_sub}',
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Pool
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    context.l10n.sys2_clinic_pool_title.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                      color: GuildPalette.titanium,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      fontSize: 11,
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
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 10),
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GuildPressable(
                  enabled: widget.canUpgrade && !_busy && _poolReady,
                  onTap: widget.canUpgrade && !_busy && _poolReady
                      ? _upgrade
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: widget.canUpgrade && _poolReady
                          ? const LinearGradient(
                              colors: <Color>[
                                GuildPalette.neon,
                                GuildPalette.iridescentCyan,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: widget.canUpgrade && _poolReady
                          ? null
                          : GuildPalette.obsidian.withValues(alpha: 0.75),
                      border: Border.all(
                        color: widget.canUpgrade && _poolReady
                            ? GuildPalette.neon.withValues(alpha: 0.9)
                            : GuildPalette.titanium.withValues(alpha: 0.25),
                        width: widget.canUpgrade && _poolReady ? 1.5 : 1.0,
                      ),
                      boxShadow: widget.canUpgrade && _poolReady
                          ? <BoxShadow>[
                              BoxShadow(
                                color: GuildPalette.neon.withValues(alpha: 0.4),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          widget.canUpgrade && _poolReady
                              ? Icons.upgrade_rounded
                              : Icons.lock_outline_rounded,
                          size: 20,
                          color: widget.canUpgrade && _poolReady
                              ? GuildPalette.void_
                              : GuildPalette.titanium,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.canUpgrade && _poolReady
                              ? context.l10n.sys2_clinic_upgrade
                              : (_poolReady
                                  ? 'YETKİ GEREKLİ'
                                  : 'KAYNAKLAR TOPLANIYOR (%${(_poolProgress * 100).toStringAsFixed(0)})'),
                          style: TextStyle(
                            color: widget.canUpgrade && _poolReady
                                ? GuildPalette.void_
                                : GuildPalette.titanium,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!widget.canUpgrade)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: GuildPalette.titanium,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          context.l10n.sys2_clinic_upgrade_role,
                          style: AppTextStyles.caption.copyWith(
                            color: GuildPalette.titanium,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
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
    this.onTap,
  });

  final String label;
  final bool active;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GuildPressable(
      onTap: () {
        AppHaptics.selection();
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: active
                ? <Color>[
                    accent.withValues(alpha: 0.28),
                    accent.withValues(alpha: 0.12),
                    GuildPalette.celestialVoid.withValues(alpha: 0.8),
                  ]
                : <Color>[
                    GuildPalette.surfaceHi.withValues(alpha: 0.35),
                    GuildPalette.celestialVoid.withValues(alpha: 0.65),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: accent.withValues(alpha: active ? 0.85 : 0.25),
            width: active ? 1.4 : 1,
          ),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: active ? accent : GuildPalette.titanium,
                    shape: BoxShape.circle,
                    boxShadow: active
                        ? <BoxShadow>[
                            BoxShadow(
                              color: accent,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? accent : GuildPalette.titanium,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    this.badgeText,
    this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  final String? badgeText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GuildPressable(
      onTap: () {
        AppHaptics.light();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: <Color>[
              accent.withValues(alpha: 0.12),
              GuildPalette.celestialSurface.withValues(alpha: 0.85),
              GuildPalette.celestialVoid.withValues(alpha: 0.92),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: accent.withValues(alpha: 0.42),
            width: 1.1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: accent.withValues(alpha: 0.16),
                    border: Border.all(color: accent.withValues(alpha: 0.45)),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: accent.withValues(alpha: 0.15),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    badgeText ?? 'AKTİF',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 8.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: GuildPalette.titanium,
                fontSize: 10.5,
                height: 1.25,
              ),
            ),
          ],
        ),
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

  IconData get _kindIcon => switch (kind) {
        MonumentResourceKind.structural => Icons.architecture_rounded,
        MonumentResourceKind.mystical => Icons.auto_awesome_rounded,
        MonumentResourceKind.critical => Icons.bolt_rounded,
        MonumentResourceKind.gold => Icons.monetization_on_rounded,
      };

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
    final bool canDonateNow = onDonate != null && dailyLeft > 0 && owned > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: 0.08),
            GuildPalette.celestialSurface.withValues(alpha: 0.85),
            GuildPalette.celestialVoid.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: accent.withValues(
            alpha: progress >= 1.0 && need > 0 ? 0.65 : 0.35,
          ),
          width: 1.1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(
              alpha: progress >= 1.0 && need > 0 ? 0.16 : 0.06,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: accent.withValues(alpha: 0.16),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Icon(_kindIcon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      kind.shortLabel,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        letterSpacing: 0.2,
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
                  ],
                ),
              ),
              if (need > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: (progress >= 1.0 ? GuildPalette.neon : accent)
                        .withValues(alpha: 0.16),
                    border: Border.all(
                      color: (progress >= 1.0 ? GuildPalette.neon : accent)
                          .withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    progress >= 1.0
                        ? 'TAMAMLANDI'
                        : '%${(progress * 100).toInt()}',
                    style: TextStyle(
                      color: progress >= 1.0 ? GuildPalette.neon : accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GkkProgressBar(
            value: progress,
            color: accent,
            height: 6,
            glow: progress >= 1.0 && need > 0,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.sys2_clinic_owned_left(owned, dailyLeft),
                  style: TextStyle(
                    color: canDonateNow
                        ? GuildPalette.neon
                        : GuildPalette.titanium,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GuildPressable(
                enabled: onDonate != null,
                onTap: onDonate != null
                    ? () {
                        AppHaptics.selection();
                        onDonate!();
                      }
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: canDonateNow
                        ? LinearGradient(
                            colors: <Color>[
                              accent.withValues(alpha: 0.25),
                              accent.withValues(alpha: 0.12),
                            ],
                          )
                        : null,
                    color: canDonateNow
                        ? null
                        : GuildPalette.obsidian.withValues(alpha: 0.5),
                    border: Border.all(
                      color:
                          accent.withValues(alpha: canDonateNow ? 0.6 : 0.25),
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 13,
                        color: canDonateNow ? accent : GuildPalette.titanium,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'BAĞIŞ YAP',
                        style: TextStyle(
                          color: canDonateNow ? accent : GuildPalette.titanium,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
