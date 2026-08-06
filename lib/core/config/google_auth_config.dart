import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Google Sign-In OAuth client IDs (console.cloud.google.com > Google Auth
/// Platform > Clients). Unlike [ApiConfig]'s dart-define values, these are
/// safe to hardcode directly: they're public identifiers Google matches
/// against this app's package name/bundle ID/SHA-1 or authorized JS
/// origins at Google's end, not a secret this app itself protects. Same
/// values in dev and prod - see the backend's config/google.php.
class GoogleAuthConfig {
  GoogleAuthConfig._();

  static const String webClientId =
      '896234443669-p5nedti40vlbclkh3973gdf3in5pjskj.apps.googleusercontent.com';

  static const String iosClientId =
      '896234443669-2nv573a07nf4b702pg5evmbdu4bqabe8.apps.googleusercontent.com';

  static const String androidClientId =
      '896234443669-pk7d0irr2vraodoki5e6km2cqgc1b8qs.apps.googleusercontent.com';

  /// The `clientId` GoogleSignIn.initialize() wants for the current
  /// platform - null on Android, which matches by package name + SHA-1
  /// registered in Cloud Console instead of an explicit client ID.
  static String? get clientIdForPlatform {
    if (kIsWeb) return webClientId;
    if (defaultTargetPlatform == TargetPlatform.iOS) return iosClientId;
    return null;
  }
}
