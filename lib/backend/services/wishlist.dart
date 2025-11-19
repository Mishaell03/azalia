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

  // Сделаем метод получения токена публичным
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
        print('Ошибка авторизации: пользователь не авторизован');
        throw Exception('не авторизован');
      }

      final token = await getToken();
      if (token == null) {
        print('Ошибка авторизации: токен не получен');
        throw Exception('не авторизован');
      }

      if (currentlyInWishlist) {
        print('Удаление из избранного: plantId=${plant.id}');
        await WishlistService.removeFromWishlist(token, plant.id);
      } else {
        print('Добавление в избранное: plantId=${plant.id}');
        await WishlistService.addToWishlist(token, plant.id);
      }
    } catch (e) {
      print('Ошибка toggleWishlist: $e');
      if (e.toString().contains('не авторизован')) {
        throw Exception('не авторизован');
      } else if (e.toString().contains('Wishlist item not found')) {
        print('Элемент уже удален из избранного, продолжаем');
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
        print('Пользователь не авторизован, избранное недоступно');
        return false;
      }

      final token = await getToken();
      if (token == null) {
        print('Токен не получен, избранное недоступно');
        return false;
      }

      final result = await WishlistService.checkWishlist(token, plant.id);
      print('Статус избранного для plantId=${plant.id}: $result');
      return result;
    } catch (e) {
      print('Ошибка checkWishlistStatus: $e');
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
        print('Ошибка авторизации при добавлении в корзину');
        throw Exception('не авторизован');
      }

      final token = await getToken();
      if (token == null) {
        print('Токен не получен при добавлении в корзину');
        throw Exception('не авторизован');
      }

      print('Добавление в корзину: plantId=${plant.id}, quantity=$quantity');
      
      final request = AddToCartRequest(
        plantId: plant.id,
        potMaterial: potMaterial,
        potSize: potSize,
        potColor: potColor,
        quantity: quantity,
      );

      await CartService.addToCart(token, request);
      print('Успешно добавлено в корзину: plantId=${plant.id}');
    } catch (e) {
      print('Ошибка addToCart: $e');
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
        print('Пользователь не авторизован, корзина недоступна');
        return false;
      }

      final token = await getToken();
      if (token == null) {
        print('Токен не получен, корзина недоступна');
        return false;
      }

      final cart = await CartService.getCart(token);
      final isInCart = cart.items.any((item) => item.plantId == plant.id);
      print('Статус корзины для plantId=${plant.id}: $isInCart');
      return isInCart;
    } catch (e) {
      print('Ошибка checkCartStatus: $e');
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
      print('Удалено из корзины: cartItemId=$cartItemId');
    } catch (e) {
      print('Ошибка removeFromCart: $e');
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
      print('Обновлено количество: cartItemId=$cartItemId, quantity=$quantity');
    } catch (e) {
      print('Ошибка updateCartQuantity: $e');
      throw Exception('ошибка обновления количества');
    }
  }
}