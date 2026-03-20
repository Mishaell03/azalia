import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/components/widgets/adminHeader.dart';
import 'package:azalia/components/widgets/data_pages.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:azalia/pages/admin/widgets/subscriptions/subscription_plans_editor.dart';
import 'package:flutter/material.dart';

class AdminPageSettings extends StatelessWidget {
  const AdminPageSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(items: adminHeaderItems),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Центр управления подписками',
                  style: AppText.bold_20.copyWith(color: AppColors.black),
                ),
              ],
            ),
          ),
          const Expanded(child: AdminSubscriptionPlansEditor()),
        ],
      ),
      bottomNavigationBar: AppFooter(items: adminFooterItems),
    );
  }
}
