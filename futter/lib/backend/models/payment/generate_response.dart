import 'item.dart';

class PaymentGenerateResponse {
  final int paymentLinkId;
  final int orderId;
  final String paymentUrl;
  final double amount;
  final String currency;
  final DateTime expiresAt;
  final int itemsCount;
  final List<PaymentItem> items;
  final String address;
  final String paymentMethod;
  final String message;

  PaymentGenerateResponse({
    required this.paymentLinkId,
    required this.orderId,
    required this.paymentUrl,
    required this.amount,
    required this.currency,
    required this.expiresAt,
    required this.itemsCount,
    required this.items,
    required this.address,
    required this.paymentMethod,
    required this.message,
  });

  factory PaymentGenerateResponse.fromJson(Map<String, dynamic> json) {
    return PaymentGenerateResponse(
      paymentLinkId: json['payment_link_id'],
      orderId: json['order_id'],
      paymentUrl: json['payment_url'],
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'],
      expiresAt: DateTime.parse(json['expires_at']),
      itemsCount: json['items_count'],
      items: (json['items'] as List)
          .map((e) => PaymentItem.fromJson(e))
          .toList(),
      address: json['address'],
      paymentMethod: json['payment_method'],
      message: json['message'],
    );
  }
}