import 'dart:async';
import 'dart:io';

import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/services/local_notifications.dart';

class ImportantDateDto {
  final int id;
  final String title;
  final DateTime eventDate;
  final String? comment;

  ImportantDateDto({
    required this.id,
    required this.title,
    required this.eventDate,
    required this.comment,
  });

  factory ImportantDateDto.fromJson(Map<String, dynamic> json) {
    return ImportantDateDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      eventDate:
          DateTime.tryParse(json['event_date']?.toString() ?? '') ??
          DateTime.now(),
      comment: json['comment']?.toString(),
    );
  }
}

class PlantCareDateDto {
  final int id;
  final int? userPlantId;
  final int? productId;
  final String plantName;
  final String plantPhotoUrl;
  final String? wateringRequirement;
  final String careType;
  final DateTime careDate;
  final String? comment;
  final bool isDone;

  PlantCareDateDto({
    required this.id,
    required this.userPlantId,
    required this.productId,
    required this.plantName,
    required this.plantPhotoUrl,
    required this.wateringRequirement,
    required this.careType,
    required this.careDate,
    required this.comment,
    required this.isDone,
  });

  factory PlantCareDateDto.fromJson(Map<String, dynamic> json) {
    return PlantCareDateDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userPlantId: (json['user_plant_id'] as num?)?.toInt(),
      productId: (json['product_id'] as num?)?.toInt(),
      plantName: json['plant_name']?.toString() ?? '',
      plantPhotoUrl: json['plant_photo_url']?.toString() ?? 'img/none.png',
      wateringRequirement: json['watering_requirement']?.toString(),
      careType: json['care_type']?.toString() ?? 'watering',
      careDate:
          DateTime.tryParse(json['care_date']?.toString() ?? '') ??
          DateTime.now(),
      comment: json['comment']?.toString(),
      isDone: json['is_done'] == true || json['is_done'] == 1,
    );
  }
}

class UserPlantDto {
  final int id;
  final int? productId;
  final String plantName;
  final String? customName;
  final String displayName;
  final String photoUrl;
  final String? wateringRequirement;
  final int wateringFrequencyDays;
  final int soilChangeFrequencyDays;
  final String? notes;
  final DateTime? lastWateredAt;
  final DateTime? nextWateringAt;
  final DateTime? lastSoilChangeAt;
  final DateTime? nextSoilChangeAt;

  UserPlantDto({
    required this.id,
    required this.productId,
    required this.plantName,
    required this.customName,
    required this.displayName,
    required this.photoUrl,
    required this.wateringRequirement,
    required this.wateringFrequencyDays,
    required this.soilChangeFrequencyDays,
    required this.notes,
    required this.lastWateredAt,
    required this.nextWateringAt,
    required this.lastSoilChangeAt,
    required this.nextSoilChangeAt,
  });

  factory UserPlantDto.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) {
      final raw = json[key]?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return UserPlantDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt(),
      plantName: json['plant_name']?.toString() ?? '',
      customName: json['custom_name']?.toString(),
      displayName:
          json['display_name']?.toString() ??
          json['plant_name']?.toString() ??
          '',
      photoUrl: json['photo_url']?.toString() ?? 'img/none.png',
      wateringRequirement: json['watering_requirement']?.toString(),
      wateringFrequencyDays:
          (json['watering_frequency_days'] as num?)?.toInt() ?? 7,
      soilChangeFrequencyDays:
          (json['soil_change_frequency_days'] as num?)?.toInt() ?? 180,
      notes: json['notes']?.toString(),
      lastWateredAt: parseDate('last_watered_at'),
      nextWateringAt: parseDate('next_watering_at'),
      lastSoilChangeAt: parseDate('last_soil_change_at'),
      nextSoilChangeAt: parseDate('next_soil_change_at'),
    );
  }
}

class UserPlantCareMarkDto {
  final int taskId;
  final String careType;
  final DateTime careDate;
  final UserPlantDto plant;

  UserPlantCareMarkDto({
    required this.taskId,
    required this.careType,
    required this.careDate,
    required this.plant,
  });

  factory UserPlantCareMarkDto.fromJson(Map<String, dynamic> json) {
    final plantJson = json['plant'] as Map<String, dynamic>? ?? const {};
    return UserPlantCareMarkDto(
      taskId: (json['task_id'] as num?)?.toInt() ?? 0,
      careType: json['care_type']?.toString() ?? 'watering',
      careDate:
          DateTime.tryParse(json['care_date']?.toString() ?? '') ??
          DateTime.now(),
      plant: UserPlantDto.fromJson(plantJson),
    );
  }
}

class UserPlantLimitsDto {
  final int currentCount;
  final int maxPlants;
  final bool canAdd;
  final bool upgradeRequired;
  final String? message;

  UserPlantLimitsDto({
    required this.currentCount,
    required this.maxPlants,
    required this.canAdd,
    required this.upgradeRequired,
    required this.message,
  });

  factory UserPlantLimitsDto.fromJson(Map<String, dynamic> json) {
    return UserPlantLimitsDto(
      currentCount: (json['current_count'] as num?)?.toInt() ?? 0,
      maxPlants: (json['max_plants'] as num?)?.toInt() ?? 1,
      canAdd: json['can_add'] == true,
      upgradeRequired: json['upgrade_required'] == true,
      message: json['message']?.toString(),
    );
  }
}

class OrganizationDto {
  final int companyId;
  final String companyName;
  final String role;

  OrganizationDto({
    required this.companyId,
    required this.companyName,
    required this.role,
  });

  factory OrganizationDto.fromJson(Map<String, dynamic> json) {
    return OrganizationDto(
      companyId: (json['company_id'] as num?)?.toInt() ?? 0,
      companyName: json['company_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
    );
  }
}

class CompanyCalendarEventDto {
  final int id;
  final int companyId;
  final String companyName;
  final String title;
  final DateTime eventDate;
  final String? comment;

  CompanyCalendarEventDto({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.title,
    required this.eventDate,
    required this.comment,
  });

  factory CompanyCalendarEventDto.fromJson(Map<String, dynamic> json) {
    return CompanyCalendarEventDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      companyId: (json['company_id'] as num?)?.toInt() ?? 0,
      companyName: json['company_name']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      eventDate:
          DateTime.tryParse(json['event_date']?.toString() ?? '') ??
          DateTime.now(),
      comment: json['comment']?.toString(),
    );
  }
}

class CompanyCalendarEventPreferenceDto {
  final int id;
  final int companyEventId;
  final int? categoryId;
  final String? categoryName;
  final int? productId;
  final String? productName;

  CompanyCalendarEventPreferenceDto({
    required this.id,
    required this.companyEventId,
    required this.categoryId,
    required this.categoryName,
    required this.productId,
    required this.productName,
  });

  factory CompanyCalendarEventPreferenceDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return CompanyCalendarEventPreferenceDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      companyEventId: (json['company_event_id'] as num?)?.toInt() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt(),
      categoryName: json['category_name']?.toString(),
      productId: (json['product_id'] as num?)?.toInt(),
      productName: json['product_name']?.toString(),
    );
  }

  String get displayName => categoryName ?? productName ?? 'Без названия';
}

class HolidayPreferenceDto {
  final int id;
  final String holidayCode;
  final String holidayTitle;
  final int? categoryId;
  final String? categoryName;
  final int? productId;
  final String? productName;

  HolidayPreferenceDto({
    required this.id,
    required this.holidayCode,
    required this.holidayTitle,
    required this.categoryId,
    required this.categoryName,
    required this.productId,
    required this.productName,
  });

  factory HolidayPreferenceDto.fromJson(Map<String, dynamic> json) {
    return HolidayPreferenceDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      holidayCode: json['holiday_code']?.toString() ?? '',
      holidayTitle: json['holiday_title']?.toString() ?? '',
      categoryId: (json['category_id'] as num?)?.toInt(),
      categoryName: json['category_name']?.toString(),
      productId: (json['product_id'] as num?)?.toInt(),
      productName: json['product_name']?.toString(),
    );
  }

  String get displayName => categoryName ?? productName ?? 'Без названия';
}

class ImportantDatePreferenceDto {
  final int id;
  final int importantDateId;
  final int? categoryId;
  final String? categoryName;
  final int? productId;
  final String? productName;

  ImportantDatePreferenceDto({
    required this.id,
    required this.importantDateId,
    required this.categoryId,
    required this.categoryName,
    required this.productId,
    required this.productName,
  });

  factory ImportantDatePreferenceDto.fromJson(Map<String, dynamic> json) {
    return ImportantDatePreferenceDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      importantDateId: (json['important_date_id'] as num?)?.toInt() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt(),
      categoryName: json['category_name']?.toString(),
      productId: (json['product_id'] as num?)?.toInt(),
      productName: json['product_name']?.toString(),
    );
  }

  String get displayName => categoryName ?? productName ?? 'Без названия';
}

class HolidayPreferenceOptionDto {
  final int id;
  final String name;

  HolidayPreferenceOptionDto({required this.id, required this.name});

  factory HolidayPreferenceOptionDto.fromJson(Map<String, dynamic> json) {
    return HolidayPreferenceOptionDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class HolidayPreferenceOptionsResponse {
  final List<HolidayPreferenceOptionDto> categories;
  final List<HolidayPreferenceOptionDto> products;

  HolidayPreferenceOptionsResponse({
    required this.categories,
    required this.products,
  });
}

class OrganizationsResponse {
  final bool canUseCorporate;
  final List<OrganizationDto> items;

  OrganizationsResponse({required this.canUseCorporate, required this.items});
}

class CalendarService {
  static final ApiClient _api = ApiClient();

  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static void _syncLocalNotifications() {
    unawaited(LocalNotificationsService.instance.syncCalendarNotifications());
  }

  static Future<List<ImportantDateDto>> getImportantDates() async {
    final response = await _api.get(ApiConfig.importantDates);
    if (response['success'] != true) return const [];
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ImportantDateDto.fromJson)
        .toList();
  }

  static Future<ImportantDateDto> createImportantDate({
    required String title,
    required DateTime date,
    String? comment,
  }) async {
    final response = await _api.post(
      ApiConfig.importantDates,
      body: {'title': title, 'event_date': _dateOnly(date), 'comment': comment},
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final result = ImportantDateDto.fromJson(data);
    _syncLocalNotifications();
    return result;
  }

  static Future<ImportantDateDto> updateImportantDate({
    required int id,
    String? title,
    DateTime? date,
    String? comment,
  }) async {
    final response = await _api.put(
      '${ApiConfig.importantDates}/$id',
      body: {
        if (title != null) 'title': title,
        if (date != null) 'event_date': _dateOnly(date),
        if (comment != null) 'comment': comment,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final result = ImportantDateDto.fromJson(data);
    _syncLocalNotifications();
    return result;
  }

  static Future<void> deleteImportantDate(int id) async {
    await _api.delete('${ApiConfig.importantDates}/$id');
    _syncLocalNotifications();
  }

  static Future<List<PlantCareDateDto>> getPlantCareDates() async {
    final response = await _api.get(ApiConfig.plantCareDates);
    if (response['success'] != true) return const [];
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PlantCareDateDto.fromJson)
        .toList();
  }

  static Future<PlantCareDateDto> createPlantCareDate({
    int? userPlantId,
    int? productId,
    String? plantName,
    String? plantPhotoUrl,
    String? wateringRequirement,
    required String careType,
    required DateTime date,
    String? comment,
    bool isDone = false,
  }) async {
    final response = await _api.post(
      ApiConfig.plantCareDates,
      body: {
        if (userPlantId != null) 'user_plant_id': userPlantId,
        if (productId != null) 'product_id': productId,
        if (plantName != null) 'plant_name': plantName,
        if (plantPhotoUrl != null) 'plant_photo_url': plantPhotoUrl,
        if (wateringRequirement != null)
          'watering_requirement': wateringRequirement,
        'care_type': careType,
        'care_date': _dateOnly(date),
        'comment': comment,
        'is_done': isDone,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final result = PlantCareDateDto.fromJson(data);
    _syncLocalNotifications();
    return result;
  }

  static Future<PlantCareDateDto> updatePlantCareDate({
    required int id,
    int? userPlantId,
    String? plantName,
    String? plantPhotoUrl,
    String? wateringRequirement,
    String? careType,
    DateTime? careDate,
    bool? isDone,
    String? comment,
  }) async {
    final response = await _api.put(
      '${ApiConfig.plantCareDates}/$id',
      body: {
        if (userPlantId != null) 'user_plant_id': userPlantId,
        if (plantName != null) 'plant_name': plantName,
        if (plantPhotoUrl != null) 'plant_photo_url': plantPhotoUrl,
        if (wateringRequirement != null)
          'watering_requirement': wateringRequirement,
        if (careType != null) 'care_type': careType,
        if (careDate != null) 'care_date': _dateOnly(careDate),
        if (isDone != null) 'is_done': isDone,
        if (comment != null) 'comment': comment,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final result = PlantCareDateDto.fromJson(data);
    _syncLocalNotifications();
    return result;
  }

  static Future<void> deletePlantCareDate(int id) async {
    await _api.delete('${ApiConfig.plantCareDates}/$id');
    _syncLocalNotifications();
  }

  static Future<List<UserPlantDto>> getUserPlants() async {
    final response = await _api.get(ApiConfig.userPlants);
    if (response['success'] != true) return const [];
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(UserPlantDto.fromJson)
        .toList();
  }

  static Future<UserPlantLimitsDto> getUserPlantLimits() async {
    final response = await _api.get(ApiConfig.userPlantLimits);
    if (response['success'] != true) {
      return UserPlantLimitsDto(
        currentCount: 0,
        maxPlants: 1,
        canAdd: true,
        upgradeRequired: false,
        message: null,
      );
    }
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return UserPlantLimitsDto.fromJson(data);
  }

  static Future<UserPlantDto> createUserPlant({
    int? productId,
    String? plantName,
    String? customName,
    String? photoUrl,
    String? wateringRequirement,
    int? wateringFrequencyDays,
    int? soilChangeFrequencyDays,
    DateTime? lastWateredAt,
    DateTime? lastSoilChangeAt,
    String? notes,
  }) async {
    final response = await _api.post(
      ApiConfig.userPlants,
      body: {
        if (productId != null) 'product_id': productId,
        if (plantName != null) 'plant_name': plantName,
        if (customName != null) 'custom_name': customName,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (wateringRequirement != null)
          'watering_requirement': wateringRequirement,
        if (wateringFrequencyDays != null)
          'watering_frequency_days': wateringFrequencyDays,
        if (soilChangeFrequencyDays != null)
          'soil_change_frequency_days': soilChangeFrequencyDays,
        if (lastWateredAt != null) 'last_watered_at': _dateOnly(lastWateredAt),
        if (lastSoilChangeAt != null)
          'last_soil_change_at': _dateOnly(lastSoilChangeAt),
        if (notes != null) 'notes': notes,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final result = UserPlantDto.fromJson(data);
    _syncLocalNotifications();
    return result;
  }

  static Future<UserPlantDto> updateUserPlant({
    required int id,
    int? productId,
    String? plantName,
    String? customName,
    String? photoUrl,
    String? wateringRequirement,
    int? wateringFrequencyDays,
    int? soilChangeFrequencyDays,
    DateTime? lastWateredAt,
    DateTime? lastSoilChangeAt,
    String? notes,
  }) async {
    final response = await _api.put(
      ApiConfig.userPlantById(id),
      body: {
        if (productId != null) 'product_id': productId,
        if (plantName != null) 'plant_name': plantName,
        if (customName != null) 'custom_name': customName,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (wateringRequirement != null)
          'watering_requirement': wateringRequirement,
        if (wateringFrequencyDays != null)
          'watering_frequency_days': wateringFrequencyDays,
        if (soilChangeFrequencyDays != null)
          'soil_change_frequency_days': soilChangeFrequencyDays,
        if (lastWateredAt != null) 'last_watered_at': _dateOnly(lastWateredAt),
        if (lastSoilChangeAt != null)
          'last_soil_change_at': _dateOnly(lastSoilChangeAt),
        if (notes != null) 'notes': notes,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final result = UserPlantDto.fromJson(data);
    _syncLocalNotifications();
    return result;
  }

  static Future<void> deleteUserPlant(int id) async {
    await _api.delete(ApiConfig.userPlantById(id));
    _syncLocalNotifications();
  }

  static Future<UserPlantDto> uploadUserPlantPhoto({
    required int id,
    required File file,
  }) async {
    final response = await _api.postMultipart(
      ApiConfig.userPlantPhoto(id),
      file: file,
      fieldName: 'file',
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return UserPlantDto.fromJson(data);
  }

  static Future<UserPlantCareMarkDto> markUserPlantCare({
    required int id,
    required String careType,
    DateTime? careDate,
    String? notes,
  }) async {
    final response = await _api.post(
      ApiConfig.userPlantCare(id),
      body: {
        'care_type': careType,
        if (careDate != null) 'care_date': _dateOnly(careDate),
        if (notes != null) 'notes': notes,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final result = UserPlantCareMarkDto.fromJson(data);
    _syncLocalNotifications();
    return result;
  }

  static Future<OrganizationsResponse> getOrganizations() async {
    final response = await _api.get(ApiConfig.companyCalendarOrganizations);
    if (response['success'] != true) {
      return OrganizationsResponse(canUseCorporate: false, items: const []);
    }
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return OrganizationsResponse(
      canUseCorporate: data['can_use_corporate'] == true,
      items: items
          .whereType<Map<String, dynamic>>()
          .map(OrganizationDto.fromJson)
          .toList(),
    );
  }

  static Future<List<CompanyCalendarEventDto>> getCompanyEvents(
    int companyId,
  ) async {
    final url = '${ApiConfig.companyCalendarEvents}?company_id=$companyId';
    final response = await _api.get(url);
    if (response['success'] != true) return const [];
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(CompanyCalendarEventDto.fromJson)
        .toList();
  }

  static Future<CompanyCalendarEventDto> createCompanyEvent({
    required int companyId,
    required String title,
    required DateTime date,
    String? comment,
  }) async {
    final response = await _api.post(
      ApiConfig.companyCalendarEvents,
      body: {
        'company_id': companyId,
        'title': title,
        'event_date': _dateOnly(date),
        'comment': comment,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return CompanyCalendarEventDto.fromJson(data);
  }

  static Future<void> deleteCompanyEvent(int id) async {
    await _api.delete('${ApiConfig.companyCalendarEvents}/$id');
  }

  static Future<CompanyCalendarEventDto> updateCompanyEvent({
    required int id,
    String? title,
    DateTime? date,
    String? comment,
  }) async {
    final response = await _api.put(
      '${ApiConfig.companyCalendarEvents}/$id',
      body: {
        if (title != null) 'title': title,
        if (date != null) 'event_date': _dateOnly(date),
        if (comment != null) 'comment': comment,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return CompanyCalendarEventDto.fromJson(data);
  }

  static Future<List<CompanyCalendarEventPreferenceDto>>
  getCompanyEventPreferences(int eventId) async {
    final response = await _api.get(
      ApiConfig.companyCalendarPreferences(eventId),
    );
    if (response['success'] != true) return const [];
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(CompanyCalendarEventPreferenceDto.fromJson)
        .toList();
  }

  static Future<CompanyCalendarEventPreferenceDto>
  createCompanyEventPreference({
    required int eventId,
    int? categoryId,
    int? productId,
  }) async {
    final response = await _api.post(
      ApiConfig.companyCalendarPreferences(eventId),
      body: {
        if (categoryId != null) 'category_id': categoryId,
        if (productId != null) 'product_id': productId,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final pref = data['preference'] as Map<String, dynamic>? ?? const {};
    return CompanyCalendarEventPreferenceDto.fromJson(pref);
  }

  static Future<void> deleteCompanyEventPreference(int preferenceId) async {
    await _api.delete(ApiConfig.companyCalendarPreferenceById(preferenceId));
  }

  static Future<HolidayPreferenceOptionsResponse>
  getCompanyEventPreferenceOptions() async {
    final response = await _api.get(ApiConfig.companyCalendarPreferenceOptions);
    if (response['success'] != true) {
      return HolidayPreferenceOptionsResponse(
        categories: const [],
        products: const [],
      );
    }
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final categories = (data['categories'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HolidayPreferenceOptionDto.fromJson)
        .toList();
    final products = (data['products'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HolidayPreferenceOptionDto.fromJson)
        .toList();
    return HolidayPreferenceOptionsResponse(
      categories: categories,
      products: products,
    );
  }

  static Future<List<HolidayPreferenceDto>> getHolidayPreferences({
    String? holidayCode,
  }) async {
    final url = holidayCode == null || holidayCode.trim().isEmpty
        ? ApiConfig.holidayPreferences
        : '${ApiConfig.holidayPreferences}?holiday_code=$holidayCode';
    final response = await _api.get(url);
    if (response['success'] != true) return const [];
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(HolidayPreferenceDto.fromJson)
        .toList();
  }

  static Future<HolidayPreferenceDto> createHolidayPreference({
    required String holidayCode,
    int? categoryId,
    int? productId,
  }) async {
    final response = await _api.post(
      ApiConfig.holidayPreferences,
      body: {
        'holiday_code': holidayCode,
        if (categoryId != null) 'category_id': categoryId,
        if (productId != null) 'product_id': productId,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return HolidayPreferenceDto.fromJson(data);
  }

  static Future<void> deleteHolidayPreference(int id) async {
    await _api.delete('${ApiConfig.holidayPreferences}/$id');
  }

  static Future<HolidayPreferenceOptionsResponse>
  getHolidayPreferenceOptions() async {
    final response = await _api.get(ApiConfig.holidayPreferenceOptions);
    if (response['success'] != true) {
      return HolidayPreferenceOptionsResponse(
        categories: const [],
        products: const [],
      );
    }
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final categories = (data['categories'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HolidayPreferenceOptionDto.fromJson)
        .toList();
    final products = (data['products'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HolidayPreferenceOptionDto.fromJson)
        .toList();
    return HolidayPreferenceOptionsResponse(
      categories: categories,
      products: products,
    );
  }

  static Future<List<ImportantDatePreferenceDto>> getImportantDatePreferences(
    int importantDateId,
  ) async {
    final response = await _api.get(
      ApiConfig.importantDatePreferences(importantDateId),
    );
    if (response['success'] != true) return const [];
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ImportantDatePreferenceDto.fromJson)
        .toList();
  }

  static Future<ImportantDatePreferenceDto> createImportantDatePreference({
    required int importantDateId,
    int? categoryId,
    int? productId,
  }) async {
    final response = await _api.post(
      ApiConfig.importantDatePreferences(importantDateId),
      body: {
        if (categoryId != null) 'category_id': categoryId,
        if (productId != null) 'product_id': productId,
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final pref = data['preference'] as Map<String, dynamic>? ?? const {};
    return ImportantDatePreferenceDto.fromJson(pref);
  }

  static Future<void> deleteImportantDatePreference(int preferenceId) async {
    await _api.delete(ApiConfig.importantDatePreferenceById(preferenceId));
  }

  static Future<HolidayPreferenceOptionsResponse>
  getImportantDatePreferenceOptions() async {
    final response = await _api.get(ApiConfig.importantDatePreferencesOptions);
    if (response['success'] != true) {
      return HolidayPreferenceOptionsResponse(
        categories: const [],
        products: const [],
      );
    }
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final categories = (data['categories'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HolidayPreferenceOptionDto.fromJson)
        .toList();
    final products = (data['products'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HolidayPreferenceOptionDto.fromJson)
        .toList();
    return HolidayPreferenceOptionsResponse(
      categories: categories,
      products: products,
    );
  }
}
