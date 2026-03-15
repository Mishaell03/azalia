import 'package:azalia/backend/models/plant.dart';

class CartItem {
  final int id;
  final int userId;
  final int plantId;
  final int quantity;
  final String? potColor;
  final String? potSize;
  final String? potMaterial;
  final double plantUnitPrice;
  final double potUnitPrice;
  final double totalPrice;
  final Plant plant;

  CartItem({
    required this.id,
    required this.userId,
    required this.plantId,
    required this.quantity,
    this.potColor,
    this.potSize,
    this.potMaterial,
    required this.plantUnitPrice,
    required this.potUnitPrice,
    required this.totalPrice,
    required this.plant,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productId =
        (json['plant_id'] as num?)?.toInt() ??
        (json['product_id'] as num?)?.toInt() ??
        0;

    return CartItem(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      plantId: productId,
      quantity: json['quantity'] ?? 1,
      potColor: json['pot_color']?.toString(),
      potSize: json['pot_size']?.toString(),
      potMaterial: json['pot_material']?.toString(),
      plantUnitPrice:
          (json['plant_unit_price'] ?? json['product_unit_price'] ?? 0)
              .toDouble(),
      potUnitPrice: (json['pot_unit_price'] ?? 0).toDouble(),
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      plant: json['plant'] is Map<String, dynamic>
          ? Plant.fromJson(json['plant'] as Map<String, dynamic>)
          : Plant.fromJson({
              'id': productId,
              'name': json['product_name'],
              'base_price':
                  json['plant_unit_price'] ?? json['product_unit_price'],
              'image_url': json['image_url'],
              'stock_quantity': json['stock_quantity'] ?? 0,
              'in_stock': json['in_stock'] ?? false,
              'is_active': json['is_active'] ?? true,
              'deleted_at': json['deleted_at'],
            }),
    );
  }

  CartItem copyWith({Plant? plant}) {
    return CartItem(
      id: id,
      userId: userId,
      plantId: plantId,
      quantity: quantity,
      potColor: potColor,
      potSize: potSize,
      potMaterial: potMaterial,
      plantUnitPrice: plantUnitPrice,
      potUnitPrice: potUnitPrice,
      totalPrice: totalPrice,
      plant: plant ?? this.plant,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plant_id': plantId,
      'quantity': quantity,
      'pot_color': potColor,
      'pot_size': potSize,
      'pot_material': potMaterial,
      'plant_unit_price': plantUnitPrice,
      'pot_unit_price': potUnitPrice,
      'total_price': totalPrice,
    };
  }
}

class CartSummary {
  final int totalItems;
  final double totalPrice;
  final int itemsCount;

  CartSummary({
    required this.totalItems,
    required this.totalPrice,
    required this.itemsCount,
  });

  factory CartSummary.fromJson(Map<String, dynamic> json) {
    return CartSummary(
      totalItems: json['total_items'] ?? 0,
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      itemsCount: json['items_count'] ?? 0,
    );
  }
}

class CartResponse {
  final List<CartItem> items;
  final CartSummary summary;

  CartResponse({required this.items, required this.summary});

  factory CartResponse.fromJson(Map<String, dynamic> json) {
    return CartResponse(
      items: (json['items'] as List? ?? [])
          .map((item) => CartItem.fromJson(item))
          .toList(),
      summary: CartSummary.fromJson(json['summary'] ?? {}),
    );
  }
}

class PotMaterial {
  final int id;
  final String name;
  final String? description;

  PotMaterial({required this.id, required this.name, this.description});

  factory PotMaterial.fromJson(Map<String, dynamic> json) {
    return PotMaterial(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}

class PotSize {
  final int id;
  final String code;
  final String name;
  final int? diameterCm;
  final int? heightCm;
  final double? volumeLiters;

  PotSize({
    required this.id,
    required this.code,
    required this.name,
    this.diameterCm,
    this.heightCm,
    this.volumeLiters,
  });

  factory PotSize.fromJson(Map<String, dynamic> json) {
    return PotSize(
      id: json['id'] ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      diameterCm: json['diameter_cm'],
      heightCm: json['height_cm'],
      volumeLiters: (json['volume_liters'] ?? 0).toDouble(),
    );
  }
}

class PotColor {
  final int id;
  final String name;
  final String? hexCode;

  PotColor({required this.id, required this.name, this.hexCode});

  factory PotColor.fromJson(Map<String, dynamic> json) {
    return PotColor(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      hexCode: json['hex_code']?.toString(),
    );
  }
}

class PotPrice {
  final int id;
  final int materialId;
  final int sizeId;
  final double price;
  final PotMaterial? material;
  final PotSize? size;

  PotPrice({
    required this.id,
    required this.materialId,
    required this.sizeId,
    required this.price,
    this.material,
    this.size,
  });

  factory PotPrice.fromJson(Map<String, dynamic> json) {
    return PotPrice(
      id: json['id'] ?? 0,
      materialId: json['material_id'] ?? 0,
      sizeId: json['size_id'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      material: json['material'] != null
          ? PotMaterial.fromJson(json['material'])
          : null,
      size: json['size'] != null ? PotSize.fromJson(json['size']) : null,
    );
  }
}

class PotPriceResponse {
  final double price;
  final String material;
  final String size;

  PotPriceResponse({
    required this.price,
    required this.material,
    required this.size,
  });

  factory PotPriceResponse.fromJson(Map<String, dynamic> json) {
    return PotPriceResponse(
      price: (json['price'] ?? 0).toDouble(),
      material: json['material']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
    );
  }
}

class AddToCartRequest {
  final int plantId;
  final int quantity;
  final String? potColor;
  final String? potSize;
  final String? potMaterial;

  AddToCartRequest({
    required this.plantId,
    required this.quantity,
    this.potColor,
    this.potSize,
    this.potMaterial,
  });

  Map<String, dynamic> toJson() {
    return {
      'plant_id': plantId,
      'quantity': quantity,
      'pot_color': potColor,
      'pot_size': potSize,
      'pot_material': potMaterial,
    };
  }
}

class UpdateCartRequest {
  final int quantity;

  UpdateCartRequest({required this.quantity});

  Map<String, dynamic> toJson() {
    return {'quantity': quantity};
  }
}

class CartItemWithPot {
  final int id;
  final int userId;
  final int plantId;
  final int quantity;
  final String? potColor;
  final String? potSize;
  final String? potMaterial;
  final double plantUnitPrice;
  final double potUnitPrice;
  final double totalPrice;
  final Plant plant;
  final PotDetails? potDetails;

  CartItemWithPot({
    required this.id,
    required this.userId,
    required this.plantId,
    required this.quantity,
    this.potColor,
    this.potSize,
    this.potMaterial,
    required this.plantUnitPrice,
    required this.potUnitPrice,
    required this.totalPrice,
    required this.plant,
    this.potDetails,
  });

  factory CartItemWithPot.fromCartItem(
    CartItem item, {
    PotDetails? potDetails,
  }) {
    return CartItemWithPot(
      id: item.id,
      userId: item.userId,
      plantId: item.plantId,
      quantity: item.quantity,
      potColor: item.potColor,
      potSize: item.potSize,
      potMaterial: item.potMaterial,
      plantUnitPrice: item.plantUnitPrice,
      potUnitPrice: item.potUnitPrice,
      totalPrice: item.totalPrice,
      plant: item.plant,
      potDetails: potDetails,
    );
  }

  String get potDescription {
    if (potMaterial == null && potSize == null && potColor == null) {
      return 'Без горшка';
    }

    final parts = <String>[];
    if (potMaterial != null) parts.add(potMaterial!);
    if (potSize != null) parts.add(potSize!);
    if (potColor != null) parts.add(potColor!);

    return parts.join(', ');
  }

  double get itemTotal => plantUnitPrice + potUnitPrice;
}

class PotDetails {
  final String material;
  final String size;
  final String color;
  final double price;

  PotDetails({
    required this.material,
    required this.size,
    required this.color,
    required this.price,
  });

  factory PotDetails.fromJson(Map<String, dynamic> json) {
    return PotDetails(
      material: json['material'] ?? '',
      size: json['size'] ?? '',
      color: json['color'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
    );
  }
}
