import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/provider_scheduling.dart';
import '../../core/utils/restriction_time.dart';
import '../../providers/player_provider.dart';

/// Shared 1-second countdown for hospital/prison restriction screens.
mixin RestrictionTimerMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Timer? restrictionTimer;
  Duration restrictionRemainingDuration = Duration.zero;
  int restrictionInitialSeconds = 0;
  bool _restrictionProfileListenerAttached = false;

  String? readRestrictionUntil();

  @override
  void dispose() {
    restrictionTimer?.cancel();
    super.dispose();
  }

  void attachRestrictionProfileListener() {
    if (_restrictionProfileListenerAttached) return;
    _restrictionProfileListenerAttached = true;
    ref.listenManual<PlayerState>(playerProvider, (
      PlayerState? previous,
      PlayerState next,
    ) {
      if (!mounted) return;
      deferProviderUpdate(() => updateRestrictionRemaining(isFirst: true));
    });
  }

  void startRestrictionTimer({bool attachProfileListener = false}) {
    if (attachProfileListener) attachRestrictionProfileListener();
    restrictionTimer?.cancel();
    updateRestrictionRemaining(isFirst: true);
    restrictionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      updateRestrictionRemaining();
    });
  }

  void updateRestrictionRemaining({bool isFirst = false}) {
    final String? until = readRestrictionUntil();
    if (until == null || until.isEmpty) {
      setState(() => restrictionRemainingDuration = Duration.zero);
      return;
    }

    final Duration remaining = restrictionRemaining(until);
    if (remaining > Duration.zero) {
      setState(() {
        restrictionRemainingDuration = remaining;
        if (isFirst) restrictionInitialSeconds = remaining.inSeconds;
      });
      return;
    }

    setState(() => restrictionRemainingDuration = Duration.zero);
    deferProviderUpdate(() {
      ref.read(playerProvider.notifier).loadProfile();
    });
  }

  bool get restrictionActive =>
      isRestrictionActive(readRestrictionUntil()) ||
      restrictionRemainingDuration > Duration.zero;

  double restrictionProgress() {
    if (restrictionInitialSeconds <= 0) return 0;
    return (1 -
            restrictionRemainingDuration.inSeconds /
                restrictionInitialSeconds)
        .clamp(0.0, 1.0);
  }
}
