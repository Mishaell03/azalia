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
    required String address,
    required String paymentMethod,
    List<int>? selectedItemIds,
  }) async {
    final response = await _api.post(
      ApiConfig.paymentGenerateLink,
      body: {
        'address': address,
        'payment_method': paymentMethod,
        'selected_item_ids': selectedItemIds ?? [],
      },
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
}