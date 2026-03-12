import 'package:azalia/components/widgets/data_pages.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/pages/admin/widgets/user/cards.dart';
import 'package:flutter/material.dart';

class AdminPageUser extends StatelessWidget {
  const AdminPageUser({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminHeaderItems),
      body: AdminUsersPage(),
      bottomNavigationBar: AppFooter(items: adminFooterItems),
    );
  }
}
