import 'package:azalia/backend/services/session.dart';
import 'package:azalia/pages/error/app_errors.dart';
import 'package:flutter/material.dart';

/// Базовый State для экранов, которым нужна единая проверка авторизации.
abstract class AuthGuardedState<T extends StatefulWidget> extends State<T> {
  final SessionService sessionService = SessionService();

  @protected
  bool get hasValidSession =>
      sessionService.isLoggedIn && sessionService.isTokenValid;

  @protected
  bool isUnauthorizedError(Object error) {
    return AppErrors.isUnauthorizedError(error.toString());
  }

  @protected
  bool isForbiddenAccountError(Object error) {
    return AppErrors.isForbiddenAccountError(error.toString());
  }

  @protected
  void safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }
}
