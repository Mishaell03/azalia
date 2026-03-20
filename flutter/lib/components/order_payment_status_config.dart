import 'package:azalia/components/colors.dart';
import 'package:flutter/material.dart';

class OrderPaymentStatusConfig {
  static const List<String> orderStatusCodes = [
    'new',
    'awaiting_payment',
    'processing',
    'assembled',
    'shipped',
    'ready_for_pickup',
    'delivered',
    'completed',
    'cancelled',
  ];

  static const List<String> paymentStatusCodes = [
    'pending',
    'authorized',
    'paid',
    'failed',
    'refunded',
    'partially_refunded',
  ];

  static const List<String> adminEditablePickupOrderStatusCodes = [
    'assembled',
    'ready_for_pickup',
    'completed',
    'cancelled',
  ];

  static const List<String> adminEditableDeliveryOrderStatusCodes = [
    'assembled',
    'shipped',
    'delivered',
    'completed',
    'cancelled',
  ];

  static const Map<String, String> orderLabels = {
    'new': 'Новый',
    'awaiting_payment': 'Ожидает оплаты',
    'processing': 'В работе',
    'assembled': 'Собран',
    'shipped': 'В доставке',
    'ready_for_pickup': 'Готов к выдаче',
    'delivered': 'Доставлен',
    'completed': 'Завершен',
    'cancelled': 'Отменен',
  };

  static const Map<String, String> paymentLabels = {
    'pending': 'Ожидает оплаты',
    'authorized': 'Ожидает оплаты',
    'paid': 'Оплачен',
    'failed': 'Ошибка оплаты',
    'refunded': 'Средства возвращены',
    'partially_refunded': 'Частичный возврат',
  };

  static String normalize(String value) => value.trim().toLowerCase();

  static bool isOrderStatus(String status) {
    return orderLabels.containsKey(normalize(status));
  }

  static bool isPaymentStatus(String status) {
    return paymentLabels.containsKey(normalize(status));
  }

  static String orderLabel(String status) {
    final code = normalize(status);
    return orderLabels[code] ?? status;
  }

  static String paymentLabel(String status) {
    final code = normalize(status);
    return paymentLabels[code] ?? status;
  }

  static List<MapEntry<String, String>> orderStatusFilterOptions() {
    return [
      const MapEntry('', 'Все статусы'),
      ...orderStatusCodes.map((code) => MapEntry(code, orderLabel(code))),
    ];
  }

  static List<MapEntry<String, String>> editableOrderStatusOptions({
    required String orderType,
  }) {
    final resolvedType = normalize(orderType);
    final codes = resolvedType == 'pickup'
        ? adminEditablePickupOrderStatusCodes
        : adminEditableDeliveryOrderStatusCodes;
    return codes.map((code) => MapEntry(code, orderLabel(code))).toList();
  }

  static Color orderColor(String status) {
    final code = normalize(status);
    if (code == 'completed') return AppColors.success;
    if (code == 'cancelled') return AppColors.error;
    if (code == 'delivered') return AppColors.brown;
    return AppColors.star;
  }

  static Color paymentColor(String status) {
    final code = normalize(status);
    if (code == 'paid') return AppColors.success;
    if (code == 'failed' ||
        code == 'refunded' ||
        code == 'partially_refunded') {
      return AppColors.error;
    }
    if (code == 'pending' ||
        code == 'authorized' ||
        code == 'awaiting_payment') {
      return AppColors.brown;
    }
    return AppColors.grey;
  }
}
