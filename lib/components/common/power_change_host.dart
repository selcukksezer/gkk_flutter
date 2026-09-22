import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/power_change_provider.dart';
import '../../routing/app_router.dart';
import 'power_change_overlay.dart';

class PowerChangeHost extends ConsumerStatefulWidget {
  const PowerChangeHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PowerChangeHost> createState() => _PowerChangeHostState();
}

class _PowerChangeHostState extends ConsumerState<PowerChangeHost> {
  bool _showing = false;
  PowerChangeEvent? _queued;

  @override
  void initState() {
    super.initState();
    ref.listenManual<PowerChangeEvent?>(powerChangeProvider, _onPowerChange);
  }

  void _onPowerChange(PowerChangeEvent? prev, PowerChangeEvent? next) {
    if (next == null || _showing) {
      if (next != null && _showing) {
        _queued = next;
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _present(next));
  }

  BuildContext? _dialogContext() {
    final BuildContext? root = appRootNavigatorKey.currentContext;
    if (root != null && root.mounted) return root;
    if (mounted && context.mounted) return context;
    return null;
  }

  Future<void> _present(PowerChangeEvent event) async {
    if (!mounted || _showing) return;

    final BuildContext? dialogContext = _dialogContext();
    if (dialogContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _present(event));
      return;
    }

    setState(() => _showing = true);
    ref.read(powerChangeProvider.notifier).clear();

    try {
      await showPowerChangeOverlay(
        dialogContext,
        oldPower: event.oldPower,
        newPower: event.newPower,
      );
    } finally {
      if (mounted) setState(() => _showing = false);
      if (_queued != null && mounted) {
        final PowerChangeEvent pending = _queued!;
        _queued = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _present(pending));
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
