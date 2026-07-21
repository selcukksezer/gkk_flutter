import 'dart:async';

import '../../models/facility_model.dart';
import '../../models/notification_item.dart';
import '../../models/player_model.dart';
import '../../providers/box_opening_provider.dart';
import '../../routing/app_router.dart';
import '../utils/restriction_time.dart';
import 'local_notification_service.dart';
import 'supabase_service.dart';

/// Zamanlı telefon bildirimlerini oyun durumuna göre senkronlar.
class GameNotificationScheduler {
  GameNotificationScheduler._();

  static final GameNotificationScheduler instance = GameNotificationScheduler._();

  static const int hospitalReleaseId = 1001;
  static const int prisonReleaseId = 1002;
  static const int boxIdBase = 2000;
  static const int facilityIdBase = 3000;
  static const int inboxPushIdBase = 4000;

  final LocalNotificationService _notifications = LocalNotificationService.instance;

  int _boxNotificationId(String openingId) =>
      boxIdBase + (openingId.hashCode.abs() % 7000);

  int _facilityNotificationId(String facilityId, String queueItemId) =>
      facilityIdBase + ('$facilityId:$queueItemId'.hashCode.abs() % 7000);

  int inboxPushNotificationId(String notificationItemId) =>
      inboxPushIdBase + (notificationItemId.hashCode.abs() % 5000);

  Future<void> syncProfile(PlayerProfile? profile) async {
    if (profile == null) {
      await _notifications.cancel(hospitalReleaseId);
      await _notifications.cancel(prisonReleaseId);
      return;
    }

    await _syncRestriction(
      id: hospitalReleaseId,
      untilRaw: profile.hospitalUntil,
      title: 'Hastaneden çıktın',
      body: 'İyileşme süren bitti — oyuna dönebilirsin.',
      routePath: AppRoutes.hospital,
    );

    await _syncRestriction(
      id: prisonReleaseId,
      untilRaw: profile.prisonUntil,
      title: 'Cezaevinden çıktın',
      body: 'Serbest kaldın — hareketlerin tekrar açık.',
      routePath: AppRoutes.prison,
    );
  }

  Future<void> _syncRestriction({
    required int id,
    required String? untilRaw,
    required String title,
    required String body,
    required String routePath,
  }) async {
    final DateTime? release = parseRestrictionUntil(untilRaw);
    if (release == null || !release.isAfter(DateTime.now())) {
      await _notifications.cancel(id);
      return;
    }

    await _notifications.scheduleAt(
      id: id,
      title: title,
      body: body,
      when: release,
      payload: routePath,
    );
  }

  Future<void> syncBoxOpenings(List<BoxOpening> openings) async {
    for (final BoxOpening box in openings) {
      final int id = _boxNotificationId(box.openingId);
      if (box.isReady || !box.opensAt.toLocal().isAfter(DateTime.now())) {
        await _notifications.cancel(id);
        continue;
      }

      await _notifications.scheduleAt(
        id: id,
        title: 'Kasa açılmaya hazır',
        body: '${box.boxName} kasasını açabilirsin.',
        when: box.opensAt.toLocal(),
        payload: AppRoutes.inventory,
      );
    }
  }

  Future<void> syncFacilities(List<PlayerFacility> facilities) async {
    for (final PlayerFacility facility in facilities) {
      for (final FacilityQueueItem item in facility.facilityQueue) {
        final int id = _facilityNotificationId(facility.id, item.id);
        if (item.isCompleted) {
          await _notifications.cancel(id);
          continue;
        }

        final DateTime? completesAt = parseRestrictionUntil(item.completesAt);
        if (completesAt == null || !completesAt.isAfter(DateTime.now())) {
          await _notifications.cancel(id);
          continue;
        }

        await _notifications.scheduleAt(
          id: id,
          title: 'Tesis üretimi hazır',
          body: '${_facilityLabel(facility.facilityType)} — kaynakları topla.',
          when: completesAt,
          payload: '${AppRoutes.facilities}/${facility.facilityType}',
        );
      }
    }
  }

  Future<void> syncFacilitiesFromServer() async {
    if (!SupabaseService.isInitialized) return;
    if (SupabaseService.client.auth.currentUser == null) return;

    try {
      final dynamic response =
          await SupabaseService.client.rpc('get_player_facilities_with_queue');
      final List<PlayerFacility> facilities = _parseFacilities(response);
      await syncFacilities(facilities);
    } catch (_) {
      // Son bilinen zamanlayıcılar korunur.
    }
  }

  List<PlayerFacility> _parseFacilities(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => PlayerFacility.fromJson(Map<String, dynamic>.from(row)))
          .where((PlayerFacility f) => f.isActive)
          .toList(growable: false);
    }
    if (response is Map) {
      final dynamic payload = response['data'];
      if (payload is List) {
        return payload
            .whereType<Map>()
            .map((row) => PlayerFacility.fromJson(Map<String, dynamic>.from(row)))
            .where((PlayerFacility f) => f.isActive)
            .toList(growable: false);
      }
    }
    return const <PlayerFacility>[];
  }

  Future<void> syncAll({
    PlayerProfile? profile,
    List<BoxOpening>? boxOpenings,
  }) async {
    await syncProfile(profile);
    if (boxOpenings != null) {
      await syncBoxOpenings(boxOpenings);
    } else {
      await syncFacilitiesFromServer();
      return;
    }
    await syncFacilitiesFromServer();
  }

  Future<void> pushInboxItemIfBackground(GameNotificationItem item) async {
    if (!_shouldPushInstant(item)) return;

    await _notifications.showNow(
      id: inboxPushNotificationId(item.id),
      title: item.title,
      body: item.body,
      payload: item.routePath,
    );
  }

  bool _shouldPushInstant(GameNotificationItem item) {
    return switch (item.kind) {
      NotificationKind.hospital ||
      NotificationKind.prison ||
      NotificationKind.lowHealth ||
      NotificationKind.boxReady ||
      NotificationKind.facilityReady =>
        false,
      NotificationKind.friendRequest ||
      NotificationKind.friendRequestAccepted ||
      NotificationKind.friendRequestRejected ||
      NotificationKind.pvpInvite ||
      NotificationKind.pvpResult ||
      NotificationKind.tradeInvite ||
      NotificationKind.chatMessage ||
      NotificationKind.dailyReward ||
      NotificationKind.questReward ||
      NotificationKind.referralReward =>
        true,
    };
  }

  String _facilityLabel(String typeKey) {
    return switch (typeKey) {
      'farming' => 'Çiftlik',
      'mine' => 'Maden',
      'lumber' => 'Kereste',
      'fishing' => 'Balıkçılık',
      _ => typeKey.isEmpty ? 'Tesis' : typeKey,
    };
  }

  Future<void> clearAllOnLogout() async {
    await _notifications.cancelAll();
  }
}
