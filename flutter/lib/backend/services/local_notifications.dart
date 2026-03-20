import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance =
      LocalNotificationsService._();
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final ApiClient _api = ApiClient();

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
}
