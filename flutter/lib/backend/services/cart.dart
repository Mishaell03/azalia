import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/cart.dart';
import 'package:azalia/backend/services/plant.dart';

/// Сервис для работы с корзиной
class CartService {
  static final ApiClient _api = ApiClient();

  /// Получить корзину пользователя
  static Future<CartResponse> getCart() async {
    final response = await _api.get(ApiConfig.cartItems);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Ошибка загрузки корзины');
    }

    final cart = CartResponse.fromJson(response['data']);
    final hydratedItems = await Future.wait(
      cart.items.map(_hydrateCartItem),
    );

    return CartResponse(items: hydratedItems, summary: cart.summary);
  }

  static Future<Set<int>> getCartPlantIds() async {
    final response = await _api.get(ApiConfig.cartItems);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Ошибка загрузки корзины');
    }

    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];

    return items
        .map((item) {
          final raw = item as Map<String, dynamic>;
          final plantId = raw['plant_id'] ?? raw['product_id'];
          return plantId is num ? plantId.toInt() : null;
        })
        .whereType<int>()
        .toSet();
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
    return _hydrateCartItem(CartItem.fromJson(response['data']));
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
    return _hydrateCartItem(CartItem.fromJson(response['data']));
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

  static Future<CartItem> _hydrateCartItem(CartItem item) async {
    try {
      final plant = await PlantService.getPlantById(item.plantId);
      return item.copyWith(plant: plant);
    } catch (_) {
      return item;
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
  static Future<double> getPotPrice(
    String material,
    String size, {
    String? color,
  }) async {
    try {
      final response = await _api.get(
        ApiConfig.potPriceByParams(material, size, color: color),
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

  /// Получить доступность опций (для дизейбла несовместимых вариантов)
  static Future<Map<String, dynamic>> getOptions({
    String? material,
    String? size,
    String? color,
  }) async {
    final params = <String, String>{
      if (material != null && material.trim().isNotEmpty) 'material': material.trim(),
      if (size != null && size.trim().isNotEmpty) 'size': size.trim(),
      if (color != null && color.trim().isNotEmpty) 'color': color.trim(),
    };
    final url = Uri.parse(ApiConfig.potOptions).replace(queryParameters: params).toString();
    final response = await _api.get(url);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Не удалось загрузить доступность опций');
    }
    return response['data'] as Map<String, dynamic>? ?? const {};
  }
}
