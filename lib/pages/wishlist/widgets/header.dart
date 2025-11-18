import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class WishlistHeader extends StatelessWidget implements PreferredSizeWidget {
  const WishlistHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        onPressed: () {
          context.goNamed('home');
        },
        icon: SvgPicture.asset(
          'assets/icons/Back.svg',
          colorFilter: ColorFilter.mode(AppColors.black, BlendMode.srcIn),
        ),
      ),
      title: Text(
        "Избранное",
        style: AppText.semibold_25.copyWith(color: AppColors.black),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: AppColors.white,
    );
  }
}
