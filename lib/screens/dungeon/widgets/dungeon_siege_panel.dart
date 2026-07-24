import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../components/common/app_messenger.dart';
import '../../../core/utils/gold_format.dart';
import '../../../models/dungeon_model.dart';
import '../../../models/dungeon_siege_economy.dart';
import '../../../models/dungeon_siege_model.dart';
import '../../../models/player_model.dart';
import '../../../providers/dungeon_siege_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../siege_challenge_battle_screen.dart';
import 'dungeon_siege_design.dart';

Future<void> showDungeonSiegePanel({
  required BuildContext context,
  required WidgetRef ref,
  required DungeonData dungeon,
}) async {
  await ref.read(dungeonSiegeProvider.notifier).loadStatus(dungeonId: dungeon.dungeonId);
  if (!context.mounted) return;

  final String? error = ref.read(dungeonSiegeProvider).errorMessage;
  if (error != null) {
    AppMessenger.show(context, error);
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.carbonVoid.withValues(alpha: 0.55),
    builder: (BuildContext sheetContext) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: _DungeonSiegeSheet(dungeon: dungeon),
      );
    },
  );
}

class _DungeonSiegeSheet extends ConsumerStatefulWidget {
  const _DungeonSiegeSheet({required this.dungeon});

  final DungeonData dungeon;

  @override
  ConsumerState<_DungeonSiegeSheet> createState() => _DungeonSiegeSheetState();
}

class _DungeonSiegeSheetState extends ConsumerState<_DungeonSiegeSheet> {
  Timer? _pollTimer;
  bool _holdDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      unawaited(
        ref.read(dungeonSiegeProvider.notifier).loadStatus(
              dungeonId: widget.dungeon.dungeonId,
              silent: true,
            ),
      );
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    ref.read(dungeonSiegeProvider.notifier).clearScopedDungeon();
    super.dispose();
  }

  DungeonData get dungeon => widget.dungeon;

  @override
  Widget build(BuildContext context) {
    final DungeonSiegeState siegeState = ref.watch(dungeonSiegeProvider);
    final DungeonSiegeStatus status = siegeState.status;
    final DungeonSiegeSession? session = status.sessionForDungeon(dungeon.dungeonId);
    final List<DungeonSiegeSlot> slots = session?.slots ?? const <DungeonSiegeSlot>[];
    final DungeonSiegeConfig config = status.config;
    final String? myGuildId = ref.watch(playerProvider).profile?.guildId;
    final bool hasSlotHere = session?.slots.any((DungeonSiegeSlot s) => s.isMine) ?? false;
    final bool holdsSlotElsewhere = status.mySlotGlobalDungeonId != null &&
        status.mySlotGlobalDungeonId!.isNotEmpty &&
        status.mySlotGlobalDungeonId != dungeon.dungeonId;
    final bool isBannedHere = status.isBannedForDungeon(dungeon.dungeonId);
    final bool canClaimHere =
        status.siegeActive && !isBannedHere && !hasSlotHere && !holdsSlotElsewhere;
    final int challengeGoldCost = DungeonSiegeEconomy.challengeGoldForDungeon(dungeon);
    final bool showInitialLoader = siegeState.loading && slots.isEmpty;

    return SiegeSheetShell(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SiegeHandle(),
              Row(
                children: <Widget>[
                  const SiegeTag(label: 'Kuşatma'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dungeon.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SiegePressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SiegePalette.obsidian.withValues(alpha: 0.6),
                        border: Border.all(color: SiegePalette.titanium.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.close_rounded, color: SiegePalette.titanium, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SiegeInfoStrip(status: status, config: config, session: session, myGuildId: myGuildId, challengeGoldCost: challengeGoldCost),
              if (session != null) ...<Widget>[
                const SizedBox(height: 10),
                _SiegeHoldStrip(
                  session: session,
                  config: config,
                  siegeActive: status.siegeActive,
                  actionLoading: siegeState.actionLoading || _holdDialogOpen,
                  myGuildId: myGuildId,
                  hasMySlot: hasSlotHere,
                  onStartHold: status.siegeActive && hasSlotHere ? () => _startHold(context, ref) : null,
                ),
              ],
              if (isBannedHere) ...<Widget>[
                const SizedBox(height: 10),
                _SiegeWarningBanner(
                  text: 'Bu zindandan kuşatma kaybı banındasın — meydan okuyamazsın.',
                  color: SiegePalette.solar,
                ),
              ],
              if (holdsSlotElsewhere) ...<Widget>[
                const SizedBox(height: 10),
                _SiegeWarningBanner(
                  text:
                      'Başka zindanda kuşatma slotu tutuyorsun'
                      '${status.mySlotGlobalDungeonId != null ? ' (${status.mySlotGlobalDungeonId})' : ''}. '
                      'Önce onu bırak.',
                  color: SiegePalette.ruby,
                ),
              ],
              if (!status.siegeActive) ...<Widget>[
                const SizedBox(height: 10),
                _SiegeWarningBanner(
                  text: status.enabled
                      ? 'Prime time dışında — kuşatma şu an kapalı.'
                      : 'Kuşatma geçici olarak kapalı.',
                  color: SiegePalette.titanium,
                ),
              ],
              if (status.siegeActive && !hasSlotHere) ...<Widget>[
                const SizedBox(height: 10),
                _SiegeWarningBanner(
                  text:
                      'Prime aktif — bu zindanda slotun yok: normal ödül. Bonus: '
                      '${DungeonSiegeConfig.farmBonusSummary(config)}',
                  color: SiegePalette.solar,
                ),
              ],
              if (canClaimHere && status.siegeActive && slots.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                SiegeGoldButton(
                  label: siegeState.actionLoading ? 'Alınıyor...' : 'Slot Al',
                  onPressed: siegeState.actionLoading ? null : () => _claim(context, ref),
                ),
                const SizedBox(height: 4),
                Text(
                  'İlk uygun boş slota otomatik yerleşir (rezerv slotlar hariç).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SiegePalette.titanium.withValues(alpha: 0.85),
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: showInitialLoader
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: SiegePalette.gold),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: slots.isEmpty ? 1 : slots.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (BuildContext context, int index) {
                          if (slots.isEmpty) {
                            return _SiegeEmptySlots(
                              actionLoading: siegeState.actionLoading,
                              onClaim: canClaimHere ? () => _claim(context, ref) : null,
                            );
                          }
                          final DungeonSiegeSlot slot = slots[index];
                          final bool reservedBlocked = slot.isTerritoryReserved &&
                              !slot.isOccupied &&
                              session != null &&
                              session.territoryOwnerGuildId != null &&
                              myGuildId != session.territoryOwnerGuildId;
                          return SiegeFadeSlide(
                            index: index,
                            child:                             _SiegeSlotTile(
                              slot: slot,
                              session: session,
                              actionLoading: siegeState.actionLoading,
                              challengeGoldCost: challengeGoldCost,
                              siegeActive: status.siegeActive,
                              isBanned: isBannedHere,
                              reservedBlocked: reservedBlocked,
                              onChallenge: status.canChallengeSlot(dungeon.dungeonId, slot)
                                  ? () => _challenge(context, ref, slot)
                                  : null,
                              onRelease: slot.isMine ? () => _release(context, ref, slot) : null,
                            ),
                          );
                        },
                      ),
              ),
              if (status.siegeActive && hasSlotHere) ...<Widget>[
                const SizedBox(height: 12),
                SiegeDottedPanel(
                  borderColor: SiegePalette.neon.withValues(alpha: 0.35),
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    () {
                      final bool holdBonus = session?.hold != null &&
                          session!.hold!.holdId.isNotEmpty &&
                          myGuildId != null &&
                          session.hold!.guildId == myGuildId;
                      return 'Slot #${status.mySlotNumber} sende — bonus: '
                          '${DungeonSiegeConfig.farmBonusSummary(config, holdBonus: holdBonus)}'
                          '${holdBonus ? ' (hold dahil)' : ''}.';
                    }(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SiegePalette.neon, fontSize: 11, height: 1.35),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final DungeonSiegeActionResult? result =
        await ref.read(dungeonSiegeProvider.notifier).claimSlot(dungeon.dungeonId);
    if (!context.mounted) return;
    if (result == null) {
      final String? err = ref.read(dungeonSiegeProvider).errorMessage;
      if (err != null) AppMessenger.show(context, err);
      return;
    }
    AppMessenger.show(
      context,
      result.success
          ? (result.message ?? 'Slot alındı.')
          : userFacingErrorMessage(result.error ?? 'Slot alınamadı.', fallback: 'Slot alınamadı.'),
    );
  }

  Future<void> _challenge(BuildContext context, WidgetRef ref, DungeonSiegeSlot slot) async {
    final DungeonSiegeStatus status = ref.read(dungeonSiegeProvider).status;
    if (!status.canChallengeSlot(dungeon.dungeonId, slot)) {
      AppMessenger.show(
        context,
        status.hasSlotInDungeon(dungeon.dungeonId)
            ? 'Zaten slot tutuyorsun; başka slota meydan okuyamazsın.'
            : 'Meydan okuma şu an mümkün değil.',
      );
      return;
    }

    final DungeonSiegeConfig config = status.config;
    final int challengeCost = DungeonSiegeEconomy.challengeGoldForDungeon(dungeon);
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    final int playerGold = profile?.gold ?? 0;
    if (playerGold < challengeCost) {
      AppMessenger.showError(
        context,
        'Yetersiz altın. Gerekli: ${formatCompactGold(challengeCost)} · Bakiye: ${formatCompactGold(playerGold)}',
      );
      return;
    }

    final DungeonSiegeSession? session = status.sessionForDungeon(dungeon.dungeonId);
    final int defenderPower = session?.effectiveSiegePowerForSlot(slot) ?? slot.holderPower;
    final int baseAttackerPower =
        (profile?.power ?? 0) > 0 ? profile!.power : (profile?.attack ?? 0) + (profile?.defense ?? 0);
    final int attackerPower = DungeonSiegeConfig.siegeChallengePower(
      baseAttackerPower,
      shadowClass: profile?.characterClass == CharacterClass.shadow,
    );
    if (DungeonSiegeConfig.exceedsChallengePowerBand(
      attackerPower: attackerPower,
      defenderPower: defenderPower,
      powerBandPct: config.powerBandPct,
    )) {
      AppMessenger.showError(context, DungeonSiegeConfig.challengePowerBandError(config.powerBandPct));
      return;
    }

    final String bandText = config.powerBandPct > 0
        ? ' Güç farkı ±${(config.powerBandPct * 100).round()}% bandında olmalı.'
        : '';
    final String cooldownText = config.challengeCooldownMinutes > 0
        ? ' Tekrar meydan okuma: ${config.challengeCooldownMinutes} dk bekleme.'
        : '';
    final bool? confirm = await SiegeDialog.confirm(
      context: context,
      title: 'Meydan Oku',
      message:
          '${slot.holderName ?? 'Rakip'} slotunu almak için ${formatCompactGold(challengeCost)} altın harcanır. '
          'Kaybedersen ${config.banDurationMinutes} dk ban yersin.$bandText$cooldownText',
      confirmLabel: 'Dövüş',
    );
    if (confirm != true || !context.mounted) return;

    final SiegeChallengeBattleArgs args = SiegeChallengeBattleArgs(
      slotId: slot.slotId,
      dungeonId: dungeon.dungeonId,
      dungeonName: dungeon.name,
      zone: dungeon.zone,
      slotNumber: slot.slotNumber,
      defenderName: slot.holderName ?? 'Rakip',
      defenderPower: session?.effectiveSiegePowerForSlot(slot) ?? slot.holderPower,
      defenderGuildName: slot.guildName,
      challengeGoldCost: challengeCost,
    );

    Navigator.of(context).pop();
    if (!context.mounted) return;

    await SiegeChallengeBattleScreen.open(context, args: args);

    if (!context.mounted) return;
    await ref.read(dungeonSiegeProvider.notifier).loadStatus(
          dungeonId: dungeon.dungeonId,
          silent: true,
        );
  }

  Future<void> _release(BuildContext context, WidgetRef ref, DungeonSiegeSlot slot) async {
    final DungeonSiegeActionResult? result = await ref
        .read(dungeonSiegeProvider.notifier)
        .releaseSlot(slotId: slot.slotId, dungeonId: dungeon.dungeonId);
    if (!context.mounted) return;
    if (result == null) {
      final String? err = ref.read(dungeonSiegeProvider).errorMessage;
      if (err != null) AppMessenger.show(context, err);
      return;
    }
    AppMessenger.show(
      context,
      result.success ? (result.message ?? 'Slot bırakıldı.') : (result.error ?? 'Slot bırakılamadı.'),
    );
  }

  Future<void> _startHold(BuildContext context, WidgetRef ref) async {
    if (_holdDialogOpen || ref.read(dungeonSiegeProvider).actionLoading) return;

    final DungeonSiegeStatus status = ref.read(dungeonSiegeProvider).status;
    final DungeonSiegeConfig config = status.config;
    final DungeonSiegeSession? session = status.sessionForDungeon(dungeon.dungeonId);
    final String? myGuildId = ref.read(playerProvider).profile?.guildId;

    if (session == null || !session.canStartHold(config, myGuildId: myGuildId)) {
      final int holdMin = session?.holdMinRequired(config, myGuildId: myGuildId) ?? config.holdMinMembers;
      AppMessenger.show(
        context,
        'Hold için en az $holdMin lonca üyesi slot tutmalı (${session?.guildSlots ?? 0}/$holdMin).',
      );
      return;
    }

    final int holdMin = session.holdMinRequired(config, myGuildId: myGuildId);
    setState(() => _holdDialogOpen = true);
    final bool? confirm = await SiegeDialog.confirm(
      context: context,
      title: 'Lonca Hold',
      message:
          'En az $holdMin lonca üyesi slot tutunca hold başlar. '
          'Ek +${(config.holdBonusPct * 100).round()}% bonus. '
          'Rakip ${config.holdBreakWinsRequired} galibiyetle kırabilir.',
      confirmLabel: 'Hold Başlat',
    );
    if (!mounted) return;
    setState(() => _holdDialogOpen = false);
    if (confirm != true) return;

    final DungeonSiegeActionResult? result =
        await ref.read(dungeonSiegeProvider.notifier).startGuildHold(dungeon.dungeonId);
    if (!context.mounted) return;
    if (result == null) {
      final String? err = ref.read(dungeonSiegeProvider).errorMessage;
      if (err != null) AppMessenger.show(context, err);
      return;
    }
    AppMessenger.show(
      context,
      result.success
          ? (result.message ?? 'Hold başladı.')
          : userFacingErrorMessage(result.error ?? 'Hold başlatılamadı.', fallback: 'Hold başlatılamadı.'),
    );
  }
}

class _SiegeHoldStrip extends StatelessWidget {
  const _SiegeHoldStrip({
    required this.session,
    required this.config,
    required this.siegeActive,
    required this.actionLoading,
    this.myGuildId,
    this.hasMySlot = false,
    this.onStartHold,
  });

  final DungeonSiegeSession session;
  final DungeonSiegeConfig config;
  final bool siegeActive;
  final bool actionLoading;
  final String? myGuildId;
  final bool hasMySlot;
  final VoidCallback? onStartHold;

  @override
  Widget build(BuildContext context) {
    final DungeonSiegeHold? hold = session.hold;
    final bool hasHold = hold != null && hold.holdId.isNotEmpty;
    final int holdMin = session.holdMinRequired(config, myGuildId: myGuildId);
    final bool ownerBlocked = session.hasTerritoryOwner &&
        (myGuildId == null || myGuildId != session.territoryOwnerGuildId);
    final bool canStart = siegeActive &&
        !hasHold &&
        !ownerBlocked &&
        hasMySlot &&
        session.canStartHold(config, myGuildId: myGuildId) &&
        onStartHold != null;

    return SiegeNeonCard(
      accent: hasHold ? SiegePalette.ruby : SiegePalette.fuchsia,
      glow: hasHold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.flag_rounded, color: SiegePalette.ruby, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Lonca Hold',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const Spacer(),
              SiegeStatChip(
                emoji: '👥',
                label: '${session.guildSlots}/$holdMin',
                accent: SiegePalette.gold,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasHold)
            Text(
              '${hold.guildName ?? 'Lonca'} hold aktif · kırılma ${hold.breakProgress}/${hold.breakRequired}',
              style: const TextStyle(color: SiegePalette.ruby, fontSize: 11, fontWeight: FontWeight.w700),
            )
          else if (ownerBlocked)
            Text(
              'Hold yalnızca bölge sahibi ${session.territoryOwnerGuildName ?? 'lonca'} başlatabilir.',
              style: const TextStyle(color: SiegePalette.coral, fontSize: 11, fontWeight: FontWeight.w700),
            )
          else if (session.hasTerritoryOwner)
            Text(
              'Bölge sahibi hold · rezerv slot #${config.territoryReserveSlotCount}',
              style: const TextStyle(color: SiegePalette.gold, fontSize: 11),
            )
          else
            Text(
              'Hold için loncada $holdMin+ slot gerekli.',
              style: const TextStyle(color: SiegePalette.titanium, fontSize: 11),
            ),
          if (!hasHold) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Hold aktif → ek +${(config.holdBonusPct * 100).round()}% loot & altın.',
              style: TextStyle(
                color: SiegePalette.gold.withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (session.territoryDefensePower > 0) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              DungeonSiegeConfig.territoryDefenseSessionLabel(
                defensePower: session.territoryDefensePower,
                myBonusPercent: session.territoryDefenseSiegeBonusPercent,
                maxBonusPercent: session.territoryDefenseMaxBonusPercent,
                receivesBonus: session.receivesTerritoryDefenseBonus(myGuildId),
              ),
              style: TextStyle(
                color: session.receivesTerritoryDefenseBonus(myGuildId)
                    ? SiegePalette.neon
                    : SiegePalette.titanium,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!hasHold && siegeActive && session.guildSlots < holdMin && !ownerBlocked) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Hold için $holdMin üye slot tutmalı (${session.guildSlots}/$holdMin).',
              style: TextStyle(
                color: SiegePalette.solar.withValues(alpha: 0.95),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (canStart) ...<Widget>[
            const SizedBox(height: 10),
            SiegeOutlineButton(
              label: actionLoading ? 'Başlatılıyor...' : 'Hold Başlat',
              accent: SiegePalette.ruby,
              icon: Icons.flag_rounded,
              onPressed: actionLoading ? null : onStartHold,
            ),
          ],
        ],
      ),
    );
  }
}

class _SiegeInfoStrip extends StatelessWidget {
  const _SiegeInfoStrip({
    required this.status,
    required this.config,
    required this.challengeGoldCost,
    this.session,
    this.myGuildId,
  });

  final DungeonSiegeStatus status;
  final DungeonSiegeConfig config;
  final int challengeGoldCost;
  final DungeonSiegeSession? session;
  final String? myGuildId;

  @override
  Widget build(BuildContext context) {
    return SiegeDottedPanel(
      borderColor: SiegePalette.gold.withValues(alpha: 0.28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              _InfoChip(
                label: 'Durum',
                value: status.siegeActive ? 'AKTİF' : 'KAPALI',
                color: status.siegeActive ? SiegePalette.neon : SiegePalette.titanium,
              ),
              _InfoChip(label: 'Slot', value: '${config.slotCount}', color: SiegePalette.gold),
              _InfoChip(label: 'Meydan', value: formatCompactGold(challengeGoldCost), color: SiegePalette.coral),
            ],
          ),
          if (session != null && session!.territoryDefensePower > 0) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              session!.receivesTerritoryDefenseBonus(myGuildId)
                  ? '🛡 Owner lonca slotları +${session!.territoryDefenseSiegeBonusPercent}% güç (elmas savunması dahil).'
                  : '🛡 Bölge savunması ${session!.territoryDefensePower} — owner +${session!.territoryDefenseMaxBonusPercent}% alır.',
              style: const TextStyle(color: SiegePalette.neon, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(label, style: const TextStyle(color: SiegePalette.titanium, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SiegeWarningBanner extends StatelessWidget {
  const _SiegeWarningBanner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SiegeDottedPanel(
      borderColor: color.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 11, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _SiegeEmptySlots extends StatelessWidget {
  const _SiegeEmptySlots({this.onClaim, this.actionLoading = false});

  final VoidCallback? onClaim;
  final bool actionLoading;

  @override
  Widget build(BuildContext context) {
    return SiegeNeonCard(
      accent: SiegePalette.gold,
      child: Column(
        children: <Widget>[
          const Text('🏰', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          const Text(
            'Slot Al — kuşatma oturumu otomatik açılır.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SiegePalette.titanium, fontSize: 12, height: 1.35),
          ),
          if (onClaim != null) ...<Widget>[
            const SizedBox(height: 12),
            SiegeGoldButton(
              label: actionLoading ? 'Alınıyor...' : 'Slot Al',
              onPressed: actionLoading ? null : onClaim,
            ),
          ],
        ],
      ),
    );
  }
}

class _SiegeSlotTile extends StatelessWidget {
  const _SiegeSlotTile({
    required this.slot,
    required this.session,
    required this.actionLoading,
    required this.challengeGoldCost,
    required this.siegeActive,
    required this.isBanned,
    this.reservedBlocked = false,
    this.onChallenge,
    this.onRelease,
  });

  final DungeonSiegeSlot slot;
  final DungeonSiegeSession? session;
  final bool actionLoading;
  final int challengeGoldCost;
  final bool siegeActive;
  final bool isBanned;
  final bool reservedBlocked;
  final VoidCallback? onChallenge;
  final VoidCallback? onRelease;

  @override
  Widget build(BuildContext context) {
    final bool occupied = slot.isOccupied;
    final int displayPower = session?.effectiveSiegePowerForSlot(slot) ?? slot.holderPower;
    final bool hasDefenseBonus =
        session != null && session!.slotReceivesTerritoryDefenseBonus(slot) && displayPower > slot.holderPower;
    final Color accent = slot.isMine
        ? SiegePalette.neon
        : slot.isTerritoryReserved
            ? SiegePalette.gold
            : occupied
                ? SiegePalette.ruby
                : SiegePalette.titanium;

    return SiegeNeonCard(
      accent: accent,
      glow: slot.isMine || (occupied && !slot.isMine),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: <Color>[accent.withValues(alpha: 0.28), SiegePalette.navy],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
              boxShadow: <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 10)],
            ),
            child: Text(
              '${slot.slotNumber}',
              style: TextStyle(color: accent, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        occupied ? (slot.holderName ?? 'Bilinmeyen') : 'Boş slot',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (slot.isTerritoryReserved && !reservedBlocked)
                      const SiegeTag(label: 'Rezerv', accent: SiegePalette.gold, compact: true),
                  ],
                ),
                Text(
                  occupied
                      ? 'Güç $displayPower${hasDefenseBonus ? ' (+${session!.territoryDefenseMaxBonusPercent}% bölge)' : ''}${slot.guildName != null ? ' · ${slot.guildName}' : ''}'
                      : reservedBlocked
                          ? 'Bölge sahibi lonca rezervi'
                          : 'Bonus farm için müsait',
                  style: const TextStyle(color: SiegePalette.titanium, fontSize: 11),
                ),
                if (slot.expiresAt != null && occupied)
                  Text(
                    'Bitiş: ${slot.expiresAt}',
                    style: TextStyle(color: SiegePalette.titanium.withValues(alpha: 0.65), fontSize: 10),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SlotAction(
            actionLoading: actionLoading,
            challengeGoldCost: challengeGoldCost,
            onRelease: onRelease,
            onChallenge: onChallenge,
            reservedBlocked: reservedBlocked,
            siegeActive: siegeActive,
            isBanned: isBanned,
            slot: slot,
          ),
        ],
      ),
    );
  }
}

class _SlotAction extends StatelessWidget {
  const _SlotAction({
    required this.actionLoading,
    required this.challengeGoldCost,
    required this.slot,
    required this.siegeActive,
    required this.isBanned,
    required this.reservedBlocked,
    this.onRelease,
    this.onChallenge,
  });

  final bool actionLoading;
  final int challengeGoldCost;
  final DungeonSiegeSlot slot;
  final bool siegeActive;
  final bool isBanned;
  final bool reservedBlocked;
  final VoidCallback? onRelease;
  final VoidCallback? onChallenge;

  @override
  Widget build(BuildContext context) {
    if (isBanned) {
      return const SiegeTag(label: 'BANNED', accent: SiegePalette.solar, compact: true);
    }
    if (onRelease != null) {
      return SiegeOutlineButton(
        label: 'Bırak',
        expand: false,
        accent: SiegePalette.neon,
        onPressed: actionLoading ? null : onRelease,
      );
    }
    if (onChallenge != null) {
      return SizedBox(
        width: 118,
        child: SiegeChallengeButton(
          label: 'Meydan ${formatCompactGold(challengeGoldCost)}',
          onPressed: actionLoading ? null : onChallenge,
        ),
      );
    }
    if (reservedBlocked) {
      return const SiegeTag(label: 'REZERV', accent: SiegePalette.gold, compact: true);
    }
    if (!siegeActive) {
      return const Text('—', style: TextStyle(color: SiegePalette.titanium));
    }
    if (!slot.isOccupied && !slot.isMine) {
      return const SiegeTag(label: 'Müsait', accent: SiegePalette.titanium, compact: true);
    }
    if (slot.isMine) {
      return const SiegeTag(label: 'Sen', accent: SiegePalette.neon, compact: true);
    }
    return const SizedBox.shrink();
  }
}
