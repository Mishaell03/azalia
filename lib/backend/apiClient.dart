import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:azalia/backend/services/session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException(status: $statusCode, message: $message)';
}

/// Спец исключение для 401
class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(message, 401);
}

/// Клиент для HTTP-запросов, автоматически подставляет заголовки авторизации
class ApiClient {
  final SessionService _session = SessionService();

  ApiClient();

  /// Формируем заголовки для запроса, берём токен из SessionService
  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};

    try {
      final auth = _session.getAuthHeaders();
      headers.addAll(auth);
    } catch (e) {
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
      debugPrint('ApiException get error: $e');
      throw 'Ошибка сети';
    }
  }

  /// POST (body nullable)
  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(url);
    try {
      debugPrint('ApiClient: POST к $uri');
      final response = await http.post(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 10));
      _log('POST', uri, response, body: body);
      return _handleResponse(response);
    } on TimeoutException {
      debugPrint('ApiClient: Timeout при POST $uri');
      throw ApiException('Timeout - сервер не отвечает', 0);
    } on SocketException catch (e) {
      debugPrint('ApiClient: SocketException при POST $uri: $e');
      throw ApiException('Не удалось подключиться к серверу: $e', 0);
    } catch (e) {
      debugPrint('ApiClient: Неожиданная ошибка при POST $uri: $e');
      throw ApiException('Ошибка сети: $e', 0);
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
      debugPrint('ApiException put error: $e');
      throw 'Ошибка сети';
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
      debugPrint('ApiException delete error: $e');
      throw 'Ошибка сети';
    }
  }

  /// Загрузка файлов
  Future<Map<String, dynamic>> postMultipart(
    String url, {
    required File file,
    required String fieldName,
  }) async {
    final uri = Uri.parse(url);
    try {
      final request = http.MultipartRequest('POST', uri);

      // Добавляем заголовки авторизации
      final authHeaders = _session.getAuthHeaders();
      request.headers.addAll(authHeaders);

      // Добавляем файл
      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();
      final multipartFile = http.MultipartFile(
        fieldName,
        fileStream,
        fileLength,
        filename: file.path.split('/').last,
      );
      request.files.add(multipartFile);

      // Отправляем запрос
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      _log('POST (multipart)', uri, response);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('ApiException postMultipart error: $e');
      throw 'Ошибка сети';
    }
  }

  /// Обработка ответа: декодируем JSON или выводим исключение
  Map<String, dynamic> _handleResponse(http.Response response) {
    final status = response.statusCode;

    // Пустое тело
    final body = response.body.trim();
    final bool hasBody = body.isNotEmpty;

    Map<String, dynamic> decoded = {};
    if (hasBody) {
      try {
        final parsed = jsonDecode(body);
        if (parsed is Map<String, dynamic>) {
          decoded = parsed;
        } else {
          decoded = {'data': parsed};
        }
      } catch (e) {
        throw 'Ошибка обработки ответа';
      }
    }

    if (status == 401) {
      throw 'Не авторизован';
    }

    if (status >= 400) {
      String message = 'Ошибка сети';
      if (status == 404) {
        message = 'Ресурс не найден';
      } else if (status == 500) {
        message = 'Ошибка сервера';
      }
      throw ApiException(message, status);
    }

    return decoded;
  }

  /// Логирование запросов для выявления ошибок
  void _log(
    String method,
    Uri url,
    http.Response response, {
    Map<String, dynamic>? body,
  }) {
    debugPrint('=== $method $url ===');
    // final tokenPresent = _session.sessionToken != null ? 'yes' : 'no';
    // if (body != null) debugPrint('BODY: $body');
    // debugPrint('TOKEN_PRESENT: $tokenPresent');
    // debugPrint('STATUS: ${response.statusCode}');
    // debugPrint('RESPONSE: ${response.body}');
    // для отладки
    // debugPrint('TOKEN_VALUE: ${_session.sessionToken}');
    // debugPrint('HEADERS: ${_headers.toString()}');
  }
}
