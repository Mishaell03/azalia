import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/apiClient.dart';

class EmployeesService {
  final ApiClient api;

  EmployeesService(this.api);

  Future<Map<String, dynamic>> whoAmI() async {
    final res = await api.get(ApiConfig.whoAmI);
    _checkSuccess(res);
    return res;
  }

  Future<List<dynamic>> getUsers() async {
    final res = await api.get(ApiConfig.users);
    _checkSuccess(res);
    return res['data'];
  }

  Future<List<dynamic>> getEmployees() async {
    final res = await api.get(ApiConfig.employees);
    _checkSuccess(res);
    return res['data'];
  }

  Future<Map<String, dynamic>> getEmployee(int id) async {
    final res = await api.get(ApiConfig.employee(id));
    _checkSuccess(res);
    return res['data'];
  }

  Future<void> assignEmployee({
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
  }

  void _checkSuccess(Map<String, dynamic> res) {
    if (res['success'] != true) {
      throw Exception(res['error'] ?? 'Unknown API error');
    }
  }
}
