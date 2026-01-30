class PaymentLink {
  final int id;
  final int userId;
  final int? orderId;
  final double amount;
  final String paymentUrl;
  final String status;
  final String? paymentSystemId;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? paymentConfirmedAt;

  PaymentLink({
    required this.id,
    required this.userId,
    this.orderId,
    required this.amount,
    required this.paymentUrl,
    required this.status,
    this.paymentSystemId,
    this.createdAt,
    this.expiresAt,
    this.paymentConfirmedAt,
  });

  factory PaymentLink.fromJson(Map<String, dynamic> json) {
    return PaymentLink(
      id: json['id'],
      userId: json['user_id'],
      orderId: json['order_id'],
      amount: (json['amount'] as num).toDouble(),
      paymentUrl: json['payment_url'],
      status: json['status'],
      paymentSystemId: json['payment_system_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      paymentConfirmedAt: json['payment_confirmed_at'] != null
          ? DateTime.parse(json['payment_confirmed_at'])
          : null,
    );
  }
}
