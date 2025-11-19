class AppErrors {
  static const String unauthorized = 'Не авторизован';
  static const String networkError = 'Ошибка сети';
  static const String unknownError = 'Неизвестная ошибка';

  static const String addToCartError = 'Не удалось добавить в корзину';
  static const String removeFromCartError = 'Не удалось удалить из корзины';
  static const String addToWishlistError = 'Не удалось добавить в избранное';
  static const String removeFromWishlistError = 'Не удалось удалить из избранного';
  static const String unauthorizedMessage = 'Войдите в аккаунт, чтобы выполнить действие';
  
  static bool isUnauthorizedError(String error) {
    return error.contains(unauthorized) || 
           error.contains('authorized') || 
           error.contains('token') ||
           error.contains('session');
  }
}