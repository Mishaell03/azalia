import 'link.dart';

class OrderStatusResponse {
  final int orderId;
  final String orderStatus;
  final bool isPaid;
  final double totalPrice;
  final PaymentLink? paymentLink;

  OrderStatusResponse({
    required this.orderId,
    required this.orderStatus,
    required this.isPaid,
    required this.totalPrice,
    this.paymentLink,
  });

  factory OrderStatusResponse.fromJson(Map<String, dynamic> json) {
    return OrderStatusResponse(
      orderId: json['order_id'],
      orderStatus: json['order_status'],
      isPaid: json['is_paid'],
      totalPrice: (json['total_price'] as num).toDouble(),
      paymentLink: json['payment_link'] != null
          ? PaymentLink.fromJson(json['payment_link'])
          : null,
    );
  }
}
