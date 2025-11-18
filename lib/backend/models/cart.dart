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
    return CartItem(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      plantId: json['plant_id'] ?? 0,
      quantity: json['quantity'] ?? 1,
      potColor: json['pot_color'],
      potSize: json['pot_size'],
      potMaterial: json['pot_material'],
      plantUnitPrice: (json['plant_unit_price'] ?? 0).toDouble(),
      potUnitPrice: (json['pot_unit_price'] ?? 0).toDouble(),
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      plant: Plant.fromJson(json['plant'] ?? {}),
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

  CartResponse({
    required this.items,
    required this.summary,
  });

  factory CartResponse.fromJson(Map<String, dynamic> json) {
    return CartResponse(
      items: (json['items'] as List? ?? []).map((item) => CartItem.fromJson(item)).toList(),
      summary: CartSummary.fromJson(json['summary'] ?? {}),
    );
  }
}

class WishlistItem {
  final int id;
  final int userId;
  final int plantId;
  final Plant plant;

  WishlistItem({
    required this.id,
    required this.userId,
    required this.plantId,
    required this.plant,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      plantId: json['plant_id'] ?? 0,
      plant: Plant.fromJson(json['plant'] ?? {}),
    );
  }
}

class WishlistResponse {
  final List<WishlistItem> items;
  final int count;

  WishlistResponse({
    required this.items,
    required this.count,
  });

  factory WishlistResponse.fromJson(Map<String, dynamic> json) {
    return WishlistResponse(
      items: (json['items'] as List? ?? []).map((item) => WishlistItem.fromJson(item)).toList(),
      count: json['count'] ?? 0,
    );
  }
}

class WishlistCheckResponse {
  final bool inWishlist;

  WishlistCheckResponse({
    required this.inWishlist,
  });

  factory WishlistCheckResponse.fromJson(Map<String, dynamic> json) {
    return WishlistCheckResponse(
      inWishlist: json['in_wishlist'] ?? false,
    );
  }
}

class PotMaterial {
  final int id;
  final String name;
  final String? description;

  PotMaterial({
    required this.id,
    required this.name,
    this.description,
  });

  factory PotMaterial.fromJson(Map<String, dynamic> json) {
    return PotMaterial(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
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
      code: json['code'] ?? '',
      name: json['name'] ?? '',
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

  PotColor({
    required this.id,
    required this.name,
    this.hexCode,
  });

  factory PotColor.fromJson(Map<String, dynamic> json) {
    return PotColor(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      hexCode: json['hex_code'],
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
      material: json['material'] != null ? PotMaterial.fromJson(json['material']) : null,
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
      material: json['material'] ?? '',
      size: json['size'] ?? '',
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

  UpdateCartRequest({
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'quantity': quantity,
    };
  }
}

class AddToWishlistRequest {
  final int plantId;

  AddToWishlistRequest({
    required this.plantId,
  });

  Map<String, dynamic> toJson() {
    return {
      'plant_id': plantId,
    };
  }
}