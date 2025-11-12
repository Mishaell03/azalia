import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeHeader extends StatefulWidget implements PreferredSizeWidget {
  const HomeHeader({super.key});

  @override
  State<HomeHeader> createState() => _HomeHeader();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HomeHeader extends State<HomeHeader> {
  bool _searchActive = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text("Azalia"),
      titleSpacing: 24,
      titleTextStyle: AppText.semibold_25.copyWith(color: AppColors.black),
      backgroundColor: AppColors.white,
      elevation: 0,
      surfaceTintColor: AppColors.white,
      actions: [
        if (_searchActive)
          Container(
            margin: const EdgeInsets.only(right: 24, top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.grey_light, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            width: MediaQuery.of(context).size.width * 0.60,
            child: Row(
              children: [
                const SizedBox(width: 12),
                SvgPicture.asset(
                  'assets/icons/Searh.svg',
                  color: AppColors.grey_light,
                  height: 18, width: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Поиск растений...",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 11),
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: IconButton(
                    icon: Icon(Icons.close, color: AppColors.grey),
                    onPressed: () {
                      setState(() {
                        _searchActive = false;
                        _searchController.clear();
                      });
                    },
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(right: 24),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _searchActive = true;
                });
              },
              icon: SvgPicture.asset(
                "assets/icons/Searh.svg",
                color: AppColors.black,
              ),
            ),
          ),
      ],
    );
  }
}