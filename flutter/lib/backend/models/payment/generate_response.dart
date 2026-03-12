import 'item.dart';

class PaymentGenerateResponse {
  final int paymentLinkId;
  final int orderId;
  final String paymentUrl;
  final double amount;
  final String currency;
  final DateTime? expiresAt;
  final int itemsCount;
  final List<PaymentItem> items;
  final String? address;
  final String paymentMethod;
  final String message;

  PaymentGenerateResponse({
    required this.paymentLinkId,
    required this.orderId,
    required this.paymentUrl,
    required this.amount,
    required this.currency,
    this.expiresAt,
    required this.itemsCount,
    required this.items,
    this.address,
    required this.paymentMethod,
    required this.message,
  });

  factory PaymentGenerateResponse.fromJson(Map<String, dynamic> json) {
    return PaymentGenerateResponse(
      paymentLinkId: (json['payment_link_id'] as num).toInt(),
      orderId: (json['order_id'] as num).toInt(),
      paymentUrl: json['payment_url']?.toString() ?? '',
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency']?.toString() ?? 'RUB',
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PaymentItem.fromJson)
          .toList(),
      address: json['address']?.toString(),
      paymentMethod: json['payment_method']?.toString() ?? 'card',
      message: json['message']?.toString() ?? '',
    );
  }
}
