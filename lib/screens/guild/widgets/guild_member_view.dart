import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/common/gkk_progress_bar.dart';
import '../../../components/player/player_name_label.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/utils/provider_scheduling.dart';
import '../../../l10n/l10n.dart';
import '../../../models/guild_model.dart';
import '../../../providers/guild_monument_provider.dart';
import '../../../providers/guild_vault_provider.dart';
import '../../../repositories/guild_monument_repository.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../guild_helpers.dart';
import 'guild_clinic_card.dart';
import 'guild_design.dart';
import 'guild_emblem_banner.dart';
import 'guild_perks_and_buffs.dart';

class GuildMemberView extends ConsumerStatefulWidget {
  const GuildMemberView({
    super.key,
    required this.guild,
    required this.myPlayerId,
    required this.myRole,
    required this.memberActionLoading,
    required this.onMemberTap,
    this.onStaffMemberAction,
    required this.onLeave,
    required this.leaveLabel,
    required this.onGuildWar,
    required this.onMonument,
    required this.onVault,
    required this.onRefresh,
    this.onEditMinJoinPower,
  });

  final GuildData guild;
  final String myPlayerId;
  final GuildRole myRole;
  final bool memberActionLoading;
  final Future<void> Function(GuildMemberData) onMemberTap;
  final void Function(GuildMemberData)? onStaffMemberAction;
  final VoidCallback onLeave;
  final String leaveLabel;
  final VoidCallback onGuildWar;
  final VoidCallback onMonument;
  final VoidCallback onVault;
  final Future<void> Function() onRefresh;
  final VoidCallback? onEditMinJoinPower;

  @override
  ConsumerState<GuildMemberView> createState() => _GuildMemberViewState();
}

class _GuildMemberViewState extends ConsumerState<GuildMemberView> {
  @override
  void initState() {
    super.initState();
    deferProviderUpdate(() async {
      await ref.read(guildVaultProvider.notifier).load(silent: true);
      await ref.read(guildMonumentProvider.notifier).bootstrap();
    });
  }

  Future<void> _refreshAll() async {
    await widget.onRefresh();
    await ref.read(guildVaultProvider.notifier).load(silent: true);
    await ref.read(guildMonumentProvider.notifier).loadDashboard();
  }

  String _roleBadge(GuildRole role) => switch (role) {
    GuildRole.leader => 'GM',
    GuildRole.officer => 'SUBAY',
    GuildRole.member => 'ÜYE',
  };

  Color _roleAccent(GuildRole role) => switch (role) {
    GuildRole.leader => GuildPalette.gold,
    GuildRole.officer => GuildPalette.coral,
    GuildRole.member => GuildPalette.titanium,
  };

  @override
  Widget build(BuildContext context) {
    final GuildData guild = widget.guild;
    final vault = ref.watch(guildVaultProvider);
    final monumentState = ref.watch(guildMonumentProvider);
    final MonumentDashboard? dash = monumentState.dashboard;
    final MonumentUpgradeProgress? upgradeProgress = dash == null
        ? null
        : MonumentUpgradeProgress.compute(
            guild: dash.guild,
            nextCost: dash.nextCost,
            blueprints: dash.blueprints,
          );

    final int liveVaultGold = vault.hydrated
        ? vault.vaultGold
        : guild.vaultGold;
    final int onlineCount = (guild.members ?? const <GuildMemberData>[])
        .where((GuildMemberData m) => m.isOnline == true)
        .length;
    final List<GuildMemberData> sortedMembers = guild.members == null
        ? <GuildMemberData>[]
        : (List<GuildMemberData>.from(guild.members!)..sort(
            (GuildMemberData a, GuildMemberData b) {
              final int roleComp = guildRoleSortOrder(a.role).compareTo(guildRoleSortOrder(b.role));
              if (roleComp != 0) return roleComp;
              return (b.contribution ?? 0).compareTo(a.contribution ?? 0);
            },
          ));

    return SafeArea(
      child: RefreshIndicator(
        color: GuildPalette.gold,
        backgroundColor: GuildPalette.navy,
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: <Widget>[
            TutorialAnchorScope(
              id: TutorialAnchorId.guildHeader,
              child: _GuildHeroCard(
                guild: guild,
                myRole: widget.myRole,
                liveVaultGold: liveVaultGold,
                onlineCount: onlineCount,
                onEditMinJoinPower: widget.onEditMinJoinPower,
                roleBadge: _roleBadge(widget.myRole),
                roleAccent: _roleAccent(widget.myRole),
              ),
            ),
            const SizedBox(height: 14),
            TutorialAnchorScope(
              id: TutorialAnchorId.guildJoinBtn,
              child: _GuildCommandGrid(
                onGuildWar: widget.onGuildWar,
                onMonument: widget.onMonument,
                onVault: widget.onVault,
                vaultGoldLabel: formatGuildCompact(liveVaultGold),
                monumentLevel: guild.monumentLevel,
              ),
            ),
            if (upgradeProgress != null) ...<Widget>[
              const SizedBox(height: 14),
              GuildPressable(
                onTap: widget.onMonument,
                child: GuildGlassCard(
                  accent: GuildPalette.coral,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text('🏛', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Anıt Sv.${guild.monumentLevel} → ${upgradeProgress.nextLevel}',
                              style: AppTextStyles.label.copyWith(
                                color: GuildPalette.textHi,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            upgradeProgress.isReady
                                ? 'HAZIR'
                                : '%${upgradeProgress.filledPercent}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: upgradeProgress.isReady
                                  ? GuildPalette.neon
                                  : GuildPalette.solar,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: GuildPalette.titanium,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GkkProgressBar(
                        value: upgradeProgress.overallProgress,
                        color: upgradeProgress.isReady
                            ? GuildPalette.neon
                            : GuildPalette.coral,
                        height: 7,
                        glow: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        upgradeProgress.isReady
                            ? 'Tüm kaynaklar tamam — anıtı yükselt.'
                            : upgradeProgress.resources
                                  .where(
                                    (MonumentResourceProgress r) =>
                                        !r.isComplete && r.required > 0,
                                  )
                                  .map(
                                    (MonumentResourceProgress r) =>
                                        '${r.kind.shortLabel} −${formatGuildCompact(r.remaining)}',
                                  )
                                  .join(' · '),
                        style: AppTextStyles.caption.copyWith(
                          color: GuildPalette.titanium,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            // 2027 Aion 2 Guild Perks & Active Buffs
            GuildPerksAndBuffsSection(
              monumentLevel: guild.monumentLevel,
              guildLevel: guild.level,
            ),
            const SizedBox(height: 14),
            GuildGlassCard(
              accent: GuildPalette.gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Text('🪙', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'LONCA KASASI',
                              style: AppTextStyles.caption.copyWith(
                                color: GuildPalette.titanium,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              '${formatGuildCompact(liveVaultGold)}g',
                              style: AppTextStyles.h2.copyWith(
                                fontSize: 26,
                                color: GuildPalette.gold,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GuildPressable(
                        onTap: widget.onVault,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: GuildPalette.goldGrad,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: GuildPalette.gold.withValues(alpha: 0.35),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Aç',
                            style: TextStyle(
                              color: GuildPalette.void_,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bölge geliri + anıt altın bağışı buraya akar. Savaş ve anıt yükseltme kasadan düşer.',
                    style: AppTextStyles.caption.copyWith(
                      color: GuildPalette.titanium,
                      height: 1.35,
                    ),
                  ),
                  if (vault.hydrated && vault.items.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    GuildStatPill(
                      icon: Icons.inventory_2_outlined,
                      label: '${vault.items.length} kasa eşyası',
                      accent: GuildPalette.coral,
                      filled: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            GuildSectionTitle(
              title: context.l10n.sys2_clinic_title.toUpperCase(),
              subtitle: context.l10n.sys2_clinic_section_sub,
              accent: GuildPalette.neon,
            ),
            const SizedBox(height: 10),
            GuildClinicCard(
              canUpgrade: widget.myRole == GuildRole.leader ||
                  widget.myRole == GuildRole.officer,
            ),
            const SizedBox(height: 18),
            GuildSectionTitle(
              title: 'ÜYELER & KATKI SIRALAMASI',
              subtitle:
                  '${sortedMembers.length} kayıt · $onlineCount çevrimiçi',
              accent: GuildPalette.fuchsia,
              trailing: widget.memberActionLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: GuildPalette.gold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            if (sortedMembers.isEmpty)
              GuildGlassCard(
                accent: GuildPalette.titanium,
                glow: false,
                child: Text(
                  guild.loadError ?? 'Henüz üye kaydı yok.',
                  style: AppTextStyles.caption.copyWith(
                    color: GuildPalette.titanium,
                  ),
                ),
              )
            else
              ...List<Widget>.generate(sortedMembers.length, (int i) {
                final GuildMemberData member = sortedMembers[i];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: i == sortedMembers.length - 1 ? 0 : 8,
                  ),
                  child: _GuildMemberCard(
                    member: member,
                    rank: i + 1,
                    isMe: member.playerId == widget.myPlayerId,
                    canAct:
                        widget.myRole != GuildRole.member &&
                        member.playerId != widget.myPlayerId,
                    roleAccent: _roleAccent(member.role),
                    roleBadge: _roleBadge(member.role),
                    onTap: () => widget.onMemberTap(member),
                    onLongPress:
                        widget.onStaffMemberAction != null &&
                            member.userId != null
                        ? () => widget.onStaffMemberAction!(member)
                        : null,
                    onStaffTap:
                        widget.onStaffMemberAction != null &&
                            member.userId != null &&
                            member.userId!.isNotEmpty &&
                            member.playerId != widget.myPlayerId
                        ? () => widget.onStaffMemberAction!(member)
                        : null,
                  ),
                );
              }),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: GuildPressable(
                onTap: widget.onLeave,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: GuildPalette.ruby.withValues(alpha: 0.55),
                    ),
                    color: GuildPalette.ruby.withValues(alpha: 0.10),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: GuildPalette.ruby.withValues(alpha: 0.15),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        widget.myRole == GuildRole.leader
                            ? Icons.dangerous_outlined
                            : Icons.logout_rounded,
                        size: 16,
                        color: GuildPalette.ruby,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.leaveLabel,
                        style: const TextStyle(
                          color: GuildPalette.ruby,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuildHeroCard extends StatelessWidget {
  const _GuildHeroCard({
    required this.guild,
    required this.myRole,
    required this.liveVaultGold,
    required this.onlineCount,
    required this.roleBadge,
    required this.roleAccent,
    this.onEditMinJoinPower,
  });

  final GuildData guild;
  final GuildRole myRole;
  final int liveVaultGold;
  final int onlineCount;
  final String roleBadge;
  final Color roleAccent;
  final VoidCallback? onEditMinJoinPower;

  @override
  Widget build(BuildContext context) {
    final GuildPrestigeTier tier = GuildPrestigeTier.fromLevel(guild.level);

    return GuildGlassCard(
      accent: tier.primaryAccent,
      padding: EdgeInsets.zero,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Image.asset(
                'assets/images/backgrounds/elysea/bg_sanctum_citadel.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[
                      const Color(0xFF090E1A).withValues(alpha: 0.94),
                      const Color(0xFF0C1322).withValues(alpha: 0.88),
                      const Color(0xFF0F1A2E).withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Status Badges
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tier.primaryAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: tier.primaryAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: tier.primaryAccent,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: tier.primaryAccent,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tier.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: tier.primaryAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: roleAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: roleAccent.withValues(alpha: 0.45)),
                ),
                child: Text(
                  roleBadge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: roleAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Emblem & Guild Identity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  GuildCelestialEmblem(
                    level: guild.level,
                    monogram: '',
                    size: 68,
                    showGlow: true,
                  ),
                  Center(
                    child: Image.asset(
                      'assets/images/icons/weapons/weapon_kallida_shield.png',
                      width: 42,
                      height: 42,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/icons/armor/armor_crown_of_light.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          guild.name.isNotEmpty
                              ? guild.name.characters.first.toUpperCase()
                              : '⚔️',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      guild.name,
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 22,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guild.description?.trim().isNotEmpty == true
                          ? guild.description!.trim()
                          : 'Lonca güçlerini birleştir — savaş, anıt, kasa.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: GuildPalette.titanium,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        GuildStatPill(
                          icon: Icons.workspace_premium_rounded,
                          label: 'Sv.${guild.level}',
                          accent: GuildPalette.gold,
                          filled: true,
                        ),
                        GuildStatPill(
                          icon: Icons.account_balance_rounded,
                          label: 'Anıt ${guild.monumentLevel}',
                          accent: GuildPalette.coral,
                        ),
                        GuildStatPill(
                          icon: Icons.circle,
                          label: '$onlineCount online',
                          accent: GuildPalette.neon,
                          filled: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bento Metric Cards
          Row(
            children: <Widget>[
              Expanded(
                child: _HeroMetric(
                  label: 'ÜYE',
                  value: '${guild.memberCount}/${guild.maxMembers}',
                  accent: GuildPalette.fuchsia,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroMetric(
                  label: 'TOPLAM GÜÇ',
                  value: formatGuildCompact(guild.totalPower),
                  accent: GuildPalette.solar,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroMetric(
                  label: 'KASA',
                  value: '${formatGuildCompact(liveVaultGold)}g',
                  accent: GuildPalette.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GuildProgressStrip(
            label: 'Kadro doluluk',
            value: guild.maxMembers <= 0
                ? 0
                : guild.memberCount / guild.maxMembers,
            detail: '${guild.memberCount} / ${guild.maxMembers}',
            accent: tier.primaryAccent,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                Icons.shield_rounded,
                size: 14,
                color: guild.minJoinPower > 0
                    ? GuildPalette.coral
                    : GuildPalette.titanium,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  guild.minJoinPower > 0
                      ? 'Katılım min ${formatGuildCompact(guild.minJoinPower)} güç'
                      : 'Katılım güç limiti yok',
                  style: AppTextStyles.caption.copyWith(
                    color: GuildPalette.titanium,
                  ),
                ),
              ),
              if (onEditMinJoinPower != null)
                GuildPressable(
                  onTap: onEditMinJoinPower,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: GuildPalette.fuchsia.withValues(alpha: 0.45),
                      ),
                      color: GuildPalette.fuchsia.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      context.l10n.kat_l_m_g_limiti,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: GuildPalette.fuchsia,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  ],
),
);
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: GuildPalette.obsidian.withValues(alpha: 0.65),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: accent.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: GuildPalette.textHi,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuildCommandGrid extends StatelessWidget {
  const _GuildCommandGrid({
    required this.onGuildWar,
    required this.onMonument,
    required this.onVault,
    required this.vaultGoldLabel,
    required this.monumentLevel,
  });

  final VoidCallback onGuildWar;
  final VoidCallback onMonument;
  final VoidCallback onVault;
  final String vaultGoldLabel;
  final int monumentLevel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: GuildActionTile(
                title: context.l10n.lonca_sava,
                subtitle: 'Fetih & savunma',
                icon: Icons.flag_rounded,
                accent: GuildPalette.fuchsia,
                filled: true,
                onTap: onGuildWar,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GuildActionTile(
                title: 'Anıt',
                subtitle: 'Sv.$monumentLevel bağış',
                icon: Icons.account_balance_rounded,
                accent: GuildPalette.coral,
                onTap: onMonument,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GuildActionTile(
          title: 'Lonca Kasası',
          subtitle: '${vaultGoldLabel}g · yatırım & dağıtım',
          icon: Icons.savings_rounded,
          accent: GuildPalette.gold,
          onTap: onVault,
        ),
      ],
    );
  }
}

class _GuildMemberCard extends StatelessWidget {
  const _GuildMemberCard({
    required this.member,
    this.rank,
    required this.isMe,
    required this.canAct,
    required this.roleAccent,
    required this.roleBadge,
    required this.onTap,
    this.onLongPress,
    this.onStaffTap,
  });

  final GuildMemberData member;
  final int? rank;
  final bool isMe;
  final bool canAct;
  final Color roleAccent;
  final String roleBadge;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onStaffTap;

  Color get _rankColor {
    if (rank == 1) return GuildPalette.gold;
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return GuildPalette.titanium;
  }

  @override
  Widget build(BuildContext context) {
    final bool online = member.isOnline == true;

    return GuildPressable(
      enabled: canAct,
      onTap: canAct ? onTap : null,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                isMe
                    ? GuildPalette.fuchsia.withValues(alpha: 0.16)
                    : GuildPalette.surfaceHi.withValues(alpha: 0.9),
                GuildPalette.celestialVoid.withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: isMe
                  ? GuildPalette.fuchsia.withValues(alpha: 0.55)
                  : roleAccent.withValues(alpha: 0.28),
              width: isMe ? 1.4 : 1.0,
            ),
            boxShadow: isMe
                ? <BoxShadow>[
                    BoxShadow(
                      color: GuildPalette.fuchsia.withValues(alpha: 0.16),
                      blurRadius: 14,
                    ),
                  ]
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: <Widget>[
              // Rank indicator if available
              if (rank != null) ...<Widget>[
                SizedBox(
                  width: 26,
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _rankColor,
                    ),
                  ),
                ),
              ],
              // Avatar & Online Status
              Stack(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: roleAccent.withValues(alpha: 0.16),
                      border: Border.all(
                        color: roleAccent.withValues(alpha: 0.45),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: roleAccent.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      guildRoleEmoji(member.role),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online
                            ? GuildPalette.neon
                            : GuildPalette.obsidian,
                        border: Border.all(
                          color: GuildPalette.navy,
                          width: 1.5,
                        ),
                        boxShadow: online
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: GuildPalette.neon.withValues(
                                    alpha: 0.75,
                                  ),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Member Info & Contribution Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: PlayerNameLabel(
                            username: member.username,
                            staffBadge: member.staffBadge,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isMe
                                  ? GuildPalette.fuchsia
                                  : GuildPalette.textHi,
                            ),
                            compactBadge: true,
                            showUsername: false,
                            onTap: onStaffTap,
                          ),
                        ),
                        if (isMe) ...<Widget>[
                          const SizedBox(width: 4),
                          Text(
                            '(Ben)',
                            style: AppTextStyles.caption.copyWith(
                              color: GuildPalette.fuchsia,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Text(
                          'Sv.${member.level} · ${guildRoleLabel(member.role)}',
                          style: AppTextStyles.caption.copyWith(
                            color: GuildPalette.titanium,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: GuildPalette.titanium,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          member.contribution != null && member.contribution! > 0
                              ? '${formatGuildCompact(member.contribution!)} katkı'
                              : '${formatGuildCompact(member.power)} güç',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: member.contribution != null && member.contribution! > 0
                                ? GuildPalette.gold
                                : GuildPalette.solar,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: roleAccent.withValues(alpha: 0.16),
                  border: Border.all(color: roleAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  roleBadge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: roleAccent,
                  ),
                ),
              ),
              if (canAct) ...<Widget>[
                const SizedBox(width: 4),
                const Icon(
                  Icons.more_vert_rounded,
                  size: 16,
                  color: GuildPalette.titanium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kept for any external imports.
class GuildMemberTile extends StatelessWidget {
  const GuildMemberTile({
    super.key,
    required this.member,
    required this.isMe,
    required this.canAct,
    required this.onTap,
    this.onLongPress,
    this.onStaffTap,
  });

  final GuildMemberData member;
  final bool isMe;
  final bool canAct;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onStaffTap;

  @override
  Widget build(BuildContext context) {
    return _GuildMemberCard(
      member: member,
      isMe: isMe,
      canAct: canAct,
      roleAccent: switch (member.role) {
        GuildRole.leader => GuildPalette.gold,
        GuildRole.officer => GuildPalette.coral,
        GuildRole.member => GuildPalette.titanium,
      },
      roleBadge: switch (member.role) {
        GuildRole.leader => 'GM',
        GuildRole.officer => 'SUBAY',
        GuildRole.member => 'ÜYE',
      },
      onTap: onTap,
      onLongPress: onLongPress,
      onStaffTap: onStaffTap,
    );
  }
}

class GuildStatChip extends StatelessWidget {
  const GuildStatChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GuildStatPill(icon: icon, label: label);
  }
}
