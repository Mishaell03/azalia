import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/services/session.dart';
import 'package:azalia/backend/services/cart.dart';
import 'payment_flow.dart';
import 'package:azalia/router.dart';

class PaymentCoordinator {
  final BuildContext context;

  PaymentCoordinator(this.context);

  final SessionService _session = SessionService();
  final ApiClient _api = ApiClient();

  Future<void> startPaymentFlow({
    required String address,
    required String paymentMethod,
  }) async {
    // проверка авторизации
    if (!_session.isLoggedIn || !_session.isTokenValid) {
      throw Exception('Пользователь не авторизован');
    }

    // проверка корзины
    final cart = await CartService.getCart();
    if (cart.items.isEmpty) {
      throw Exception('Корзина пуста');
    }

    final controller = PaymentFlowController(_api);

    final payment = await controller.startPayment(
      address: address,
      paymentMethod: paymentMethod,
    );

    // навигация
    if (!context.mounted) return;

    context.goNamed(
      'payment',
      extra: PaymentRouteArgs(
        paymentLinkId: payment.paymentLinkId,
        orderId: payment.orderId,
        paymentUrl: payment.paymentUrl,
      ),
    );
  }
}
