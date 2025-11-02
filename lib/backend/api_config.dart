class ApiConfig {
  static const String baseURL = 'http://10.0.0.250:5000/api';
  static const Duration timeout = Duration(seconds: 10);

  static const String plants = '$baseURL/plants/';
  static String plantsId(int id) => '$baseURL/plants$id';
  static const String categories = '$baseURL/plants/categories';
  static const String filters = '$baseURL/plants/filters';

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  // на время разработки включены логи
  static const bool enableLogging = true;
}