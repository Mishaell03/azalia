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
    List<int>? selectedItemIds,
  }) async {
    try {
      // проверка авторизации
      if (!_session.isLoggedIn || !_session.isTokenValid) {
        debugPrint('PaymentCoordinator: пользователь не авторизован');
        throw Exception('Пользователь не авторизован');
      }

      // проверка корзины
      final cart = await CartService.getCart();
      if (cart.items.isEmpty) {
        debugPrint('PaymentCoordinator: корзина пуста');
        throw Exception('Корзина пуста');
      }

      debugPrint('PaymentCoordinator: начинаем платёж');
      final controller = PaymentFlowController(_api);

      final payment = await controller.startPayment(
        address: address,
        paymentMethod: paymentMethod,
        selectedItemIds: selectedItemIds,
      );

      debugPrint('PaymentCoordinator: платёж создан, orderId=${payment.orderId}');

      // навигация
      if (!context.mounted) {
        debugPrint('PaymentCoordinator: контекст не смонтирован');
        return;
      }

      final items = payment.items.map((item) {
        return PaymentItemArgs(
          plantName: item.plantName,
          quantity: item.quantity,
          plantPrice: item.plantPrice,
          potPrice: item.potPrice,
          itemTotal: item.itemTotal,
        );
      }).toList();

      debugPrint('PaymentCoordinator: переходим на payment экран');
      context.goNamed(
        'payment',
        extra: PaymentRouteArgs(
          paymentLinkId: payment.paymentLinkId,
          orderId: payment.orderId,
          paymentUrl: payment.paymentUrl,
          totalPrice: payment.amount,
          address: payment.address,
          paymentMethod: payment.paymentMethod,
          items: items,
        ),
      );
      debugPrint('PaymentCoordinator: навигация успешна');
    } catch (e, stackTrace) {
      debugPrint('PaymentCoordinator Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
