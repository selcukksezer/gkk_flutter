import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Telefon bildirim kanalı — zamanlı (hastane/cezaevi/kasa/tesis) + anlık önemli olaylar.
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const String _enabledKey = 'phone_notifications_enabled';
  static const String nightMarketEnabledKey = 'notif_night_market_enabled';
  static const String nemesisEnabledKey = 'notif_nemesis_enabled';
  static const String channelId = 'gkk_game_events';
  static const String channelName = 'Oyun Bildirimleri';
  static const String channelDescription =
      'Hastane, cezaevi, kasa, tesis ve önemli oyun olayları';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _enabled = true;
  bool _nightMarketEnabled = true;
  bool _nemesisEnabled = true;

  bool get isEnabled => _enabled;
  bool get isNightMarketEnabled => _nightMarketEnabled;
  bool get isNemesisEnabled => _nemesisEnabled;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final TimezoneInfo timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              channelName,
              description: channelDescription,
              importance: Importance.high,
            ),
          );
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    _nightMarketEnabled = prefs.getBool(nightMarketEnabledKey) ?? true;
    _nemesisEnabled = prefs.getBool(nemesisEnabledKey) ?? true;
    _initialized = true;

    if (_enabled) {
      unawaited(requestPermissions());
    }
  }

  Future<void> _onNotificationTap(NotificationResponse response) {
    // Route payload ileride deep-link ile bağlanabilir.
    return Future<void>.value();
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final bool? granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final bool? granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    return true;
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      await requestPermissions();
    } else {
      await cancelAll();
    }
  }

  Future<void> setNightMarketEnabled(bool enabled) async {
    _nightMarketEnabled = enabled;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(nightMarketEnabledKey, enabled);
  }

  Future<void> setNemesisEnabled(bool enabled) async {
    _nemesisEnabled = enabled;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(nemesisEnabledKey, enabled);
  }

  Future<void> loadEnabledPreference() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    _nightMarketEnabled = prefs.getBool(nightMarketEnabledKey) ?? true;
    _nemesisEnabled = prefs.getBool(nemesisEnabledKey) ?? true;
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    if (!_enabled || !_initialized) return;
    if (!when.isAfter(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_enabled || !_initialized) return;

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details(),
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }
}
