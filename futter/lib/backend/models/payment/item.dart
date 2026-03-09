class PaymentItem {
  final int plantId;
  final String plantName;
  final int quantity;
  final double plantPrice;
  final double potPrice;
  final double itemTotal;

  PaymentItem({
    required this.plantId,
    required this.plantName,
    required this.quantity,
    required this.plantPrice,
    required this.potPrice,
    required this.itemTotal,
  });

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    return PaymentItem(
      plantId: json['plant_id'],
      plantName: json['plant_name'],
      quantity: json['quantity'],
      plantPrice: (json['plant_price'] as num).toDouble(),
      potPrice: (json['pot_price'] as num).toDouble(),
      itemTotal: (json['item_total'] as num).toDouble(),
    );
  }
}
