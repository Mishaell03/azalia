import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';

class AdminCategory extends StatelessWidget {
  final String name;
  final bool isActive;
  final VoidCallback onTap;

  const AdminCategory({
    super.key,
    required this.name,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(microseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brown : AppColors.white_dark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.white : AppColors.brown,
            width: 1.5,
          ),
        ),
        child: Text(
          name,
          style: AppText.medium_14.copyWith(
            color: isActive ? AppColors.white : AppColors.grey,
          ),
        ),
      ),
    );
  }
}
