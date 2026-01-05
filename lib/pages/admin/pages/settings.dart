import 'package:azalia/components/colors.dart';
import 'package:azalia/components/widgets/data_footer.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:flutter/material.dart';

class AdminPageSettings extends StatelessWidget {
  const AdminPageSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Админ-настройки"), centerTitle: true),
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
      bottomNavigationBar: AppFooter(items: adminFooterItems),
    );
  }
}
