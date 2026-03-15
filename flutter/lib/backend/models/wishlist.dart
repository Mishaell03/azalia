import 'package:azalia/backend/models/plant.dart';

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
    final productId =
        (json['plant_id'] as num?)?.toInt() ??
        (json['product_id'] as num?)?.toInt() ??
        0;

    return WishlistItem(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      plantId: productId,
      plant: json['plant'] is Map<String, dynamic>
          ? Plant.fromJson(json['plant'] as Map<String, dynamic>)
          : Plant.fromJson({
              'id': productId,
              'name': json['product_name'],
              'base_price': 0,
              'image_url': json['image_url'],
              'stock_quantity': json['stock_quantity'] ?? 0,
              'in_stock': json['in_stock'] ?? false,
              'is_active': json['is_active'] ?? true,
              'deleted_at': json['deleted_at'],
            }),
    );
  }

  WishlistItem copyWith({Plant? plant}) {
    return WishlistItem(
      id: id,
      userId: userId,
      plantId: plantId,
      plant: plant ?? this.plant,
    );
  }
}

class WishlistResponse {
  final List<WishlistItem> items;
  final int count;

  WishlistResponse({required this.items, required this.count});

  factory WishlistResponse.fromJson(Map<String, dynamic> json) {
    return WishlistResponse(
      items: (json['items'] as List? ?? [])
          .map((item) => WishlistItem.fromJson(item))
          .toList(),
      count: json['count'] ?? 0,
    );
  }
}

class WishlistCheckResponse {
  final bool inWishlist;

  WishlistCheckResponse({required this.inWishlist});

  factory WishlistCheckResponse.fromJson(Map<String, dynamic> json) {
    return WishlistCheckResponse(inWishlist: json['in_wishlist'] ?? false);
  }
}

class AddToWishlistRequest {
  final int plantId;

  AddToWishlistRequest({required this.plantId});

  Map<String, dynamic> toJson() {
    return {'plant_id': plantId};
  }
}
