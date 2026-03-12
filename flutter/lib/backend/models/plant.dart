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
    final imageUrl = json['image_url']?.toString() ?? _extractImageUrl(json);
    final stockQuantity =
        (json['inventory_available'] as num?)?.toInt() ??
        (json['stock_quantity'] as num?)?.toInt() ??
        0;

    return Plant(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      inStock: (json['in_stock'] as bool?) ?? stockQuantity > 0,
      careInstructions: json['care_instructions']?.toString() ?? '',
      lightRequirements: json['light_requirements']?.toString() ?? '',
      wateringFrequency:
          json['watering_notes']?.toString() ??
          json['watering_frequency']?.toString() ??
          '',
      heightCm: (json['height_cm'] as num?)?.toInt() ?? 0,
      plantType:
          json['plant_type_name']?.toString() ?? json['plant_type']?.toString(),
      recommendedPotSize:
          json['recommended_pot_size_name']?.toString() ??
          json['recommended_pot_size']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      imageUrl: imageUrl,
      stockQuantity: stockQuantity,
      categoryId: (json['category_id'] as num?)?.toInt(),
    );
  }

  static String? _extractImageUrl(Map<String, dynamic> json) {
    final images = json['images'];
    if (images is! List || images.isEmpty) {
      return null;
    }

    final firstImage = images.first;
    if (firstImage is! Map<String, dynamic>) {
      return null;
    }

    return firstImage['image_url']?.toString();
  }

  String get fullImageUrl {
    return ApiConfig.imageUrl(imageUrl);
  }
}

class PaginationInfo {
  final int page;
  final int perPage;
  final int total;
  final int pages;

  const PaginationInfo({
    required this.page,
    required this.perPage,
    required this.total,
    required this.pages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: (json['page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      pages: (json['pages'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlantResponse {
  final bool success;
  final List<Plant> data;
  final int count;
  final PaginationInfo? pagination;

  PlantResponse({
    required this.success,
    required this.data,
    required this.count,
    this.pagination,
  });

  factory PlantResponse.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Plant.fromJson)
        .toList();

    return PlantResponse(
      success: json['success'] == true,
      data: data,
      count: (json['count'] as num?)?.toInt() ?? data.length,
      pagination: json['pagination'] is Map<String, dynamic>
          ? PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
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
