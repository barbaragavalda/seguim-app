import 'package:flutter/widgets.dart';

/// Stub for the web-only renderButton() - never actually called on
/// non-web platforms, since GoogleSignInButton only reaches for this when
/// GoogleSignIn.instance.supportsAuthenticate() is false, which is web-only.
Widget renderButton() {
  throw StateError('This should only be called on web');
}
