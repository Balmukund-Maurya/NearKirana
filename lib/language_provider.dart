import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'en'; // 'hi', 'en'
  bool _isLoaded = false;

  String get currentLanguage => _currentLanguage;
  bool get isLoaded => _isLoaded;

  LanguageProvider() {
    loadSavedLanguage();
  }

  Future<void> loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('app_language');
      if (savedLang != null) {
        // Fallback to 'en' if 'hinglish' was saved previously
        if (savedLang == 'hinglish') {
          _currentLanguage = 'en';
          prefs.setString('app_language', 'en');
        } else {
          _currentLanguage = savedLang;
        }
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
