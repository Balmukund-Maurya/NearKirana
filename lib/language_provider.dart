import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
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
      if (savedLang != null) {
        _currentLanguage = savedLang;
      }
    } catch (e) {
      debugPrint('Error loading language: $e');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _currentLanguage = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', lang);
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }
}
