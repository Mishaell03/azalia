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
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      basePrice: (json['basePrice'] as num).toDouble(),
      inStock: json['inStock'] ?? false,
      careInstructions: json['care_instructions'] ?? '',
      lightRequirements: json['light_requirements'] ?? '',
      wateringFrequency: json['watering_frequency'] ?? '',
      heightCm: json['heightCm'] ?? 0,
      plantType: json['plant_type'],
      recommendedPotSize: json['recommended_pot_size'],
    );
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

  Category({required this.id, required this.name, required this.description});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
    );
  }
}
