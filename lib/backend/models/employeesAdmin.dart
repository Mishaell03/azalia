class User {
  final int id;
  final String name;
  final String phone;
  final int telegramId;
  final bool isEmployee;
  final String? sessionToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.phone,
    required this.telegramId,
    required this.isEmployee,
    this.sessionToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      telegramId: json['telegram_id'],
      isEmployee: json['is_employee'],
      sessionToken: json['session_token'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

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

class EmployeeUserInfo {
  final String name;
  final String phone;

  EmployeeUserInfo({
    required this.name,
    required this.phone,
  });

  factory EmployeeUserInfo.fromJson(Map<String, dynamic> json) {
    return EmployeeUserInfo(
      name: json['name'],
      phone: json['phone'],
    );
  }
}

class Employee {
  final int id;
  final int telegramId;
  final int positionId;
  final int salary;
  final bool isActive;
  final DateTime hireDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Position position;
  final EmployeeUserInfo userInfo;

  Employee({
    required this.id,
    required this.telegramId,
    required this.positionId,
    required this.salary,
    required this.isActive,
    required this.hireDate,
    required this.createdAt,
    required this.updatedAt,
    required this.position,
    required this.userInfo,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      telegramId: json['telegram_id'],
      positionId: json['position_id'],
      salary: json['salary'],
      isActive: json['is_active'],
      hireDate: DateTime.parse(json['hire_date']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      position: Position.fromJson(json['position']),
      userInfo: EmployeeUserInfo.fromJson(json['user_info']),
    );
  }
}

class ApiListResponse<T> {
  final bool success;
  final List<T> data;

  ApiListResponse({
    required this.success,
    required this.data,
  });
}

class ApiObjectResponse<T> {
  final bool success;
  final T data;
  final String? message;

  ApiObjectResponse({
    required this.success,
    required this.data,
    this.message,
  });
}
