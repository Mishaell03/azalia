class AdminSubscriptionPlan {
  final int id;
  final String code;
  final String name;
  final String description;
  final double monthlyPrice;
  final double yearlyPrice;
  final int maxPlants;
  final int maxMembers;
  final String notifications;
  final bool hasCorporate;
  final bool canCreateCompany;
  final bool hasAnalytics;
  final bool hasExtendedFeatures;
  final bool isActive;
  final List<String> features;

  const AdminSubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.maxPlants,
    required this.maxMembers,
    required this.notifications,
    required this.hasCorporate,
    required this.canCreateCompany,
    required this.hasAnalytics,
    required this.hasExtendedFeatures,
    required this.isActive,
    required this.features,
  });

  factory AdminSubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      monthlyPrice: (json['monthly_price'] as num?)?.toDouble() ?? 0,
      yearlyPrice: (json['yearly_price'] as num?)?.toDouble() ?? 0,
      maxPlants: (json['max_plants'] as num?)?.toInt() ?? 1,
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 1,
      notifications: json['notifications']?.toString() ?? 'basic',
      hasCorporate: json['has_corporate'] == true,
      canCreateCompany: json['can_create_company'] == true,
      hasAnalytics: json['has_analytics'] == true,
      hasExtendedFeatures: json['has_extended_features'] == true,
      isActive: json['is_active'] != false,
      features: (json['features'] as List? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
    );
  }
}
