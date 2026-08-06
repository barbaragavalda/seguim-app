import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/google_auth_service.dart';
import 'google_render_button.dart' as web_button;

/// "Continue with Google". On platforms that support
/// GoogleSignIn.authenticate() directly (iOS/Android), a normal button
/// triggers it. On web, authenticate() isn't supported - Google's own GIS
/// SDK only allows signing in through its own rendered button (see
/// google_sign_in_web's docs), so [onIdToken] instead fires from a
/// subscription to authenticationEvents. Either way, [onIdToken] fires
/// once with a verified Google ID token, ready to hand to the backend
/// (Api\Controller\Login\Google).
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onIdToken,
    required this.onError,
  });

  final String label;
  final ValueChanged<String> onIdToken;
  final ValueChanged<Object> onError;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  late final Future<void> _ready;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _ready = GoogleAuthService.instance.ensureInitialized().then((_) {
      if (!mounted) return;
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        _subscription = GoogleSignIn.instance.authenticationEvents.listen(
          _handleEvent,
          onError: widget.onError,
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _handleEvent(GoogleSignInAuthenticationEvent event) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      final idToken = event.user.authentication.idToken;
      if (idToken != null) {
        widget.onIdToken(idToken);
      }
    }
  }

  Future<void> _handleAuthenticate() async {
    setState(() => _signingIn = true);
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken != null) {
        widget.onIdToken(idToken);
      } else {
        widget.onError(StateError('Google did not return an ID token'));
      }
    } on GoogleSignInException catch (e) {
      // a user-initiated cancel isn't an error worth surfacing
      if (e.code != GoogleSignInExceptionCode.canceled) {
        widget.onError(e);
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 44);
        }
        // GoogleSignIn.instance.initialize() failed - most likely cause: the
        // platform-specific plugin (e.g. google_sign_in_web) never
        // registered itself, so every GoogleSignIn.instance.* call below
        // would throw UnimplementedError from the platform interface's own
        // placeholder implementation. Hiding the button beats crashing the
        // whole screen (Flutter's default release-mode error widget is a
        // blank grey box) over a feature that's optional to begin with.
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        if (!GoogleSignIn.instance.supportsAuthenticate()) {
          return SizedBox(height: 44, child: web_button.renderButton());
        }
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _signingIn ? null : _handleAuthenticate,
            icon: _signingIn
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const _GoogleLogo(),
            label: Text(widget.label),
          ),
        );
      },
    );
  }
}

/// A minimal approximation of Google's "G" mark using plain text, since this
/// app doesn't otherwise bundle brand logo assets - good enough to signal
/// "this is Google" next to the label; can be swapped for Google's official
/// button asset later if the plain style doesn't look right in practice.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 16,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
