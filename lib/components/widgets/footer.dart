import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:flutter_svg/svg.dart';
import 'package:azalia/router.dart';
import 'package:go_router/go_router.dart';

class AppFooter extends StatefulWidget {
  const AppFooter({super.key});

  @override
  State<AppFooter> createState() => _AppFooter();
}

class _AppFooter extends State<AppFooter> {
  int _currentIndex = 0;

  final List<String> _footerItems = [
    'assets/icons/Home.svg',
    'assets/icons/Love.svg',
    'assets/icons/Bag.svg',
    'assets/icons/User.svg',
  ];

  void _onItemTepped(int index) {
    setState(() {
      _currentIndex = index;
    });
    switch (index) {
      case 0:
      context.go('/');
    }
    switch (index) {
      case 3:
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: AppColors.white,
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
            isActive: index == _currentIndex,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterIco(String icoPath, int index, {bool isActive = false}) {
    return GestureDetector(
      onTap: () => _onItemTepped(index),
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
