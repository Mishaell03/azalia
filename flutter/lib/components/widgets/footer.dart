import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

class FooterItems {
  final String icon;
  final String route;
  final bool isSvg;

  const FooterItems({
    required this.icon,
    required this.route,
    this.isSvg = true,
  });
}

IconData _iconFromString(String name) {
  switch (name) {
    case 'analytics_outlined':
      return Icons.analytics_outlined;
    case 'local_florist':
      return Icons.local_florist;
    case 'home_filled':
      return Icons.home_filled;
    case 'supervised_user_circle_outlined':
      return Icons.supervised_user_circle_outlined;
    case 'workspace_premium_outlined':
      return Icons.workspace_premium_outlined;
    default:
      return Icons.help_outline;
  }
}


class AppFooter extends StatefulWidget {
  final List<FooterItems> items;

  const AppFooter({super.key, required this.items});

  @override
  State<AppFooter> createState() => _AppFooter();
}

class _AppFooter extends State<AppFooter> {
  int _getCurrentIndex(BuildContext context) {
    final String currentLocation = GoRouterState.of(context).uri.toString();
    int matchedIndex = 0;
    int longestMatch = -1;

    for (int i = 0; i < widget.items.length; i++) {
      final route = widget.items[i].route;
      if (currentLocation == route || currentLocation.startsWith('$route/')) {
        if (route.length > longestMatch) {
          longestMatch = route.length;
          matchedIndex = i;
        }
      }
    }
    return matchedIndex;
  }

  void _onItemTapped(int index, BuildContext context) {
    if (index < widget.items.length) {
      context.go(widget.items[index].route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex = _getCurrentIndex(context);

    return Container(
      height: 75,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.grey_light.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(
          widget.items.length,
          (index) => _buildFooterIco(
            widget.items[index],
            index,
            context,
            isActive: index == currentIndex,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterIco(
    FooterItems item,
    int index,
    BuildContext context, {
    bool isActive = false,
  }) {
    final _color = isActive ? AppColors.brown : AppColors.grey_light;
    return GestureDetector(
      onTap: () => _onItemTapped(index, context),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (item.isSvg)
            SvgPicture.asset(
              item.icon,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(_color, BlendMode.srcIn),
            )
          else
            Icon(_iconFromString(item.icon), size: 25, color: _color),
          const SizedBox(height: 8),
          Container(
            width: 10,
            height: 5,
            decoration: BoxDecoration(
              color: isActive ? AppColors.brown : AppColors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ],
      ),
    );
  }
}
