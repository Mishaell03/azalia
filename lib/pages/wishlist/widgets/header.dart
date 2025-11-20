import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class WishlistHeader extends StatelessWidget implements PreferredSizeWidget {
  final int itemCount;
  final VoidCallback? onClearWishlist;

  const WishlistHeader({super.key, this.itemCount = 0, this.onClearWishlist});

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
                "Избранное",
                style: AppText.semibold_25.copyWith(color: AppColors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
