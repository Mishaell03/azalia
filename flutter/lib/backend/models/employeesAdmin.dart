/// Универсальная обёртка для ответа с объектом
class ApiObjectResponse<T> {
  final bool success;
  final T data;
  final String? message;

  ApiObjectResponse({
    required this.success,
    required this.data,
    this.message,
  });

  factory ApiObjectResponse.fromJson(
      Map<String, dynamic> json,
      T Function(Map<String, dynamic>) fromJsonT,
      ) {
    return ApiObjectResponse(
      success: json['success'],
      data: fromJsonT(json['data']),
      message: json['message'],
    );
  }
}

/// Универсальная обёртка для ответа с листом объектов
class ApiListResponse<T> {
  final bool success;
  final List<T> data;
  final Pagination? pagination;

  ApiListResponse({
    required this.success,
    required this.data,
    this.pagination,
  });

  factory ApiListResponse.fromJson(
      Map<String, dynamic> json,
      T Function(Map<String, dynamic>) fromJsonT,
      ) {
    final items = (json['data'] as List? ?? [])
        .map((item) => fromJsonT(item as Map<String, dynamic>))
        .toList();

    return ApiListResponse(
      success: json['success'] ?? false,
      data: items,
      pagination: json['pagination'] is Map<String, dynamic>
          ? Pagination.fromJson(json['pagination'])
          : null,
    );
  }
}

class Pagination {
  final int page;
  final int perPage;
  final int total;
  final int pages;

  Pagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.pages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      perPage: json['per_page'] ?? 0,
      total: json['total'] ?? 0,
      pages: json['pages'] ?? 0,
    );
  }
}

/// Модель пользователя
class User {
  final int id;
  final String name;
  final String phone;
  final int telegramId;
  final String? sessionToken;
  final String? avatarUrl;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.phone,
    required this.telegramId,
    this.sessionToken,
    this.avatarUrl,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      telegramId: json['telegram_id'],
      sessionToken: json['session_token'],
      avatarUrl: json['avatar_url'] ?? json['avatar'],
      status: json['status']?.toString(),
      createdAt: _tryParseDateTime(json['created_at']),
      updatedAt: _tryParseDateTime(json['updated_at']),
    );
  }
}

/// Ответ WhoAmI
class WhoAmIResponse {
  final bool success;
  final bool isAdmin;
  final User user;

  WhoAmIResponse({
    required this.success,
    required this.isAdmin,
    required this.user,
  });

  factory WhoAmIResponse.fromJson(Map<String, dynamic> json) {
    return WhoAmIResponse(
      success: json['success'],
      isAdmin: json['is_admin'],
      user: User.fromJson(json['user']),
    );
  }
}

/// Позиция сотрудника
class Position {
  final int id;
  final String title;
  final String requirements;
  final String responsibilities;
  final DateTime createdAt;

  Position({
    required this.id,
    required this.title,
    required this.requirements,
    required this.responsibilities,
    required this.createdAt,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: json['id'],
      title: json['title'],
      requirements: json['requirements'],
      responsibilities: json['responsibilities'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// Информация о пользователе сотрудника
class EmployeeUserInfo {
  final String name;
  final String phone;
  final String? avatarUrl;

  EmployeeUserInfo({
    required this.name,
    required this.phone,
    this.avatarUrl,
  });

  factory EmployeeUserInfo.fromJson(Map<String, dynamic> json) {
    return EmployeeUserInfo(
      name: json['name'],
      phone: json['phone'],
      avatarUrl: json['avatar_url'] ?? json['avatar'],
    );
  }
}

/// Сотрудник
class Employee {
  final int id;
  final int userId;
  final int telegramId;
  final int positionId;
  final int storeId;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final double salary;
  final bool isActive;
  final DateTime? hireDate;
  final DateTime? firedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String positionTitle;
  final String storeName;
  final String storeAddress;

  Employee({
    required this.id,
    required this.userId,
    required this.telegramId,
    required this.positionId,
    required this.storeId,
    required this.fullName,
    required this.phone,
    this.avatarUrl,
    required this.salary,
    required this.isActive,
    required this.hireDate,
    this.firedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.positionTitle,
    required this.storeName,
    required this.storeAddress,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      userId: json['user_id'],
      telegramId: json['telegram_id'],
      positionId: json['position_id'],
      storeId: json['store_id'],
      fullName: json['full_name'] ?? json['name'] ?? '',
      phone: json['phone'] ?? '',
      avatarUrl: json['avatar_url'],
      salary: (json['salary'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'],
      hireDate: _tryParseDateTime(json['hired_at'] ?? json['hire_date']),
      firedAt: _tryParseDateTime(json['fired_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      positionTitle:
          json['position_title'] ??
          (json['position'] is Map<String, dynamic>
              ? json['position']['title']
              : '') ??
          '',
      storeName: json['store_name']?.toString() ?? '',
      storeAddress: json['store_address']?.toString() ?? '',
    );
  }
}

class AdminUserOrderSummary {
  final int id;
  final String orderNumber;
  final String orderType;
  final String storeName;
  final double subtotal;
  final double deliveryFee;
  final double discountAmount;
  final String status;
  final String paymentStatus;
  final double totalPrice;
  final String createdAt;
  final String updatedAt;

  const AdminUserOrderSummary({
    required this.id,
    required this.orderNumber,
    required this.orderType,
    required this.storeName,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.status,
    required this.paymentStatus,
    required this.totalPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminUserOrderSummary.fromJson(Map<String, dynamic> json) {
    return AdminUserOrderSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderNumber: json['order_number']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? '',
      storeName: json['store_name']?.toString() ?? '',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class AdminEmployeeState {
  final int id;
  final int positionId;
  final int storeId;
  final double salary;
  final bool isActive;
  final String positionTitle;
  final String storeName;

  const AdminEmployeeState({
    required this.id,
    required this.positionId,
    required this.storeId,
    required this.salary,
    required this.isActive,
    required this.positionTitle,
    required this.storeName,
  });

  factory AdminEmployeeState.fromJson(Map<String, dynamic> json) {
    return AdminEmployeeState(
      id: (json['id'] as num?)?.toInt() ?? 0,
      positionId: (json['position_id'] as num?)?.toInt() ?? 0,
      storeId: (json['store_id'] as num?)?.toInt() ?? 0,
      salary: (json['salary'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] == true,
      positionTitle: json['position_title']?.toString() ?? '',
      storeName: json['store_name']?.toString() ?? '',
    );
  }
}

class AdminOptionItem {
  final int id;
  final String title;

  const AdminOptionItem({
    required this.id,
    required this.title,
  });
}

class AdminUserDetails {
  final int id;
  final String name;
  final String status;
  final bool isAdmin;
  final AdminEmployeeState? employee;
  final List<AdminOptionItem> positions;
  final List<AdminOptionItem> stores;
  final List<AdminUserOrderSummary> orders;

  const AdminUserDetails({
    required this.id,
    required this.name,
    required this.status,
    required this.isAdmin,
    required this.employee,
    required this.positions,
    required this.stores,
    required this.orders,
  });

  factory AdminUserDetails.fromApiResponse(Map<String, dynamic> response) {
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final options = response['options'] as Map<String, dynamic>? ?? const {};
    final positionRows = options['positions'] as List? ?? const [];
    final storeRows = options['stores'] as List? ?? const [];

    return AdminUserDetails(
      id: (data['id'] as num?)?.toInt() ?? 0,
      name: data['name']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      isAdmin: data['is_admin'] == true,
      employee: data['employee'] is Map<String, dynamic>
          ? AdminEmployeeState.fromJson(data['employee'] as Map<String, dynamic>)
          : null,
      positions: positionRows
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => AdminOptionItem(
              id: (row['id'] as num?)?.toInt() ?? 0,
              title: row['title']?.toString() ?? 'Позиция',
            ),
          )
          .toList(),
      stores: storeRows
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => AdminOptionItem(
              id: (row['id'] as num?)?.toInt() ?? 0,
              title: row['name']?.toString() ?? 'Магазин',
            ),
          )
          .toList(),
      orders: (data['orders'] as List? ?? const [])
          .map((item) => AdminUserOrderSummary.fromJson(item))
          .toList(),
    );
  }
}

DateTime? _tryParseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  final text = value.toString();
  if (text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text);
}
