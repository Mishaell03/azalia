import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/home/widgets/header.dart';
import 'package:azalia/pages/home/widgets/categories.dart';
import 'package:azalia/pages/home/widgets/cards.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/plant.dart';
import 'package:azalia/components/widgets/footer.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  Category? _selectedCategory;
  List<Plant> _plants = [];
  List<Plant> _displayedPlants = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _error = '';
  final int _batchSize = 10;
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();

  final PlantService _plantService = PlantService();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMorePlants();
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final categories = await _plantService.getCategories();
      final plants = await _plantService.getPlants();

      setState(() {
        _categories = categories;
        _plants = plants.data;
        _currentIndex = 0;
        _loadNextBatch();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadNextBatch() {
    final nextIndex = _currentIndex + _batchSize;
    final newPlants = _plants.sublist(
      _currentIndex,
      nextIndex < _plants.length ? nextIndex : _plants.length,
    );

    setState(() {
      _displayedPlants.addAll(newPlants);
      _currentIndex = nextIndex;
    });
  }

  Future<void> _loadMorePlants() async {
    if (_isLoadingMore || _currentIndex >= _plants.length) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));
    
    _loadNextBatch();

    setState(() {
      _isLoadingMore = false;
    });
  }

  void _onCategorySelected(Category? category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
      _displayedPlants.clear();
      _currentIndex = 0;
    });

    try {
      final plants = await _plantService.getPlants(categoryId: category?.id);

      setState(() {
        _plants = plants.data;
        _loadNextBatch();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildLoadingMoreIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: HomeHeader(),
      bottomNavigationBar: const AppFooter(),
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
                    controller: _scrollController,
                    itemCount: _displayedPlants.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _displayedPlants.length) {
                        return _buildLoadingMoreIndicator();
                      }
                      final plant = _displayedPlants[index];
                      return PlantCard(plant: plant);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}