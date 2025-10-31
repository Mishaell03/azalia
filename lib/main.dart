import 'package:azalia/router.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(      
      routerConfig: AppRouter().router,
      debugShowCheckedModeBanner: false,
    );
  }
}