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
