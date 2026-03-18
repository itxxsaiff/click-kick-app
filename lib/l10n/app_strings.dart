import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_locale_controller.dart';

class AppStrings {
  const AppStrings._();

  static final Map<String, Map<String, String>> _translations = {
    'en': <String, String>{},
    'ar': <String, String>{},
  };

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    final enRaw = await rootBundle.loadString('assets/i18n/en.json');
    final arRaw = await rootBundle.loadString('assets/i18n/ar.json');

    _translations['en'] = _decodeMap(enRaw);
    _translations['ar'] = _decodeMap(arRaw);
    _loaded = true;
  }

  static String translate(String key, AppLanguage language) {
    final code = switch (language) {
      AppLanguage.arabic => 'ar',
      AppLanguage.portuguese => 'en',
      AppLanguage.english => 'en',
    };
    return _translations[code]?[key] ?? _translations['en']?[key] ?? key;
  }

  static Map<String, String> _decodeMap(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }
}
