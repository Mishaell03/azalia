import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';

class CartlistUnauthorized extends StatelessWidget {
  const CartlistUnauthorized({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  color: AppColors.brown.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Image.asset("assets/images/cart.png"),
              ),
              const SizedBox(height: 32),

              // Заголовок
              Text(
                'Требуется авторизация',
                style: AppText.bold_20.copyWith(color: AppColors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Описание
              Text(
                'Войдите аккаунт, чтобы сохранять\nтовары в корзине',
                style: AppText.medium_16.copyWith(color: AppColors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Кнопка входа
              ElevatedButton(
                onPressed: () {
                  context.go('/auth');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brown,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Войти',
                  style: AppText.medium_16.copyWith(color: AppColors.white),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
