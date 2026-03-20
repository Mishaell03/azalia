import 'dart:io';
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
        body: {'name': name.trim(), 'phone': phone.trim()},
      );

      if (response['success'] == true) {
        debugPrint('ProfileService: Профиль успешно обновлен');
        return UpdateProfileResponse.fromJson(response);
      } else {
        debugPrint('ProfileService: Ошибка обновления профиля');
        throw ProfileException(
          message: 'Не удалось обновить профиль',
          statusCode: 400,
        );
      }
    } on ApiException catch (e) {
      debugPrint('ProfileService: Ошибка API - $e');
      throw ProfileException(
        message: 'Не удалось обновить профиль',
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

  /// Загрузка аватарки
  static Future<UploadAvatarResponse> uploadAvatar(File imageFile) async {
    try {
      final session = SessionService();
      final token = await session.getToken();

      if (token == null || token.isEmpty) {
        throw ProfileException(message: 'Сессия недействительна');
      }

      final response = await _api.postMultipart(
        ApiConfig.avatar,
        file: imageFile,
        fieldName: 'avatar',
      );

      if (response['success'] == true) {
        debugPrint('ProfileService: Аватарка успешно загружена');
        return UploadAvatarResponse.fromJson(response);
      } else {
        debugPrint('ProfileService: Ошибка загрузки аватарки');
        throw ProfileException(
          message: 'Не удалось загрузить аватарку',
          statusCode: 400,
        );
      }
    } on ApiException catch (e) {
      debugPrint('ProfileService: Ошибка API - $e');
      throw ProfileException(
        message: 'Не удалось загрузить аватарку',
        statusCode: e.statusCode,
      );
    } on ProfileException {
      rethrow;
    } catch (e) {
      debugPrint('ProfileService: Исключение - $e');
      throw ProfileException(message: 'Не удалось загрузить аватарку');
    }
  }

  /// Получение аватарки
  static Future<String?> getAvatar() async {
    try {
      final session = SessionService();
      final token = await session.getToken();

      if (token == null || token.isEmpty) {
        throw ProfileException(message: 'Сессия недействительна');
      }

      final response = await _api.get(ApiConfig.avatar);

      if (response['success'] == true) {
        debugPrint('ProfileService: Аватарка успешно получена');
        return response['avatar'] as String? ??
            response['avatar_url'] as String?;
      } else {
        debugPrint('ProfileService: Аватарка не найдена');
        return null;
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // Аватарка не найдена - это нормально
        return null;
      }
      debugPrint('ProfileService: Ошибка API - $e');
      throw ProfileException(
        message: 'Не удалось получить аватарку',
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('ProfileService: Исключение - $e');
      return null;
    }
  }
}

class UploadAvatarResponse {
  final bool success;
  final String message;
  final String? avatar; // base64

  UploadAvatarResponse({
    required this.success,
    required this.message,
    this.avatar,
  });

  factory UploadAvatarResponse.fromJson(Map<String, dynamic> json) {
    return UploadAvatarResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      avatar: json['avatar'] ?? json['avatar_url'],
    );
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
