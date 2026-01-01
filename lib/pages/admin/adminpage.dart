import 'package:azalia/components/colors.dart';
import 'package:flutter/material.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Админ-панель"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build, size: 80, color: AppColors.grey),
            SizedBox(height: 20),
            Text("Раздел находится в разработке"),
          ],
        ),
      ),
    );
  }
}
