import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class CartHeader extends StatelessWidget implements PreferredSizeWidget {
  final int itemCount;
  final VoidCallback? onClearCart;

  const CartHeader({super.key, this.itemCount = 0, this.onClearCart});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: AppBar(
          elevation: 0,
          backgroundColor: AppColors.white,
          leading: IconButton(
            onPressed: () {
              context.goNamed('home');
            },
            icon: SvgPicture.asset(
              'assets/icons/Back.svg',
              colorFilter: const ColorFilter.mode(
                AppColors.black,
                BlendMode.srcIn,
              ),
            ),
          ),
          title: Column(
            children: [
              Text(
                "Корзина",
                style: AppText.semibold_25.copyWith(color: AppColors.black),
              ),
              if (itemCount > 0)
                Text(
                  '$itemCount ${_getItemText(itemCount)}',
                  style: AppText.medium_14.copyWith(color: AppColors.grey),
                ),
            ],
          ),
          centerTitle: true,
          actions: [
            if (itemCount > 0 && onClearCart != null)
              IconButton(
                onPressed: onClearCart,
                icon: SvgPicture.asset(
                  'assets/icons/Garbage.svg',
                  colorFilter: const ColorFilter.mode(
                    AppColors.black,
                    BlendMode.srcIn,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getItemText(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'товар';
    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'товара';
    }
    return 'товаров';
  }
}
