import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/admin_subscription_plan.dart';

class AdminSubscriptionPlansService {
  final ApiClient _api;

  AdminSubscriptionPlansService(this._api);

  Future<List<AdminSubscriptionPlan>> getPlans() async {
    final response = await _api.get(ApiConfig.adminSubscriptionPlans);
    final raw = response['data'] as List? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AdminSubscriptionPlan.fromJson)
        .toList();
  }

  Future<AdminSubscriptionPlan> updatePlan({
    required String planId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _api.put(
      ApiConfig.adminSubscriptionPlanById(planId),
      body: payload,
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return AdminSubscriptionPlan.fromJson(data);
  }
}
