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

/// Спец исключение для 403 (заблокирован/удален аккаунт)
class ForbiddenAccountException extends ApiException {
  final String? accountStatus;
  final String? imagePath;

  ForbiddenAccountException(
    String message, {
    this.accountStatus,
    this.imagePath,
  }) : super(message, 403);
}

/// Клиент для HTTP-запросов, автоматически подставляет заголовки авторизации
class ApiClient {
  final SessionService _session = SessionService();
  static const Duration _requestTimeout = Duration(seconds: 10);

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
    return _request('GET', url);
  }

  /// POST (body nullable)
  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    return _request('POST', url, body: body);
  }

  /// PUT (body nullable)
  Future<Map<String, dynamic>> put(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    return _request('PUT', url, body: body);
  }

  /// PATCH (body nullable)
  Future<Map<String, dynamic>> patch(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    return _request('PATCH', url, body: body);
  }

  /// DELETE (body nullable)
  Future<Map<String, dynamic>> delete(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    return _request('DELETE', url, body: body);
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
      final streamedResponse = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      _log('POST (multipart)', uri, response);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Timeout - сервер не отвечает', 0);
    } on SocketException catch (e) {
      throw ApiException('Не удалось подключиться к серверу: $e', 0);
    } catch (e) {
      throw ApiException('Ошибка сети: $e', 0);
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(url);
    try {
      final response = await _sendRequest(
        method,
        uri,
        body: body,
      ).timeout(_requestTimeout);
      _log(method, uri, response, body: body);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Timeout - сервер не отвечает', 0);
    } on SocketException catch (e) {
      throw ApiException('Не удалось подключиться к серверу: $e', 0);
    } catch (e) {
      throw ApiException('Ошибка сети: $e', 0);
    }
  }

  Future<http.Response> _sendRequest(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) {
    final encodedBody = body != null ? jsonEncode(body) : null;
    switch (method) {
      case 'GET':
        return http.get(uri, headers: _headers);
      case 'POST':
        return http.post(uri, headers: _headers, body: encodedBody);
      case 'PUT':
        return http.put(uri, headers: _headers, body: encodedBody);
      case 'PATCH':
        return http.patch(uri, headers: _headers, body: encodedBody);
      case 'DELETE':
        return http.delete(uri, headers: _headers, body: encodedBody);
      default:
        throw ApiException('Неподдерживаемый HTTP-метод: $method');
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
        throw ApiException('Ошибка обработки ответа', status);
      }
    }

    if (status == 401) {
      throw UnauthorizedException(
        _extractErrorMessage(decoded) ?? 'Не авторизован',
      );
    }

    if (status == 403) {
      final detail = decoded['detail'];
      String message = 'Аккаунт деактивирован или удален';
      String? accountStatus;
      String? imagePath;

      if (detail is Map<String, dynamic>) {
        final detailMessage = detail['message']?.toString();
        if (detailMessage != null && detailMessage.isNotEmpty) {
          message = detailMessage;
        }
        accountStatus = detail['status']?.toString();
        imagePath = detail['image']?.toString();
      } else {
        final fallback = _extractErrorMessage(decoded);
        if (fallback != null && fallback.isNotEmpty) {
          message = fallback;
        }
      }

      throw ForbiddenAccountException(
        message,
        accountStatus: accountStatus,
        imagePath: imagePath,
      );
    }

    if (status >= 400) {
      String message =
          _extractErrorMessage(decoded) ?? _defaultErrorMessage(status);
      throw ApiException(message, status);
    }

    return decoded;
  }

  String _defaultErrorMessage(int status) {
    if (status == 404) {
      return 'Ресурс не найден';
    }
    if (status == 422) {
      return 'Ошибка валидации запроса';
    }
    if (status >= 500) {
      return 'Ошибка сервера';
    }
    return 'Ошибка сети';
  }

  String? _extractErrorMessage(Map<String, dynamic> decoded) {
    final detail = decoded['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty) {
      final parts = detail
          .map((item) {
            if (item is Map<String, dynamic>) {
              final loc = item['loc'] is List
                  ? (item['loc'] as List).join('.')
                  : null;
              final msg = item['msg']?.toString();
              if (loc != null && msg != null) {
                return '$loc: $msg';
              }
              return msg ?? item.toString();
            }
            return item.toString();
          })
          .where((part) => part.isNotEmpty)
          .toList();

      if (parts.isNotEmpty) {
        return parts.join('\n');
      }
    }

    for (final key in ['error', 'message']) {
      final value = decoded[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  void _log(
    String method,
    Uri url,
    http.Response response, {
    Map<String, dynamic>? body,
  }) {
    // debugPrint('=== $method $url ===');
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
