import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/payment/order_history.dart';

class OrderHistoryService {
  static final ApiClient _api = ApiClient();

  static const Map<String, dynamic> _emptyListResponse = {
    'items': [],
    'pagination': {'limit': 0, 'offset': 0, 'count': 0, 'total': 0},
  };

  static Map<String, dynamic> _normalizeOrdersListResponse(
    dynamic rawData, {
    required int limit,
    required int offset,
  }) {
    if (rawData is List) {
      return {
        'items': rawData,
        'pagination': {
          'limit': limit,
          'offset': offset,
          'count': rawData.length,
          'total': rawData.length,
        },
      };
    }

    if (rawData is! Map) {
      return _emptyListResponse;
    }

    final data = rawData.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final items = data['items'] ?? data['orders'] ?? data['results'];
    final pagination = data['pagination'] ?? data['meta'];

    return {
      'items': items is List ? items : const [],
      'pagination': pagination is Map
          ? pagination.map((key, value) => MapEntry(key.toString(), value))
          : {
              'limit': limit,
              'offset': offset,
              'count': items is List ? items.length : 0,
              'total': items is List ? items.length : 0,
            },
    };
  }

  static Map<String, dynamic>? _normalizeOrderDetailsResponse(dynamic rawData) {
    if (rawData is Map<String, dynamic>) return rawData;
    if (rawData is Map) {
      return rawData.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static Future<OrderHistoryListResponse> getOrders({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _api.get(
        ApiConfig.orders(limit: limit, offset: offset),
      );
      return OrderHistoryListResponse.fromJson(
        _normalizeOrdersListResponse(
          response['data'],
          limit: limit,
          offset: offset,
        ),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return OrderHistoryListResponse.fromJson(_emptyListResponse);
      }
      rethrow;
    }
  }

  static Future<OrderHistoryDetail> getOrderDetails(int orderId) async {
    final response = await _api.get(ApiConfig.orderDetails(orderId));
    final dataContainer = _normalizeOrderDetailsResponse(response['data']);
    final nestedOrder = _normalizeOrderDetailsResponse(dataContainer?['order']);

    final data = nestedOrder ??
        _normalizeOrderDetailsResponse(response['data']) ??
        _normalizeOrderDetailsResponse(response['order']) ??
        dataContainer;
    if (data == null) {
      throw ApiException('Order details data is missing');
    }

    return OrderHistoryDetail.fromJson(data);
  }

  static Future<void> cancelOrder(int orderId) async {
    final response = await _api.post(ApiConfig.orderCancel(orderId));
    if (response['success'] != true) {
      throw ApiException('Не удалось отменить заказ');
    }
  }
}
