import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/auth.dart'; 
import 'package:azalia/backend/services/device_id.dart';
import 'package:azalia/backend/services/session.dart';

class AuthService {
  static Future<AuthResponse> verifyCode(String code) async {
    try {
      final deviceId = await DeviceService.getDeviceId();
      final cleanDeviceId = deviceId.replaceAll('.', '_');

      final response = await http.post(
        Uri.parse(ApiConfig.authVerify),
        headers: ApiConfig.headers(),
        body: json.encode({
          'code': code,
          'device_id': cleanDeviceId,
        }),
      ).timeout(ApiConfig.timeout);

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(responseData);
        
        final token = authResponse.user.sessionToken ?? _generateTempToken();
        
        await SessionService().saveSession(
          user: authResponse.user,
          token: token,
          expiresAt: DateTime.now().add(Duration(days: 30)),
          isEmployee: authResponse.isEmployee,
          position: authResponse.position,
        );

        return authResponse;
      } else {
        throw AuthException(
          message: 'Что-то пошло не так',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw AuthException(message: 'Что-то пошло не так');
    }
  }

  static String _generateTempToken() {
    return 'temp_token_${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<CodeStatusResponse> checkCodeStatus(String code) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.authCheckStatus(code)),
        headers: ApiConfig.headers(),
      ).timeout(ApiConfig.timeout);

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return CodeStatusResponse.fromJson(responseData);
      } else {
        throw AuthException(
          message: 'Что-то пошло не так',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw AuthException(message: 'Что-то пошло не так');
    }
  }

  static bool validateCodeFormat(String code) {
    return RegExp(r'^\d{4}$').hasMatch(code);
  }

  static bool isCodeExpired(String? expiresAt) {
    if (expiresAt == null) return true;
    
    try {
      final expiryTime = DateTime.parse(expiresAt);
      return expiryTime.isBefore(DateTime.now());
    } catch (e) {
      return true;
    }
  }
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException({required this.message, this.statusCode});

  @override
  String toString() => 'AuthException: $message';
}