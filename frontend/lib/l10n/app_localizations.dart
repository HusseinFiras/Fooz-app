import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;

class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);
  
  // Helper method to keep the code in the widgets concise
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }
  
  // Static member to have a simple access to the delegate from the MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  
  // Simple translations map
  static Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'Luxury Shopping',
      'home': 'Home',
      'brands': 'Brands',
      'favorites': 'Favorites',
      'cart': 'Shopping Cart',
      'settings': 'Settings',
      'searchHint': 'Search...',
      'allBrands': 'All Brands',
      'luxury': 'Luxury',
      'fashion': 'Fashion',
      'accessories': 'Accessories',
      'checkout': 'Checkout',
      'addToCart': 'Add to Cart',
      'removeFromCart': 'Remove',
      'placeOrder': 'Place Order',
      'contactInfo': 'Contact Information',
      'shippingAddress': 'Shipping Address',
      'language': 'Language',
      'english': 'English',
      'arabic': 'Arabic',
      'price': 'Price',
      'total': 'Total:',
      'viewProduct': 'View Product',
      'viewDetails': 'View Details',
    },
    'ar': {
      'appTitle': 'التسوّق الفاخر',
      'home': 'الرئيسية',
      'brands': 'العلامات التجارية',
      'favorites': 'المفضلة',
      'cart': 'سلة التسوق',
      'settings': 'الإعدادات',
      'searchHint': 'بحث...',
      'allBrands': 'جميع العلامات التجارية',
      'luxury': 'فاخرة',
      'fashion': 'أزياء',
      'accessories': 'اكسسوارات',
      'checkout': 'الدفع',
      'addToCart': 'أضف إلى السلة',
      'removeFromCart': 'إزالة',
      'placeOrder': 'تأكيد الطلب',
      'contactInfo': 'معلومات الاتصال',
      'shippingAddress': 'عنوان الشحن',
      'language': 'اللغة',
      'english': 'الإنجليزية',
      'arabic': 'العربية',
      'price': 'السعر',
      'total': 'المجموع:',
      'viewProduct': 'عرض المنتج',
      'viewDetails': 'عرض التفاصيل',
    },
  };
  
  String get appTitle => _localizedValues[locale.languageCode]!['appTitle'] ?? '';
  String get home => _localizedValues[locale.languageCode]!['home'] ?? '';
  String get brands => _localizedValues[locale.languageCode]!['brands'] ?? '';
  String get favorites => _localizedValues[locale.languageCode]!['favorites'] ?? '';
  String get cart => _localizedValues[locale.languageCode]!['cart'] ?? '';
  String get settings => _localizedValues[locale.languageCode]!['settings'] ?? '';
  String get searchHint => _localizedValues[locale.languageCode]!['searchHint'] ?? '';
  String get allBrands => _localizedValues[locale.languageCode]!['allBrands'] ?? '';
  String get luxury => _localizedValues[locale.languageCode]!['luxury'] ?? '';
  String get fashion => _localizedValues[locale.languageCode]!['fashion'] ?? '';
  String get accessories => _localizedValues[locale.languageCode]!['accessories'] ?? '';
  String get checkout => _localizedValues[locale.languageCode]!['checkout'] ?? '';
  String get addToCart => _localizedValues[locale.languageCode]!['addToCart'] ?? '';
  String get removeFromCart => _localizedValues[locale.languageCode]!['removeFromCart'] ?? '';
  String get placeOrder => _localizedValues[locale.languageCode]!['placeOrder'] ?? '';
  String get contactInfo => _localizedValues[locale.languageCode]!['contactInfo'] ?? '';
  String get shippingAddress => _localizedValues[locale.languageCode]!['shippingAddress'] ?? '';
  String get language => _localizedValues[locale.languageCode]!['language'] ?? '';
  String get english => _localizedValues[locale.languageCode]!['english'] ?? '';
  String get arabic => _localizedValues[locale.languageCode]!['arabic'] ?? '';
  String get price => _localizedValues[locale.languageCode]!['price'] ?? '';
  String get total => _localizedValues[locale.languageCode]!['total'] ?? '';
  String get viewProduct => _localizedValues[locale.languageCode]!['viewProduct'] ?? '';
  String get viewDetails => _localizedValues[locale.languageCode]!['viewDetails'] ?? '';
}

// LocalizationsDelegate implementation
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  // Supported languages list
  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    // Returning a SynchronousFuture here because there's no need to await for anything
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}