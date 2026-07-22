import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/common/app_messenger.dart';
import '../../../models/dungeon_model.dart';
import '../../../models/dungeon_siege_model.dart';
import '../../../providers/dungeon_siege_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_colors.dart';

Future<void> showDungeonSiegePanel({
  required BuildContext context,
  required WidgetRef ref,
  required DungeonData dungeon,
}) async {
  await ref.read(dungeonSiegeProvider.notifier).loadStatus(dungeonId: dungeon.dungeonId);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return _DungeonSiegeSheet(dungeon: dungeon);
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

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      unawaited(
        ref.read(dungeonSiegeProvider.notifier).loadStatus(dungeonId: widget.dungeon.dungeonId),
      );
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1020),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFFEF4444), width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'KUŞATMA',
                      style: TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dungeon.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SiegeInfoStrip(status: status, config: config),
              if (status.isBanned) ...<Widget>[
                const SizedBox(height: 10),
                _SiegeWarningBanner(
                  text: 'Bu zindandan kuşatma kaybı banındasın.',
                  color: AppColors.warningSolar,
                ),
              ],
              if (!status.siegeActive) ...<Widget>[
                const SizedBox(height: 10),
                _SiegeWarningBanner(
                  text: status.enabled
                      ? 'Prime time dışında — kuşatma şu an kapalı.'
                      : 'Kuşatma sistemi kapalı (DB: is_enabled=false).',
                  color: Colors.white54,
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: siegeState.loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: slots.isEmpty ? 1 : slots.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          if (slots.isEmpty) {
                            return _SiegeEmptySlots(
                              actionLoading: siegeState.actionLoading,
                              onClaim: status.siegeActive &&
                                      !status.isBanned &&
                                      status.mySlotId == null
                                  ? () => _claim(context, ref)
                                  : null,
                            );
                          }
                          final DungeonSiegeSlot slot = slots[index];
                          return _SiegeSlotTile(
                            slot: slot,
                            actionLoading: siegeState.actionLoading,
                            challengeGoldCost: config.challengeGoldCost,
                            siegeActive: status.siegeActive,
                            isBanned: status.isBanned,
                            onClaim: status.siegeActive &&
                                    !slot.isOccupied &&
                                    !status.isBanned &&
                                    status.mySlotId == null
                                ? () => _claim(context, ref)
                                : null,
                            onChallenge: status.siegeActive &&
                                    slot.isOccupied &&
                                    !slot.isMine &&
                                    !status.isBanned
                                ? () => _challenge(context, ref, slot)
                                : null,
                            onRelease: slot.isMine
                                ? () => _release(context, ref, slot)
                                : null,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              if (status.siegeActive && status.mySlotId != null)
                Text(
                  'Slot #${status.mySlotNumber} sende — bonus: '
                  '+${(config.lootBonusPct * 100).round()}% loot, '
                  '+${(config.goldBonusPct * 100).round()}% gold, '
                  '+${(config.repBonusPct * 100).round()}% rep.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final DungeonSiegeActionResult? result =
        await ref.read(dungeonSiegeProvider.notifier).claimSlot(dungeon.dungeonId);
    if (!context.mounted || result == null) return;
    AppMessenger.show(
      context,
      result.success ? (result.message ?? 'Slot alındı.') : (result.error ?? 'Slot alınamadı.'),
    );
  }

  Future<void> _challenge(BuildContext context, WidgetRef ref, DungeonSiegeSlot slot) async {
    final DungeonSiegeConfig config = ref.read(dungeonSiegeProvider).status.config;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Meydan Oku', style: TextStyle(color: Colors.white)),
        content: Text(
          '${slot.holderName ?? 'Rakip'} slotunu almak için ${config.challengeGoldCost} altın harcanır. Kaybedersen ${config.banDurationMinutes} dk ban yersin.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Dövüş')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final DungeonSiegeActionResult? result = await ref
        .read(dungeonSiegeProvider.notifier)
        .challengeSlot(slotId: slot.slotId, dungeonId: dungeon.dungeonId);
    if (!context.mounted || result == null) return;
    AppMessenger.show(
      context,
      result.success ? (result.message ?? 'Düello bitti.') : (result.error ?? 'Meydan okuma başarısız.'),
    );
    if (result.success && result.youWon == true) {
      await ref.read(playerProvider.notifier).loadProfile();
    }
  }

  Future<void> _release(BuildContext context, WidgetRef ref, DungeonSiegeSlot slot) async {
    final DungeonSiegeActionResult? result = await ref
        .read(dungeonSiegeProvider.notifier)
        .releaseSlot(slotId: slot.slotId, dungeonId: dungeon.dungeonId);
    if (!context.mounted || result == null) return;
    AppMessenger.show(
      context,
      result.success ? (result.message ?? 'Slot bırakıldı.') : (result.error ?? 'Slot bırakılamadı.'),
    );
  }
}

class _SiegeInfoStrip extends StatelessWidget {
  const _SiegeInfoStrip({required this.status, required this.config});

  final DungeonSiegeStatus status;
  final DungeonSiegeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: <Widget>[
          _InfoChip(
            label: 'Durum',
            value: status.siegeActive ? 'AKTİF' : 'KAPALI',
            color: status.siegeActive ? const Color(0xFF22C55E) : Colors.white54,
          ),
          const SizedBox(width: 8),
          _InfoChip(
            label: 'Slot',
            value: '${config.slotCount}',
            color: const Color(0xFF60A5FA),
          ),
          const SizedBox(width: 8),
          _InfoChip(
            label: 'Meydan',
            value: '${config.challengeGoldCost}g',
            color: const Color(0xFFFBBF24),
          ),
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
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _SiegeEmptySlots extends StatelessWidget {
  const _SiegeEmptySlots({this.onClaim, this.actionLoading = false});

  final VoidCallback? onClaim;
  final bool actionLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'Henüz oturum yok. İlk slot alan kuşatmayı başlatır.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (onClaim != null) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: actionLoading ? null : onClaim,
              child: const Text('Slot Al'),
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
    required this.actionLoading,
    required this.challengeGoldCost,
    required this.siegeActive,
    required this.isBanned,
    this.onClaim,
    this.onChallenge,
    this.onRelease,
  });

  final DungeonSiegeSlot slot;
  final bool actionLoading;
  final int challengeGoldCost;
  final bool siegeActive;
  final bool isBanned;
  final VoidCallback? onClaim;
  final VoidCallback? onChallenge;
  final VoidCallback? onRelease;

  @override
  Widget build(BuildContext context) {
    final bool occupied = slot.isOccupied;
    final Color accent = slot.isMine
        ? const Color(0xFF22C55E)
        : occupied
            ? const Color(0xFFEF4444)
            : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: Text(
              '${slot.slotNumber}',
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  occupied ? (slot.holderName ?? 'Bilinmeyen') : 'Boş slot',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  occupied
                      ? 'Güç ${slot.holderPower}${slot.guildName != null ? ' · ${slot.guildName}' : ''}'
                      : 'Bonus farm için müsait',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          if (onRelease != null)
            TextButton(onPressed: actionLoading ? null : onRelease, child: const Text('Bırak'))
          else if (onChallenge != null)
            FilledButton(
              onPressed: actionLoading ? null : onChallenge,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: Text('Meydan Oku ($challengeGoldCostg)'),
            )
          else if (onClaim != null)
            FilledButton(
              onPressed: actionLoading ? null : onClaim,
              child: const Text('Slot Al'),
            )
          else if (!siegeActive)
            const Text('—', style: TextStyle(color: Colors.white24))
          else if (isBanned)
            const Text('Ban', style: TextStyle(color: AppColors.warningSolar, fontSize: 11))
          else if (slot.isMine)
            const Text('Sen', style: TextStyle(color: Color(0xFF86EFAC), fontSize: 11)),
        ],
      ),
    );
  }
}
