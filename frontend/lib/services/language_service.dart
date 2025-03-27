// lib/services/language_service.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageCodeKey = 'language_code';
  static const String _countryCodeKey = 'country_code';
  
  // Default language is English
  static const Locale defaultLocale = Locale('en');
  
  // Supported locales
  static final List<Locale> supportedLocales = [
    const Locale('en'), // English
    const Locale('ar'), // Arabic
  ];
  
  // Locale names for display in the UI
  static final Map<String, String> localeDisplayNames = {
    'en': 'English',
    'ar': 'العربية',
  };
  
  // Get the current locale from SharedPreferences
  Future<Locale> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    
    String languageCode = prefs.getString(_languageCodeKey) ?? defaultLocale.languageCode;
    String? countryCode = prefs.getString(_countryCodeKey);
    
    return Locale(languageCode, countryCode);
  }
  
  // Save locale to SharedPreferences
  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_languageCodeKey, locale.languageCode);
    if (locale.countryCode != null) {
      await prefs.setString(_countryCodeKey, locale.countryCode!);
    } else {
      await prefs.remove(_countryCodeKey);
    }
  }
  
  // Check if the current locale is RTL
  static bool isRtl(Locale locale) {
    return ['ar', 'fa', 'he', 'ur'].contains(locale.languageCode);
  }
}