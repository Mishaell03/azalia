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

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final _router = AppRouter().router;

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
