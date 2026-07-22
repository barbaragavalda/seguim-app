// Copy this file to api_config.dart and fill in the real dev default_token
// from tv-tracker-local's config/api/dev/webservice.php (gitignored there too).
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'http://tv-tracker.local';
  static const String defaultToken = 'REPLACE_WITH_DEV_DEFAULT_TOKEN';
}
