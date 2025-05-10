// lib/models/product_info.dart
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'variant_option.dart';

class ProductInfo {
  final bool isProductPage;
  final String? title;
  final double? price;
  final double? originalPrice;
  final String? currency;
  final String? imageUrl;
  final String? description;
  final String? sku;
  final String? availability;
  final String? brand;
  final String? extractionMethod;
  final String url;
  final bool success;
  final Map<String, List<VariantOption>>? variants;

  ProductInfo({
    required this.isProductPage,
    this.title,
    this.price,
    this.originalPrice,
    this.currency,
    this.imageUrl,
    this.description,
    this.sku,
    this.availability,
    this.brand,
    this.extractionMethod,
    required this.url,
    required this.success,
    this.variants,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    // Basic debug info to show we started parsing
    debugPrint('[PD] ProductInfo.fromJson - started parsing');

    // Process variants
    Map<String, List<VariantOption>>? variantMap;
    if (json.containsKey('variants')) {
      variantMap = {};
      final variants = json['variants'];

      // Process colors
      if (variants.containsKey('colors')) {
        try {
          final List<dynamic> colorsList = variants['colors'];
          debugPrint('[PD] Processing ${colorsList.length} colors');

          // Create a list for the processed colors
          final List<VariantOption> processedColors = [];

          // Process each color manually to ensure proper handling
          for (int i = 0; i < colorsList.length; i++) {
            final color = colorsList[i];
            try {
              // Validate if this is a proper color object before adding
              if (color is Map) {
                // Create a new Map<String, dynamic> from the dynamic map
                final Map<String, dynamic> colorMap = {};
                color.forEach((key, value) {
                  if (key is String) {
                    colorMap[key] = value;
                  }
                });

                // Now check if this has the required 'text' field
                if (colorMap.containsKey('text')) {
                  processedColors.add(VariantOption.fromJson(colorMap));
                }
              }
            } catch (e) {
              debugPrint('[PD] Error processing color at index $i: $e');
            }
          }

          // Add to the variant map
          variantMap['colors'] = processedColors;
          debugPrint('[PD] Processed ${processedColors.length} colors');
        } catch (e) {
          debugPrint('[PD] Error processing colors list: $e');
        }
      }

      // Process sizes
      if (variants.containsKey('sizes')) {
        try {
          final List<dynamic> sizesList = variants['sizes'];
          debugPrint('[PD] Processing ${sizesList.length} sizes');

          // Create a list for the processed sizes
          final List<VariantOption> processedSizes = [];

          // Process each size manually to ensure proper handling
          for (int i = 0; i < sizesList.length; i++) {
            final size = sizesList[i];
            try {
              // Validate if this is a proper size object before adding
              if (size is Map) {
                // Create a new Map<String, dynamic> from the dynamic map
                final Map<String, dynamic> sizeMap = {};
                size.forEach((key, value) {
                  if (key is String) {
                    sizeMap[key] = value;
                  }
                });

                // Now check if this has the required 'text' field
                if (sizeMap.containsKey('text')) {
                  processedSizes.add(VariantOption.fromJson(sizeMap));
                }
              }
            } catch (e) {
              debugPrint('[PD] Error processing size at index $i: $e');
            }
          }

          // Add to the variant map
          variantMap['sizes'] = processedSizes;
          debugPrint('[PD] Processed ${processedSizes.length} sizes');
        } catch (e) {
          debugPrint('[PD] Error processing sizes list: $e');
        }
      }

      // Handle other options if present
      if (variants.containsKey('otherOptions')) {
        try {
          final List<dynamic> otherOptionsList = variants['otherOptions'];
          final List<VariantOption> processedOtherOptions = [];

          for (int i = 0; i < otherOptionsList.length; i++) {
            final option = otherOptionsList[i];
            try {
              // Validate if this is a proper option object before adding
              if (option is Map) {
                // Create a new Map<String, dynamic> from the dynamic map
                final Map<String, dynamic> optionMap = {};
                option.forEach((key, value) {
                  if (key is String) {
                    optionMap[key] = value;
                  }
                });

                // Now check if this has the required 'text' field
                if (optionMap.containsKey('text')) {
                  processedOtherOptions.add(VariantOption.fromJson(optionMap));
                }
              }
            } catch (e) {
              debugPrint('[PD] Error processing option at index $i: $e');
            }
          }

          // Add to the variant map
          variantMap['otherOptions'] = processedOtherOptions;
        } catch (e) {
          debugPrint('[PD] Error processing otherOptions list: $e');
        }
      }
    }

    // Special handling for Zara products - check the URL to ensure brand detection
    bool isZaraProduct = false;
    if (json.containsKey('url')) {
      String url = json['url'] as String;
      isZaraProduct = url.toLowerCase().contains('zara.com');

      if (isZaraProduct && !json.containsKey('brand')) {
        // Force set the brand to Zara if detected from URL
        json['brand'] = 'Zara';
      }
    }
    
    // Special handling for Stradivarius products
    bool isStradivariusProduct = false;
    if (json.containsKey('url')) {
      String url = json['url'] as String;
      isStradivariusProduct = url.toLowerCase().contains('stradivarius.com');

      if (isStradivariusProduct && !json.containsKey('brand')) {
        // Force set the brand to Stradivarius if detected from URL
        json['brand'] = 'Stradivarius';
      }
    }
    
    // Special handling for Louis Vuitton products
    bool isLVProduct = false;
    if (json.containsKey('url')) {
      String url = json['url'] as String;
      isLVProduct = url.toLowerCase().contains('louisvuitton.com');

      if (isLVProduct) {
        // Force set the brand to Louis Vuitton if detected from URL
        if (!json.containsKey('brand')) {
          json['brand'] = 'Louis Vuitton';
        }
        
        // Force set the currency to USD for US Louis Vuitton site
        if (url.toLowerCase().contains('us.louisvuitton.com') || 
            url.toLowerCase().contains('louisvuitton.com/eng-us')) {
          json['currency'] = 'USD';
        }
      }
    }

    // Create the ProductInfo with properly processed variants
    final result = ProductInfo(
      isProductPage: json['isProductPage'] ?? false,
      title: json['title'],
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
      originalPrice: json['originalPrice'] != null
          ? double.tryParse(json['originalPrice'].toString())
          : null,
      currency: json['currency'],
      imageUrl: json['imageUrl'],
      description: json['description'],
      sku: json['sku'],
      availability: json['availability'],
      brand: json['brand'],
      extractionMethod: json['extractionMethod'],
      url: json['url'] ?? '',
      success: json['success'] ?? false,
      variants: variantMap,
    );

    // Final summary of variants
    if (result.variants != null) {
      debugPrint('[PD] Variants summary:');
      if (result.variants!.containsKey('colors')) {
        debugPrint('[PD] Final colors count: ${result.variants!['colors']!.length}');
      }
      if (result.variants!.containsKey('sizes')) {
        debugPrint('[PD] Final sizes count: ${result.variants!['sizes']!.length}');
      }
    }

    return result;
  }
  
  String formatPrice(double? price, String? currency) {
    if (price == null) return '';

    String symbol;
    NumberFormat formatter;
    
    switch (currency) {
      case 'USD':
        symbol = '\$';
        formatter = NumberFormat.currency(
          locale: 'en_US',
          symbol: '',
          decimalDigits: 2,
        );
        return '$symbol${formatter.format(price)}';
      case 'EUR':
        symbol = '€';
        formatter = NumberFormat.currency(
          locale: 'de_DE',
          symbol: '',
          decimalDigits: 2,
        );
        return '${formatter.format(price)}$symbol';
      case 'GBP':
        symbol = '£';
        formatter = NumberFormat.currency(
          locale: 'en_GB',
          symbol: '',
          decimalDigits: 2,
        );
        return '$symbol${formatter.format(price)}';
      case 'TRY':
      default:
        symbol = '₺';
        formatter = NumberFormat.currency(
          locale: 'tr_TR',
          symbol: '',
          decimalDigits: 2,
        );
        return '${formatter.format(price)} $symbol';
    }
  }

  String get formattedPrice {
    return formatPrice(price, currency);
  }

  String get formattedOriginalPrice {
    return formatPrice(originalPrice, currency);
  }
}
