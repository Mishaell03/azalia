import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/auth.dart';
import 'package:azalia/backend/services/session.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  static Future<UpdateProfileResponse> updateProfile({
    required String name,
    required String phone,
  }) async {
    try {
      final session = SessionService();
      final token = await session.getToken();
      
      if (token == null || token.isEmpty) {
        throw ProfileException(message: 'Сессия недействительна');
      }

      if (name.trim().isEmpty) {
        throw ProfileException(message: 'Имя не может быть пустым');
      }

      if (phone.trim().isEmpty) {
        throw ProfileException(message: 'Телефон не может быть пустым');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseURL}/auth/update_profile'),
        headers: ApiConfig.headers,
        body: json.encode({
          'session_token': token,
          'name': name.trim(),
          'phone': phone.trim(),
        }),
      ).timeout(ApiConfig.timeout);

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return UpdateProfileResponse.fromJson(responseData);
      } else {
        throw ProfileException(
          message: responseData['error'] ?? 'Не удалось обновить профиль',
          statusCode: response.statusCode,
        );
      }
    } on http.ClientException catch (e) {
      throw ProfileException(message: 'Ошибка соединения');
    } on ProfileException {
      rethrow;
    } catch (e) {
      throw ProfileException(message: 'Не удалось обновить профиль');
    }
  }

  static bool validateName(String name) {
    return name.trim().isNotEmpty;
  }

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