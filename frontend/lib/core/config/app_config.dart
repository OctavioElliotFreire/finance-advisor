import 'package:flutter/foundation.dart';

/// Compile-time configuration, supplied via `--dart-define-from-file=.env`
/// (copy `.env.example` to `.env` and fill in real values — never commit `.env`).
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Falls back to platform-appropriate localhost addresses (see PLAN.md
  /// "Local API Addresses") when API_BASE_URL isn't supplied at build time.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }
}
