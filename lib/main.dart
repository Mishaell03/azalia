import 'package:azalia/components/colors.dart';
import 'package:azalia/router.dart';
import 'package:flutter/material.dart';
import 'package:azalia/backend/services/session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionService().initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter().router,
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