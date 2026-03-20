import 'package:azalia/backend/api_config.dart';

class Plant {
  final int id;
  final String name;
  final String description;
  final double basePrice;
  final double costPrice;
  final bool inStock;
  final String careInstructions;
  final String lightRequirements;
  final String wateringFrequency;
  final int heightCm;
  final String? plantType;
  final String? recommendedPotSize;
  final int? recommendedPotSizeId;
  final double? rating;
  final String? imageUrl;
  final List<String> productImages;
  final int stockQuantity;
  final int? categoryId;
  final bool isActive;
  final String? deletedAt;

  Plant({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.costPrice,
    required this.inStock,
    required this.careInstructions,
    required this.lightRequirements,
    required this.wateringFrequency,
    required this.heightCm,
    required this.plantType,
    required this.recommendedPotSize,
    this.recommendedPotSizeId,
    this.rating,
    this.imageUrl,
    this.productImages = const [],
    required this.stockQuantity,
    this.categoryId,
    required this.isActive,
    this.deletedAt,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    final imageUrl = json['image_url']?.toString() ?? _extractImageUrl(json);
    final productImages = _extractGallery(json, imageUrl);
    final stockQuantity =
        (json['inventory_available'] as num?)?.toInt() ??
        (json['stock_quantity'] as num?)?.toInt() ??
        0;

    return Plant(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
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
      recommendedPotSizeId: (json['recommended_pot_size_id'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble(),
      imageUrl: imageUrl,
      productImages: productImages,
      stockQuantity: stockQuantity,
      categoryId: (json['category_id'] as num?)?.toInt(),
      isActive: json['is_active'] == null
          ? true
          : (json['is_active'] == true || json['is_active'] == 1),
      deletedAt: json['deleted_at']?.toString(),
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

  static List<String> _extractGallery(
    Map<String, dynamic> json,
    String? fallback,
  ) {
    final images = json['images'];
    if (images is List) {
      final list = images
          .whereType<Map<String, dynamic>>()
          .map((e) => e['image_url']?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    }
    if ((fallback ?? '').trim().isNotEmpty) {
      return [fallback!.trim()];
    }
    return const [];
  }

  String get fullImageUrl {
    return ApiConfig.imageUrl(imageUrl);
  }

  Plant copyWith({
    int? id,
    String? name,
    String? description,
    double? basePrice,
    double? costPrice,
    bool? inStock,
    String? careInstructions,
    String? lightRequirements,
    String? wateringFrequency,
    int? heightCm,
    String? plantType,
    String? recommendedPotSize,
    int? recommendedPotSizeId,
    double? rating,
    String? imageUrl,
    List<String>? productImages,
    int? stockQuantity,
    int? categoryId,
    bool? isActive,
    String? deletedAt,
  }) {
    return Plant(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      costPrice: costPrice ?? this.costPrice,
      inStock: inStock ?? this.inStock,
      careInstructions: careInstructions ?? this.careInstructions,
      lightRequirements: lightRequirements ?? this.lightRequirements,
      wateringFrequency: wateringFrequency ?? this.wateringFrequency,
      heightCm: heightCm ?? this.heightCm,
      plantType: plantType ?? this.plantType,
      recommendedPotSize: recommendedPotSize ?? this.recommendedPotSize,
      recommendedPotSizeId: recommendedPotSizeId ?? this.recommendedPotSizeId,
      rating: rating ?? this.rating,
      imageUrl: imageUrl ?? this.imageUrl,
      productImages: productImages ?? this.productImages,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      categoryId: categoryId ?? this.categoryId,
      isActive: isActive ?? this.isActive,
      deletedAt: deletedAt ?? this.deletedAt,
    );
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
