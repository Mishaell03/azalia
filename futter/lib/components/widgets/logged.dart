import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';

class AppProfileLoggeg extends StatelessWidget {
  const AppProfileLoggeg({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 80, color: AppColors.grey),
          const SizedBox(height: 20),
          Text(
            'Вы не авторизованы',
            style: AppText.medium_18.copyWith(color: AppColors.grey),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton(
              onPressed: () => context.go('/auth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brown,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Войти',
                style: AppText.medium_16.copyWith(color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}