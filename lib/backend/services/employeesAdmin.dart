import 'package:flutter/foundation.dart';
import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/employeesAdmin.dart';

class EmployeesService {
  final ApiClient api;

  EmployeesService(this.api);

  /// Получаем данные о текущем пользователе
  Future<WhoAmIResponse> whoAmI() async {
    final res = await api.get(ApiConfig.whoAmI);
    _checkSuccess(res);
    _log('Данные о текущем пользователе получены');
    return WhoAmIResponse.fromJson(res);
  }

  /// Получаем список всех пользователей
  Future<List<User>> getUsers() async {
    final res = await api.get(ApiConfig.users);
    _checkSuccess(res);
    _log('Список пользователей получен');
    return (res['data'] as List)
        .map((e) => User.fromJson(e))
        .toList();
  }

  /// Получаем список всех сотрудников
  Future<List<Employee>> getEmployees() async {
    final res = await api.get(ApiConfig.employees);
    _checkSuccess(res);
    _log('Список сотрудников получен');
    return (res['data'] as List)
        .map((e) => Employee.fromJson(e))
        .toList();
  }

  /// Получаем данные конкретного сотрудника
  Future<Employee> getEmployee(int id) async {
    final res = await api.get(ApiConfig.employee(id));
    _checkSuccess(res);
    _log('Данные сотрудника с ID=$id получены');
    return Employee.fromJson(res['data']);
  }

  /// Назначаем пользователя сотрудником
  Future<Employee> assignEmployee({
    required int telegramId,
    required int positionId,
    required int salary,
  }) async {
    final res = await api.post(
      ApiConfig.assignEmployee,
      body: {
        'telegram_id': telegramId,
        'position_id': positionId,
        'salary': salary,
      },
    );
    _checkSuccess(res);
    _log('Пользователь tg_id=$telegramId назначен сотрудником');
    return Employee.fromJson(res['data']);
  }

  /// Активируем / деактивируем сотрудника
  Future<Employee> employeeDeactivate({
    required int telegramId,
    required bool isActive,
  }) async {
    final res = await api.post(
      ApiConfig.assignEmployee,
      body: {
        'telegram_id': telegramId,
        'is_active': isActive,
      },
    );
    _checkSuccess(res);
    _log('Пользователь tg_id=$telegramId имеет статус активности: $isActive');
    return Employee.fromJson(res['data']);
  }

  void _checkSuccess(Map<String, dynamic> res) {
    if (res['success'] != true) {
      throw Exception(res['error'] ?? 'Unknown API error');
    }
  }

  void _log(String message) {
    debugPrint('EmployeesService: $message');
  }
}
