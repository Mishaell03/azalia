import 'package:azalia/backend/apiClient.dart';
import 'package:azalia/backend/api_config.dart';
import 'package:azalia/backend/models/auth.dart';
import 'package:azalia/backend/services/device_id.dart';
import 'package:azalia/backend/services/session.dart';

class AuthService {
  static final ApiClient _api = ApiClient();

  /// Верификация кода авторизации
  static Future<AuthResponse> verifyCode(String code) async {
    try {
      final deviceId = await DeviceService.getDeviceId();
      final cleanDeviceId = deviceId.replaceAll('.', '_');

      final response = await _api.post(
        ApiConfig.authVerify,
        body: {
          'code': code,
          'device_id': cleanDeviceId,
        },
      );

      final authResponse = AuthResponse.fromJson(response);

      final token =
          authResponse.user.sessionToken ?? _generateTempToken();

      await SessionService().saveSession(
        user: authResponse.user,
        token: token,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        isEmployee: authResponse.isEmployee,
        position: authResponse.position,
      );

      return authResponse;
    } on ApiException catch (e) {
      throw AuthException(
        message: e.message,
        statusCode: e.statusCode,
      );
    } catch (e) {
      throw AuthException(
        message: 'Ошибка авторизации: $e',
      );
    }
  }

  /// Проверка статуса кода авторизации
  static Future<CodeStatusResponse> checkCodeStatus(String code) async {
    try {
      final response = await _api.get(ApiConfig.authCheckStatus(code));
      return CodeStatusResponse.fromJson(response);
    } on ApiException catch (e) {
      throw AuthException(
        message: e.message,
        statusCode: e.statusCode,
      );
    } catch (e) {
      throw AuthException(
        message: 'Ошибка проверки кода: $e',
      );
    }
  }

  /// Получение текущего пользователя (обновление сессии)
  static Future<AuthResponse> fetchMe() async {
    try {
      final session = SessionService();
      
      if (!session.isLoggedIn || !session.isTokenValid) {
        throw AuthException(
          message: 'Сессия недействительна',
          statusCode: 401,
        );
      }

      final token = await session.getToken();
      if (token == null || token.isEmpty) {
        throw AuthException(
          message: 'Сессия недействительна',
          statusCode: 401,
        );
      }

      // Используем GET или POST без body, токен в заголовке Authorization
      final response = await _api.get(ApiConfig.authMe);

      final authResponse = AuthResponse.fromJson(response);

      final sessionToken = token;

      await session.saveSession(
        user: authResponse.user,
        token: sessionToken,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        isEmployee: authResponse.isEmployee,
        position: authResponse.position,
      );

      return authResponse;
    } on UnauthorizedException {
      throw AuthException(
        message: 'Сессия недействительна',
        statusCode: 401,
      );
    } on ApiException catch (e) {
      throw AuthException(
        message: e.message,
        statusCode: e.statusCode,
      );
    } catch (e) {
      throw AuthException(
        message: 'Ошибка обновления профиля: $e',
      );
    }
  }

  /// Валидация формата кода
  static bool validateCodeFormat(String code) {
    return RegExp(r'^\d{4}$').hasMatch(code);
  }

  /// Проверка истечения кода
  static bool isCodeExpired(String? expiresAt) {
    if (expiresAt == null) return true;

    try {
      return DateTime.parse(expiresAt).isBefore(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  /// Генерация временного токена
  static String _generateTempToken() {
    return 'temp_${DateTime.now().millisecondsSinceEpoch}';
  }
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException({
    required this.message,
    this.statusCode,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'AuthException ($statusCode): $message';
    }
    return 'AuthException: $message';
  }
}
