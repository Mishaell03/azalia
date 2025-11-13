import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/auth.dart';

class AuthService {
  static Future<AuthResponse> verifyCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.authVerify),
        headers: ApiConfig.headers,
        body: json.encode({'code': code}),
      ).timeout(ApiConfig.timeout);

      if (ApiConfig.enableLogging) {
        print('Auth Verify - Status: ${response.statusCode}');
        print('Auth Verify - Response: ${response.body}');
      }

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(responseData);
      } else {
        throw AuthException(
          message: responseData['error'] ?? 'Verification failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (ApiConfig.enableLogging) {
        print('Auth Verify - Error: $e');
      }
      throw AuthException(message: 'Network error: $e');
    }
  }

  static Future<CodeStatusResponse> checkCodeStatus(String code) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.authCheckStatus(code)),
        headers: ApiConfig.headers,
      ).timeout(ApiConfig.timeout);

      if (ApiConfig.enableLogging) {
        print('Check Status - Status: ${response.statusCode}');
        print('Check Status - Response: ${response.body}');
      }

      final Map<String, dynamic> responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return CodeStatusResponse.fromJson(responseData);
      } else {
        throw AuthException(
          message: responseData['error'] ?? 'Status check failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (ApiConfig.enableLogging) {
        print('Check Status - Error: $e');
      }
      throw AuthException(message: 'Network error: $e');
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
  String toString() {
    return statusCode != null 
        ? 'AuthException: $message (Status: $statusCode)'
        : 'AuthException: $message';
  }
}