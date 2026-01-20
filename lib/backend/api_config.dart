class ApiConfig {
  static const String baseURL = 'http://127.0.0.1:5000/api';
  static const Duration timeout = Duration(seconds: 10);

  // admin employees
  static const String whoAmI = '$baseURL/debug/whoami';
  static const String users = '$baseURL/users';
  static const String employees = '$baseURL/employees';
  static String employee(int id) => '$baseURL/employee/$id';
  static const String assignEmployee = '$baseURL/employees/assign';
  static String employeeDeactivate(int id) => '$baseURL/employees/$id/deactivate';

  // auth
  static const String authVerify = '$baseURL/auth/verify';
  static String authCheckStatus(String code) =>
      '$baseURL/auth/check_status/$code';
  static const String updateProfile = '$baseURL/auth/update_profile';
  static const String authMe = '$baseURL/auth/me';

  // plants
  static const String plants = '$baseURL/plants/';
  static String plantsId(int id) => '$baseURL/plants/$id';
  static const String categories = '$baseURL/plants/categories';
  static const String filters = '$baseURL/plants/filters';
  static const String topRated = '$baseURL/plants/top-rated';

  // cart & wishlist
  static const String cartItems = '$baseURL/cart/items';
  static String cartItemId(int id) => '$baseURL/cart/items/$id';
  static const String cartClear = '$baseURL/cart/clear';
  static const String wishlist = '$baseURL/cart/wishlist';
  static String wishlistCheck(int plantId) =>
      '$baseURL/cart/wishlist/check/$plantId';
  static String wishlistRemove(int plantId) =>
      '$baseURL/cart/wishlist/$plantId';

  // configuration
  static const String potMaterials = '$baseURL/pot/materials';
  static const String potSizes = '$baseURL/pot/sizes';
  static const String potColors = '$baseURL/pot/colors';
  static const String potPrices = '$baseURL/pot/prices';
  static String potPriceByParams(String material, String size) =>
      '$baseURL/pot/price?material=$material&size=$size';

  // img
  static String imageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    if (imagePath.startsWith('api/'))
      return '$baseURL/${imagePath.substring(4)}';
    return '$baseURL/$imagePath';
  }

  // headers
  static Map<String, String> headers({String? authToken}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authToken != null) headers['Authorization'] = authToken;
    return headers;
  }
  static const bool enableLogging = true;
}