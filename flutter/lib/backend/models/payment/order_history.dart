class OrderHistoryListResponse {
  final List<OrderHistorySummary> items;
  final OrderHistoryPagination pagination;

  OrderHistoryListResponse({
    required this.items,
    required this.pagination,
  });

  factory OrderHistoryListResponse.fromJson(Map<String, dynamic> json) {
    return OrderHistoryListResponse(
      items: (json['items'] as List? ?? const [])
          .map((item) => OrderHistorySummary.fromJson(item))
          .toList(),
      pagination: OrderHistoryPagination.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class OrderHistoryPagination {
  final int limit;
  final int offset;
  final int count;
  final int total;

  OrderHistoryPagination({
    required this.limit,
    required this.offset,
    required this.count,
    required this.total,
  });

  factory OrderHistoryPagination.fromJson(Map<String, dynamic> json) {
    return OrderHistoryPagination(
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrderHistorySummary {
  final int orderId;
  final String orderNumber;
  final String status;
  final String statusCode;
  final String paymentStatus;
  final String paymentStatusCode;
  final String orderType;
  final String orderTypeLabel;
  final double totalPrice;
  final int itemsCount;
  final String createdAt;
  final String updatedAt;
  final OrderHistoryPayment? payment;

  OrderHistorySummary({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.statusCode,
    required this.paymentStatus,
    required this.paymentStatusCode,
    required this.orderType,
    required this.orderTypeLabel,
    required this.totalPrice,
    required this.itemsCount,
    required this.createdAt,
    required this.updatedAt,
    required this.payment,
  });

  factory OrderHistorySummary.fromJson(Map<String, dynamic> json) {
    return OrderHistorySummary(
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      orderNumber: json['order_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusCode: json['status_code']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      paymentStatusCode: json['payment_status_code']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? '',
      orderTypeLabel: json['order_type_label']?.toString() ?? '',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      payment: json['payment'] is Map<String, dynamic>
          ? OrderHistoryPayment.fromJson(json['payment'])
          : null,
    );
  }
}

class OrderHistoryDetail {
  final int orderId;
  final String orderNumber;
  final String status;
  final String statusCode;
  final String paymentStatus;
  final String paymentStatusCode;
  final String orderType;
  final String orderTypeLabel;
  final int storeId;
  final String? address;
  final String? comment;
  final double subtotal;
  final double deliveryFee;
  final double discountAmount;
  final double totalPrice;
  final int? assignedEmployeeId;
  final String createdAt;
  final String updatedAt;
  final List<OrderHistoryItem> items;
  final OrderHistoryPayment? payment;
  final List<OrderRefund> refunds;
  final List<OrderStatusHistoryItem> statusHistory;

  OrderHistoryDetail({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.statusCode,
    required this.paymentStatus,
    required this.paymentStatusCode,
    required this.orderType,
    required this.orderTypeLabel,
    required this.storeId,
    required this.address,
    required this.comment,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.totalPrice,
    required this.assignedEmployeeId,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.payment,
    required this.refunds,
    required this.statusHistory,
  });

  factory OrderHistoryDetail.fromJson(Map<String, dynamic> json) {
    return OrderHistoryDetail(
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      orderNumber: json['order_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusCode: json['status_code']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      paymentStatusCode: json['payment_status_code']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? '',
      orderTypeLabel: json['order_type_label']?.toString() ?? '',
      storeId: (json['store_id'] as num?)?.toInt() ?? 0,
      address: json['address']?.toString(),
      comment: json['comment']?.toString(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      assignedEmployeeId: (json['assigned_employee_id'] as num?)?.toInt(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      items: (json['items'] as List? ?? const [])
          .map((item) => OrderHistoryItem.fromJson(item))
          .toList(),
      payment: json['payment'] is Map<String, dynamic>
          ? OrderHistoryPayment.fromJson(json['payment'])
          : null,
      refunds: (json['refunds'] as List? ?? const [])
          .map((item) => OrderRefund.fromJson(item))
          .toList(),
      statusHistory: (json['status_history'] as List? ?? const [])
          .map((item) => OrderStatusHistoryItem.fromJson(item))
          .toList(),
    );
  }
}

class OrderHistoryItem {
  final int id;
  final int? productId;
  final int? plantId;
  final String name;
  final String? description;
  final int quantity;
  final int returnedQuantity;
  final double productUnitPrice;
  final double potUnitPrice;
  final double discountAmount;
  final double totalPrice;
  final String? imageUrl;
  final OrderItemPot pot;
  final String createdAt;

  OrderHistoryItem({
    required this.id,
    required this.productId,
    required this.plantId,
    required this.name,
    required this.description,
    required this.quantity,
    required this.returnedQuantity,
    required this.productUnitPrice,
    required this.potUnitPrice,
    required this.discountAmount,
    required this.totalPrice,
    required this.imageUrl,
    required this.pot,
    required this.createdAt,
  });

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) {
    return OrderHistoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt(),
      plantId: (json['plant_id'] as num?)?.toInt(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      returnedQuantity: (json['returned_quantity'] as num?)?.toInt() ?? 0,
      productUnitPrice: (json['product_unit_price'] as num?)?.toDouble() ?? 0,
      potUnitPrice: (json['pot_unit_price'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      imageUrl: json['image_url']?.toString(),
      pot: OrderItemPot.fromJson(json['pot'] as Map<String, dynamic>? ?? const {}),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class OrderItemPot {
  final int? sizeId;
  final String? sizeCode;
  final String? sizeName;
  final int? materialId;
  final String? materialName;
  final int? colorId;
  final String? colorName;

  OrderItemPot({
    required this.sizeId,
    required this.sizeCode,
    required this.sizeName,
    required this.materialId,
    required this.materialName,
    required this.colorId,
    required this.colorName,
  });

  factory OrderItemPot.fromJson(Map<String, dynamic> json) {
    return OrderItemPot(
      sizeId: (json['size_id'] as num?)?.toInt(),
      sizeCode: json['size_code']?.toString(),
      sizeName: json['size_name']?.toString(),
      materialId: (json['material_id'] as num?)?.toInt(),
      materialName: json['material_name']?.toString(),
      colorId: (json['color_id'] as num?)?.toInt(),
      colorName: json['color_name']?.toString(),
    );
  }
}

class OrderHistoryPayment {
  final int id;
  final int orderId;
  final int userId;
  final double amount;
  final String status;
  final int? paymentMethodId;
  final String? paymentMethodCode;
  final String? paymentMethodName;
  final String? externalPaymentId;
  final String createdAt;
  final String? paidAt;
  final String? failedAt;
  final String? expiresAt;

  OrderHistoryPayment({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.amount,
    required this.status,
    required this.paymentMethodId,
    required this.paymentMethodCode,
    required this.paymentMethodName,
    required this.externalPaymentId,
    required this.createdAt,
    required this.paidAt,
    required this.failedAt,
    required this.expiresAt,
  });

  factory OrderHistoryPayment.fromJson(Map<String, dynamic> json) {
    return OrderHistoryPayment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderId: (json['order_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
      paymentMethodId: (json['payment_method_id'] as num?)?.toInt(),
      paymentMethodCode: json['payment_method_code']?.toString(),
      paymentMethodName: json['payment_method_name']?.toString(),
      externalPaymentId: json['external_payment_id']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      paidAt: json['paid_at']?.toString(),
      failedAt: json['failed_at']?.toString(),
      expiresAt: json['expires_at']?.toString(),
    );
  }
}

class OrderRefund {
  final int id;
  final double amount;
  final String? reason;
  final String status;
  final String? processedAt;
  final String createdAt;

  OrderRefund({
    required this.id,
    required this.amount,
    required this.reason,
    required this.status,
    required this.processedAt,
    required this.createdAt,
  });

  factory OrderRefund.fromJson(Map<String, dynamic> json) {
    return OrderRefund(
      id: (json['id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      reason: json['reason']?.toString(),
      status: json['status']?.toString() ?? '',
      processedAt: json['processed_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class OrderStatusHistoryItem {
  final int id;
  final String? oldStatus;
  final String? oldStatusCode;
  final String newStatus;
  final String newStatusCode;
  final String changedAt;
  final OrderStatusChangedBy changedBy;

  OrderStatusHistoryItem({
    required this.id,
    required this.oldStatus,
    required this.oldStatusCode,
    required this.newStatus,
    required this.newStatusCode,
    required this.changedAt,
    required this.changedBy,
  });

  factory OrderStatusHistoryItem.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      oldStatus: json['old_status']?.toString(),
      oldStatusCode: json['old_status_code']?.toString(),
      newStatus: json['new_status']?.toString() ?? '',
      newStatusCode: json['new_status_code']?.toString() ?? '',
      changedAt: json['changed_at']?.toString() ?? '',
      changedBy: OrderStatusChangedBy.fromJson(
        json['changed_by'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class OrderStatusChangedBy {
  final int? employeeId;
  final String? employeeName;

  OrderStatusChangedBy({
    required this.employeeId,
    required this.employeeName,
  });

  factory OrderStatusChangedBy.fromJson(Map<String, dynamic> json) {
    return OrderStatusChangedBy(
      employeeId: (json['employee_id'] as num?)?.toInt(),
      employeeName: json['employee_name']?.toString(),
    );
  }
}
