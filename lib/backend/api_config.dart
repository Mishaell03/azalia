class ApiConfig {
  static const String baseURL = 'http://10.0.0.250:5000/api';
  static const Duration timeout = Duration(seconds: 10);

  static const String plantsEndpoint = '/plants/';
  static String plantDetailURL(int, id) => '$baseURL/plants$id';
  static const String categoriesEndpoint = '$baseURL/plants/categories';
  static const String filtersEndpoint = '$baseURL/plants/filters';

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  // на время разработки включены логи
  static const bool enableLogging = true;
}