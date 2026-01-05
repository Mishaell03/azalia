import 'package:azalia/components/colors.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:flutter/material.dart';

class AdminProductsCartOrders extends StatelessWidget{
  const AdminProductsCartOrders({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:  AppHeader(items: adminProductsHeaderItems),
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