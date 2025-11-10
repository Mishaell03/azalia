import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/home/widgets/header.dart';
import 'package:azalia/pages/home/widgets/categories.dart';
import 'package:azalia/pages/home/widgets/cards.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/plant.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  Category? _selectedCategory;
  List<Plant> _plants = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  String _error = '';

  final PlantService _plantService = PlantService();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final categories = await _plantService.getCategories();
      final plants = await _plantService.getPlants();

      setState(() {
        _categories = categories;
        _plants = plants.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onCategorySelected(Category? category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });

    try {
      final plants = await _plantService.getPlants(categoryId: category?.id);

      setState(() {
        _plants = plants.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: HomeHeader(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Text('Ошибка: $_error'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 20,
                    left: 24,
                    right: 0,
                  ),
                  child: Text(
                    "Растения для \nдомашнего уюта",
                    style: AppText.semibold_28.copyWith(color: AppColors.black),
                  ),
                ),
                HomeCategory(
                  onCategorySelected: _onCategorySelected,
                  selectedCategory: _selectedCategory,
                  categories: _categories,
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _plants.length,
                    itemBuilder: (context, index) {
                      final plant = _plants[index];
                      return PlantCard(plant: plant);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}