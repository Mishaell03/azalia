import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';

class SubscriptionPlanDto {
  final String id;
  final String name;
  final double price;
  final String description;
  final List<String> features;
  final int maxPlants;
  final String notifications;
  final bool hasCorporate;
  final bool hasAnalytics;
  final bool isCurrent;

  SubscriptionPlanDto({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.features,
    required this.maxPlants,
    required this.notifications,
    required this.hasCorporate,
    required this.hasAnalytics,
    required this.isCurrent,
  });

  factory SubscriptionPlanDto.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString() ?? '',
      features: (json['features'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      maxPlants: (json['max_plants'] as num?)?.toInt() ?? 1,
      notifications: json['notifications']?.toString() ?? 'basic',
      hasCorporate: json['has_corporate'] == true,
      hasAnalytics: json['has_analytics'] == true,
      isCurrent: json['is_current'] == true,
    );
  }
}

class SubscriptionPlansResponse {
  final List<SubscriptionPlanDto> items;
  final int count;
  final String currentPlanId;

  SubscriptionPlansResponse({
    required this.items,
    required this.count,
    required this.currentPlanId,
  });
}

class SubscriptionService {
  static final ApiClient _api = ApiClient();

  static Future<SubscriptionPlansResponse> getPlans() async {
    final response = await _api.get(ApiConfig.subscriptionPlans);
    if (response['success'] != true) {
      throw Exception('Не удалось загрузить тарифы');
    }

    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final rawItems = data['items'] as List? ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPlanDto.fromJson)
        .toList();

    return SubscriptionPlansResponse(
      items: items,
      count: (data['count'] as num?)?.toInt() ?? items.length,
      currentPlanId: data['current_plan_id']?.toString() ?? 'free',
    );
  }

  static Future<SubscriptionCheckoutDto> createCheckout({
    required String planId,
    String billingPeriod = 'monthly',
  }) async {
    final response = await _api.post(
      '${ApiConfig.subscriptionPlans}/checkout',
      body: {
        'plan_id': planId,
        'billing_period': billingPeriod,
      },
    );
    if (response['success'] != true) {
      throw Exception('Не удалось создать оплату подписки');
    }
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return SubscriptionCheckoutDto.fromJson(data);
  }

  static Future<SubscriptionCheckoutStatusDto> getCheckoutStatus(int checkoutId) async {
    final response = await _api.get('${ApiConfig.subscriptionPlans}/checkout/$checkoutId/status');
    if (response['success'] != true) {
      throw Exception('Не удалось получить статус оплаты');
    }
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return SubscriptionCheckoutStatusDto.fromJson(data);
  }

  static Future<void> cancelCurrentPlan(String planId) async {
    final response = await _api.post(
      '${ApiConfig.subscriptionPlans}/$planId/cancel',
    );
    if (response['success'] != true) {
      throw Exception('Не удалось отключить подписку');
    }
  }
}

class SubscriptionCheckoutDto {
  final int checkoutId;
  final String paymentUrl;
  final String status;
  final bool autoRenew;

  SubscriptionCheckoutDto({
    required this.checkoutId,
    required this.paymentUrl,
    required this.status,
    required this.autoRenew,
  });

  factory SubscriptionCheckoutDto.fromJson(Map<String, dynamic> json) {
    return SubscriptionCheckoutDto(
      checkoutId: (json['checkout_id'] as num?)?.toInt() ?? 0,
      paymentUrl: json['payment_url']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      autoRenew: json['auto_renew'] == true,
    );
  }
}

class SubscriptionCheckoutStatusDto {
  final int checkoutId;
  final String statusCode;
  final String status;
  final bool autoRenew;
  final int? subscriptionId;

  SubscriptionCheckoutStatusDto({
    required this.checkoutId,
    required this.statusCode,
    required this.status,
    required this.autoRenew,
    required this.subscriptionId,
  });

  bool get isPaid => statusCode == 'paid';

  factory SubscriptionCheckoutStatusDto.fromJson(Map<String, dynamic> json) {
    return SubscriptionCheckoutStatusDto(
      checkoutId: (json['checkout_id'] as num?)?.toInt() ?? 0,
      statusCode: json['status_code']?.toString() ?? 'pending',
      status: json['status']?.toString() ?? 'Ожидает оплату',
      autoRenew: json['auto_renew'] == true,
      subscriptionId: (json['subscription_id'] as num?)?.toInt(),
    );
  }
}
