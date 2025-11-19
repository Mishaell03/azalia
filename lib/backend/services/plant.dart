import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/plant.dart';

class PlantService {
  // получение растений с фильтрами
  Future<PlantResponse> getPlants({
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

      final uri = Uri.parse(ApiConfig.plants).replace(queryParameters: params);
      
      final response = await http
          .get(uri, headers: ApiConfig.headers())
          .timeout(ApiConfig.timeout);
          
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('PlantService: Растения загружены');
        return PlantResponse.fromJson(data);
      } else {
        debugPrint('PlantService: Ошибка сервера ${response.statusCode}');
        throw Exception("Не удалось загрузить растения");
      }
    } catch (e) {
      debugPrint('PlantService: Исключение - $e');
      throw Exception("Не удалось загрузить растения");
    }
  }

  // получение растения по ID
  Future<Plant> getPlantById(int id) async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.plantsId(id)), headers: ApiConfig.headers())
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          debugPrint('PlantService: Растение загружено (id: $id)');
          return Plant.fromJson(data['data']);
        } else {
          debugPrint('PlantService: Ошибка API');
          throw Exception('Не удалось загрузить растение');
        }
      } else {
        debugPrint('PlantService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось загрузить растение');
      }
    } catch (e) {
      debugPrint('PlantService: Исключение - $e');
      throw Exception('Не удалось загрузить растение');
    }
  }

  // получение категорий
  Future<List<Category>> getCategories() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.categories), headers: ApiConfig.headers())
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success']) {
          debugPrint('PlantService: Категории загружены');
          return (data['data'] as List)
              .map((categoryJson) => Category.fromJson(categoryJson))
              .toList();
        } else {
          debugPrint('PlantService: Ошибка API категорий');
          throw Exception('Не удалось загрузить категории');
        }
      } else {
        debugPrint('PlantService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось загрузить категории');
      }
    } catch (e) {
      debugPrint('PlantService: Исключение - $e');
      throw Exception('Не удалось загрузить категории');
    }
  }

  // получение растений с высоким рейтингом
  Future<PlantResponse> getTopRatedPlants({
    double minRating = 4.0,
    int limit = 10,
  }) async {
    try {
      final params = {
        'min_rating': minRating.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse(
        ApiConfig.topRated,
      ).replace(queryParameters: params);

      final response = await http
          .get(uri, headers: ApiConfig.headers())
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('PlantService: Популярные растения загружены');
        return PlantResponse.fromJson(data);
      } else {
        debugPrint('PlantService: Ошибка сервера ${response.statusCode}');
        throw Exception("Не удалось загрузить популярные растения");
      }
    } catch (e) {
      debugPrint('PlantService: Исключение - $e');
      throw Exception("Не удалось загрузить популярные растения");
    }
  }

  // получение фильтров
  Future<Map<String, dynamic>> getFilters() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.filters), headers: ApiConfig.headers())
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success']) {
          debugPrint('PlantService: Фильтры загружены');
          return data['data'];
        } else {
          debugPrint('PlantService: Ошибка API фильтров');
          throw Exception('Не удалось загрузить фильтры');
        }
      } else {
        debugPrint('PlantService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось загрузить фильтры');
      }
    } catch (e) {
      debugPrint('PlantService: Исключение - $e');
      throw Exception('Не удалось загрузить фильтры');
    }
  }
}