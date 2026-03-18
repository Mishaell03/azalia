import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';

class AdminAnalyticsService {
  final ApiClient _api;

  AdminAnalyticsService(this._api);

  Future<Map<String, dynamic>> getAnalytics({
    int? storeId,
    int days = 30,
    int top = 7,
  }) async {
    final response = await _api.get(
      ApiConfig.adminAnalytics(storeId: storeId, days: days, top: top),
    );
    return response['data'] as Map<String, dynamic>? ?? const {};
  }
}
