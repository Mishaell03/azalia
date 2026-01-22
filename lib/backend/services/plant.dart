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
    String? plantType,
    String? search,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    double? maxRating,
  }) async {
    try {
      final params = <String, String>{};
      
      if (categoryId != null) params['category_id'] = categoryId.toString();
      if (inStock != null) params['in_stock'] = inStock.toString();
      if (plantType != null) params['plant_type'] = plantType;
      if (search != null) params['search'] = search;
      if (minPrice != null) params['min_price'] = minPrice.toString();
      if (maxPrice != null) params['max_price'] = maxPrice.toString();
      if (minRating != null) params['min_rating'] = minRating.toString();
      if (maxRating != null) params['max_rating'] = maxRating.toString();

      String url = ApiConfig.plants;
      if (params.isNotEmpty) {
        final queryString = params.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url = '$url?$queryString';
      }
      
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
      final params = {
        'min_rating': minRating.toString(),
        'limit': limit.toString(),
      };

      String url = ApiConfig.topRated;
      if (params.isNotEmpty) {
        final queryString = params.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url = '$url?$queryString';
      }

      final response = await _api.get(url);
      debugPrint('PlantService: Популярные растения загружены');
      return PlantResponse.fromJson(response);
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
