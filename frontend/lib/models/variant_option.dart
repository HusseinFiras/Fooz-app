// lib/models/variant_option.dart - Enhanced to handle richer data

import 'dart:convert';
import 'package:flutter/foundation.dart';

class VariantOption {
  final String text;
  final bool selected;
  final String? value;

  // Additional fields for better functionality
  final Map<String, dynamic>? additionalData;

  VariantOption({
    required this.text,
    required this.selected,
    this.value,
    this.additionalData,
  });

  factory VariantOption.fromJson(Map<String, dynamic> json) {
    // Capture any additional fields we might want to use later
    Map<String, dynamic>? additionalData;

    // Extract specific properties we want to preserve
    if (json.containsKey('inStock') ||
        json.containsKey('colorValue') ||
        json.containsKey('rgbValue') ||
        json.containsKey('imageUrl')) {
      additionalData = {};

      if (json.containsKey('inStock')) {
        additionalData['inStock'] = json['inStock'];
      }

      if (json.containsKey('colorValue')) {
        additionalData['colorValue'] = json['colorValue'];
      }

      if (json.containsKey('rgbValue')) {
        additionalData['rgbValue'] = json['rgbValue'];
      }

      if (json.containsKey('imageUrl')) {
        additionalData['imageUrl'] = json['imageUrl'];
      }
    }

    return VariantOption(
      text: json['text'] ?? '',
      selected: json['selected'] ?? false,
      value: json['value'],
      additionalData: additionalData,
    );
  }
  // Is this size/color in stock?
  bool get isInStock {
    // For debugging
    final currentValue = value;
    final sizeText = text;
    
    // Check additionalData first
    if (additionalData != null && additionalData!.containsKey('inStock')) {
      final inStockValue = additionalData!['inStock'];
      debugPrint('[VO] Size $sizeText: additionalData inStock=$inStockValue');
      return inStockValue == true;
    }

    // Try to parse from value if it contains inStock information
    if (currentValue != null) {
      try {
        // Value might be a JSON string with inStock information
        if (currentValue.contains('inStock')) {
          final Map<String, dynamic> data = jsonDecode(currentValue);
          final inStock = data['inStock'];
          debugPrint('[VO] Size $sizeText: parsed from JSON inStock=$inStock');
          return inStock == true; // Explicitly compare to true for safety
        }
      } catch (e) {
        debugPrint('[VO] Size $sizeText: error parsing JSON: $e');
        // Parsing failed, continue to other checks
      }
    }

    // For Zara specific cases - check for size-specific indicators in the value
    if (currentValue != null) {
      // Check for out-of-stock indicators specific to Zara
      if (currentValue.toLowerCase().contains('unavailable') ||
          currentValue.toLowerCase().contains('out of stock') ||
          currentValue.toLowerCase().contains('out-of-stock') ||
          currentValue.toLowerCase().contains('disabled')) {
        debugPrint('[VO] Size $sizeText: detected out-of-stock keyword in value');
        return false;
      }
    }

    // Check if value contains text indicators of stock status
    if (currentValue != null) {
      if (currentValue.toLowerCase().contains('out of stock') ||
          currentValue.toLowerCase().contains('unavailable') ||
          currentValue.toLowerCase().contains('sold out')) {
        debugPrint('[VO] Size $sizeText: detected general out-of-stock keyword');
        return false;
      }
    }

    // Default to true if we can't determine
    debugPrint('[VO] Size $sizeText: no stock info found, defaulting to inStock=true');
    return true;
  }

  // Get the color value for color variants
  String? get colorValue {
    // Check additionalData first
    if (additionalData != null && additionalData!.containsKey('colorValue')) {
      return additionalData!['colorValue'];
    }

    // For backward compatibility, the color might be in the value
    return value;
  }

  // Get RGB value for color variants (useful for Zara)
  String? get rgbValue {
    // Check additionalData first
    if (additionalData != null && additionalData!.containsKey('rgbValue')) {
      return additionalData!['rgbValue'];
    }

    // Try to extract RGB from value
    if (value != null && value!.contains('rgb')) {
      // Extract just the RGB part using regex
      final rgbRegex = RegExp(r'rgb\([^)]+\)');
      final match = rgbRegex.firstMatch(value!);
      if (match != null) {
        return match.group(0);
      }
    }

    return null;
  }

  // Get image URL for color variants with images
  String? get imageUrl {
    // Check additionalData first
    if (additionalData != null && additionalData!.containsKey('imageUrl')) {
      return additionalData!['imageUrl'];
    }

    // For backward compatibility, check if value is a URL
    if (value != null &&
        (value!.startsWith('http') || value!.startsWith('//'))) {
      return value;
    }

    return null;
  }
}
