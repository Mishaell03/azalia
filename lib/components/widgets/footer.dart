import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

class AppFooter extends StatefulWidget {
  const AppFooter({super.key});

  @override
  State<AppFooter> createState() => _AppFooter();
}

class _AppFooter extends State<AppFooter> {
  final List<String> _footerItems = [
    'assets/icons/Home.svg',
    'assets/icons/Love.svg',
    'assets/icons/Bag.svg',
    'assets/icons/User.svg',
  ];

  final List<String> _routes = [
    '/',
    '/love',
    '/',
    '/profile',
  ];

  int _getCurrentIndex(BuildContext context) {
    final String currentLocation = GoRouterState.of(context).uri.toString();
    
    for (int i = 0; i < _routes.length; i++) {
      if (currentLocation == _routes[i] || 
          currentLocation.startsWith(_routes[i] + '/')) {
        return i;
      }
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    if (index < _routes.length) {
      context.go(_routes[index]);
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
          _footerItems.length,
          (index) => _buildFooterIco(
            _footerItems[index],
            index,
            context,
            isActive: index == currentIndex,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterIco(
    String icoPath, 
    int index, 
    BuildContext context, {
    bool isActive = false
  }) {
    return GestureDetector(
      onTap: () => _onItemTapped(index, context),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            icoPath,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              isActive ? AppColors.brown : AppColors.grey_light,
              BlendMode.srcIn,
            ),
          ),
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