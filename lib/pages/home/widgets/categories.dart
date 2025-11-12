import 'package:flutter/material.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/plant.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/error/loading_error.dart';

class HomeCategory extends StatefulWidget {
  final Function(Category?) onCategorySelected;
  final Category? selectedCategory;
  final List<Category>? categories;

  const HomeCategory({
    Key? key,
    required this.onCategorySelected,
    this.selectedCategory,
    this.categories,
  }) : super(key: key);

  @override
  State<HomeCategory> createState() => _HomeCategory();
}

class _HomeCategory extends State<HomeCategory> {
  late PlantService _plantService;
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plantService = PlantService();

    if (widget.categories != null && widget.categories!.isNotEmpty) {
      setState(() {
        _categories = widget.categories!;
        _isLoading = false;
      });
    } else {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final categories = await _plantService.getCategories();

      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Ошибка загрузки';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(size: 50,);
    }

    if (_error != null) {
      return ErrorWidgetWithRetry(
        errorMessage: _error!,
        onRetry: _loadCategories,
        height: 50,
      );
    }
    if (_categories.isEmpty) {
      return const EmptyStateWidget(
        message: 'Нет доступных категорий',
        height: 50,
      );
    }

    return SizedBox(
      height: 35,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 24),
        children: [
          _buildCategoryItem(
            name: 'Все',
            isSelected: widget.selectedCategory == null,
            onTap: () => widget.onCategorySelected(null),
          ),
          const SizedBox(width: 12),

          ..._categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildCategoryItem(
                name: category.name,
                isSelected: widget.selectedCategory?.id == category.id,
                onTap: () => widget.onCategorySelected(category),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryItem({
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brown : AppColors.white_dark,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        child: Center(
          child: Text(
            name,
            style: AppText.medium_14.copyWith(
              color: isSelected ? AppColors.white : AppColors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
