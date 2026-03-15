import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/payment/link.dart';
import 'package:azalia/backend/models/payment/generate_response.dart';
import 'package:azalia/backend/models/payment/order_status.dart';

class PaymentService {
  final ApiClient _api;

  PaymentService(this._api);

  /// создать ссылку на оплату
  Future<PaymentGenerateResponse> generatePaymentLink({
    String? address,
    required String paymentMethod,
    String paymentTiming = 'online',
    String? onDeliveryMethod,
    String orderType = 'delivery',
    int? storeId,
    List<int>? selectedItemIds,
    bool acceptQuantityChanges = false,
  }) async {
    final body = <String, dynamic>{
      'address': address,
      'payment_method': paymentMethod,
      'payment_timing': paymentTiming,
      'on_delivery_method': onDeliveryMethod,
      'order_type': orderType,
      'selected_item_ids': selectedItemIds ?? [],
      'accept_quantity_changes': acceptQuantityChanges,
    };
    if (storeId != null) {
      body['store_id'] = storeId;
    }

    final response = await _api.post(
      ApiConfig.paymentGenerateLink,
      body: body,
    );

    // Берём только data из ответа
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('Отсутствуют платежные данные');
    }
    return PaymentGenerateResponse.fromJson(data);
  }

  /// получить ссылку на оплату
  Future<PaymentLink> getPaymentLink(int linkId) async {
    final response = await _api.get(
      ApiConfig.paymentLink(linkId),
    );

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('Payment link data is missing');
    }

    return PaymentLink.fromJson(data);
  }

  /// отменить ссылку
  Future<void> cancelPaymentLink(int linkId) async {
    await _api.post(
      ApiConfig.paymentCancel(linkId),
    );
  }

  /// статус ссылки
  Future<PaymentLink> checkPaymentLinkStatus(int linkId) async {
    final response = await _api.get(
      ApiConfig.paymentLinkStatus(linkId),
    );

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('Payment link status data is missing');
    }

    return PaymentLink.fromJson(data);
  }

  /// проверить статус заказа
  Future<OrderStatusResponse> checkOrderStatus(int orderId) async {
    final response = await _api.get(
      ApiConfig.orderStatus(orderId),
    );

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('Order status data is missing');
    }

    return OrderStatusResponse.fromJson(data);
  }

  Future<String> updateOrderAddress(int orderId, String address) async {
    final response = await _api.put(
      ApiConfig.orderAddress(orderId),
      body: {'address': address},
    );

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('Order address update data is missing');
    }

    return data['address']?.toString() ?? address;
  }

  Future<List<Map<String, dynamic>>> getStores() async {
    final response = await _api.get(ApiConfig.paymentStores);
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> checkAvailability({
    required List<int> selectedItemIds,
    required String orderType,
    int? storeId,
  }) async {
    final body = <String, dynamic>{
      'selected_item_ids': selectedItemIds,
      'order_type': orderType,
    };
    if (storeId != null) {
      body['store_id'] = storeId;
    }

    final response = await _api.post(
      ApiConfig.paymentAvailability,
      body: body,
    );
    return response['data'] as Map<String, dynamic>? ?? const {};
  }
}
