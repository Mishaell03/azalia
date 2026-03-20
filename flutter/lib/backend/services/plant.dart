import 'dart:io';

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
    bool includeInactive = false,
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
      if (includeInactive) params['include_inactive'] = 'true';

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

  /// Создание категории (админ)
  static Future<Category> createCategory({
    required String name,
    String? description,
    int? parentId,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.adminCategoriesCreate,
        body: {
          'name': name,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          if (parentId != null) 'parent_id': parentId,
        },
      );
      if (response['success'] != true) {
        throw Exception('Не удалось создать категорию');
      }
      final data = response['data'] as Map<String, dynamic>? ?? const {};
      return Category(
        id: (data['id'] as num?)?.toInt() ?? 0,
        name: data['name']?.toString() ?? name,
        description: description ?? '',
        parentId: (data['parent_id'] as num?)?.toInt(),
      );
    } catch (e) {
      debugPrint('PlantService: createCategory исключение - $e');
      throw Exception('Не удалось создать категорию');
    }
  }

  /// Удаление категории (админ)
  static Future<void> deleteCategory(int categoryId) async {
    try {
      final response = await _api.delete(
        ApiConfig.adminCategoryDelete(categoryId),
      );
      if (response['success'] != true) {
        throw Exception('Не удалось удалить категорию');
      }
    } catch (e) {
      debugPrint('PlantService: deleteCategory исключение - $e');
      throw Exception('Не удалось удалить категорию');
    }
  }

  /// Проверка удаления категории и список товаров в ней (админ)
  static Future<Map<String, dynamic>> getCategoryDeletionCheck(
    int categoryId,
  ) async {
    try {
      final response = await _api.get(
        ApiConfig.adminCategoryDeletionCheck(categoryId),
      );
      if (response['success'] != true) {
        throw Exception('Не удалось получить информацию по категории');
      }
      return response['data'] as Map<String, dynamic>? ?? const {};
    } catch (e) {
      debugPrint('PlantService: getCategoryDeletionCheck исключение - $e');
      throw Exception('Не удалось получить информацию по категории');
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

  /// Обновление товара
  static Future<void> updatePlant(
    int id, {
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _api.put(ApiConfig.plantsId(id), body: payload);
      if (response['success'] != true) {
        throw Exception('Не удалось обновить товар');
      }
    } catch (e) {
      debugPrint('PlantService: updatePlant исключение - $e');
      throw Exception('Не удалось обновить товар');
    }
  }

  /// Создание товара (админ)
  static Future<int> createPlant({
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.plantsAdminCreate,
        body: payload,
      );
      if (response['success'] != true) {
        throw Exception('Не удалось создать товар');
      }

      final data = response['data'] as Map<String, dynamic>?;
      final id = (data?['id'] as num?)?.toInt();
      if (id == null || id <= 0) {
        throw Exception('Некорректный id созданного товара');
      }
      return id;
    } catch (e) {
      debugPrint('PlantService: createPlant исключение - $e');
      throw Exception('Не удалось создать товар');
    }
  }

  /// Загрузка превью изображения товара
  static Future<String> uploadPlantImage(int id, File imageFile) async {
    try {
      final response = await _api.postMultipart(
        '${ApiConfig.plantsId(id)}/image',
        file: imageFile,
        fieldName: 'image',
      );
      if (response['success'] != true) {
        throw Exception('Не удалось загрузить изображение');
      }
      return (response['image_url'] ?? '').toString();
    } catch (e) {
      debugPrint('PlantService: uploadPlantImage исключение - $e');
      throw Exception('Не удалось загрузить изображение');
    }
  }

  /// Загрузка фото для подробной информации товара (галерея)
  static Future<String> uploadPlantDetailImage(int id, File imageFile) async {
    try {
      final response = await _api.postMultipart(
        '${ApiConfig.plantsId(id)}/images',
        file: imageFile,
        fieldName: 'image',
      );
      if (response['success'] != true) {
        throw Exception('Не удалось загрузить изображение');
      }
      return (response['image_url'] ?? '').toString();
    } catch (e) {
      debugPrint('PlantService: uploadPlantDetailImage исключение - $e');
      throw Exception('Не удалось загрузить изображение');
    }
  }

  /// Получить все изображения товара (админ)
  static Future<List<Map<String, dynamic>>> getPlantImages(int id) async {
    try {
      final response = await _api.get('${ApiConfig.plantsId(id)}/images');
      if (response['success'] != true) {
        throw Exception('Не удалось загрузить изображения');
      }
      final data = response['data'] as Map<String, dynamic>? ?? const {};
      final items = data['items'] as List? ?? const [];
      return items.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('PlantService: getPlantImages исключение - $e');
      throw Exception('Не удалось загрузить изображения');
    }
  }

  /// Удалить одно изображение товара (админ)
  static Future<void> deletePlantImageById(int plantId, int imageId) async {
    try {
      final response = await _api.delete(
        '${ApiConfig.plantsId(plantId)}/images/$imageId',
      );
      if (response['success'] != true) {
        throw Exception('Не удалось удалить изображение');
      }
    } catch (e) {
      debugPrint('PlantService: deletePlantImageById исключение - $e');
      throw Exception('Не удалось удалить изображение');
    }
  }
}
