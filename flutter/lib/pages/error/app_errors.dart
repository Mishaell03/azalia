class AppErrors {
  static const String unauthorized = 'Не авторизован';
  static const String forbidden = '403';
  static const String networkError = 'Ошибка сети';
  static const String unknownError = 'Неизвестная ошибка';
  static const String accountBlockedMessage =
      'Аккаунт удален или деактивирован. Обратитесь в поддержку через Telegram-бота.';

  static const String addToCartError = 'Не удалось добавить в корзину';
  static const String removeFromCartError = 'Не удалось удалить из корзины';
  static const String addToWishlistError = 'Не удалось добавить в избранное';
  static const String removeFromWishlistError =
      'Не удалось удалить из избранного';
  static const String unauthorizedMessage =
      'Войдите в аккаунт, чтобы выполнить действие';
  static const String unauthorizedCartMessage =
      'Нельзя добавлять в корзину без входа';
  static const String unauthorizedWishlistMessage =
      'Нельзя добавлять в избранное без входа';

  static bool isUnauthorizedError(String error) {
    return error.contains(unauthorized) ||
        error.contains('authorized') ||
        error.contains('token') ||
        error.contains('session') ||
        error.contains('не авторизован');
  }

  static bool isForbiddenAccountError(String error) {
    final lower = error.toLowerCase();
    return lower.contains(forbidden) ||
        lower.contains('blocked') ||
        lower.contains('deleted') ||
        lower.contains('deactivated') ||
        lower.contains('аккаунт удален') ||
        lower.contains('аккаунт деактивирован');
  }
}
