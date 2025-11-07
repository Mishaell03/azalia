import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/plant.dart';

class PlantService {
  Future<PlantResponse> getPlant() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.plants), headers: ApiConfig.headers)
          .timeout(ApiConfig.timeout);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return PlantResponse.fromJson(data);
      } else {
        throw Exception("Ошибка сервера: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Ошбка загрузки растения: $e");
    }
  }

  Future<Plant> getPlantById(int id) async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.plantsId(id)), headers: ApiConfig.headers)
          .timeout(ApiConfig.timeout);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return Plant.fromJson(data['data']);
        } else {
          throw Exception('Ошибка API: ${data['error']}');
        }
      } else {
        throw Exception('Ошбка Сервера: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка загрузки сервера: $e');
    }
  }

  Future<List<Category>> getCategory() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.categories), headers: ApiConfig.headers)
          .timeout(ApiConfig.timeout);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success']) {
          return (data['data'] as List)
              .map((categoryJson) => Category.fromJson(categoryJson))
              .toList();
        } else {
          throw Exception('Оштибка API: ${data['error']}');
        }
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка загрузки категорий: $e');
    }
  }
}
