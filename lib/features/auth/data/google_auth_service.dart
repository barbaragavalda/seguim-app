import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/google_auth_config.dart';

/// Ensures GoogleSignIn.instance.initialize() only ever runs once for the
/// app's lifetime, regardless of how many times GoogleSignInButton mounts -
/// GoogleSignIn's own docs warn that calling initialize() more than once,
/// or calling other methods before its future completes, is undefined
/// behavior.
class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  Future<void>? _initialization;

  Future<void> ensureInitialized() {
    return _initialization ??= GoogleSignIn.instance.initialize(
      clientId: GoogleAuthConfig.clientIdForPlatform,
      // google_sign_in_web asserts serverClientId == null and never
      // finishes initializing if it isn't - confirmed by reading
      // GoogleSignInPlugin.init() directly (google_sign_in_web 1.1.3),
      // after the "Getting ready" button got stuck forever with no visible
      // error (the assert failure just leaves its internal Completer
      // uncompleted). Harmless to omit on web: clientId is already the Web
      // client there, so the resulting ID token's `aud` is the Web client
      // regardless. Only mobile needs serverClientId to get that same
      // audience (see TokenVerifier on the backend).
      serverClientId: kIsWeb ? null : GoogleAuthConfig.webClientId,
    );
  }
}
