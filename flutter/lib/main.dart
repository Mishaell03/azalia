import 'dart:async';

import 'package:azalia/components/colors.dart';
import 'package:azalia/backend/services/local_notifications.dart';
import 'package:azalia/router.dart';
import 'package:flutter/material.dart';
import 'package:azalia/backend/services/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final session = SessionService();
  await session.initialize();
  await LocalNotificationsService.instance.initialize();
  await LocalNotificationsService.instance.syncCalendarNotifications();
  await LocalNotificationsService.instance.syncOrderStatusNotifications();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final _router = AppRouter().router;
  Timer? _orderNotificationsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startOrderNotificationsPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orderNotificationsTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncOrderNotificationsSafely();
    }
  }

  void _startOrderNotificationsPolling() {
    _orderNotificationsTimer?.cancel();
    _orderNotificationsTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _syncOrderNotificationsSafely(),
    );
  }

  Future<void> _syncOrderNotificationsSafely() async {
    try {
      await LocalNotificationsService.instance.syncOrderStatusNotifications();
    } catch (_) {
      // Ignore transient networking errors for background polling.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
        ),
        colorScheme: ColorScheme.light(
          primary: AppColors.brown,
          secondary: AppColors.brown,
          surface: AppColors.white,
        ),
      ),
    );
  }
}
