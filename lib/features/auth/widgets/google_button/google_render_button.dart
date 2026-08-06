// Conditional-import wrapper for google_sign_in_web's web-only renderButton()
// - mirrors the google_sign_in package's own example app
// (example/lib/src/web_wrapper*.dart), since google_sign_in_web can't be
// imported directly on non-web platforms.
export 'google_render_button_stub.dart'
    if (dart.library.js_util) 'google_render_button_web.dart';
