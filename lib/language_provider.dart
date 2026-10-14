import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:near_kirana/l10n/app_localizations.dart';

class LanguageProvider extends ChangeNotifier {
  static const List<String> supportedLanguages = ['en', 'hi', 'hinglish', 'hi_Latn'];

  String _currentLanguage = 'en'; // 'hi', 'en', 'hinglish'
  bool _isLoaded = false;

  String get currentLanguage => _currentLanguage;
  bool get isLoaded => _isLoaded;

  Locale get currentLocale {
    if (_currentLanguage == 'hinglish' || _currentLanguage == 'hi_Latn') {
      return const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn');
    }
    return Locale(_currentLanguage);
  }

  String get currentLanguageName {
    if (_currentLanguage == 'hi') return 'हिंदी';
    if (_currentLanguage == 'hinglish' || _currentLanguage == 'hi_Latn') {
      return 'Hinglish';
    }
    return 'English';
  }

  bool get isHindi => _currentLanguage == 'hi';
  bool get isHinglish =>
      _currentLanguage == 'hinglish' || _currentLanguage == 'hi_Latn';
  bool get isEnglish => _currentLanguage == 'en';

  LanguageProvider() {
    loadSavedLanguage();
  }

  Future<void> loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('app_language');
      if (savedLang != null && supportedLanguages.contains(savedLang)) {
        _currentLanguage = savedLang;
      } else {
        _currentLanguage = 'en';
      }
    } catch (e) {
      debugPrint('Error loading language: $e');
      _currentLanguage = 'en';
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    final effectiveLang = supportedLanguages.contains(lang) ? lang : 'en';
    _currentLanguage = effectiveLang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', effectiveLang);
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }
}

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

