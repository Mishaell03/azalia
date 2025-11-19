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
  List<Plant> _allPlants = [];
  List<Plant> _displayedPlants = []; 
  List<Category> _categories = [];
  bool _isLoading = true;
  String _error = '';
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  final PlantService _plantService = PlantService();

  // бескоечная карусель
  final int _visibleItemsCount = 10; //сколько прогружать карточек
  int _currentCycle = 0; // цикл прокрутки

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
      // когда доходим до конца видимого списка, переходим к следующему циклу
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        _loadNextCycle();
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

      // фильтр по количеству stockQuantity > 0
      final availablePlants = plants.data.where((plant) => plant.stockQuantity > 0).toList();

      print('Всего растений получено: ${plants.data.length}');
      print('Доступных растений: ${availablePlants.length}');

      setState(() {
        _categories = categories;
        _allPlants = availablePlants;
        _currentCycle = 0;
        _updateDisplayedPlants();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Что-то пошло не так';
        _isLoading = false;
      });
    }
  }

  void _updateDisplayedPlants() {
    if (_allPlants.isEmpty) {
      _displayedPlants = [];
      return;
    }

    final List<Plant> newDisplayedPlants = [];
    
    // растения для текущего цикла
    for (int i = 0; i <= _currentCycle; i++) {
      final startIndex = (i * _visibleItemsCount) % _allPlants.length;
      final endIndex = startIndex + _visibleItemsCount;
      
      if (endIndex <= _allPlants.length) {
        newDisplayedPlants.addAll(_allPlants.sublist(startIndex, endIndex));
      } else {
        // выходим за границы - берем с начала
        newDisplayedPlants.addAll(_allPlants.sublist(startIndex));
        newDisplayedPlants.addAll(_allPlants.sublist(0, endIndex - _allPlants.length));
      }
    }

    setState(() {
      _displayedPlants = newDisplayedPlants;
    });
  }

  void _loadNextCycle() {
    if (_allPlants.isEmpty) return;

    setState(() {
      _currentCycle++;
      _updateDisplayedPlants();
    });
  }

  void _onCategorySelected(Category? category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
      _allPlants = [];
      _displayedPlants = [];
      _currentCycle = 0;
      _error = '';
    });

    try {
      final plants = await _plantService.getPlants(
        categoryId: category?.id,
      );

      // фильтр по количеству stockQuantity > 0
      final availablePlants = plants.data.where((plant) => plant.stockQuantity > 0).toList();

      setState(() {
        _allPlants = availablePlants;
        _updateDisplayedPlants();
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
      appBar: HomeHeader(),
      bottomNavigationBar: const AppFooter(),
      body: _isLoading
          ? const LoadingWidget()
          : _error.isNotEmpty
          ? GenericErrorWidget(onRetry: _loadInitialData)
          : RefreshIndicator(
              key: _refreshIndicatorKey,
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
                  if (_displayedPlants.isEmpty && !_isLoading)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'Нет доступных растений',
                            style: AppText.medium_16.copyWith(color: AppColors.grey),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final plant = _displayedPlants[index];
                          
                          // 2я проверка
                          if (plant.stockQuantity <= 0) {
                            return const SizedBox.shrink();
                          }
                          
                          return HomeCard(plant: plant);
                        },
                        childCount: _displayedPlants.length,
                      ),
                    ),
                  // индикатор следующего цикла
                  SliverToBoxAdapter(
                    child: _allPlants.isNotEmpty 
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'Продолжение списка...',
                                style: AppText.medium_14.copyWith(color: AppColors.grey),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
    );
  }
}