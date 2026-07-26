import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/combat_restriction.dart';
import '../../models/player_model.dart';
import '../../providers/player_provider.dart';
import '../../providers/pvp_invite_provider.dart';
import '../../routing/app_router.dart';
import '../common/app_messenger.dart';
import '../common/profile_avatar.dart';
import 'pvp_duel_battle_screen.dart';

/// Global overlay: PvP düello daveti gelince her ekranda VS popup gösterir.
class PvpInviteHost extends ConsumerStatefulWidget {
  const PvpInviteHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PvpInviteHost> createState() => _PvpInviteHostState();
}

class _PvpInviteHostState extends ConsumerState<PvpInviteHost> {
  String? _openInviteId;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<PvpInviteState>(
      pvpInviteProvider,
      (PvpInviteState? previous, PvpInviteState next) {
        _schedule(next);
      },
      fireImmediately: true,
    );
  }

  void _schedule(PvpInviteState state) {
    if (_showing) return;
    final PvpInvite? invite = state.nextPopup;
    if (invite != null) {
      if (_openInviteId == invite.inviteId) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _present(invite));
      return;
    }
    _openInviteId = null;

    // Davet eden taraf: rakip yanıtladı, sonucu göster.
    final PvpDuelResultNotice? result = state.nextResult;
    if (result != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _presentResult(result));
      return;
    }

    final PvpArenaResultNotice? arenaResult = state.nextArenaResult;
    if (arenaResult != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _presentArenaResult(arenaResult));
    }
  }

  Future<void> _presentArenaResult(PvpArenaResultNotice notice) async {
    if (!mounted || _showing) return;
    final BuildContext? ctx = appRootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    _showing = true;
    await ref.read(pvpInviteProvider.notifier).markArenaResultSeen(notice.notificationId);

    final BuildContext? showCtx = appRootNavigatorKey.currentContext;
    if (showCtx != null && showCtx.mounted) {
      final String title = notice.won ? '🏆 Arena Galibiyeti' : '💀 Arena Yenilgisi';
      final Color accent = notice.won ? Colors.greenAccent : const Color(0xFFEF4444);
      await showDialog<void>(
        context: showCtx,
        builder: (BuildContext dCtx) => AlertDialog(
          backgroundColor: const Color(0xFF141B2A),
          title: Text(title, textAlign: TextAlign.center, style: TextStyle(color: accent, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                notice.won
                    ? '${notice.opponentName} oyuncusunu yendin!'
                    : '${notice.opponentName} seni arena\'da yendi.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              if (notice.wager > 0) ...[
                const SizedBox(height: 8),
                Text('Bahis: ${notice.wager} altın', style: const TextStyle(color: Colors.amber, fontSize: 12)),
              ],
              const SizedBox(height: 6),
              Text(
                'Rating: ${notice.ratingChange >= 0 ? '+' : ''}${notice.ratingChange}',
                style: TextStyle(color: notice.ratingChange >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 13),
              ),
            ],
          ),
          actions: <Widget>[
            FilledButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Tamam')),
          ],
        ),
      );
    }
    _showing = false;
  }

  Future<void> _presentResult(PvpDuelResultNotice notice) async {
    if (!mounted || _showing) return;
    final BuildContext? ctx = appRootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    _showing = true;
    await ref.read(pvpInviteProvider.notifier).markResultSeen(notice.inviteId);

    final BuildContext? showCtx = appRootNavigatorKey.currentContext;
    if (showCtx != null && showCtx.mounted) {
      if (notice.declined) {
        await showDialog<void>(
          context: showCtx,
          builder: (BuildContext dCtx) => AlertDialog(
            backgroundColor: const Color(0xFF141B2A),
            title: const Text(
              '🚫 Düello Reddedildi',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            content: Text(
              '${notice.opponentName} düello davetini reddetti.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.of(dCtx).pop(),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      } else if (notice.duel.isNotEmpty) {
        final String myAuthId =
            SupabaseService.client.auth.currentUser?.id ?? '';
        await PvpDuelBattleScreen.showForChallenger(
          showCtx,
          notice: notice,
          myAuthId: myAuthId,
        );
        await ref.read(playerProvider.notifier).loadProfile();
      }
    }

    if (mounted) {
      _showing = false;
      _schedule(ref.read(pvpInviteProvider));
    }
  }

  Future<void> _present(PvpInvite invite) async {
    if (!mounted || _showing) return;
    final BuildContext? dialogContext = appRootNavigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;

    _showing = true;
    _openInviteId = invite.inviteId;

    final bool? accept = await showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (BuildContext ctx) => _PvpVsDialog(
        invite: invite,
        myProfile: ref.read(playerProvider).profile,
      ),
    );

    if (accept == null) {
      ref.read(pvpInviteProvider.notifier).dismiss(invite.inviteId);
    } else {
      final Map<String, dynamic> res = await ref
          .read(pvpInviteProvider.notifier)
          .respond(inviteId: invite.inviteId, accept: accept);

      final BuildContext? resultContext = appRootNavigatorKey.currentContext;
      if (accept && resultContext != null && resultContext.mounted) {
        if (res['success'] == true && res['duel'] is Map) {
          final Map<String, dynamic> duel =
              Map<String, dynamic>.from(res['duel'] as Map);
          final String myAuthId =
              SupabaseService.client.auth.currentUser?.id ?? '';
          await PvpDuelBattleScreen.show(
            resultContext,
            invite: invite,
            duel: duel,
            myAuthId: myAuthId,
          );
          await ref.read(playerProvider.notifier).loadProfile();
        } else if (res['success'] != true && resultContext.mounted) {
          AppMessenger.showError(
            resultContext,
            (res['error'] ?? 'Düello başlatılamadı').toString(),
          );
        }
      }
    }

    if (mounted) {
      _showing = false;
      _schedule(ref.read(pvpInviteProvider));
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _PvpVsDialog extends StatelessWidget {
  const _PvpVsDialog({required this.invite, required this.myProfile});

  final PvpInvite invite;
  final PlayerProfile? myProfile;

  Widget _fighter({
    required String name,
    required String? avatarUrl,
    required int level,
    required int power,
    required Color accent,
  }) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.5),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ProfileAvatar(size: 64, avatarUrl: avatarUrl),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Lv.$level  ·  ⚡$power',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String myName = myProfile?.displayName ?? myProfile?.username ?? 'Sen';
    final String? combatBlock = combatRestrictionMessage(
      hospitalUntil: myProfile?.hospitalUntil,
      prisonUntil: myProfile?.prisonUntil,
    );

    return Dialog(
      backgroundColor: const Color(0xFF10131D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFFEF4444).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '⚔️ DÜELLO DAVETİ',
              style: TextStyle(
                color: Color(0xFFF5C842),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _fighter(
                  name: invite.challengerName,
                  avatarUrl: invite.challengerAvatar,
                  level: invite.challengerLevel,
                  power: invite.challengerPower,
                  accent: const Color(0xFFEF4444),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                _fighter(
                  name: myName,
                  avatarUrl: myProfile?.avatarUrl,
                  level: myProfile?.level ?? 1,
                  power: myProfile?.power ?? 0,
                  accent: const Color(0xFF3B82F6),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                invite.wager > 0
                    ? '💰 Bahis: ${invite.wager} altın'
                    : '🤝 Dostluk maçı (bahissiz)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (combatBlock != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                combatBlock,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      foregroundColor: const Color(0xFFEF4444),
                    ),
                    child: const Text('Reddet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: combatBlock != null
                        ? null
                        : () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      disabledBackgroundColor: Colors.white12,
                    ),
                    child: const Text(
                      '⚔️ Kabul Et',
                      style: TextStyle(fontWeight: FontWeight.w900),
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
