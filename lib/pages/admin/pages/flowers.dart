import 'package:azalia/components/widgets/data_pages.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/pages/admin/widgets/flowers/cards.dart';
import 'package:flutter/material.dart';

class AdminPageFlowers extends StatelessWidget {
  const AdminPageFlowers({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminHeaderItems),
      body: SingleChildScrollView(child: AdminFlowersCards()),
      bottomNavigationBar: AppFooter(items: adminFooterItems),
    );
  }
}
