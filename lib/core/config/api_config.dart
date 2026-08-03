/// Values come from `--dart-define-from-file=env/<env>.json` (see
/// `env/dev.json.example` / `env/prod.json.example`) - never hardcoded here,
/// so no real secret ever lives in tracked source. Running without a
/// dart-define file falls back to the local dev backend with an empty
/// token, which fails obviously (rather than silently) on token-gated calls.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://tv-tracker.local',
  );

  static const String defaultToken = String.fromEnvironment('API_DEFAULT_TOKEN');

  /// Culture code (ca/es/en) of the app's current locale, sent as
  /// Accept-Language on every request - kept as a plain static (like
  /// [defaultToken] above) rather than threaded through every provider,
  /// since most `*Api` classes are plain Dart classes without `ref` access.
  /// Set by LocaleController whenever the locale changes.
  static String? currentLanguage;
}
