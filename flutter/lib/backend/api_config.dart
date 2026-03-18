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
  static String adminAnalytics({int? storeId, int days = 30, int top = 7}) {
    final params = <String, String>{
      'days': '$days',
      'top': '$top',
      if (storeId != null) 'store_id': '$storeId',
    };
    return Uri.parse('$baseURL/admin/analytics')
        .replace(queryParameters: params)
        .toString();
  }
  static const String warehouseProducts = '$baseURL/warehouse/products';
  static String warehouseAdjustProduct(int productId) =>
      '$baseURL/warehouse/products/$productId/adjust';
  static const String procurementStores = '$baseURL/procurement/stores';
  static String procurementMissingProducts(int storeId) =>
      '$baseURL/procurement/missing-products?store_id=$storeId';
  static String procurementCatalogProducts(int storeId) =>
      '$baseURL/procurement/catalog-products?store_id=$storeId';
  static String procurementCart(int storeId) =>
      '$baseURL/procurement/cart?store_id=$storeId';
  static String procurementHistory({int? storeId, int limit = 200}) {
    final params = <String, String>{
      'limit': '$limit',
      if (storeId != null) 'store_id': '$storeId',
    };
    return Uri.parse('$baseURL/procurement/history')
        .replace(queryParameters: params)
        .toString();
  }
  static String procurementReceipts({int? storeId, int limit = 200}) {
    final params = <String, String>{
      'limit': '$limit',
      if (storeId != null) 'store_id': '$storeId',
    };
    return Uri.parse('$baseURL/procurement/receipts')
        .replace(queryParameters: params)
        .toString();
  }
  static const String procurementCartItems = '$baseURL/procurement/cart/items';
  static String procurementCartItemById(int cartItemId) =>
      '$baseURL/procurement/cart/items/$cartItemId';
  static const String procurementCheckout = '$baseURL/procurement/cart/checkout';
  static const String procurementCreateReceipt = '$baseURL/procurement/receipts';

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
  static const String subscriptionPlans = '$baseURL/auth/subscription-plans';

  // plants
  static const String plants = '$baseURL/plants/';
  static const String plantsAdminCreate = '$baseURL/plants/admin/create';
  static String plantsId(int id) => '$baseURL/plants/$id';
  static const String categories = '$baseURL/plants/categories';
  static const String adminCategories = '$baseURL/categories';
  static String adminCategoryById(int id) => '$baseURL/categories/$id';
  static const String adminCategoriesCreate = '$baseURL/categories/admin/create';
  static String adminCategoryDeletionCheck(int id) =>
      '$baseURL/categories/admin/$id/deletion-check';
  static String adminCategoryDelete(int id) =>
      '$baseURL/categories/admin/$id/delete';
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
  static const String potOptions = '$baseURL/pot/options';
  static const String potVariants = '$baseURL/pot/variants';
  static const String potPrices = '$baseURL/pot/prices';
  static String potPriceByParams(String material, String size, {String? color}) {
    final params = <String, String>{
      'material': material,
      'size': size,
      if (color != null && color.trim().isNotEmpty) 'color': color.trim(),
    };
    return Uri.parse('$baseURL/pot/price').replace(queryParameters: params).toString();
  }

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
