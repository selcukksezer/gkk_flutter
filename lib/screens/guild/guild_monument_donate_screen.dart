import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/gkk_progress_bar.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/utils/gold_format.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../l10n/l10n.dart';
import '../../models/guild_model.dart';
import '../../providers/guild_monument_provider.dart';
import '../../providers/guild_provider.dart';
import '../../repositories/guild_monument_repository.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/logout_helper.dart';
import 'widgets/guild_monument_ui.dart';

class GuildMonumentDonateScreen extends ConsumerStatefulWidget {
  const GuildMonumentDonateScreen({super.key});

  @override
  ConsumerState<GuildMonumentDonateScreen> createState() => _GuildMonumentDonateScreenState();
}

class _GuildMonumentDonateScreenState extends ConsumerState<GuildMonumentDonateScreen> {
  final Map<MonumentResourceKind, TextEditingController> _controllers =
      <MonumentResourceKind, TextEditingController>{
    for (final MonumentResourceKind kind in MonumentResourceKind.values) kind: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    deferProviderUpdate(() => ref.read(guildMonumentProvider.notifier).bootstrap());
  }

  @override
  void dispose() {
    for (final TextEditingController ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _donateKind(MonumentResourceKind kind, {int? amount}) async {
    final MonumentDashboard? dashboard = ref.read(guildMonumentProvider).dashboard;
    if (dashboard == null) return;

    final int? parsed = int.tryParse(_controllers[kind]!.text.trim());
    final int requested = amount ?? parsed ?? 0;

    if (requested <= 0) {
      AppMessenger.show(context, 'Bağış miktarı gir');
      return;
    }

    final int capped = monumentDonateCap(
      owned: dashboard.myStats.owned(kind),
      donatedToday: dashboard.myStats.donatedToday(kind),
      dailyMax: dashboard.myStats.dailyMax(kind),
      requested: requested,
    );

    if (capped <= 0) {
      AppMessenger.show(context, '${kind.shortLabel} için bağışlanacak miktar yok veya limit doldu');
      return;
    }

    final MonumentDonateResult? result = await ref
        .read(guildMonumentProvider.notifier)
        .donateKind(kind: kind, amount: capped);
    if (!mounted) return;

    if (result != null) {
      _controllers[kind]!.clear();
      setState(() {});
      final String formattedAmount = kind == MonumentResourceKind.gold
          ? formatCompactGold(capped)
          : NumberFormat.decimalPattern('tr_TR').format(capped);
      AppMessenger.show(
        context,
        '${kind.shortLabel}: $formattedAmount bağışlandı · +${result.scoreAdded} Katkı Puanı',
      );
      return;
    }

    final String? error = ref.read(guildMonumentProvider).errorMessage;
    if (error != null) {
      AppMessenger.showError(context, error);
    }
  }

  void _fillMax(MonumentResourceKind kind) {
    final MonumentDashboard? dashboard = ref.read(guildMonumentProvider).dashboard;
    if (dashboard == null) return;
    final int max = dashboard.myStats.maxDonatable(kind);
    final TextEditingController ctrl = _controllers[kind]!;
    if (max > 0) {
      ctrl.text = '$max';
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    } else {
      ctrl.clear();
    }
    setState(() {});
  }

  void _setAmount(MonumentResourceKind kind, int amount) {
    final TextEditingController ctrl = _controllers[kind]!;
    ctrl.text = '$amount';
    ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    setState(() {});
  }

  Color _kindAccent(MonumentResourceKind kind) => switch (kind) {
        MonumentResourceKind.structural => AppColors.cyberFuchsia,
        MonumentResourceKind.mystical => AppColors.liquidGold,
        MonumentResourceKind.critical => AppColors.coralFlare,
        MonumentResourceKind.gold => AppColors.warningSolar,
      };

  IconData _kindIcon(MonumentResourceKind kind) => switch (kind) {
        MonumentResourceKind.structural => Icons.architecture_rounded,
        MonumentResourceKind.mystical => Icons.auto_awesome_rounded,
        MonumentResourceKind.critical => Icons.bolt_rounded,
        MonumentResourceKind.gold => Icons.monetization_on_rounded,
      };

  String _kindRoleSubtitle(MonumentResourceKind kind) => switch (kind) {
        MonumentResourceKind.structural => 'Mimari Dayanıklılık',
        MonumentResourceKind.mystical => 'Ruhani Çekirdek Gücü',
        MonumentResourceKind.critical => 'Rezonans Matrisi',
        MonumentResourceKind.gold => 'Lonca Kasası Katkısı',
      };

  String _formatNumber(int value) => NumberFormat.decimalPattern('tr_TR').format(value);

  List<int> _presetsForKind(MonumentResourceKind kind, int maxDonate) {
    final List<int> candidates = kind == MonumentResourceKind.gold
        ? <int>[50000, 100000, 500000, 1000000, 5000000]
        : <int>[1, 5, 10, 25, 50];
    return candidates.where((int v) => v > 0 && v < maxDonate).toList();
  }

  Widget _presetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: 0.22)
                : AppColors.darkObsidian.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : AppColors.mutedTitanium.withValues(alpha: 0.25),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.textPrimary : AppColors.mutedTitanium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _monumentAltarHeader(MonumentDashboard dashboard) {
    return monumentPanel(
      borderColor: AppColors.liquidGold.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.liquidGold.withValues(alpha: 0.35),
                      AppColors.liquidGold.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.7), width: 1.5),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.account_balance_rounded, color: AppColors.liquidGold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'LONCA ANITI SUNAĞI',
                      style: AppTextStyles.caption.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                        color: AppColors.liquidGold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dashboard.guild.name,
                      style: AppTextStyles.h2.copyWith(fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mevcut Seviye: Lv.${dashboard.guild.monumentLevel} · ${dashboard.memberCount} Lonca Üyesi',
                      style: AppTextStyles.caption.copyWith(color: AppColors.mutedTitanium),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkObsidian.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.mutedTitanium.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.military_tech_rounded, color: AppColors.liquidGold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Toplam Bireysel Katkın: ${_formatNumber(dashboard.myStats.contributionScore)} Puan',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Her kaynağı ayrı bağışlayabilirsin. Dört alanı birden doldurmak zorunda değilsin — loncanı güçlendirmek için elindeki kaynakları sunağa adayın.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mutedTitanium,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _donateCard(MonumentResourceKind kind, GuildMonumentState monumentState) {
    final MonumentDashboard? dashboard = monumentState.dashboard;
    if (dashboard == null) return const SizedBox.shrink();

    final MonumentMyStats stats = dashboard.myStats;
    final int owned = stats.owned(kind);
    final int today = stats.donatedToday(kind);
    final int total = stats.donatedTotal(kind);
    final int maxDonate = stats.maxDonatable(kind);
    final int dailyMax = stats.dailyMax(kind);
    final int dailyLeft = stats.dailyLeft(kind);
    final bool busy = monumentState.donatingKind == kind;
    final TextEditingController ctrl = _controllers[kind]!;
    final Color accent = _kindAccent(kind);
    final IconData iconData = _kindIcon(kind);
    final String roleSubtitle = _kindRoleSubtitle(kind);

    final double quotaRatio = dailyMax > 0 ? (today / dailyMax).clamp(0.0, 1.0) : 0.0;
    final int? parsedAmount = int.tryParse(ctrl.text.trim());
    final bool hasValidInput = parsedAmount != null && parsedAmount > 0 && parsedAmount <= maxDonate;
    final List<int> presets = _presetsForKind(kind, maxDonate);

    return monumentPanel(
      borderColor: accent.withValues(alpha: 0.38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: accent.withValues(alpha: 0.14),
                  border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: accent.withValues(alpha: 0.20), blurRadius: 8),
                  ],
                ),
                child: Icon(iconData, color: accent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(kind.label, style: AppTextStyles.label.copyWith(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      roleSubtitle,
                      style: AppTextStyles.caption.copyWith(color: AppColors.mutedTitanium, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: owned > 0
                      ? AppColors.toxicNeon.withValues(alpha: 0.12)
                      : AppColors.mysticRuby.withValues(alpha: 0.12),
                  border: Border.all(
                    color: owned > 0
                        ? AppColors.toxicNeon.withValues(alpha: 0.35)
                        : AppColors.mysticRuby.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  owned > 0
                      ? (kind == MonumentResourceKind.gold ? '${formatCompactGold(owned)} Altın' : '$owned Adet')
                      : 'Stok Yok',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: owned > 0 ? AppColors.toxicNeon : AppColors.mysticRuby,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GkkProgressBar(
            value: quotaRatio,
            color: quotaRatio >= 1.0 ? AppColors.toxicNeon : accent,
            height: 6,
            glow: true,
            label: 'Günlük Bağış Kotası',
            sublabel: '${_formatNumber(today)} / ${_formatNumber(dailyMax)} (%${(quotaRatio * 100).toInt()})',
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.darkObsidian.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.mutedTitanium.withValues(alpha: 0.14)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Toplam Katkın', style: TextStyle(fontSize: 10, color: AppColors.mutedTitanium)),
                      const SizedBox(height: 2),
                      Text(
                        _formatNumber(total),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.darkObsidian.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.mutedTitanium.withValues(alpha: 0.14)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Kalan Günlük Hak', style: TextStyle(fontSize: 10, color: AppColors.mutedTitanium)),
                      const SizedBox(height: 2),
                      Text(
                        _formatNumber(dailyLeft),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: dailyLeft > 0 ? AppColors.textPrimary : AppColors.mutedTitanium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (maxDonate > 0) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final int preset in presets)
                  _presetChip(
                    label: kind == MonumentResourceKind.gold ? '+${formatCompactGold(preset)}' : '+$preset',
                    isSelected: parsedAmount == preset,
                    onTap: () => _setAmount(kind, preset),
                    accentColor: accent,
                  ),
                _presetChip(
                  label: 'Maksimum (${_formatNumber(maxDonate)})',
                  isSelected: parsedAmount == maxDonate,
                  onTap: () => _fillMax(kind),
                  accentColor: accent,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              enabled: !busy && monumentState.donatingKind == null,
              onChanged: (_) => setState(() {}),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                _MonumentDonateMaxFormatter(maxDonate),
              ],
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: 'Miktar girin (Maks: ${_formatNumber(maxDonate)})',
                filled: true,
                fillColor: AppColors.darkObsidian.withValues(alpha: 0.65),
                prefixIcon: Icon(Icons.edit_note_rounded, color: accent.withValues(alpha: 0.7), size: 18),
                suffixIcon: ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.mutedTitanium),
                        onPressed: () {
                          ctrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(color: AppColors.mutedTitanium.withValues(alpha: 0.22)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(color: AppColors.mutedTitanium.withValues(alpha: 0.22)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.7), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            if (parsedAmount != null && parsedAmount > 0) ...<Widget>[
              const SizedBox(height: 6),
              if (parsedAmount <= maxDonate)
                Row(
                  children: <Widget>[
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.toxicNeon),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Bağışlanacak: ${_formatNumber(parsedAmount)} ${kind == MonumentResourceKind.gold ? 'Altın' : 'Adet'}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.toxicNeon),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: <Widget>[
                    const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.mysticRuby),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Limit aşıldı (En fazla ${_formatNumber(maxDonate)})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.mysticRuby),
                      ),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.vertical_align_top_rounded, size: 16),
                    label: const Text('Tümünü Yaz', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: busy || monumentState.donatingKind != null ? null : () => _fillMax(kind),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.mutedTitanium.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.carbonVoid),
                          )
                        : const Icon(Icons.volunteer_activism_rounded, size: 16),
                    label: Text(
                      busy ? 'Bağışlanıyor...' : 'Bağışla',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    onPressed: busy || monumentState.donatingKind != null || !hasValidInput
                        ? null
                        : () => _donateKind(kind),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.liquidGold,
                      disabledBackgroundColor: AppColors.darkObsidian,
                      foregroundColor: AppColors.carbonVoid,
                      disabledForegroundColor: AppColors.mutedTitanium,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: owned <= 0
                      ? AppColors.darkObsidian.withValues(alpha: 0.5)
                      : AppColors.toxicNeon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: owned <= 0
                        ? AppColors.mutedTitanium.withValues(alpha: 0.2)
                        : AppColors.toxicNeon.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      owned <= 0 ? Icons.inventory_2_outlined : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: owned <= 0 ? AppColors.mutedTitanium : AppColors.toxicNeon,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        owned <= 0
                            ? 'Bu kaynaktan envanterinde yok. Görev ve zindanlardan toplayabilirsin.'
                            : 'Bugünlük bağış kotası doldu (${_formatNumber(dailyMax)}/${_formatNumber(dailyMax)}). Gece yarısı sıfırlanır.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: owned <= 0 ? AppColors.mutedTitanium : AppColors.toxicNeon,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasGuild = ref.watch(hasGuildMembershipProvider);
    final GuildMonumentState monumentState = ref.watch(guildMonumentProvider);

    Future<void> logout() async => performLogout(ref);

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.screenTitleMonumentDonate, onLogout: logout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.guildMonumentDonate, onLogout: logout),
      body: monumentScreenShell(
        child: !hasGuild
            ? monumentEmptyState(
                title: 'Lonca Bulunamadı',
                message: 'Bağış yapmak için önce bir loncaya katılman gerekir.',
                primaryAction: monumentGoldButton(
                  label: 'Lonca Bul',
                  icon: Icons.groups_rounded,
                  onPressed: () => context.go(AppRoutes.guild),
                ),
                secondaryAction: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Geri Dön', style: TextStyle(color: AppColors.mutedTitanium)),
                ),
              )
            : monumentState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.liquidGold))
                : monumentState.dashboard == null
                    ? monumentErrorState(
                        onRetry: () => ref.read(guildMonumentProvider.notifier).loadDashboard(),
                        message: monumentState.loadError,
                      )
                    : ListView(
                        padding: MonumentUi.pagePadding(context),
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              TextButton.icon(
                                onPressed: () => context.pop(),
                                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.mutedTitanium),
                                label: const Text('Geri Dön', style: TextStyle(color: AppColors.mutedTitanium, fontSize: 13)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Yenile',
                                icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.mutedTitanium),
                                onPressed: () => ref.read(guildMonumentProvider.notifier).loadDashboard(),
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          GameScrollSection(
                            leadingGap: false,
                            child: _monumentAltarHeader(monumentState.dashboard!),
                          ),
                          for (int i = 0; i < MonumentResourceKind.values.length; i++)
                            GameScrollSection(
                              child: _donateCard(MonumentResourceKind.values[i], monumentState),
                            ),
                        ],
                      ),
      ),
    );
  }
}

class _MonumentDonateMaxFormatter extends TextInputFormatter {
  const _MonumentDonateMaxFormatter(this.maxValue);

  final int maxValue;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final String text = newValue.text;
    if (text.isEmpty) return newValue;

    final int? value = int.tryParse(text);
    if (value == null) return oldValue;
    if (value <= maxValue) return newValue;
    return oldValue;
  }
}
