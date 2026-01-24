import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/plant.dart';
import 'package:azalia/pages/home/home_constants.dart';

enum HomePageError {
  loadPlants,
  loadCategories,
  search,
}

class HomeViewModel extends ChangeNotifier {
  // Состояние загрузки
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Ошибки
  String _error = '';
  HomePageError? _errorType;
  String get error => _error;
  HomePageError? get errorType => _errorType;
  bool get hasError => _error.isNotEmpty;

  // Данные
  List<Category> _categories = [];
  List<Category> get categories => _categories;

  List<Plant> _allPlants = [];
  List<Plant> get allPlants => _allPlants;

  List<Plant> _displayedPlants = [];
  List<Plant> get displayedPlants => _displayedPlants;

  // Фильтры
  Category? _selectedCategory;
  Category? get selectedCategory => _selectedCategory;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Бесконечный скролл
  int _currentCycle = 0;
  bool _isAllCategory = true;

  // Debounce для поиска
  Timer? _searchDebounceTimer;

  HomeViewModel() {
    _loadInitialData();
  }

  /// Загрузка начальных данных (категории и растения)
  Future<void> _loadInitialData() async {
    try {
      _setLoading(true);
      _clearError();

      final categories = await PlantService.getCategories();
      final plants = await PlantService.getPlants();

      final availablePlants = _filterAvailablePlants(plants.data);

      _categories = categories;
      _allPlants = availablePlants;
      _currentCycle = 0;
      _isAllCategory = true;
      _updateDisplayedPlants();

      _setLoading(false);
    } catch (e) {
      _setError('Что-то пошло не так', HomePageError.loadPlants);
      _setLoading(false);
    }
  }

  /// Обновление данных (для pull-to-refresh)
  Future<void> refresh() async {
    _setLoading(true);
    _clearError();
    _currentCycle = 0;

    try {
      final categories = await PlantService.getCategories();
      final plants = await PlantService.getPlants(
        categoryId: _selectedCategory?.id,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      final availablePlants = _filterAvailablePlants(plants.data);

      _categories = categories;
      _allPlants = availablePlants;
      _isAllCategory = _selectedCategory == null;
      _updateDisplayedPlants();

      _setLoading(false);
    } catch (e) {
      _setError('Что-то пошло не так', HomePageError.loadPlants);
      _setLoading(false);
    }
  }

  /// Выбор категории
  Future<void> selectCategory(Category? category) async {
    _selectedCategory = category;
    _isAllCategory = category == null;
    _currentCycle = 0;
    _setLoading(true);
    _clearError();

    try {
      final plants = await PlantService.getPlants(
        categoryId: category?.id,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      final availablePlants = _filterAvailablePlants(plants.data);
      _allPlants = availablePlants;
      _updateDisplayedPlants();
      _setLoading(false);
    } catch (e) {
      _setError('Что-то пошло не так', HomePageError.loadPlants);
      _setLoading(false);
    }
  }

  /// Установка поискового запроса с debounce
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

  /// Выполнение поиска
  Future<void> _performSearch(String query) async {
    _setLoading(true);
    _clearError();
    _currentCycle = 0;

    try {
      final plants = await PlantService.getPlants(
        categoryId: _selectedCategory?.id,
        search: query.isNotEmpty ? query : null,
      );

      final availablePlants = _filterAvailablePlants(plants.data);
      _allPlants = availablePlants;
      _isAllCategory = _selectedCategory == null;
      _updateDisplayedPlants();
      _setLoading(false);
    } catch (e) {
      _setError('Ошибка поиска', HomePageError.search);
      _setLoading(false);
    }
  }

  /// Загрузка следующего цикла для бесконечного скролла
  void loadNextCycle() {
    if (_allPlants.isEmpty || !_isAllCategory) return;

    _currentCycle++;
    _updateDisplayedPlants();
  }

  /// Проверка, нужно ли загружать следующий цикл
  bool shouldLoadMore(double scrollPosition, double maxScrollExtent) {
    return _isAllCategory &&
        _allPlants.isNotEmpty &&
        scrollPosition >= maxScrollExtent - HomeConstants.scrollThreshold;
  }

  /// Фильтрация растений по наличию в наличии
  List<Plant> _filterAvailablePlants(List<Plant> plants) {
    return plants.where((plant) => plant.stockQuantity > 0).toList();
  }

  /// Обновление списка отображаемых растений
  void _updateDisplayedPlants() {
    if (_allPlants.isEmpty) {
      _displayedPlants = [];
      notifyListeners();
      return;
    }

    // Для категории "Все" используем бесконечный скролл
    if (_isAllCategory) {
      _displayedPlants = _calculateDisplayedPlants();
    } else {
      // Для конкретной категории показываем все растения сразу
      _displayedPlants = _allPlants;
    }

    notifyListeners();
  }

  /// Расчет отображаемых растений для бесконечного скролла
  List<Plant> _calculateDisplayedPlants() {
    final List<Plant> newDisplayedPlants = [];

    // Собираем растения для всех циклов до текущего
    for (int i = 0; i <= _currentCycle; i++) {
      final startIndex = (i * HomeConstants.visibleItemsCount) % _allPlants.length;
      final endIndex = startIndex + HomeConstants.visibleItemsCount;

      if (endIndex <= _allPlants.length) {
        // Обычный случай - не выходим за границы
        newDisplayedPlants.addAll(_allPlants.sublist(startIndex, endIndex));
      } else {
        // Выходим за границы - берем с начала списка
        newDisplayedPlants.addAll(_allPlants.sublist(startIndex));
        final remainingCount = endIndex - _allPlants.length;
        newDisplayedPlants.addAll(_allPlants.sublist(0, remainingCount));
      }
    }

    return newDisplayedPlants;
  }

  /// Установка состояния загрузки
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Установка ошибки
  void _setError(String message, HomePageError type) {
    _error = message;
    _errorType = type;
    notifyListeners();
  }

  /// Очистка ошибки
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
