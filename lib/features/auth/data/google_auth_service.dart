import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/google_auth_config.dart';

/// Ensures GoogleSignIn.instance.initialize() only ever runs once - calling
/// it more than once, or calling other methods before it completes, is
/// undefined behavior per GoogleSignIn's own docs.
class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  Future<void>? _initialization;

  Future<void> ensureInitialized() {
    return _initialization ??= GoogleSignIn.instance.initialize(
      clientId: GoogleAuthConfig.clientIdForPlatform,
      // google_sign_in_web asserts serverClientId == null and hangs forever
      // (no visible error) if it isn't; harmless to omit since clientId is
      // already the Web client there, giving the same token `aud`
      serverClientId: kIsWeb ? null : GoogleAuthConfig.webClientId,
    );
  }
}
