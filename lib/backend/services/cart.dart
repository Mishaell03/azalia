import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/cart.dart';

class CartService {
  static Future<CartResponse> getCart(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.cartItems),
      headers: ApiConfig.headers(authToken: token),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        return CartResponse.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['error'] ?? 'Failed to load cart');
      }
    } else {
      throw Exception('Failed to load cart: ${response.statusCode}');
    }
  }

  static Future<CartItem> addToCart(String token, AddToCartRequest request) async {
    final response = await http.post(
      Uri.parse(ApiConfig.cartItems),
      headers: ApiConfig.headers(authToken: token),
      body: json.encode(request.toJson()),
    );

    final Map<String, dynamic> responseData = json.decode(response.body);
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      if (responseData['success'] == true) {
        return CartItem.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['error'] ?? 'Failed to add to cart');
      }
    } else {
      throw Exception(responseData['error'] ?? 'Failed to add to cart: ${response.statusCode}');
    }
  }

  static Future<CartItem> updateCartItem(String token, int itemId, int quantity) async {
    final response = await http.put(
      Uri.parse(ApiConfig.cartItemId(itemId)),
      headers: ApiConfig.headers(authToken: token),
      body: json.encode({'quantity': quantity}),
    );

    final Map<String, dynamic> responseData = json.decode(response.body);
    
    if (response.statusCode == 200) {
      if (responseData['success'] == true) {
        return CartItem.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['error'] ?? 'Failed to update cart');
      }
    } else {
      throw Exception(responseData['error'] ?? 'Failed to update cart: ${response.statusCode}');
    }
  }

  static Future<void> removeFromCart(String token, int itemId) async {
    final response = await http.delete(
      Uri.parse(ApiConfig.cartItemId(itemId)),
      headers: ApiConfig.headers(authToken: token),
    );

    final Map<String, dynamic> responseData = json.decode(response.body);
    
    if (response.statusCode != 200) {
      throw Exception(responseData['error'] ?? 'Failed to remove from cart: ${response.statusCode}');
    }
  }

  static Future<void> clearCart(String token) async {
    final response = await http.delete(
      Uri.parse(ApiConfig.cartClear),
      headers: ApiConfig.headers(authToken: token),
    );

    final Map<String, dynamic> responseData = json.decode(response.body);
    
    if (response.statusCode != 200) {
      throw Exception(responseData['error'] ?? 'Failed to clear cart: ${response.statusCode}');
    }
  }
}

class WishlistService {
  static Future<WishlistResponse> getWishlist(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.wishlist),
      headers: ApiConfig.headers(authToken: token),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        return WishlistResponse.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['error'] ?? 'Failed to load wishlist');
      }
    } else {
      throw Exception('Failed to load wishlist: ${response.statusCode}');
    }
  }

  static Future<WishlistItem> addToWishlist(String token, int plantId) async {
    final response = await http.post(
      Uri.parse(ApiConfig.wishlist),
      headers: ApiConfig.headers(authToken: token),
      body: json.encode({'plant_id': plantId}),
    );

    final Map<String, dynamic> responseData = json.decode(response.body);
    
    if (response.statusCode == 201) {
      if (responseData['success'] == true) {
        return WishlistItem.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['error'] ?? 'Failed to add to wishlist');
      }
    } else {
      throw Exception(responseData['error'] ?? 'Failed to add to wishlist: ${response.statusCode}');
    }
  }

  static Future<void> removeFromWishlist(String token, int plantId) async {
    final response = await http.delete(
      Uri.parse(ApiConfig.wishlistRemove(plantId)),
      headers: ApiConfig.headers(authToken: token),
    );

    final Map<String, dynamic> responseData = json.decode(response.body);
    
    if (response.statusCode != 200) {
      throw Exception(responseData['error'] ?? 'Failed to remove from wishlist: ${response.statusCode}');
    }
  }

  static Future<bool> checkWishlist(String token, int plantId) async {
    final response = await http.get(
      Uri.parse(ApiConfig.wishlistCheck(plantId)),
      headers: ApiConfig.headers(authToken: token),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        return WishlistCheckResponse.fromJson(responseData['data']).inWishlist;
      } else {
        throw Exception(responseData['error'] ?? 'Failed to check wishlist');
      }
    } else {
      throw Exception('Failed to check wishlist: ${response.statusCode}');
    }
  }
}

class PotService {
  static Future<List<PotMaterial>> getMaterials() async {
    final response = await http.get(
      Uri.parse(ApiConfig.potMaterials),
      headers: ApiConfig.headers(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        final data = responseData['data'] as List;
        return data.map((item) => PotMaterial.fromJson(item)).toList();
      } else {
        throw Exception(responseData['error'] ?? 'Failed to load materials');
      }
    } else {
      throw Exception('Failed to load materials: ${response.statusCode}');
    }
  }

  static Future<List<PotSize>> getSizes() async {
    final response = await http.get(
      Uri.parse(ApiConfig.potSizes),
      headers: ApiConfig.headers(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        final data = responseData['data'] as List;
        return data.map((item) => PotSize.fromJson(item)).toList();
      } else {
        throw Exception(responseData['error'] ?? 'Failed to load sizes');
      }
    } else {
      throw Exception('Failed to load sizes: ${response.statusCode}');
    }
  }

  static Future<List<PotColor>> getColors() async {
    final response = await http.get(
      Uri.parse(ApiConfig.potColors),
      headers: ApiConfig.headers(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        final data = responseData['data'] as List;
        return data.map((item) => PotColor.fromJson(item)).toList();
      } else {
        throw Exception(responseData['error'] ?? 'Failed to load colors');
      }
    } else {
      throw Exception('Failed to load colors: ${response.statusCode}');
    }
  }

  // Метод для получения цены горшка по материалу и размеру через API
  static Future<double> getPotPrice(String material, String size) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.potPriceByParams(material, size)),
        headers: ApiConfig.headers(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return (responseData['data']['price'] ?? 0).toDouble();
        } else {
          throw Exception(responseData['error'] ?? 'Failed to get pot price');
        }
      } else {
        throw Exception('Failed to get pot price: ${response.statusCode}');
      }
    } catch (e) {
      // В случае ошибки возвращаем 0
      print('Error getting pot price: $e');
      return 0.0;
    }
  }

  // Исправленный метод для получения всех цен
  static Future<List<PotPrice>> getPrices() async {
    final response = await http.get(
      Uri.parse(ApiConfig.potPrices),
      headers: ApiConfig.headers(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        final data = responseData['data'] as List;
        return data.map((item) => PotPrice.fromJson(item)).toList();
      } else {
        throw Exception(responseData['error'] ?? 'Failed to load prices');
      }
    } else {
      throw Exception('Failed to load prices: ${response.statusCode}');
    }
  }
}