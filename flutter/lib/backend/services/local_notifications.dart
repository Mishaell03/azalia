import 'dart:convert';

import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/services/session.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance =
      LocalNotificationsService._();
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final ApiClient _api = ApiClient();
  static const String _orderStatusesKey = 'cached_order_statuses_v1';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);

    tz.initializeTimeZones();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> syncCalendarNotifications() async {
    await initialize();
    await _plugin.cancelAll();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final importantDates = await _loadImportantDates();
    final plantCareDates = await _loadPlantCareDates();

    for (final date in importantDates) {
      final rawDate = date['event_date']?.toString() ?? '';
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;
      final eventDay = DateTime(parsed.year, parsed.month, parsed.day);
      if (eventDay.isBefore(today)) continue;

      final scheduledAt = _withDefaultTime(eventDay);
      await _schedule(
        id: 100000 + ((date['id'] as num?)?.toInt() ?? 0),
        title: 'Памятная дата',
        body: date['title']?.toString() ?? 'Памятная дата',
        dateTime: scheduledAt,
      );
    }

    for (final care in plantCareDates) {
      final isDone = care['is_done'] == true || care['is_done'] == 1;
      if (isDone) continue;
      if ((care['care_type']?.toString() ?? 'watering') != 'watering') continue;
      final rawDate = care['care_date']?.toString() ?? '';
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) continue;
      final careDay = DateTime(parsed.year, parsed.month, parsed.day);
      if (careDay.isBefore(today)) continue;

      final scheduledAt = _withDefaultTime(careDay);
      await _schedule(
        id: 200000 + ((care['id'] as num?)?.toInt() ?? 0),
        title: 'Полив растения',
        body: '${care['plant_name']?.toString() ?? 'Растение'}: пора полить',
        dateTime: scheduledAt,
      );
    }
  }

  Future<void> syncOrderStatusNotifications() async {
    await initialize();
    final session = SessionService();
    if (!session.hasActiveSession) return;

    final orders = await _loadOrders();
    if (orders.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_orderStatusesKey);
    final previous = <String, String>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final parsed = Map<String, dynamic>.from(_decodeJson(raw));
        for (final entry in parsed.entries) {
          previous[entry.key] = entry.value?.toString() ?? '';
        }
      } catch (_) {}
    }

    final next = <String, String>{};
    for (final order in orders) {
      final orderId = (order['order_id'] as num?)?.toInt();
      if (orderId == null || orderId <= 0) continue;
      final key = '$orderId';
      final statusCode = order['status_code']?.toString() ?? '';
      next[key] = statusCode;

      final oldStatus = previous[key];
      if (oldStatus != null &&
          oldStatus.isNotEmpty &&
          oldStatus != statusCode) {
        final title = 'Статус заказа обновлен';
        final orderNumber = order['order_number']?.toString() ?? '#$orderId';
        final statusRu = order['status']?.toString() ?? statusCode;
        await _showNow(
          id: 300000 + orderId,
          title: title,
          body: 'Заказ №$orderNumber: $statusRu',
        );
      }
    }

    await prefs.setString(_orderStatusesKey, _encodeJson(next));
  }

  Future<List<Map<String, dynamic>>> _loadImportantDates() async {
    try {
      final response = await _api.get(ApiConfig.importantDates);
      if (response['success'] != true) return const [];
      final data = response['data'] as Map<String, dynamic>? ?? const {};
      final items = data['items'] as List? ?? const [];
      return items.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadPlantCareDates() async {
    try {
      final response = await _api.get(ApiConfig.plantCareDates);
      if (response['success'] != true) return const [];
      final data = response['data'] as Map<String, dynamic>? ?? const {};
      final items = data['items'] as List? ?? const [];
      return items.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadOrders() async {
    try {
      final response = await _api.get(ApiConfig.orders(limit: 50, offset: 0));
      if (response['success'] != true) return const [];
      final data = response['data'] as Map<String, dynamic>? ?? const {};
      final items = data['items'] as List? ?? const [];
      return items.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  DateTime _withDefaultTime(DateTime day) {
    final now = DateTime.now();
    final scheduled = DateTime(day.year, day.month, day.day, 9, 0);
    if (scheduled.isAfter(now)) return scheduled;
    return now.add(const Duration(seconds: 5));
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'calendar_reminders',
        'Calendar reminders',
        channelDescription: 'Напоминания о поливе и памятных датах',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final tzDate = tz.TZDateTime.from(dateTime, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'order_status_changes',
        'Order status changes',
        channelDescription: 'Изменения статусов заказов',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }

  dynamic _decodeJson(String raw) {
    return raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
  }

  String _encodeJson(Map<String, String> value) {
    return jsonEncode(value);
  }
}
