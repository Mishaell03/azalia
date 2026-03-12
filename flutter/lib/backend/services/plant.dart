import 'package:flutter/foundation.dart' hide Category;
import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/plant.dart';

class PlantService {
  static final ApiClient _api = ApiClient();

  /// Получение растений с фильтрами
  static Future<PlantResponse> getPlants({
    int? categoryId,
    bool? inStock,
    int? plantTypeId,
    String? search,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    double? maxRating,
    int page = 1,
    int perPage = 10,
    String sortBy = 'name',
  }) async {
    try {
      final params = <String, String>{};

      if (categoryId != null) params['category_id'] = categoryId.toString();
      if (inStock != null) params['in_stock'] = inStock.toString();
      if (plantTypeId != null) {
        params['plant_type_id'] = plantTypeId.toString();
      }
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      if (minPrice != null) params['min_price'] = minPrice.toString();
      if (maxPrice != null) params['max_price'] = maxPrice.toString();
      if (minRating != null) params['min_rating'] = minRating.toString();
      if (maxRating != null) params['max_rating'] = maxRating.toString();
      params['page'] = page.toString();
      params['per_page'] = perPage.toString();
      params['sort_by'] = sortBy;

      final url = Uri.parse(
        ApiConfig.plants,
      ).replace(queryParameters: params).toString();

      final response = await _api.get(url);
      debugPrint('PlantService: Растения загружены');
      return PlantResponse.fromJson(response);
    } catch (e) {
      debugPrint('PlantService: Исключение - $e');
      throw Exception("Не удалось загрузить растения");
    }
  }

  /// Получение растения по ID
  static Future<Plant> getPlantById(int id) async {
    try {
      final response = await _api.get(ApiConfig.plantsId(id));

      if (response['success'] == true) {
        debugPrint('PlantService: Растение загружено (id: $id)');
        return Plant.fromJson(response['data']);
      } else {
        debugPrint('PlantService: Ошибка API');
        throw Exception('Не удалось загрузить растение');
      }
    } catch (e) {
      debugPrint('PlantService: Исключение - $e');
      throw Exception('Не удалось загрузить растение');
    }
  }

  /// Получение категорий
  static Future<List<Category>> getCategories() async {
    try {
      final response = await _api.get(ApiConfig.categories);

      if (response['success']) {
        debugPrint('PlantService: Категории загружены');
        return (response['data'] as List)
            .map((categoryJson) => Category.fromJson(categoryJson))
            .toList();
      } else {
        debugPrint('PlantService: Ошибка API категорий');
        throw Exception('Не удалось загрузить категории');
      }
    } catch (e) {
      debugPrint('PlantService: Исключение - $e');
      throw Exception('Не удалось загрузить категории');
    }
  }

  /// Получение растений с высоким рейтингом
  static Future<PlantResponse> getTopRatedPlants({
    double minRating = 4.0,
    int limit = 10,
  }) async {
    try {
      return getPlants(
        minRating: minRating,
        page: 1,
        perPage: limit,
        sortBy: 'rating_desc',
      );
    } catch (e) {
      debugPrint('PlantService: Исключение - $e');
      throw Exception("Не удалось загрузить популярные растения");
    }
  }

  /// Получение фильтров
  static Future<Map<String, dynamic>> getFilters() async {
    try {
      final response = await _api.get(ApiConfig.filters);

      if (response['success']) {
        debugPrint('PlantService: Фильтры загружены');
        return response['data'];
      } else {
        debugPrint('PlantService: Ошибка API фильтров');
        throw Exception('Не удалось загрузить фильтры');
      }
    } catch (e) {
      debugPrint('PlantService: Исключение - $e');
      throw Exception('Не удалось загрузить фильтры');
    }
  }
}
