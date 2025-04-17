// lib/models/variant_option.dart - Enhanced to handle richer data

import 'dart:convert';

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
    // Check additionalData first
    if (additionalData != null && additionalData!.containsKey('inStock')) {
      return additionalData!['inStock'] == true;
    }

    // Try to parse from value if it contains inStock information
    if (value != null && value!.contains('inStock')) {
      try {
        // Value might be a JSON string
        final Map<String, dynamic> data = jsonDecode(value!);
        if (data.containsKey('inStock')) {
          return data['inStock'] == true;
        }
      } catch (e) {
        // Parsing failed, check for text indicators
      }
    }

    // Check if value contains text indicators of stock status
    if (value != null) {
      if (value!.toLowerCase().contains('out of stock') ||
          value!.toLowerCase().contains('unavailable') ||
          value!.toLowerCase().contains('sold out')) {
        return false;
      }
    }

    // Default to true if we can't determine
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
