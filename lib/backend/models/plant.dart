import 'package:azalia/backend/api_config.dart';

class Plant {
  final int id;
  final String name;
  final String description;
  final double basePrice;
  final bool inStock;
  final String careInstructions;
  final String lightRequirements;
  final String wateringFrequency;
  final int heightCm;
  final String? plantType;
  final String? recommendedPotSize;
  final double? rating;
  final String? imageUrl;
  final int? categoryId;

  Plant({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.inStock,
    required this.careInstructions,
    required this.lightRequirements,
    required this.wateringFrequency,
    required this.heightCm,
    required this.plantType,
    required this.recommendedPotSize,
    this.rating,
    this.imageUrl,
    this.categoryId,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      inStock: json['in_stock'] ?? false,
      careInstructions: json['care_instructions'] ?? '',
      lightRequirements: json['light_requirements'] ?? '',
      wateringFrequency: json['watering_frequency'] ?? '',
      heightCm: json['height_cm'] ?? 0,
      plantType: json['plant_type'],
      recommendedPotSize: json['recommended_pot_size'],
      rating: (json['rating'] as num?)?.toDouble(),
      imageUrl: json['image_url'],
      categoryId: json['category_id'],
    );
  }

  String get fullImageUrl {
    return ApiConfig.imageUrl(imageUrl);
  }
}

class PlantResponse {
  final bool success;
  final List<Plant> data;
  final int count;

  PlantResponse({
    required this.success,
    required this.data,
    required this.count,
  });

  factory PlantResponse.fromJson(Map<String, dynamic> json) {
    return PlantResponse(
      success: json['success'],
      data: (json['data'] as List)
          .map((PlantJson) => Plant.fromJson(PlantJson))
          .toList(),
      count: json['count'],
    );
  }
}

class Category {
  final int id;
  final String name;
  final String description;
  final int? parentId;

  Category({
    required this.id,
    required this.name,
    required this.description,
    this.parentId,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      parentId: json['parent_id'],
    );
  }
}
