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
  final int stockQuantity;
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
    required this.stockQuantity,
    this.categoryId,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      inStock: json['in_stock'] ?? false,
      careInstructions: json['care_instructions']?.toString() ?? '',
      lightRequirements: json['light_requirements']?.toString() ?? '',
      wateringFrequency: json['watering_frequency']?.toString() ?? '',
      heightCm: (json['height_cm'] as num?)?.toInt() ?? 0,
      plantType: json['plant_type']?.toString(),
      recommendedPotSize: json['recommended_pot_size']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      imageUrl: json['image_url']?.toString(),
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt(),
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
