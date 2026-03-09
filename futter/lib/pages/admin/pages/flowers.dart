import 'package:azalia/components/widgets/data_pages.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/pages/admin/widgets/products/cards.dart';
import 'package:flutter/material.dart';

class AdminPageProducts extends StatelessWidget {
  const AdminPageProducts({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminHeaderItems),
      body: SingleChildScrollView(child: AdminProductsCards()),
      bottomNavigationBar: AppFooter(items: adminFooterItems),
    );
  }
}
