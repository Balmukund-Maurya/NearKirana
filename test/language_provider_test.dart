import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:near_kirana/language_provider.dart';
import 'package:near_kirana/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageProvider & Tri-Lingual Support Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial language defaults to English', () async {
      final provider = LanguageProvider();
      expect(provider.currentLanguage, 'en');
      expect(provider.currentLocale, const Locale('en'));
      expect(provider.currentLanguageName, 'English');
      expect(provider.isEnglish, true);
      expect(provider.isHindi, false);
      expect(provider.isHinglish, false);
    });

    test('Switching to Hindi (Devanagari) updates locale and state', () async {
      final provider = LanguageProvider();
      await provider.setLanguage('hi');

      expect(provider.currentLanguage, 'hi');
      expect(provider.currentLocale, const Locale('hi'));
      expect(provider.currentLanguageName, 'हिंदी');
      expect(provider.isHindi, true);
      expect(provider.isEnglish, false);
      expect(provider.isHinglish, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_language'), 'hi');
    });

    test('Switching to Hinglish (Roman Hindi) correctly creates BCP-47 hi_Latn locale', () async {
      final provider = LanguageProvider();
      await provider.setLanguage('hinglish');

      expect(provider.currentLanguage, 'hinglish');
      expect(provider.currentLocale, const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'));
      expect(provider.currentLanguageName, 'Hinglish');
      expect(provider.isHinglish, true);
      expect(provider.isHindi, false);
      expect(provider.isEnglish, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_language'), 'hinglish');
    });

    test('Loading saved Hinglish from SharedPreferences preserves Hinglish without fallback', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'hinglish'});

      final provider = LanguageProvider();
      await provider.loadSavedLanguage();

      expect(provider.currentLanguage, 'hinglish');
      expect(provider.currentLocale, const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'));
      expect(provider.isHinglish, true);
    });

    test('AppLocalizations successfully resolves all 3 supported locales with valid translations', () {
      final enLoc = lookupAppLocalizations(const Locale('en'));
      expect(enLoc.cart_title, 'Your Cart');
      expect(enLoc.add, '+ Add');

      final hiLoc = lookupAppLocalizations(const Locale('hi'));
      expect(hiLoc.cart_title, 'आपका कार्ट');
      expect(hiLoc.add, '+ जोड़ें');

      final latnLoc = lookupAppLocalizations(const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'));
      expect(latnLoc.cart_title, 'Aapka Cart');
      expect(latnLoc.add, '+ Add Karein');
      expect(latnLoc.place_order, 'Order Place Karein');
      expect(latnLoc.out_of_stock, 'Stock Khatam');
    });
  });
}
