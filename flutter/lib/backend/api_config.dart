class ApiConfig {
  // static const String baseURL = 'https://www.nebinance.ru/api';
  static const String baseURL = 'http://127.0.0.1:5000/api';
  static const Duration timeout = Duration(seconds: 10);
  static final Uri _baseUri = Uri.parse(baseURL);

  // admin employees
  static const String whoAmI = '$baseURL/debug/whoami';
  static const String users = '$baseURL/users';
  static String updateUser(int id) => '$baseURL/users/$id';
  static const String employees = '$baseURL/employees';
  static String employee(int id) => '$baseURL/employees/$id';
  static String updateAdmin(int userId) => '$baseURL/admins/$userId';
  static const String assignEmployee = '$baseURL/employees/assign';
  static String employeeDeactivate(int id) => '$baseURL/employees/$id/deactivate';
  static const String warehouseProducts = '$baseURL/warehouse/products';
  static String warehouseAdjustProduct(int productId) =>
      '$baseURL/warehouse/products/$productId/adjust';

  // payments
  static String get paymentGenerateLink => '$baseURL/payments/generate-link';
  static String paymentLink(int linkId) => '$baseURL/payments/link/$linkId';
  static String paymentCancel(int linkId) => '$baseURL/payments/link/$linkId/cancel';
  static String paymentLinkStatus(int linkId) => '$baseURL/payments/status/link/$linkId';
  static String orderStatus(int orderId) => '$baseURL/payments/status/order/$orderId';
  static String get paymentStores => '$baseURL/payments/stores';
  static String get paymentAvailability => '$baseURL/payments/availability';
  static String orders({int limit = 20, int offset = 0}) =>
      '$baseURL/payments/orders?limit=$limit&offset=$offset';
  static String orderDetails(int orderId) => '$baseURL/payments/orders/$orderId';
  static String orderCancel(int orderId) => '$baseURL/payments/orders/$orderId/cancel';
  static String orderAddress(int orderId) => '$baseURL/payments/orders/$orderId/address';
  static String adminOrders({
    int limit = 30,
    int offset = 0,
    String? status,
    int? storeId,
    String sortBy = 'created_at_desc',
    bool includeClosed = true,
  }) {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      'sort_by': sortBy,
      'include_closed': includeClosed ? 'true' : 'false',
    };
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    if (storeId != null) {
      params['store_id'] = '$storeId';
    }
    return Uri.parse('$baseURL/payments/admin/orders')
        .replace(queryParameters: params)
        .toString();
  }
  static String adminOrderDetails(int orderId) => '$baseURL/payments/admin/orders/$orderId';
  static String adminOrderAccept(int orderId) => '$baseURL/payments/admin/orders/$orderId/accept';
  static String adminOrderStatus(int orderId) => '$baseURL/payments/admin/orders/$orderId/status';
  static String adminOrderClose(int orderId) => '$baseURL/payments/admin/orders/$orderId/close';
  static String adminOrderMarkPaid(int orderId) => '$baseURL/payments/admin/orders/$orderId/mark-paid';
  static String adminOrderRefund(int orderId) => '$baseURL/payments/admin/orders/$orderId/refund';

  // auth
  static const String authVerify = '$baseURL/auth/verify';
  static String authCheckStatus(String code) =>
      '$baseURL/auth/check_status/$code';
  static const String authValidateToken = '$baseURL/auth/validate_token';
  static const String updateProfile = '$baseURL/auth/update_profile';
  static const String authMe = '$baseURL/auth/me';
  static const String avatar = '$baseURL/auth/avatar';

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
    if (imagePath.startsWith('/')) return '${_baseUri.origin}$imagePath';
    if (imagePath.startsWith('img/')) return '${_baseUri.origin}/$imagePath';
    if (imagePath.startsWith('api/')) {
      return '${_baseUri.origin}/${imagePath.substring(4)}';
    }
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
