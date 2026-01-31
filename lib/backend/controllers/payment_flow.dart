import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/models/payment/generate_response.dart';
import 'package:azalia/backend/models/payment/link.dart';
import 'package:azalia/backend/models/payment/order_status.dart';
import 'package:azalia/backend/services/cart.dart';
import 'package:azalia/backend/services/payment.dart';
import 'package:azalia/backend/services/session.dart';
import 'package:flutter/foundation.dart';

class PaymentFlowController {
  final ApiClient _api;
  final PaymentService _paymentService;
  final SessionService _sessionService;

  PaymentFlowController(ApiClient api)
    : _api = api,
      _paymentService = PaymentService(api),
      _sessionService = SessionService();

  Future<PaymentGenerateResponse> startPayment({
    required String address,
    required String paymentMethod,
  }) async {
    // проверка авторизации
    if (!_sessionService.isLoggedIn || !_sessionService.isTokenValid) {
      debugPrint('PaymentFlow: пользователь не авторизован');
      throw Exception('Пользователь не авторизован');
    }

    // проверка корзины
    final cart = await CartService.getCart();
    if (cart.items.isEmpty) {
      debugPrint('PaymentFlow: попытка оплаты пустой корзины');
      throw Exception('Корзина пуста');
    }

    // генерация ссылки на оплату

    final paymentResponse = await _paymentService.generatePaymentLink(
      address: address,
      paymentMethod: paymentMethod,
    );

    debugPrint(
      'PaymentFlow: ссылка на оплату создана'
      '(orderId=${paymentResponse.orderId})'
      '(paymentLinkId=${paymentResponse.paymentLinkId})',
    );

    return paymentResponse;
  }

  // получение ссылки на оплату
  Future<PaymentLink> getPaymentLink(int linkId) async {
    if (!_sessionService.isLoggedIn) {
      throw Exception('Пользователь не авторизован!');
    }
    final link = await _paymentService.getPaymentLink(linkId);

    debugPrint(
      'PaymentFlow: получена ссылка на оплату'
      'id=${link.id}, status=${link.status}',
    );
    return link;
  }

  // статус заказа
  Future<OrderStatusResponse> checkOrderStatus(int orderId) async {
    final status = await _paymentService.checkOrderStatus(orderId);
    debugPrint('PaymentFlow: статус заказа получен:'
        'id=$orderId, status=${status.orderStatus}');
    return status;
  }

  Future<void> cancelPayment(int linkId) async {
    debugPrint('PaymentFlow: отмена оплаты (linkId=$linkId)');
    await _paymentService.cancelPaymentLink(linkId);
  }
}
