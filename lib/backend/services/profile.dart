import 'package:flutter/foundation.dart';
import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/auth.dart';
import 'package:azalia/backend/services/session.dart';

class ProfileService {
  static final ApiClient _api = ApiClient();

  /// Обновление профиля пользователя
  static Future<UpdateProfileResponse> updateProfile({
    required String name,
    required String phone,
  }) async {
    try {
      if (name.trim().isEmpty) {
        debugPrint('ProfileService: Пустое имя');
        throw ProfileException(message: 'Имя не может быть пустым');
      }

      if (phone.trim().isEmpty) {
        debugPrint('ProfileService: Пустой телефон');
        throw ProfileException(message: 'Телефон не может быть пустым');
      }

      final session = SessionService();
      final token = await session.getToken();
      
      if (token == null || token.isEmpty) {
        throw ProfileException(message: 'Сессия недействительна');
      }

      final response = await _api.post(
        ApiConfig.updateProfile,
        body: {
          'session_token': token,
          'name': name.trim(),
          'phone': phone.trim(),
        },
      );

      if (response['success'] == true) {
        debugPrint('ProfileService: Профиль успешно обновлен');
        return UpdateProfileResponse.fromJson(response);
      } else {
        debugPrint('ProfileService: Ошибка обновления профиля');
        throw ProfileException(
          message: response['error'] ?? response['message'] ?? 'Не удалось обновить профиль',
          statusCode: 400,
        );
      }
    } on ApiException catch (e) {
      debugPrint('ProfileService: Ошибка API - $e');
      throw ProfileException(
        message: e.message,
        statusCode: e.statusCode,
      );
    } on ProfileException {
      rethrow;
    } catch (e) {
      debugPrint('ProfileService: Исключение - $e');
      throw ProfileException(message: 'Не удалось обновить профиль');
    }
  }

  /// Валидация имени
  static bool validateName(String name) {
    return name.trim().isNotEmpty;
  }

  /// Валидация телефона
  static bool validatePhone(String phone) {
    return phone.trim().isNotEmpty;
  }
}

class UpdateProfileResponse {
  final bool success;
  final String message;
  final User user;

  UpdateProfileResponse({
    required this.success,
    required this.message,
    required this.user,
  });

  factory UpdateProfileResponse.fromJson(Map<String, dynamic> json) {
    return UpdateProfileResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      user: User.fromJson(json['user']),
    );
  }
}

class ProfileException implements Exception {
  final String message;
  final int? statusCode;

  ProfileException({required this.message, this.statusCode});

  @override
  String toString() => 'ProfileException: $message';
}
