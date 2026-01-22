import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/cart.dart';

/// Сервис для работы с корзиной
class CartService {
  static final ApiClient _api = ApiClient();

  /// Получить корзину пользователя
  static Future<CartResponse> getCart() async {
    final response = await _api.get(ApiConfig.cartItems);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Ошибка загрузки корзины');
    }
    return CartResponse.fromJson(response['data']);
  }

  /// Добавить товар в корзину
  static Future<CartItem> addToCart(AddToCartRequest request) async {
    final response = await _api.post(
      ApiConfig.cartItems,
      body: request.toJson(),
    );

    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Ошибка добавления в корзину');
    }
    return CartItem.fromJson(response['data']);
  }

  /// Обновить количество товара в корзине
  static Future<CartItem> updateCartItem(int itemId, int quantity) async {
    final response = await _api.put(
      ApiConfig.cartItemId(itemId),
      body: {'quantity': quantity},
    );
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Не удалось обновить корзину');
    }
    return CartItem.fromJson(response['data']);
  }

  /// Удалить товар из корзины
  static Future<void> removeFromCart(int itemId) async {
    final response = await _api.delete(ApiConfig.cartItemId(itemId));
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Ошибка удаления из корзины');
    }
  }

  /// Очистить корзину
  static Future<void> clearCart() async {
    final response = await _api.delete(ApiConfig.cartClear);

    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Не удалось очистить корзину');
    }
  }
}

/// Сервис для работы с горшками (материалы, размеры, цвета, цены)
class PotService {
  static final ApiClient _api = ApiClient();

  /// Получить список материалов горшков
  static Future<List<PotMaterial>> getMaterials() async {
    final response = await _api.get(ApiConfig.potMaterials);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Не удалось загрузить материалы');
    }
    final data = response['data'] as List;
    return data.map((item) => PotMaterial.fromJson(item)).toList();
  }

  /// Получить список размеров горшков
  static Future<List<PotSize>> getSizes() async {
    final response = await _api.get(ApiConfig.potSizes);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Не удалось загрузить размеры');
    }
    final data = response['data'] as List;
    return data.map((item) => PotSize.fromJson(item)).toList();
  }

  /// Получить список цветов горшков
  static Future<List<PotColor>> getColors() async {
    final response = await _api.get(ApiConfig.potColors);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Не удалось загрузить цвета');
    }
    final data = response['data'] as List;
    return data.map((item) => PotColor.fromJson(item)).toList();
  }

  /// Получить цену горшка по материалу и размеру
  static Future<double> getPotPrice(String material, String size) async {
    try {
      final response = await _api.get(
        ApiConfig.potPriceByParams(material, size),
      );
      if (response['success'] != true) {
        return 0.0;
      }
      return (response['data']['price'] ?? 0).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  /// Получить все цены на горшки
  static Future<List<PotPrice>> getPrices() async {
    final response = await _api.get(ApiConfig.potPrices);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Не удалось загрузить цены');
    }
    final data = response['data'] as List;
    return data.map((item) => PotPrice.fromJson(item)).toList();
  }
}
