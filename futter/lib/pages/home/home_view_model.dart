import 'dart:async';

import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/plant.dart';
import 'package:azalia/pages/home/home_constants.dart';
import 'package:flutter/foundation.dart' hide Category;

enum HomePageError { loadPlants, loadCategories, search }

class HomeViewModel extends ChangeNotifier {
  static const int _pageSize = 10;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  String _error = '';
  HomePageError? _errorType;
  String get error => _error;
  HomePageError? get errorType => _errorType;
  bool get hasError => _error.isNotEmpty;

  List<Category> _categories = [];
  List<Category> get categories => _categories;

  List<Plant> _allPlants = [];
  List<Plant> get allPlants => _allPlants;

  List<Plant> _displayedPlants = [];
  List<Plant> get displayedPlants => _displayedPlants;

  Category? _selectedCategory;
  Category? get selectedCategory => _selectedCategory;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int _currentPage = 1;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Timer? _searchDebounceTimer;

  HomeViewModel() {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      _setLoading(true);
      _clearError();

      _categories = await PlantService.getCategories();
      await _loadPlants(reset: true);
    } catch (e) {
      _setError('Что-то пошло не так', HomePageError.loadPlants);
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    await _loadInitialData();
  }

  Future<void> selectCategory(Category? category) async {
    _selectedCategory = category;
    _clearError();

    try {
      await _loadPlants(reset: true);
    } catch (e) {
      _setError('Что-то пошло не так', HomePageError.loadPlants);
      _setLoading(false);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _searchDebounceTimer?.cancel();

    if (query.isEmpty) {
      _performSearch('');
      return;
    }

    _searchDebounceTimer = Timer(
      Duration(milliseconds: HomeConstants.searchDebounceMs),
      () => _performSearch(query),
    );
  }

  Future<void> _performSearch(String query) async {
    _clearError();
    _searchQuery = query;

    try {
      await _loadPlants(reset: true);
    } catch (e) {
      _setError('Ошибка поиска', HomePageError.search);
      _setLoading(false);
    }
  }

  Future<void> loadNextCycle() async {
    if (_isLoading || _isLoadingMore || !_hasMore) {
      return;
    }

    try {
      await _loadPlants();
    } catch (e) {
      _setLoadingMore(false);
    }
  }

  bool shouldLoadMore(double scrollPosition, double maxScrollExtent) {
    return _hasMore &&
        !_isLoadingMore &&
        scrollPosition >= maxScrollExtent - HomeConstants.scrollThreshold;
  }

  List<Plant> _filterAvailablePlants(List<Plant> plants) {
    return plants.where((plant) => plant.stockQuantity > 0).toList();
  }

  void _updateDisplayedPlants() {
    _displayedPlants = List<Plant>.from(_allPlants);
    notifyListeners();
  }

  Future<void> _loadPlants({bool reset = false}) async {
    if (reset) {
      _currentPage = 1;
      _hasMore = true;
      _allPlants = [];
      _displayedPlants = [];
      _setLoading(true);
    } else {
      _setLoadingMore(true);
    }

    try {
      final response = await PlantService.getPlants(
        categoryId: _selectedCategory?.id,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        inStock: true,
        page: _currentPage,
        perPage: _pageSize,
      );

      final plants = _filterAvailablePlants(response.data);
      if (reset) {
        _allPlants = plants;
      } else {
        _allPlants = [..._allPlants, ...plants];
      }

      final pagination = response.pagination;
      _hasMore =
          pagination != null
              ? pagination.page < pagination.pages
              : response.data.length >= _pageSize;
      _currentPage += 1;

      _updateDisplayedPlants();
    } finally {
      _setLoadingMore(false);
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setLoadingMore(bool value) {
    _isLoadingMore = value;
    notifyListeners();
  }

  void _setError(String message, HomePageError type) {
    _error = message;
    _errorType = type;
    notifyListeners();
  }

  void _clearError() {
    _error = '';
    _errorType = null;
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}
