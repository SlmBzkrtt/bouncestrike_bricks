import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Centralized production logging service.
///
/// In release mode, standard debug logs are suppressed to prevent reverse-engineering
/// leakage and conserve CPU cycles. Warning and error logs are preserved for diagnostics.
abstract final class AppLogger {
  static void info(String message, [String tag = 'BounceStrike']) {
    if (kReleaseMode) return;
    developer.log('📘 [INFO] $message', name: tag);
  }

  static void warning(String message, [String tag = 'BounceStrike']) {
    developer.log('⚠️ [WARN] $message', name: tag);
  }

  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    String tag = 'BounceStrike',
  ]) {
    developer.log(
      '🚨 [ERROR] $message',
      name: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
