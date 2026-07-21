import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'level_up_dialog.dart';

class LevelUpHost extends ConsumerStatefulWidget {
  const LevelUpHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LevelUpHost> createState() => _LevelUpHostState();
}

class _LevelUpHostState extends ConsumerState<LevelUpHost> {
  int? _lastLevel;
  bool _showing = false;
  _PendingLevelUp? _queued;

  @override
  void initState() {
    super.initState();
    ref.listenManual<PlayerState>(playerProvider, _onPlayerState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastLevel ??= ref.read(playerProvider).profile?.level;
    });
  }

  void _onPlayerState(PlayerState? prev, PlayerState next) {
    final int? nextLevel = next.profile?.level;
    if (nextLevel == null) return;

    final int? prevLevel = prev?.profile?.level ?? _lastLevel;

    if (prevLevel != null && nextLevel > prevLevel && !_showing) {
      _lastLevel = nextLevel;
      _queueLevelUp(
        oldLevel: prevLevel,
        newLevel: nextLevel,
        statPoints: next.profile?.statPoints ?? 0,
      );
      return;
    }

    _lastLevel ??= nextLevel;
  }

  void _queueLevelUp({
    required int oldLevel,
    required int newLevel,
    required int statPoints,
  }) {
    _queued = _PendingLevelUp(
      oldLevel: oldLevel,
      newLevel: newLevel,
      statPoints: statPoints,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _flushQueue());
  }

  Future<void> _flushQueue() async {
    if (_showing || _queued == null) return;
    final _PendingLevelUp pending = _queued!;
    _queued = null;
    await _presentLevelUp(pending);
    if (_queued != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushQueue());
    }
  }

  BuildContext? _dialogContext() {
    final BuildContext? root = appRootNavigatorKey.currentContext;
    if (root != null && root.mounted) return root;
    if (mounted && context.mounted) return context;
    return null;
  }

  Future<void> _presentLevelUp(_PendingLevelUp pending) async {
    if (!mounted) return;

    final BuildContext? dialogContext = _dialogContext();
    if (dialogContext == null) {
      _queued = pending;
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushQueue());
      return;
    }

    setState(() => _showing = true);
    try {
      await showLevelUpDialog(
        dialogContext,
        oldLevel: pending.oldLevel,
        newLevel: pending.newLevel,
        statPoints: pending.statPoints,
      );
    } finally {
      if (mounted) setState(() => _showing = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PendingLevelUp {
  const _PendingLevelUp({
    required this.oldLevel,
    required this.newLevel,
    required this.statPoints,
  });

  final int oldLevel;
  final int newLevel;
  final int statPoints;
}
