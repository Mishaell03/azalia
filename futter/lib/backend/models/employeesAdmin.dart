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
