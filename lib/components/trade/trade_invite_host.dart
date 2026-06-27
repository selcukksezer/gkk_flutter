import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/trade_invite_provider.dart';
import '../../routing/app_router.dart';
import 'trade_invite_dialog.dart';

/// Global overlay: shows trade invite popup on any screen.
class TradeInviteHost extends ConsumerStatefulWidget {
  const TradeInviteHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TradeInviteHost> createState() => _TradeInviteHostState();
}

class _TradeInviteHostState extends ConsumerState<TradeInviteHost> {
  String? _openDialogSessionId;
  bool _showingDialog = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<TradeInviteState>(
      tradeInviteProvider,
      (TradeInviteState? previous, TradeInviteState next) {
        _scheduleInvitePopup(next);
      },
      fireImmediately: true,
    );
  }

  void _scheduleInvitePopup(TradeInviteState inviteState) {
    if (_showingDialog) return;

    final TradeInvite? invite = inviteState.nextPopup;
    if (invite == null) {
      _openDialogSessionId = null;
      return;
    }
    if (_openDialogSessionId == invite.sessionId) return;

    WidgetsBinding.instance.addPostFrameCallback((_) => _presentInvite(invite));
  }

  Future<void> _presentInvite(TradeInvite invite) async {
    if (!mounted || _showingDialog) return;

    final BuildContext? dialogContext = appRootNavigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;

    _showingDialog = true;
    _openDialogSessionId = invite.sessionId;

    final bool responded = await showTradeInviteDialog(
      dialogContext,
      invite: invite,
      onRespond: (bool accept, bool block) {
        return ref.read(tradeInviteProvider.notifier).respond(
              sessionId: invite.sessionId,
              accept: accept,
              blockSender: block,
            );
      },
    );

    if (mounted) {
      if (!responded) {
        _openDialogSessionId = null;
      }
      _showingDialog = false;
      _scheduleInvitePopup(ref.read(tradeInviteProvider));
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
