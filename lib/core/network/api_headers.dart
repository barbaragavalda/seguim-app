import '../config/api_config.dart';

/// Standard headers for an authenticated (or shared-secret) request -
/// see [ApiConfig.currentLanguage] for why Accept-Language is sourced
/// from a static rather than a parameter.
Map<String, String> apiHeaders(String token) {
  return {
    'Authorization': token,
    if (ApiConfig.currentLanguage != null)
      'Accept-Language': ApiConfig.currentLanguage!,
  };
}
