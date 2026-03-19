import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';

class SubscriptionPlanDto {
  final String id;
  final String name;
  final double price;
  final String description;
  final List<String> features;
  final int maxPlants;
  final int maxMembers;
  final String notifications;
  final bool hasCorporate;
  final bool canCreateCompany;
  final bool hasAnalytics;
  final bool isCurrent;

  SubscriptionPlanDto({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.features,
    required this.maxPlants,
    required this.maxMembers,
    required this.notifications,
    required this.hasCorporate,
    required this.canCreateCompany,
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
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 1,
      notifications: json['notifications']?.toString() ?? 'basic',
      hasCorporate: json['has_corporate'] == true,
      canCreateCompany: json['can_create_company'] == true,
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
      body: {'plan_id': planId, 'billing_period': billingPeriod},
    );
    if (response['success'] != true) {
      throw Exception('Не удалось создать оплату подписки');
    }
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return SubscriptionCheckoutDto.fromJson(data);
  }

  static Future<SubscriptionCheckoutStatusDto> getCheckoutStatus(
    int checkoutId,
  ) async {
    final response = await _api.get(
      '${ApiConfig.subscriptionPlans}/checkout/$checkoutId/status',
    );
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

  static Future<CorporateSubscriptionStateDto> getCorporateState() async {
    final response = await _api.get(ApiConfig.corporateCompany);
    if (response['success'] != true) {
      throw Exception('Не удалось загрузить данные компании');
    }
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return CorporateSubscriptionStateDto.fromJson(data);
  }

  static Future<CorporateSubscriptionStateDto> createCorporateCompany({
    required String name,
    String? description,
    String? contactPhone,
    String? contactEmail,
    String? address,
  }) async {
    final response = await _api.post(
      ApiConfig.corporateCompany,
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (contactPhone != null) 'contact_phone': contactPhone,
        if (contactEmail != null) 'contact_email': contactEmail,
        if (address != null) 'address': address,
      },
    );
    if (response['success'] != true) {
      throw Exception('Не удалось создать компанию');
    }
    return getCorporateState();
  }

  static Future<CorporateSubscriptionStateDto> addCorporateMember({
    int? companyId,
    int? userId,
    String? userPhone,
    String role = 'member',
  }) async {
    final response = await _api.post(
      ApiConfig.corporateCompanyMembers,
      body: {
        if (companyId != null) 'company_id': companyId,
        if (userId != null) 'user_id': userId,
        if (userPhone != null) 'user_phone': userPhone,
        'role': role,
      },
    );
    if (response['success'] != true) {
      throw Exception('Не удалось добавить участника');
    }
    return getCorporateState();
  }

  static Future<CorporateSubscriptionStateDto> removeCorporateMember({
    required int userId,
    int? companyId,
  }) async {
    final response = await _api.delete(
      ApiConfig.corporateCompanyMemberByUser(userId, companyId: companyId),
    );
    if (response['success'] != true) {
      throw Exception('Не удалось удалить участника');
    }
    return getCorporateState();
  }
}

class CorporateCompanyDto {
  final int id;
  final String name;
  final String? description;
  final String? contactPhone;
  final String? contactEmail;
  final String? address;
  final String myRole;
  final bool isOrganizer;

  CorporateCompanyDto({
    required this.id,
    required this.name,
    required this.description,
    required this.contactPhone,
    required this.contactEmail,
    required this.address,
    required this.myRole,
    required this.isOrganizer,
  });

  factory CorporateCompanyDto.fromJson(Map<String, dynamic> json) {
    return CorporateCompanyDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      contactEmail: json['contact_email']?.toString(),
      address: json['address']?.toString(),
      myRole: json['my_role']?.toString() ?? 'member',
      isOrganizer: json['is_organizer'] == true,
    );
  }
}

class CorporateMemberDto {
  final int userId;
  final String fullName;
  final String phone;
  final String role;
  final bool isActive;

  CorporateMemberDto({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.isActive,
  });

  factory CorporateMemberDto.fromJson(Map<String, dynamic> json) {
    return CorporateMemberDto(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      isActive: json['is_active'] == true,
    );
  }
}

class CorporateSubscriptionStateDto {
  final bool canUseCorporate;
  final CorporateCompanyDto? company;
  final List<CorporateMemberDto> members;
  final int maxMembers;
  final int currentMembers;
  final bool canAddMore;

  CorporateSubscriptionStateDto({
    required this.canUseCorporate,
    required this.company,
    required this.members,
    required this.maxMembers,
    required this.currentMembers,
    required this.canAddMore,
  });

  factory CorporateSubscriptionStateDto.fromJson(Map<String, dynamic> json) {
    final companyJson = json['company'] as Map<String, dynamic>?;
    final membersRaw = json['members'] as List? ?? const [];
    final limits = json['limits'] as Map<String, dynamic>? ?? const {};
    return CorporateSubscriptionStateDto(
      canUseCorporate: json['can_use_corporate'] == true,
      company: companyJson == null
          ? null
          : CorporateCompanyDto.fromJson(companyJson),
      members: membersRaw
          .whereType<Map<String, dynamic>>()
          .map(CorporateMemberDto.fromJson)
          .toList(),
      maxMembers: (limits['max_members'] as num?)?.toInt() ?? 1,
      currentMembers: (limits['current_members'] as num?)?.toInt() ?? 0,
      canAddMore: limits['can_add_more'] == true,
    );
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
