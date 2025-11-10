// api_config.dart - добавьте новый метод
class ApiConfig {
  static const String baseURL = 'http://10.0.0.250:5000/api';
  static const Duration timeout = Duration(seconds: 10);

  static const String plants = '$baseURL/plants/';
  static String plantsId(int id) => '$baseURL/plants/$id';
  static const String categories = '$baseURL/plants/categories';
  static const String filters = '$baseURL/plants/filters';
  static const String topRated = '$baseURL/plants/top-rated';

  static String imageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    if (imagePath.startsWith('api/')) {
      return '$baseURL/${imagePath.substring(4)}';
    }
    return '$baseURL/$imagePath';
  }

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  static const bool enableLogging = true;
}