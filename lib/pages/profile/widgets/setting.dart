import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';

class AppProfileSetting extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const AppProfileSetting({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.brown),
      title: Text(
        title,
        style: AppText.medium_16.copyWith(color: AppColors.black),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey),
      onTap: onTap,
    );
  }
}