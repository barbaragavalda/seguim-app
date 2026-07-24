import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';

/// Culture codes this app ships translations for, in the order offered by
/// the language picker (see ProfileScreen's `_AccountSection`).
const List<String> supportedLanguageCultures = ['ca', 'es', 'en'];

/// Language names in their own language, not translated per the current
/// locale - the standard convention for a language picker.
const Map<String, String> languageNativeNames = {
  'ca': 'Català',
  'es': 'Español',
  'en': 'English',
};

class LocaleController extends Notifier<Locale?> {
  static const _storageKey = 'locale';
  static const _storage = FlutterSecureStorage();

  @override
  Locale? build() {
    // same "modify provider outside build" reasoning as AuthController's
    // _restoreSession - runs after build() returns, not synchronously in it
    Future.microtask(_restore);
    return null;
  }

  Future<void> _restore() async {
    final culture = await _storage.read(key: _storageKey);
    if (culture != null && supportedLanguageCultures.contains(culture)) {
      ApiConfig.currentLanguage = culture;
      state = Locale(culture);
    }
  }

  /// Sets the app's own UI locale and the Accept-Language header sent on
  /// every subsequent API request. Does NOT touch the account's stored
  /// language in the database - see AccountController.updateLanguage for
  /// the (separate, login-gated) app -> DB direction.
  Future<void> setLocale(String culture) async {
    ApiConfig.currentLanguage = culture;
    state = Locale(culture);
    await _storage.write(key: _storageKey, value: culture);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);
