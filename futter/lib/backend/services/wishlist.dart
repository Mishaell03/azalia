import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/wishlist.dart';
import 'package:azalia/backend/models/cart.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/session.dart';
import 'package:azalia/backend/services/cart.dart';
import 'package:azalia/backend/services/plant.dart';
import 'package:flutter/foundation.dart';

/// Сервис для работы с избранным (wishlist)
class WishlistService {
  static final ApiClient _api = ApiClient();

  /// Получить список избранного пользователя
  static Future<WishlistResponse> getWishlist() async {
    final response = await _api.get(ApiConfig.wishlist);
    if (response['success'] != true) {
      throw Exception(
        response['error'] ?? 'Не удалось загрузить список желаний',
      );
    }

    final wishlist = WishlistResponse.fromJson(response['data']);
    final hydratedItems = await Future.wait(
      wishlist.items.map(_hydrateWishlistItem),
    );

    return WishlistResponse(items: hydratedItems, count: wishlist.count);
  }

  /// Добавить товар в избранное
  static Future<WishlistItem> addToWishlist(int plantId) async {
    final response = await _api.post(
      ApiConfig.wishlist,
      body: {'plant_id': plantId},
    );
    if (response['success'] != true) {
      throw Exception(
        response['error'] ?? 'Не удалось добавить в список желаний',
      );
    }
    return _hydrateWishlistItem(WishlistItem.fromJson(response['data']));
  }

  /// Удалить товар из избранного
  static Future<void> removeFromWishlist(int plantId) async {
    final response = await _api.delete(
      ApiConfig.wishlistRemove(plantId),
    );
    if (response['success'] != true) {
      throw Exception(
        response['error'] ?? 'Не удалось удалить из списка желаний',
      );
    }
  }

  /// Проверить, находится ли товар в избранном
  static Future<bool> checkWishlist(int plantId) async {
    final response = await _api.get(
      ApiConfig.wishlistCheck(plantId),
    );

    if (response['success'] != true) {
      throw Exception(
        response['error'] ?? 'Не удалось проверить список желаний',
      );
    }

    return WishlistCheckResponse
        .fromJson(response['data'])
        .inWishlist;
  }

  static Future<Set<int>> getWishlistPlantIds() async {
    final response = await _api.get(ApiConfig.wishlist);
    if (response['success'] != true) {
      throw Exception(
        response['error'] ?? 'Не удалось загрузить список желаний',
      );
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

  static Future<WishlistItem> _hydrateWishlistItem(WishlistItem item) async {
    try {
      final plant = await PlantService.getPlantById(item.plantId);
      return item.copyWith(plant: plant);
    } catch (_) {
      return item;
    }
  }
}

/// Вспомогательный сервис для работы с корзиной и избранным для конкретного товара
class CartWishlistService {
  final Plant plant;
  final SessionService _sessionService = SessionService();

  static String? _cachedSessionToken;
  static Set<int>? _wishlistPlantIds;
  static Set<int>? _cartPlantIds;
  static Future<Set<int>>? _wishlistPlantIdsFuture;
  static Future<Set<int>>? _cartPlantIdsFuture;

  CartWishlistService({required this.plant});

  /// Проверить, авторизован ли пользователь
  Future<bool> isUserLoggedIn() async {
    return _sessionService.hasActiveSession;
  }

  static void invalidateCache() {
    _cachedSessionToken = null;
    _wishlistPlantIds = null;
    _cartPlantIds = null;
    _wishlistPlantIdsFuture = null;
    _cartPlantIdsFuture = null;
  }

  void _syncCacheWithSession() {
    final token = _sessionService.sessionToken;
    if (!_sessionService.hasActiveSession || token == null || token.isEmpty) {
      invalidateCache();
      return;
    }

    if (_cachedSessionToken != token) {
      invalidateCache();
      _cachedSessionToken = token;
    }
  }

  Future<Set<int>> _getWishlistPlantIds() async {
    _syncCacheWithSession();
    if (!_sessionService.hasActiveSession) {
      return const <int>{};
    }
    if (_wishlistPlantIds != null) {
      return _wishlistPlantIds!;
    }

    _wishlistPlantIdsFuture ??= WishlistService.getWishlistPlantIds();
    try {
      _wishlistPlantIds = await _wishlistPlantIdsFuture!;
      return _wishlistPlantIds!;
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        invalidateCache();
      }
      rethrow;
    } finally {
      _wishlistPlantIdsFuture = null;
    }
  }

  Future<Set<int>> _getCartPlantIds() async {
    _syncCacheWithSession();
    if (!_sessionService.hasActiveSession) {
      return const <int>{};
    }
    if (_cartPlantIds != null) {
      return _cartPlantIds!;
    }

    _cartPlantIdsFuture ??= CartService.getCartPlantIds();
    try {
      _cartPlantIds = await _cartPlantIdsFuture!;
      return _cartPlantIds!;
    } catch (e) {
      if (e.toString().contains('Unauthorized')) {
        invalidateCache();
      }
      rethrow;
    } finally {
      _cartPlantIdsFuture = null;
    }
  }

  // === ИЗБРАННОЕ ===

  /// Переключить статус избранного
  Future<void> toggleWishlist(bool currentlyInWishlist) async {
    try {
      final isLoggedIn = await isUserLoggedIn();
      if (!isLoggedIn) {
        // debugPrint('CartWishlistService: Пользователь не авторизован');
        throw Exception('не авторизован');
      }

      if (currentlyInWishlist) {
        // debugPrint('CartWishlistService: Удаление из избранного');
        await WishlistService.removeFromWishlist(plant.id);
        _wishlistPlantIds?.remove(plant.id);
      } else {
        // debugPrint('CartWishlistService: Добавление в избранное');
        await WishlistService.addToWishlist(plant.id);
        (_wishlistPlantIds ??= <int>{}).add(plant.id);
      }
    } catch (e) {
      debugPrint('CartWishlistService: Ошибка избранного - $e');
      if (e.toString().contains('не авторизован') || 
          e.toString().contains('Unauthorized')) {
        invalidateCache();
        throw Exception('не авторизован');
      } else if (e.toString().contains('Wishlist item not found')) {
        debugPrint('CartWishlistService: Элемент уже удален из избранного');
        return;
      } else {
        throw Exception('ошибка обновления избранного');
      }
    }
  }

  /// Проверить статус избранного
  Future<bool> checkWishlistStatus() async {
    try {
      final isLoggedIn = await isUserLoggedIn();
      if (!isLoggedIn) {
        // debugPrint('CartWishlistService: Пользователь не авторизован');
        return false;
      }

      final wishlistIds = await _getWishlistPlantIds();
      return wishlistIds.contains(plant.id);
    } catch (e) {
      // debugPrint('CartWishlistService: Ошибка проверки избранного - $e');
      return false;
    }
  }

  // === КОРЗИНА ===

  /// Добавить товар в корзину
  Future<void> addToCart({
    String? potMaterial,
    String? potSize,
    String? potColor,
    int quantity = 1,
  }) async {
    try {
      final isLoggedIn = await isUserLoggedIn();
      if (!isLoggedIn) {
        // debugPrint('CartWishlistService: Пользователь не авторизован');
        throw Exception('не авторизован');
      }

      // debugPrint('CartWishlistService: Добавление в корзину');
      
      final request = AddToCartRequest(
        plantId: plant.id,
        potMaterial: potMaterial,
        potSize: potSize,
        potColor: potColor,
        quantity: quantity,
      );

      await CartService.addToCart(request);
      (_cartPlantIds ??= <int>{}).add(plant.id);
      // debugPrint('CartWishlistService: Успешно добавлено в корзину');
    } catch (e) {
      debugPrint('CartWishlistService: Ошибка добавления в корзину - $e');
      if (e.toString().contains('не авторизован') || 
          e.toString().contains('Unauthorized')) {
        invalidateCache();
        throw Exception('не авторизован');
      } else {
        throw Exception('ошибка добавления в корзину');
      }
    }
  }

  /// Быстрое добавление в корзину (без параметров горшка)
  Future<void> quickAddToCart() async {
    return addToCart(quantity: 1);
  }

  /// Проверить, находится ли товар в корзине
  Future<bool> checkCartStatus() async {
    try {
      final isLoggedIn = await isUserLoggedIn();
      if (!isLoggedIn) {
        // debugPrint('CartWishlistService: Пользователь не авторизован');
        return false;
      }

      final cartIds = await _getCartPlantIds();
      return cartIds.contains(plant.id);
    } catch (e) {
      // debugPrint('CartWishlistService: Ошибка проверки корзины - $e');
      return false;
    }
  }

  /// Удалить товар из корзины
  Future<void> removeFromCart(int cartItemId) async {
    try {
      await CartService.removeFromCart(cartItemId);
      _cartPlantIds = null;
      _cartPlantIdsFuture = null;
      debugPrint('CartWishlistService: Удалено из корзины');
    } catch (e) {
      debugPrint('CartWishlistService: Ошибка удаления из корзины - $e');
      throw Exception('ошибка удаления из корзины');
    }
  }

  /// Обновить количество товара в корзине
  Future<void> updateCartQuantity(int cartItemId, int quantity) async {
    try {
      await CartService.updateCartItem(cartItemId, quantity);
      _cartPlantIds = null;
      _cartPlantIdsFuture = null;
      debugPrint('CartWishlistService: Обновлено количество');
    } catch (e) {
      debugPrint('CartWishlistService: Ошибка обновления количества - $e');
      throw Exception('ошибка обновления количества');
    }
  }

  /// Удаляет все записи товара из корзины (все количество)
  Future<void> removeAllFromCart() async {
    try {
      final isLoggedIn = await isUserLoggedIn();
      if (!isLoggedIn) {
        debugPrint('CartWishlistService: Пользователь не авторизован');
        throw Exception('не авторизован');
      }

      debugPrint('CartWishlistService: Удаление всех записей товара из корзины');
      
      // Получаем корзину и находим все записи с таким plant_id
      final cart = await CartService.getCart();
      final itemsToRemove = cart.items.where((item) => item.plantId == plant.id).toList();
      
      if (itemsToRemove.isEmpty) {
        debugPrint('CartWishlistService: Товар не найден в корзине');
        return;
      }

      // Удаляем все найденные записи
      for (final item in itemsToRemove) {
        try {
          await CartService.removeFromCart(item.id);
          debugPrint('CartWishlistService: Удалена запись ${item.id}');
        } catch (e) {
          debugPrint('CartWishlistService: Ошибка удаления записи ${item.id} - $e');
          // Продолжаем удаление остальных записей даже если одна не удалилась
        }
      }

      _cartPlantIds?.remove(plant.id);
      
      debugPrint('CartWishlistService: Все записи товара удалены из корзины');
    } catch (e) {
      debugPrint('CartWishlistService: Ошибка удаления всех записей из корзины - $e');
      if (e.toString().contains('не авторизован') || 
          e.toString().contains('Unauthorized')) {
        invalidateCache();
        throw Exception('не авторизован');
      } else {
        throw Exception('ошибка удаления из корзины');
      }
    }
  }
}
