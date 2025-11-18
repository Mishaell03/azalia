import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:azalia/backend/models/auth.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  static const String _keyUser = 'session_user';
  static const String _keyToken = 'session_token';
  static const String _keyExpiresAt = 'session_expires_at';
  static const String _keyIsEmployee = 'session_is_employee';
  static const String _keyPosition = 'session_position';

  User? _currentUser;
  String? _sessionToken;
  DateTime? _tokenExpiresAt;
  bool _isEmployee = false;
  Position? _currentPosition;

  User? get currentUser => _currentUser;
  String? get sessionToken => _sessionToken;
  bool get isLoggedIn => _currentUser != null && _sessionToken != null;
  bool get isEmployee => _isEmployee;
  Position? get currentPosition => _currentPosition;
  bool get isTokenValid => _tokenExpiresAt != null && 
      _tokenExpiresAt!.isAfter(DateTime.now());

  Future<void> initialize() async {
    await _loadSessionFromStorage();
  }

  Future<void> saveSession({
    required User user,
    required String token,
    required DateTime expiresAt,
    bool isEmployee = false,
    Position? position,
  }) async {
    _currentUser = user;
    _sessionToken = token;
    _tokenExpiresAt = expiresAt;
    _isEmployee = isEmployee;
    _currentPosition = position;

    await _saveSessionToStorage();
  }

  Future<void> clearSession() async {
    _currentUser = null;
    _sessionToken = null;
    _tokenExpiresAt = null;
    _isEmployee = false;
    _currentPosition = null;

    await _clearStorage();
  }

  Future<void> refreshSession({
    String? newToken,
    DateTime? newExpiresAt,
  }) async {
    if (newToken != null) {
      _sessionToken = newToken;
    }
    if (newExpiresAt != null) {
      _tokenExpiresAt = newExpiresAt;
    }

    await _saveSessionToStorage();
  }

  Map<String, String> getAuthHeaders() {
    if (!isLoggedIn || !isTokenValid) {
      return {};
    }

    return {
      'Authorization': 'Bearer $_sessionToken',
      'X-User-ID': _currentUser!.id.toString(),
      'X-Telegram-ID': _currentUser!.telegramId.toString(),
    };
  }

  Future<void> _loadSessionFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final userJson = prefs.getString(_keyUser);
      if (userJson != null) {
        final userMap = Map<String, dynamic>.from(json.decode(userJson));
        _currentUser = User.fromJson(userMap);
      }

      _sessionToken = prefs.getString(_keyToken);
      
      final expiresAtString = prefs.getString(_keyExpiresAt);
      if (expiresAtString != null) {
        _tokenExpiresAt = DateTime.parse(expiresAtString);
      }

      _isEmployee = prefs.getBool(_keyIsEmployee) ?? false;

      final positionJson = prefs.getString(_keyPosition);
      if (positionJson != null) {
        final positionMap = Map<String, dynamic>.from(json.decode(positionJson));
        _currentPosition = Position.fromJson(positionMap);
      }
    } catch (e) {
      await clearSession();
    }
  }

  Future<void> _saveSessionToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_currentUser != null) {
        final userJson = json.encode(_currentUser!.toJson());
        await prefs.setString(_keyUser, userJson);
      }

      if (_sessionToken != null) {
        await prefs.setString(_keyToken, _sessionToken!);
      }

      if (_tokenExpiresAt != null) {
        await prefs.setString(_keyExpiresAt, _tokenExpiresAt!.toIso8601String());
      }

      await prefs.setBool(_keyIsEmployee, _isEmployee);

      if (_currentPosition != null) {
        final positionJson = json.encode(_currentPosition!.toJson());
        await prefs.setString(_keyPosition, positionJson);
      }
    } catch (e) {
      // Ошибка сохранения сессии
    }
  }

  Future<void> _clearStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUser);
      await prefs.remove(_keyToken);
      await prefs.remove(_keyExpiresAt);
      await prefs.remove(_keyIsEmployee);
      await prefs.remove(_keyPosition);
    } catch (e) {
      // Ошибка очистки хранилища
    }
  }
  Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('session_token');
}
}
