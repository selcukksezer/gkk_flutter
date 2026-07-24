import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/user_facing_error.dart';
import '../models/dungeon_siege_model.dart';
import '../repositories/dungeon_siege_repository.dart';

final Provider<DungeonSiegeRepository> dungeonSiegeRepositoryProvider =
    Provider<DungeonSiegeRepository>((Ref ref) => SupabaseDungeonSiegeRepository());

class DungeonSiegeState {
  const DungeonSiegeState({
    required this.loading,
    required this.status,
    this.hub,
    this.hubLoading = false,
    this.notifications = const <DungeonSiegeNotification>[],
    this.unreadNotificationCount = 0,
    this.errorMessage,
    this.actionLoading = false,
  });

  final bool loading;
  final DungeonSiegeStatus status;
  final DungeonSiegeHub? hub;
  final bool hubLoading;
  final List<DungeonSiegeNotification> notifications;
  final int unreadNotificationCount;
  final String? errorMessage;
  final bool actionLoading;

  factory DungeonSiegeState.initial() => DungeonSiegeState(
        loading: false,
        status: DungeonSiegeStatus.empty(),
      );

  DungeonSiegeState copyWith({
    bool? loading,
    DungeonSiegeStatus? status,
    DungeonSiegeHub? hub,
    bool? hubLoading,
    List<DungeonSiegeNotification>? notifications,
    int? unreadNotificationCount,
    String? errorMessage,
    bool? actionLoading,
    bool clearError = false,
  }) {
    return DungeonSiegeState(
      loading: loading ?? this.loading,
      status: status ?? this.status,
      hub: hub ?? this.hub,
      hubLoading: hubLoading ?? this.hubLoading,
      notifications: notifications ?? this.notifications,
      unreadNotificationCount: unreadNotificationCount ?? this.unreadNotificationCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actionLoading: actionLoading ?? this.actionLoading,
    );
  }
}

class DungeonSiegeNotifier extends Notifier<DungeonSiegeState> {
  DungeonSiegeRepository get _repository => ref.read(dungeonSiegeRepositoryProvider);

  int _statusRequestSeq = 0;
  String? _scopedDungeonId;

  @override
  DungeonSiegeState build() => DungeonSiegeState.initial();

  String? get scopedDungeonId => _scopedDungeonId;

  void clearScopedDungeon() {
    _scopedDungeonId = null;
  }

  String _message(Object error, String fallback) =>
      userFacingErrorMessage(error, fallback: fallback);

  String? _resolveQueryDungeonId(String? dungeonId) {
    if (dungeonId != null && dungeonId.isNotEmpty) {
      _scopedDungeonId = dungeonId;
      return dungeonId;
    }
    if (_scopedDungeonId != null && _scopedDungeonId!.isNotEmpty) {
      return _scopedDungeonId;
    }
    return null;
  }

  DungeonSiegeStatus _enrichForDungeon(DungeonSiegeStatus status, String? dungeonId) {
    if (dungeonId == null || dungeonId.isEmpty) return status;
    final bool holdsElsewhere = status.mySlotGlobalDungeonId != null &&
        status.mySlotGlobalDungeonId!.isNotEmpty &&
        status.mySlotGlobalDungeonId != dungeonId;
    return status.copyWith(
      holdsSlotElsewhere: holdsElsewhere,
      isBanned: status.isBannedForDungeon(dungeonId),
    );
  }

  Future<void> loadStatus({String? dungeonId, bool silent = false}) async {
    final String? queryDungeonId = _resolveQueryDungeonId(dungeonId);
    final int seq = ++_statusRequestSeq;

    if (!silent) {
      state = state.copyWith(loading: true, clearError: true);
    } else {
      state = state.copyWith(clearError: true);
    }
    try {
      final DungeonSiegeStatus raw =
          await _repository.getStatus(dungeonId: queryDungeonId);
      if (seq != _statusRequestSeq) return;

      final DungeonSiegeStatus status = _enrichForDungeon(raw, queryDungeonId);
      state = state.copyWith(loading: false, status: status);
    } catch (e) {
      if (seq != _statusRequestSeq) return;
      state = state.copyWith(
        loading: false,
        errorMessage: _message(e, 'Kuşatma durumu yüklenemedi.'),
      );
    }
  }

  Future<void> loadHub({bool includeNotifications = true, bool silent = false}) async {
    final bool showLoading = !silent || state.hub == null;
    if (showLoading) {
      state = state.copyWith(hubLoading: true, clearError: true);
    } else {
      state = state.copyWith(clearError: true);
    }
    try {
      final DungeonSiegeHub hub = await _repository.getHub();
      final String? scopedDungeonId = _scopedDungeonId;
      if (scopedDungeonId != null && scopedDungeonId.isNotEmpty) {
        // Hub poll is global — keep scoped dungeon status/enrichment intact.
        state = state.copyWith(hubLoading: false, hub: hub);
        await loadStatus(dungeonId: scopedDungeonId, silent: true);
      } else {
        state = state.copyWith(
          hubLoading: false,
          hub: hub,
          status: hub.status,
        );
      }
      if (includeNotifications) {
        await loadNotifications();
      }
    } catch (e) {
      state = state.copyWith(
        hubLoading: false,
        errorMessage: _message(e, 'Kuşatma merkezi yüklenemedi.'),
      );
    }
  }

  Future<void> loadNotifications() async {
    try {
      final ({List<DungeonSiegeNotification> notifications, int unreadCount}) result =
          await _repository.getNotifications();
      state = state.copyWith(
        notifications: result.notifications,
        unreadNotificationCount: result.unreadCount,
      );
    } catch (_) {
      // non-blocking
    }
  }

  Future<void> markAllNotificationsRead() async {
    await _repository.markNotificationsRead();
    await loadNotifications();
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _repository.markNotificationsRead(notificationIds: <String>[notificationId]);
    await loadNotifications();
  }

  bool get _actionBusy => state.actionLoading;

  Future<DungeonSiegeActionResult?> claimSlot(String dungeonId) async {
    if (_actionBusy) return null;
    state = state.copyWith(actionLoading: true, clearError: true);
    try {
      final DungeonSiegeActionResult result = await _repository.claimSlot(dungeonId);
      await loadStatus(dungeonId: dungeonId, silent: true);
      state = state.copyWith(actionLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(
        actionLoading: false,
        errorMessage: _message(e, 'Slot alınamadı.'),
      );
      return null;
    }
  }

  Future<DungeonSiegeActionResult?> challengeSlot({
    required String slotId,
    required String dungeonId,
  }) async {
    if (_actionBusy) return null;
    state = state.copyWith(actionLoading: true, clearError: true);
    try {
      final DungeonSiegeActionResult result = await _repository.challengeSlot(slotId);
      await loadStatus(dungeonId: dungeonId, silent: true);
      state = state.copyWith(actionLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(
        actionLoading: false,
        errorMessage: _message(e, 'Meydan okuma başarısız.'),
      );
      return null;
    }
  }

  Future<DungeonSiegeActionResult?> releaseSlot({
    required String slotId,
    required String dungeonId,
  }) async {
    if (_actionBusy) return null;
    state = state.copyWith(actionLoading: true, clearError: true);
    try {
      final DungeonSiegeActionResult result = await _repository.releaseSlot(slotId);
      await loadStatus(dungeonId: dungeonId, silent: true);
      state = state.copyWith(actionLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(
        actionLoading: false,
        errorMessage: _message(e, 'Slot bırakılamadı.'),
      );
      return null;
    }
  }

  Future<DungeonSiegeActionResult?> startGuildHold(String dungeonId) async {
    if (_actionBusy) return null;
    state = state.copyWith(actionLoading: true, clearError: true);
    try {
      final DungeonSiegeActionResult result = await _repository.startGuildHold(dungeonId);
      await loadStatus(dungeonId: dungeonId, silent: true);
      state = state.copyWith(actionLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(
        actionLoading: false,
        errorMessage: _message(e, 'Lonca hold başlatılamadı.'),
      );
      return null;
    }
  }
}

final NotifierProvider<DungeonSiegeNotifier, DungeonSiegeState> dungeonSiegeProvider =
    NotifierProvider<DungeonSiegeNotifier, DungeonSiegeState>(DungeonSiegeNotifier.new);
