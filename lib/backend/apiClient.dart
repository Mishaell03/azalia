import 'dart:convert';
import 'package:azalia/backend/services/session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Базный API-исключение
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException(status: $statusCode, message: $message)';
}

/// Специальное исключение для 401
class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(message, 401);
}

/// Клиент для HTTP-запросов, автоматически подставляет заголовки авторизации
class ApiClient {
  final SessionService _session = SessionService();

  ApiClient();

  /// Формируем заголовки для запроса, берём авторизацию из SessionService
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    try {
      final auth = _session.getAuthHeaders();
      // getAuthHeaders() по коду возвращает пустой map если токен не валиден
      headers.addAll(auth);
    } catch (e) {
      // Если по какой-то причине session не готов — пропускаем
      debugPrint('ApiClient: warning while reading session headers: $e');
    }

    return headers;
  }

  /// GET
  Future<Map<String, dynamic>> get(String url) async {
    final uri = Uri.parse(url);
    try {
      final response = await http.get(uri, headers: _headers);
      _log('GET', uri, response);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// POST (body nullable)
  Future<Map<String, dynamic>> post(
      String url, {
        Map<String, dynamic>? body,
      }) async {
    final uri = Uri.parse(url);
    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      _log('POST', uri, response, body: body);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }


  /// PUT (body nullable)
  Future<Map<String, dynamic>> put(
      String url, {
        Map<String, dynamic>? body,
      }) async {
    final uri = Uri.parse(url);
    try {
      final response = await http.put(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      _log('PUT', uri, response, body: body);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// DELETE (body nullable)
  Future<Map<String, dynamic>> delete(
      String url, {
        Map<String, dynamic>? body,
      }) async {
    final uri = Uri.parse(url);
    try {
      final response = await http.delete(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      _log('DELETE', uri, response, body: body);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// Обработка ответа: декодируем JSON или бросаем понятное исключение
  Map<String, dynamic> _handleResponse(http.Response response) {
    final status = response.statusCode;

    // Пустое тело (204 No Content и т.п.)
    final body = response.body.trim();
    final bool hasBody = body.isNotEmpty;

    Map<String, dynamic> decoded = {};
    if (hasBody) {
      try {
        final parsed = jsonDecode(body);
        if (parsed is Map<String, dynamic>) {
          decoded = parsed;
        } else {
          // Если сервер вернул не map (например, список), оборачиваем в поле data
          decoded = {'data': parsed};
        }
      } catch (e) {
        // Некорректный JSON
        throw ApiException('Invalid JSON response', status);
      }
    }

    if (status == 401) {
      // Специально обрабатываем 401
      final message = (decoded['error'] ?? 'Unauthorized').toString();
      throw UnauthorizedException(message);
    }

    if (status >= 400) {
      final message = (decoded['error'] ?? 'HTTP $status').toString();
      throw ApiException(message, status);
    }

    return decoded;
  }

  /// Логирование запросов (без явного вывода токена, но отмечаем его наличие)
  void _log(
      String method,
      Uri url,
      http.Response response, {
        Map<String, dynamic>? body,
      }) {
    final tokenPresent = _session.sessionToken != null ? 'yes' : 'no';
    debugPrint('=== $method $url ===');
    if (body != null) debugPrint('BODY: $body');
    debugPrint('TOKEN_PRESENT: $tokenPresent');
    debugPrint('STATUS: ${response.statusCode}');
    debugPrint('RESPONSE: ${response.body}');
    // debugPrint('TOKEN_VALUE: ${_session.sessionToken}');
    // debugPrint('HEADERS: ${_headers.toString()}');
  }
}
