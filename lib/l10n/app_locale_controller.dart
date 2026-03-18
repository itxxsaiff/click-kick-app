import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, arabic, portuguese }

class AppLocaleController extends ChangeNotifier {
  static const _prefKey = 'app_language';

  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;

  Locale get locale {
    switch (_language) {
      case AppLanguage.arabic:
        return const Locale('ar');
      case AppLanguage.portuguese:
        return const Locale('pt');
      case AppLanguage.english:
        return const Locale('en');
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey) ?? 'en';
    _language = _fromCode(raw);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _code(language));
  }

  static AppLanguage _fromCode(String code) {
    switch (code) {
      case 'ar':
        return AppLanguage.arabic;
      case 'pt':
        return AppLanguage.english;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }

  static String _code(AppLanguage language) {
    switch (language) {
      case AppLanguage.arabic:
        return 'ar';
      case AppLanguage.portuguese:
        return 'pt';
      case AppLanguage.english:
        return 'en';
    }
  }
}
