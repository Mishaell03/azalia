import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/payment/order_history.dart';

class OrderHistoryService {
  static final ApiClient _api = ApiClient();

  static Future<OrderHistoryListResponse> getOrders({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _api.get(
        ApiConfig.orders(limit: limit, offset: offset),
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) {
        return OrderHistoryListResponse.fromJson(const {
          'items': [],
          'pagination': {'limit': 0, 'offset': 0, 'count': 0, 'total': 0},
        });
      }

      return OrderHistoryListResponse.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return OrderHistoryListResponse.fromJson(const {
          'items': [],
          'pagination': {'limit': 0, 'offset': 0, 'count': 0, 'total': 0},
        });
      }
      rethrow;
    }
  }

  static Future<OrderHistoryDetail> getOrderDetails(int orderId) async {
    final response = await _api.get(ApiConfig.orderDetails(orderId));

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('Order details data is missing');
    }

    return OrderHistoryDetail.fromJson(data);
  }
}
