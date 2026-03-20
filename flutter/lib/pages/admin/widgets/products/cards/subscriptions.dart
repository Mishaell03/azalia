import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:azalia/pages/admin/widgets/subscriptions/subscription_plans_editor.dart';
import 'package:flutter/material.dart';

class AdminProductsCartSubscriptions extends StatelessWidget {
  const AdminProductsCartSubscriptions({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminProductsHeaderItems),
      body: const AdminSubscriptionPlansEditor(),
    );
  }
}
