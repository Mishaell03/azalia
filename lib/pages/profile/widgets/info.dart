import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';

class AppProfileInfo extends StatelessWidget {
  final String label;
  final String value;

  const AppProfileInfo({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: AppText.medium_16.copyWith(color: AppColors.grey)
        ),
        Text(
          value, 
          style: AppText.medium_16.copyWith(color: AppColors.black)
        ),
      ],
    );
  }
}