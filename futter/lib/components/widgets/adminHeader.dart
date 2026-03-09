import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HeaderItems {
  final String route;
  final String title;
  final bool isButton;

  const HeaderItems({
    required this.route,
    required this.title,
    this.isButton = false,
  });
}

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final List<HeaderItems> items;

  const AppHeader({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final String currentRoute = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.toString();

    final header = items.firstWhere(
      (item) => item.route == currentRoute,
      orElse: () => const HeaderItems(route: '', title: '', isButton: false),
    );

    return AppBar(
      title: Text(header.title),
      titleTextStyle: AppText.semibold_25.copyWith(color: AppColors.black),
      automaticallyImplyLeading: header.isButton,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
