import 'package:azalia/components/widgets/data_pages.dart';
import 'package:flutter/material.dart';
import 'package:azalia/components/colors.dart';
import 'package:azalia/components/text_styles.dart';
import 'package:azalia/pages/home/widgets/header.dart';
import 'package:azalia/pages/home/widgets/categories.dart';
import 'package:azalia/pages/home/widgets/cards.dart';
import 'package:azalia/pages/home/home_view_model.dart';
import 'package:azalia/components/widgets/footer.dart';
import 'package:azalia/pages/error/loading_error.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  late final HomeViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel();
    _viewModel.addListener(_onViewModelChanged);
    _setupScrollListener();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        if (_viewModel.shouldLoadMore(position.pixels, position.maxScrollExtent)) {
          _viewModel.loadNextCycle();
        }
      }
    });
  }

  Future<void> _handleRefresh() async {
    await _viewModel.refresh();
  }

  void _onCategorySelected(category) {
    _viewModel.selectCategory(category);
  }

  void _onSearchChanged(String query) {
    _viewModel.setSearchQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeHeader(
      ),
      bottomNavigationBar: const AppFooter(items: userFooterItems),
      body: _viewModel.isLoading
          ? const LoadingWidget()
          : _viewModel.hasError
              ? GenericErrorWidget(onRetry: _viewModel.refresh)
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
                                selectedCategory: _viewModel.selectedCategory,
                                categories: _viewModel.categories,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                      if (_viewModel.displayedPlants.isEmpty && !_viewModel.isLoading)
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
                              final plant = _viewModel.displayedPlants[index];
                              
                              if (plant.stockQuantity <= 0) {
                                return const SizedBox.shrink();
                              }
                              
                              return HomeCard(
                                key: ValueKey(plant.id),
                                plant: plant,
                              );
                            },
                            childCount: _viewModel.displayedPlants.length,
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: _viewModel.selectedCategory == null && 
                                _viewModel.allPlants.isNotEmpty 
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