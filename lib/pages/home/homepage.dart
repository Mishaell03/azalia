import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/home/widgets/header.dart';
import 'package:azalia/pages/home/widgets/categories.dart';
import 'package:azalia/pages/home/widgets/cards.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/plant.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:azalia/pages/error/loading_error.dart';

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
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  final PlantService _plantService = PlantService();

  Future<void> _handleRefresh() async {
    await _loadInitialData();
  }

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
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _currentIndex < _plants.length) {
        _loadMorePlants();
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _error = '';
        _isLoading = true;
      });

      final categories = await _plantService.getCategories();
      final plants = await _plantService.getPlants();

      setState(() {
        _categories = categories;
        _plants = plants.data;
        _currentIndex = 0;
        _displayedPlants.clear();
        _loadNextBatch();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Что-то пошло не так';
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
      _error = '';
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
        _error = 'Что-то пошло не так';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: HomeHeader(),
      bottomNavigationBar: const AppFooter(),
      body: _isLoading
          ? const LoadingWidget()
          : _error.isNotEmpty
          ? GenericErrorWidget(onRetry: _loadInitialData)
          : RefreshIndicator(
              key: _refreshIndicatorKey,
              color: AppColors.brown,
              backgroundColor: AppColors.white,
              displacement: 70,
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 20,
                            left: 24,
                            right: 24,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  "Растения для \nдомашнего уюта",
                                  style: AppText.semibold_28.copyWith(
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Image.asset(
                                'assets/images/cactus.png',
                                fit: BoxFit.contain,
                                height: 70,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 33,
                          child: HomeCategory(
                            onCategorySelected: _onCategorySelected,
                            selectedCategory: _selectedCategory,
                            categories: _categories,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _displayedPlants.length) {
                          return _isLoadingMore
                              ? const LoadingMoreIndicator()
                              : const SizedBox.shrink();
                        }
                        final plant = _displayedPlants[index];
                        return PlantCard(plant: plant);
                      },
                      childCount:
                          _displayedPlants.length + (_isLoadingMore ? 1 : 0),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
