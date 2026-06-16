/// Schedules [action] after the current widget build / lifecycle turn completes.
///
/// Riverpod 3 rejects provider writes during `build`, `initState`, `ref.listen`
/// callbacks, and similar lifecycle hooks. Prefer this over [Future.microtask] or
/// bare [WidgetsBinding.instance.addPostFrameCallback] for notifier updates.
void deferProviderUpdate(void Function() action) {
  Future<void>(() => action());
}
