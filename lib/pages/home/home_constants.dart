class HomeConstants {
  HomeConstants._();

  /// Количество элементов для загрузки в одном цикле бесконечного скролла
  static const int visibleItemsCount = 10;

  /// Порог прокрутки (в пикселях) для загрузки следующего цикла
  static const double scrollThreshold = 100.0;

  /// Задержка (в миллисекундах) для debounce поиска
  static const int searchDebounceMs = 300;
}
