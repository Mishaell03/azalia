import 'package:flutter/foundation.dart';
import 'package:azalia/backend/models/cart.dart';
import 'package:azalia/backend/models/plant.dart';
import 'package:azalia/backend/services/session.dart';
import 'package:azalia/backend/services/cart.dart';

class CartWishlistManager {
  final Plant plant;
  final SessionService _sessionService = SessionService();

  CartWishlistManager({required this.plant});

  Future<String?> _getToken() async {
    return await _sessionService.getToken();
  }

  Future<bool> _isUserLoggedIn() async {
    return _sessionService.isLoggedIn && _sessionService.isTokenValid;
  }

  Future<void> toggleWishlist(bool currentlyInWishlist) async {
    try {
      final isLoggedIn = await _isUserLoggedIn();
      if (!isLoggedIn) {
        throw Exception('не авторизован');
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('не авторизован');
      }

      if (currentlyInWishlist) {
        await WishlistService.removeFromWishlist(token, plant.id);
      } else {
        await WishlistService.addToWishlist(token, plant.id);
      }
    } catch (e) {
      if (e.toString().contains('не авторизован')) {
        throw Exception('не авторизован');
      } else if (e.toString().contains('Wishlist item not found')) {
        debugPrint('CartWishlistManager: Элемент уже удален из избранного');
        return;
      } else {
        throw Exception('ошибка обновления');
      }
    }
  }

  Future<bool> checkWishlistStatus() async {
    try {
      final isLoggedIn = await _isUserLoggedIn();
      if (!isLoggedIn) return false;

      final token = await _getToken();
      if (token == null) return false;

      return await WishlistService.checkWishlist(token, plant.id);
    } catch (e) {
      debugPrint('CartWishlistManager: Ошибка проверки избранного - $e');
      return false;
    }
  }

  Future<void> addToCart({
    String? potMaterial,
    String? potSize,
    String? potColor,
    int quantity = 1,
  }) async {
    try {
      final isLoggedIn = await _isUserLoggedIn();
      if (!isLoggedIn) {
        throw Exception('не авторизован');
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('не авторизован');
      }

      final request = AddToCartRequest(
        plantId: plant.id,
        potMaterial: potMaterial,
        potSize: potSize,
        potColor: potColor,
        quantity: quantity,
      );

      await CartService.addToCart(token, request);
    } catch (e) {
      if (e.toString().contains('не авторизован')) {
        throw Exception('не авторизован');
      } else {
        throw Exception('ошибка добавления');
      }
    }
  }

  Future<void> quickAddToCart() async {
    return addToCart(quantity: 1);
  }
}

class CartWishlistService {
  final Plant plant;
  final SessionService _sessionService = SessionService();

  CartWishlistService({required this.plant});

  Future<String?> getToken() async {
    return await _sessionService.getToken();
  }

  Future<bool> isUserLoggedIn() async {
    return _sessionService.isLoggedIn && _sessionService.isTokenValid;
  }

  // === ИЗБРАННОЕ ===

  Future<void> toggleWishlist(bool currentlyInWishlist) async {
    try {
      final isLoggedIn = await isUserLoggedIn();
      if (!isLoggedIn) {
        debugPrint('CartWishlistService: Пользователь не авторизован');
        throw Exception('не авторизован');
      }

      final token = await getToken();
      if (token == null) {
        debugPrint('CartWishlistService: Токен не получен');
        throw Exception('не авторизован');
      }

      if (currentlyInWishlist) {
        debugPrint('CartWishlistService: Удаление из избранного');
        await WishlistService.removeFromWishlist(token, plant.id);
      } else {
        debugPrint('CartWishlistService: Добавление в избранное');
        await WishlistService.addToWishlist(token, plant.id);
      }
    } catch (e) {
      debugPrint('CartWishlistService: Ошибка избранного - $e');
      if (e.toString().contains('не авторизован')) {
        throw Exception('не авторизован');
      } else if (e.toString().contains('Wishlist item not found')) {
        debugPrint('CartWishlistService: Элемент уже удален из избранного');
        return;
      } else {
        throw Exception('ошибка обновления избранного');
      }
    }
  }

  Future<bool> checkWishlistStatus() async {
    try {
      final isLoggedIn = await isUserLoggedIn();
      if (!isLoggedIn) {
        debugPrint('CartWishlistService: Пользователь не авторизован');
        return false;
      }

      final token = await getToken();
      if (token == null) {
        debugPrint('CartWishlistService: Токен не получен');
        return false;
      }

      final result = await WishlistService.checkWishlist(token, plant.id);
      debugPrint('CartWishlistService: Статус избранного - $result');
      return result;
    } catch (e) {
      debugPrint('CartWishlistService: Ошибка проверки избранного - $e');
      return false;
    }
  }

  // === КОРЗИНА ===

  Future<void> addToCart({
    String? potMaterial,
    String? potSize,
    String? potColor,
    int quantity = 1,
  }) async {
    try {
      final isLoggedIn = await isUserLoggedIn();
      if (!isLoggedIn) {
        debugPrint('CartWishlistService: Пользователь не авторизован');
        throw Exception('не авторизован');
      }

      final token = await getToken();
      if (token == null) {
        debugPrint('CartWishlistService: Токен не получен');
        throw Exception('не авторизован');
      }

      debugPrint('CartWishlistService: Добавление в корзину');
      
      final request = AddToCartRequest(
        plantId: plant.id,
        potMaterial: potMaterial,
        potSize: potSize,
        potColor: potColor,
        quantity: quantity,
      );

      await CartService.addToCart(token, request);
      debugPrint('CartWishlistService: Успешно добавлено в корзину');
    } catch (e) {
      debugPrint('CartWishlistService: Ошибка добавления в корзину - $e');
      if (e.toString().contains('не авторизован')) {
        throw Exception('не авторизован');
      } else {
        throw Exception('ошибка добавления в корзину');
      }
    }
  }

  Future<void> quickAddToCart() async {
    return addToCart(quantity: 1);
  }

  Future<bool> checkCartStatus() async {
    try {
      final isLoggedIn = await isUserLoggedIn();
      if (!isLoggedIn) {
        debugPrint('CartWishlistService: Пользователь не авторизован');
        return false;
      }

      final token = await getToken();
      if (token == null) {
        debugPrint('CartWishlistService: Токен не получен');
        return false;
      }

      final cart = await CartService.getCart(token);
      final isInCart = cart.items.any((item) => item.plantId == plant.id);
      debugPrint('CartWishlistService: Статус корзины - $isInCart');
      return isInCart;
    } catch (e) {
      debugPrint('CartWishlistService: Ошибка проверки корзины - $e');
      return false;
    }
  }

  Future<void> removeFromCart(int cartItemId) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('не авторизован');
      }

      await CartService.removeFromCart(token, cartItemId);
      debugPrint('CartWishlistService: Удалено из корзины');
    } catch (e) {
      debugPrint('CartWishlistService: Ошибка удаления из корзины - $e');
      throw Exception('ошибка удаления из корзины');
    }
  }

  Future<void> updateCartQuantity(int cartItemId, int quantity) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('не авторизован');
      }

      await CartService.updateCartItem(token, cartItemId, quantity);
      debugPrint('CartWishlistService: Обновлено количество');
    } catch (e) {
      debugPrint('CartWishlistService: Ошибка обновления количества - $e');
      throw Exception('ошибка обновления количества');
    }
  }
}