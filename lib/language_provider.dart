import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:near_kirana/l10n/app_localizations.dart';

class LanguageProvider extends ChangeNotifier {
  static const List<String> supportedLanguages = ['en', 'hi', 'hinglish', 'hi_Latn'];
  static final LanguageProvider _fallback = LanguageProvider(autoLoad: false);

  static LanguageProvider of(BuildContext context, {bool listen = true}) {
    try {
      final provider = Provider.of<LanguageProvider>(context, listen: listen);
      return provider;
    } catch (_) {
      try {
        final loc = Localizations.maybeLocaleOf(context);
        if (loc != null && loc.languageCode == 'hi') {
          final fallbackHi = LanguageProvider(autoLoad: false);
          fallbackHi._currentLanguage = 'hi';
          return fallbackHi;
        }
      } catch (_) {}
      return _fallback;
    }
  }

  static LanguageProvider? maybeOf(BuildContext context, {bool listen = true}) {
    try {
      return Provider.of<LanguageProvider>(context, listen: listen);
    } catch (_) {
      try {
        final loc = Localizations.maybeLocaleOf(context);
        if (loc != null && loc.languageCode == 'hi') {
          final fallbackHi = LanguageProvider(autoLoad: false);
          fallbackHi._currentLanguage = 'hi';
          return fallbackHi;
        }
      } catch (_) {}
      return _fallback;
    }
  }

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

  LanguageProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadSavedLanguage();
    }
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

