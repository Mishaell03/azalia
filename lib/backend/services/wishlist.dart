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
        print('Элемент уже удален из избранного: $e');
        return;
      } else {
        throw Exception('ошибка обновления: $e');
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
      print('Ошибка при проверке избранного: $e');
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
        throw Exception('ошибка добавления: $e');
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

  Future<String?> _getToken() async {
    return await _sessionService.getToken();
  }

  Future<bool> _isUserLoggedIn() async {
    return _sessionService.isLoggedIn && _sessionService.isTokenValid;
  }

  // === ИЗБРАННОЕ ===

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
        // Игнорируем ошибку "не найден", так как элемент уже удален
        print('Элемент уже удален из избранного: $e');
        return;
      } else {
        throw Exception('ошибка обновления: $e');
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
      print('Ошибка при проверке избранного: $e');
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
        throw Exception('ошибка добавления: $e');
      }
    }
  }

  Future<void> quickAddToCart() async {
    return addToCart(quantity: 1);
  }

  Future<bool> checkCartStatus() async {
    try {
      final isLoggedIn = await _isUserLoggedIn();
      if (!isLoggedIn) return false;

      final token = await _getToken();
      if (token == null) return false;

      final cart = await CartService.getCart(token);
      return cart.items.any((item) => item.plantId == plant.id);
    } catch (e) {
      print('Ошибка при проверке статуса корзины: $e');
      return false;
    }
  }
}
