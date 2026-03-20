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
  Future<List<User>> getUsers({int page = 1, int perPage = 100}) async {
    final url = Uri.parse(ApiConfig.users)
        .replace(
          queryParameters: {
            'page': page.toString(),
            'per_page': perPage.toString(),
          },
        )
        .toString();

    final res = await api.get(url);
    _checkSuccess(res);
    _log('Список пользователей получен');
    final users = (res['data'] as List).map((e) => User.fromJson(e)).toList();
    return users;
  }

  /// Получаем список всех сотрудников
  Future<List<Employee>> getEmployees() async {
    final res = await api.get(ApiConfig.employees);
    _checkSuccess(res);
    _log('Список сотрудников получен');
    final employees = (res['data'] as List)
        .map((e) => Employee.fromJson(e))
        .toList();
    return employees;
  }

  /// Получаем список компаний с участниками (для админки)
  Future<List<AdminCompany>> getAdminCompanies() async {
    final res = await api.get(ApiConfig.adminCompanies);
    _checkSuccess(res);
    _log('Список компаний получен');
    final companies = (res['data'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AdminCompany.fromJson)
        .toList();
    return companies;
  }

  /// Получаем данные конкретного сотрудника
  Future<Employee> getEmployee(int id) async {
    final res = await api.get(ApiConfig.employee(id));
    _checkSuccess(res);
    _log('Данные сотрудника с ID=$id получены');
    return Employee.fromJson(res['data']);
  }

  /// Получаем детали пользователя для админки
  Future<AdminUserDetails> getUserDetails(int userId) async {
    final res = await api.get(ApiConfig.updateUser(userId));
    _checkSuccess(res);
    _log('Детали пользователя с ID=$userId получены');
    return AdminUserDetails.fromApiResponse(res);
  }

  Future<AdminUserDetails> _patchUser(
    int userId, {
    required Map<String, dynamic> payload,
  }) async {
    final res = await api.patch(ApiConfig.updateUser(userId), body: payload);
    _checkSuccess(res);
    _log('Пользователь с ID=$userId обновлен: $payload');
    return AdminUserDetails.fromApiResponse(res);
  }

  Future<AdminUserDetails> activateUser(int userId) {
    return _patchUser(userId, payload: {'status': 'active'});
  }

  Future<AdminUserDetails> deactivateUser({
    required int userId,
    required String reason,
  }) {
    return _patchUser(
      userId,
      payload: {'status': 'blocked', 'blocked_reason': reason},
    );
  }

  Future<AdminUserDetails> deleteUser(int userId) {
    return _patchUser(userId, payload: {'status': 'deleted'});
  }

  Future<AdminUserDetails> hireUser({
    required int userId,
    required int positionId,
    required int storeId,
    double salary = 0,
  }) {
    return _patchUser(
      userId,
      payload: {
        'position_id': positionId,
        'store_id': storeId,
        'salary': salary,
        'is_active': true,
      },
    );
  }

  Future<AdminUserDetails> rehireUser(int userId) {
    return _patchUser(userId, payload: {'is_active': true});
  }

  Future<AdminUserDetails> fireUser(int userId) {
    return _patchUser(userId, payload: {'remove_employee': true});
  }

  Future<AdminUserDetails> updateEmployeeSalary({
    required int userId,
    required double salary,
  }) {
    return _patchUser(userId, payload: {'salary': salary});
  }

  Future<AdminUserDetails> updateEmployeeStore({
    required int userId,
    required int storeId,
  }) {
    return _patchUser(userId, payload: {'store_id': storeId});
  }

  Future<AdminUserDetails> updateEmployeeProfile({
    required int userId,
    int? positionId,
    int? storeId,
    double? salary,
  }) {
    final payload = <String, dynamic>{};
    if (positionId != null) {
      payload['position_id'] = positionId;
    }
    if (storeId != null) {
      payload['store_id'] = storeId;
    }
    if (salary != null) {
      payload['salary'] = salary;
    }
    return _patchUser(userId, payload: payload);
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
      body: {'telegram_id': telegramId, 'is_active': isActive},
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
