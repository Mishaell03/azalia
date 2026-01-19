import 'dart:convert';
import 'package:azalia/backend/services/session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  final SessionService _session = SessionService();

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    final token = _session.sessionToken;

    if (token != null && _session.isTokenValid) {
      headers['Authorization'] = token;
    }

    return headers;
  }

  Future<Map<String, dynamic>> get(String url) async {
    final uri = Uri.parse(url);

    try {
      final response = await http.get(uri, headers: _headers);
      _log('GET', uri, response);
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> post(
      String url, {
        Map<String, dynamic>? body,
      }) async {
    final uri = Uri.parse(url);

    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      );

      _log('POST', uri, response, body: body);
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 401) {
      throw Exception('Unauthorized (token expired or invalid)');
    }

    if (response.statusCode >= 400) {
      throw Exception(
        decoded['error'] ?? 'HTTP ${response.statusCode}',
      );
    }

    return decoded;
  }

  void _log(
      String method,
      Uri url,
      http.Response response, {
        Map<String, dynamic>? body,
      }) {
    debugPrint('=== $method $url ===');
    if (body != null) debugPrint('BODY: $body');
    debugPrint('STATUS: ${response.statusCode}');
    debugPrint('RESPONSE: ${response.body}');
  }
}
