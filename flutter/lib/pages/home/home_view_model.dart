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
  bool _isSearching = false;
  bool get isSearching => _isSearching;
  List<String> _searchSuggestions = const [];
  List<String> get searchSuggestions => _searchSuggestions;
  int _searchRequestVersion = 0;

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

  void setSearchQuery(String query, {bool immediate = false}) {
    _searchQuery = query.trim();
    _searchDebounceTimer?.cancel();

    if (_searchQuery.isEmpty) {
      _searchRequestVersion += 1;
      _isSearching = false;
      _searchSuggestions = const [];
      _performSearch('');
      return;
    }

    if (immediate) {
      _performSearch(_searchQuery);
      return;
    }

    _searchDebounceTimer = Timer(
      Duration(milliseconds: HomeConstants.searchDebounceMs),
      () => _performSearch(_searchQuery),
    );
  }

  void applySuggestion(String suggestion) {
    setSearchQuery(suggestion, immediate: true);
  }

  Future<void> _performSearch(String query) async {
    _clearError();
    _searchQuery = query.trim();
    final requestVersion = ++_searchRequestVersion;
    _isSearching = _searchQuery.isNotEmpty;
    notifyListeners();

    try {
      if (_searchQuery.isEmpty) {
        await _loadPlants(reset: true);
        if (requestVersion != _searchRequestVersion) return;
        _searchSuggestions = const [];
        return;
      }

      await _loadSearchResults(_searchQuery, requestVersion);
    } catch (e) {
      if (requestVersion == _searchRequestVersion) {
        _setError('Ошибка поиска', HomePageError.search);
        _setLoading(false);
      }
    } finally {
      if (requestVersion == _searchRequestVersion) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadSearchResults(String query, int requestVersion) async {
    _setLoading(true);
    _hasMore = false;
    _currentPage = 1;
    final normalizedQuery = query.trim().toLowerCase();

    final seenIds = <int>{};
    final merged = <Plant>[];

    void appendPlants(List<Plant> plants) {
      for (final plant in plants) {
        if (seenIds.add(plant.id)) {
          merged.add(plant);
        }
      }
    }

    final byName = await PlantService.getPlants(
      search: normalizedQuery,
      inStock: true,
      page: 1,
      perPage: 30,
      sortBy: 'name',
    );
    if (requestVersion != _searchRequestVersion) return;
    appendPlants(_filterAvailablePlants(byName.data));

    final matchingCategories = _categories
        .where((c) => c.name.toLowerCase().contains(normalizedQuery))
        .take(3)
        .toList();

    for (final category in matchingCategories) {
      final byCategory = await PlantService.getPlants(
        categoryId: category.id,
        inStock: true,
        page: 1,
        perPage: 20,
        sortBy: 'name',
      );
      if (requestVersion != _searchRequestVersion) return;
      appendPlants(_filterAvailablePlants(byCategory.data));
    }

    // Если точный поиск дал мало результатов, добавляем fallback:
    // разбиваем запрос на куски по 3 символа и ищем по ним.
    if (merged.length < 3 && normalizedQuery.length >= 3) {
      final chunks = _buildSearchChunks(normalizedQuery);
      for (final chunk in chunks) {
        final byChunk = await PlantService.getPlants(
          search: chunk,
          inStock: true,
          page: 1,
          perPage: 20,
          sortBy: 'name',
        );
        if (requestVersion != _searchRequestVersion) return;
        appendPlants(_filterAvailablePlants(byChunk.data));
      }
    }

    _allPlants = merged;
    _displayedPlants = List<Plant>.from(merged);
    _searchSuggestions = _buildSuggestions(
      normalizedQuery,
      merged,
      matchingCategories,
    );
    notifyListeners();
    _setLoading(false);
  }

  List<String> _buildSearchChunks(String query) {
    final chunks = <String>[];
    final seen = <String>{};
    if (query.length < 3) return chunks;

    for (int i = 0; i <= query.length - 3; i++) {
      final chunk = query.substring(i, i + 3);
      if (seen.add(chunk)) {
        chunks.add(chunk);
      }
    }
    return chunks.take(5).toList();
  }

  List<String> _buildSuggestions(
    String query,
    List<Plant> plants,
    List<Category> matchedCategories,
  ) {
    final normalized = query.toLowerCase();
    final suggestions = <String>[];
    final seen = <String>{};

    void addSuggestion(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        suggestions.add(trimmed);
      }
    }

    for (final category in matchedCategories) {
      addSuggestion(category.name);
      if (suggestions.length >= 8) return suggestions;
    }

    for (final plant in plants) {
      if (plant.name.toLowerCase().contains(normalized)) {
        addSuggestion(plant.name);
        if (suggestions.length >= 8) return suggestions;
      }
    }

    return suggestions;
  }

  Future<void> loadNextCycle() async {
    if (_searchQuery.isNotEmpty || _isLoading || _isLoadingMore || !_hasMore) {
      return;
    }

    try {
      await _loadPlants();
    } catch (e) {
      _setLoadingMore(false);
    }
  }

  bool shouldLoadMore(double scrollPosition, double maxScrollExtent) {
    if (_searchQuery.isNotEmpty) return false;
    return _hasMore &&
        !_isLoadingMore &&
        scrollPosition >= maxScrollExtent - HomeConstants.scrollThreshold;
  }

  List<Plant> _filterAvailablePlants(List<Plant> plants) {
    return plants;
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
        categoryId: _searchQuery.isNotEmpty ? null : _selectedCategory?.id,
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
      _hasMore = pagination != null
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
