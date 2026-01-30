import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/payment/link.dart';
import 'package:azalia/backend/models/payment/generate_response.dart';
import 'package:azalia/backend/models/payment/order_status.dart';

class PaymentService {
  final ApiClient _api;

  PaymentService(this._api);

  // создать ссылку на оплату
  Future<PaymentGenerateResponse> generatePaymentLink({
    required String address,
    required String paymentMethod,
  }) async {
    final data = await _api.post(
      ApiConfig.paymentGenerateLink,
      body: {
        'address': address,
        'payment_method': paymentMethod,
      },
    );
    return PaymentGenerateResponse.fromJson(data);
  }

  // получить ссылку на оплату
  Future<PaymentLink> getPaymentLink(int linkId) async {
    final data = await _api.get(
      ApiConfig.paymentLink(linkId),
    );
    return PaymentLink.fromJson(data);
  }

  // отменить ссылку
  Future<void> cancelPaymentLink(int linkId) async {
    await _api.post(
        ApiConfig.paymentCancel(linkId),
    );
  }

  // статус ссылки
  Future<PaymentLink> checkPaymentLinkStatus(int linkId) async {
    final data = await _api.get(
        ApiConfig.paymentLinkStatus(linkId),
    );
    return PaymentLink.fromJson(data);
  }

  // проверить статус заказа
  Future<OrderStatusResponse> checkOrderStatus(int orderId) async{
    final data = await _api.get(
      ApiConfig.orderStatus(orderId),
    );
    return OrderStatusResponse.fromJson(data);
  }
}
