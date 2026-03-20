class User {
  final int id;
  final int telegramId;
  final String name;
  final String phone;
  final String? sessionToken;
  final String? avatar;

  User({
    required this.id,
    required this.telegramId,
    required this.name,
    required this.phone,
    this.sessionToken,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      telegramId: json['telegram_id'],
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      sessionToken: json['session_token'],
      avatar: json['avatar'] ?? json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'telegram_id': telegramId,
      'name': name,
      'phone': phone,
      'session_token': sessionToken,
      'avatar': avatar,
    };
  }
}

class Employee {
  final int id;
  final int positionId;
  final bool isActive;

  Employee({
    required this.id,
    required this.positionId,
    required this.isActive,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      positionId: json['position_id'],
      isActive: json['is_active'] ?? false,
    );
  }
}

class Position {
  final int id;
  final String title;

  Position({required this.id, required this.title});

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(id: json['id'], title: json['title'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title};
  }
}

class AuthResponse {
  final bool success;
  final User user;
  final String message;
  final Employee? employee;
  final bool isEmployee;
  final Position? position;

  AuthResponse({
    required this.success,
    required this.user,
    required this.message,
    this.employee,
    required this.isEmployee,
    this.position,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final dynamic employeeRaw = json['employee'];
    Map<String, dynamic>? employeeMap;
    if (employeeRaw is Map<String, dynamic>) {
      employeeMap = employeeRaw;
    } else if (employeeRaw is Map) {
      employeeMap = Map<String, dynamic>.from(employeeRaw);
    }

    final dynamic positionRaw = json['position'] ?? employeeMap?['position'];
    Map<String, dynamic>? positionMap;
    if (positionRaw is Map<String, dynamic>) {
      positionMap = positionRaw;
    } else if (positionRaw is Map) {
      positionMap = Map<String, dynamic>.from(positionRaw);
    }

    return AuthResponse(
      success: json['success'] ?? false,
      user: User.fromJson(json['user']),
      message: json['message'] ?? '',
      employee: employeeMap != null ? Employee.fromJson(employeeMap) : null,
      isEmployee: json['is_employee'] ?? false,
      position: positionMap != null ? Position.fromJson(positionMap) : null,
    );
  }
}

class CodeStatus {
  final String code;
  final String? expiresAt;
  final bool used;
  final bool userLinked;
  final bool isValid;
  final User? user;
  final Employee? employee;
  final bool? isEmployee;

  CodeStatus({
    required this.code,
    this.expiresAt,
    required this.used,
    required this.userLinked,
    required this.isValid,
    this.user,
    this.employee,
    this.isEmployee,
  });

  factory CodeStatus.fromJson(Map<String, dynamic> json) {
    return CodeStatus(
      code: json['code'],
      expiresAt: json['expires_at'],
      used: json['used'] ?? false,
      userLinked: json['user_linked'] ?? false,
      isValid: json['is_valid'] ?? false,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      employee: json['employee'] != null
          ? Employee.fromJson(json['employee'])
          : null,
      isEmployee: json['is_employee'],
    );
  }
}

class CodeStatusResponse {
  final bool success;
  final CodeStatus status;
  final String? error;

  CodeStatusResponse({required this.success, required this.status, this.error});

  factory CodeStatusResponse.fromJson(Map<String, dynamic> json) {
    return CodeStatusResponse(
      success: json['success'] ?? false,
      status: CodeStatus.fromJson(json['status']),
      error: json['error'],
    );
  }
}
