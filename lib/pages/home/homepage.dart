import 'dart:ui';

import 'package:azalia/components/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/pages/home/widgets/header.dart';
import 'package:azalia/pages/home/widgets/categories.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  Category? _selectedCategory;

  void _onCategorySelected(Category? category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: HomeHeader(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsetsGeometry.only(
              top: 0,
              bottom: 20,
              left: 24,
              right: 0,
            ),
            child: 
            Text(
              "Растения для \nдомашнего уюта",
              style: AppText.semibold_28.copyWith(color: AppColors.black),
            ),
          ),
          HomeCategory(
            onCategorySelected: _onCategorySelected,
            selectedCategory: _selectedCategory,
          ),
        ],
      ),
    );
  }
}
