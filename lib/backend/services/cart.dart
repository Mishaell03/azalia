import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/cart.dart';

class CartService {
  static Future<CartResponse> getCart(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.cartItems),
        headers: ApiConfig.headers(authToken: token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('CartService: Корзина загружена');
          return CartResponse.fromJson(responseData['data']);
        } else {
          debugPrint('CartService: Ошибка загрузки корзины');
          throw Exception('Не удалось загрузить корзину');
        }
      } else {
        debugPrint('CartService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось загрузить корзину');
      }
    } catch (e) {
      debugPrint('CartService: Исключение - $e');
      throw Exception('Не удалось загрузить корзину');
    }
  }

  static Future<CartItem> addToCart(String token, AddToCartRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.cartItems),
        headers: ApiConfig.headers(authToken: token),
        body: json.encode(request.toJson()),
      );

      final Map<String, dynamic> responseData = json.decode(response.body);
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (responseData['success'] == true) {
          debugPrint('CartService: Товар добавлен в корзину');
          return CartItem.fromJson(responseData['data']);
        } else {
          debugPrint('CartService: Ошибка добавления в корзину');
          throw Exception('Не удалось добавить в корзину');
        }
      } else {
        debugPrint('CartService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось добавить в корзину');
      }
    } catch (e) {
      debugPrint('CartService: Исключение - $e');
      throw Exception('Не удалось добавить в корзину');
    }
  }

  static Future<CartItem> updateCartItem(String token, int itemId, int quantity) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.cartItemId(itemId)),
        headers: ApiConfig.headers(authToken: token),
        body: json.encode({'quantity': quantity}),
      );

      final Map<String, dynamic> responseData = json.decode(response.body);
      
      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          debugPrint('CartService: Корзина обновлена');
          return CartItem.fromJson(responseData['data']);
        } else {
          debugPrint('CartService: Ошибка обновления корзины');
          throw Exception('Не удалось обновить корзину');
        }
      } else {
        debugPrint('CartService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось обновить корзину');
      }
    } catch (e) {
      debugPrint('CartService: Исключение - $e');
      throw Exception('Не удалось обновить корзину');
    }
  }

  static Future<void> removeFromCart(String token, int itemId) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.cartItemId(itemId)),
        headers: ApiConfig.headers(authToken: token),
      );

      if (response.statusCode != 200) {
        debugPrint('CartService: Ошибка удаления из корзины');
        throw Exception('Не удалось удалить из корзины');
      } else {
        debugPrint('CartService: Товар удален из корзины');
      }
    } catch (e) {
      debugPrint('CartService: Исключение - $e');
      throw Exception('Не удалось удалить из корзины');
    }
  }

  static Future<void> clearCart(String token) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.cartClear),
        headers: ApiConfig.headers(authToken: token),
      );

      if (response.statusCode != 200) {
        debugPrint('CartService: Ошибка очистки корзины');
        throw Exception('Не удалось очистить корзину');
      } else {
        debugPrint('CartService: Корзина очищена');
      }
    } catch (e) {
      debugPrint('CartService: Исключение - $e');
      throw Exception('Не удалось очистить корзину');
    }
  }
}

class WishlistService {
  static Future<WishlistResponse> getWishlist(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.wishlist),
        headers: ApiConfig.headers(authToken: token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('WishlistService: Список желаний загружен');
          return WishlistResponse.fromJson(responseData['data']);
        } else {
          debugPrint('WishlistService: Ошибка загрузки списка желаний');
          throw Exception('Не удалось загрузить список желаний');
        }
      } else {
        debugPrint('WishlistService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось загрузить список желаний');
      }
    } catch (e) {
      debugPrint('WishlistService: Исключение - $e');
      throw Exception('Не удалось загрузить список желаний');
    }
  }

  static Future<WishlistItem> addToWishlist(String token, int plantId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.wishlist),
        headers: ApiConfig.headers(authToken: token),
        body: json.encode({'plant_id': plantId}),
      );

      final Map<String, dynamic> responseData = json.decode(response.body);
      
      if (response.statusCode == 201) {
        if (responseData['success'] == true) {
          debugPrint('WishlistService: Товар добавлен в список желаний');
          return WishlistItem.fromJson(responseData['data']);
        } else {
          debugPrint('WishlistService: Ошибка добавления в список желаний');
          throw Exception('Не удалось добавить в список желаний');
        }
      } else {
        debugPrint('WishlistService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось добавить в список желаний');
      }
    } catch (e) {
      debugPrint('WishlistService: Исключение - $e');
      throw Exception('Не удалось добавить в список желаний');
    }
  }

  static Future<void> removeFromWishlist(String token, int plantId) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.wishlistRemove(plantId)),
        headers: ApiConfig.headers(authToken: token),
      );

      if (response.statusCode != 200) {
        debugPrint('WishlistService: Ошибка удаления из списка желаний');
        throw Exception('Не удалось удалить из списка желаний');
      } else {
        debugPrint('WishlistService: Товар удален из списка желаний');
      }
    } catch (e) {
      debugPrint('WishlistService: Исключение - $e');
      throw Exception('Не удалось удалить из списка желаний');
    }
  }

  static Future<bool> checkWishlist(String token, int plantId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.wishlistCheck(plantId)),
        headers: ApiConfig.headers(authToken: token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('WishlistService: Проверка списка желаний выполнена');
          return WishlistCheckResponse.fromJson(responseData['data']).inWishlist;
        } else {
          debugPrint('WishlistService: Ошибка проверки списка желаний');
          throw Exception('Не удалось проверить список желаний');
        }
      } else {
        debugPrint('WishlistService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось проверить список желаний');
      }
    } catch (e) {
      debugPrint('WishlistService: Исключение - $e');
      throw Exception('Не удалось проверить список желаний');
    }
  }
}

class PotService {
  static Future<List<PotMaterial>> getMaterials() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.potMaterials),
        headers: ApiConfig.headers(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('PotService: Материалы загружены');
          final data = responseData['data'] as List;
          return data.map((item) => PotMaterial.fromJson(item)).toList();
        } else {
          debugPrint('PotService: Ошибка загрузки материалов');
          throw Exception('Не удалось загрузить материалы');
        }
      } else {
        debugPrint('PotService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось загрузить материалы');
      }
    } catch (e) {
      debugPrint('PotService: Исключение - $e');
      throw Exception('Не удалось загрузить материалы');
    }
  }

  static Future<List<PotSize>> getSizes() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.potSizes),
        headers: ApiConfig.headers(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('PotService: Размеры загружены');
          final data = responseData['data'] as List;
          return data.map((item) => PotSize.fromJson(item)).toList();
        } else {
          debugPrint('PotService: Ошибка загрузки размеров');
          throw Exception('Не удалось загрузить размеры');
        }
      } else {
        debugPrint('PotService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось загрузить размеры');
      }
    } catch (e) {
      debugPrint('PotService: Исключение - $e');
      throw Exception('Не удалось загрузить размеры');
    }
  }

  static Future<List<PotColor>> getColors() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.potColors),
        headers: ApiConfig.headers(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('PotService: Цвета загружены');
          final data = responseData['data'] as List;
          return data.map((item) => PotColor.fromJson(item)).toList();
        } else {
          debugPrint('PotService: Ошибка загрузки цветов');
          throw Exception('Не удалось загрузить цвета');
        }
      } else {
        debugPrint('PotService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось загрузить цвета');
      }
    } catch (e) {
      debugPrint('PotService: Исключение - $e');
      throw Exception('Не удалось загрузить цвета');
    }
  }

  static Future<double> getPotPrice(String material, String size) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.potPriceByParams(material, size)),
        headers: ApiConfig.headers(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('PotService: Цена горшка получена');
          return (responseData['data']['price'] ?? 0).toDouble();
        } else {
          debugPrint('PotService: Ошибка получения цены горшка');
          throw Exception('Не удалось получить цену горшка');
        }
      } else {
        debugPrint('PotService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось получить цену горшка');
      }
    } catch (e) {
      debugPrint('PotService: Исключение получения цены - $e');
      return 0.0;
    }
  }

  static Future<List<PotPrice>> getPrices() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.potPrices),
        headers: ApiConfig.headers(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          debugPrint('PotService: Цены загружены');
          final data = responseData['data'] as List;
          return data.map((item) => PotPrice.fromJson(item)).toList();
        } else {
          debugPrint('PotService: Ошибка загрузки цен');
          throw Exception('Не удалось загрузить цены');
        }
      } else {
        debugPrint('PotService: Ошибка сервера ${response.statusCode}');
        throw Exception('Не удалось загрузить цены');
      }
    } catch (e) {
      debugPrint('PotService: Исключение - $e');
      throw Exception('Не удалось загрузить цены');
    }
  }
}