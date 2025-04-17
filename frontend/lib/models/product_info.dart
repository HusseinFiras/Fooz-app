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
    // Debug log
    debugPrint('[PD][DEBUG] ProductInfo.fromJson started');
    debugPrint('[PD][DEBUG] JSON keys: ${json.keys.join(", ")}');

    if (json.containsKey('variants')) {
      debugPrint('[PD][DEBUG] Variants type: ${json['variants'].runtimeType}');

      if (json['variants'] is Map) {
        Map variantsMap = json['variants'] as Map;
        debugPrint('[PD][DEBUG] Variants keys: ${variantsMap.keys.join(", ")}');

        if (variantsMap.containsKey('colors')) {
          var colors = variantsMap['colors'];
          debugPrint(
              '[PD][DEBUG] Variants.colors type: ${colors.runtimeType}, length: ${colors.length}');

          if (colors is List && colors.isNotEmpty) {
            debugPrint(
                '[PD][DEBUG] First color type: ${colors.first.runtimeType}');
            if (colors.first is Map) {
              Map firstColor = colors.first as Map;
              debugPrint(
                  '[PD][DEBUG] First color keys: ${firstColor.keys.join(", ")}');
              if (firstColor.containsKey('text')) {
                debugPrint(
                    '[PD][DEBUG] First color text: ${firstColor['text']}');
              }
            }
          }
        }

        if (variantsMap.containsKey('sizes')) {
          var sizes = variantsMap['sizes'];
          debugPrint(
              '[PD][DEBUG] Variants.sizes type: ${sizes.runtimeType}, length: ${sizes.length}');

          if (sizes is List && sizes.isNotEmpty) {
            debugPrint(
                '[PD][DEBUG] First size type: ${sizes.first.runtimeType}');
            if (sizes.first is Map) {
              Map firstSize = sizes.first as Map;
              debugPrint(
                  '[PD][DEBUG] First size keys: ${firstSize.keys.join(", ")}');
              if (firstSize.containsKey('text')) {
                debugPrint('[PD][DEBUG] First size text: ${firstSize['text']}');
              }
            }
          }
        }
      }
    }

    // Process variants
    Map<String, List<VariantOption>>? variantMap;
    if (json.containsKey('variants')) {
      variantMap = {};
      final variants = json['variants'];

      // Process colors
      if (variants.containsKey('colors')) {
        try {
          final List<dynamic> colorsList = variants['colors'];
          debugPrint('[PD][DEBUG] Processing ${colorsList.length} colors');

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

                // Debug log the color map
                debugPrint(
                    '[PD][DEBUG] Color $i map: ${colorMap.keys.join(", ")}');

                // Now check if this has the required 'text' field
                if (colorMap.containsKey('text')) {
                  debugPrint('[PD][DEBUG] Adding color: ${colorMap['text']}');
                  processedColors.add(VariantOption.fromJson(colorMap));
                } else {
                  debugPrint(
                      '[PD][DEBUG] Skipping invalid color format at index $i - missing text field');
                }
              } else {
                debugPrint(
                    '[PD][DEBUG] Skipping invalid color format at index $i - not a Map: ${color.runtimeType}');
              }
            } catch (e) {
              debugPrint('[PD][DEBUG] Error processing color at index $i: $e');
            }
          }

          // Add to the variant map
          variantMap['colors'] = processedColors;
          debugPrint('[PD][DEBUG] Processed ${processedColors.length} colors');
          // Log each processed color
          for (int i = 0; i < processedColors.length; i++) {
            debugPrint(
                '[PD][DEBUG] Processed color $i: ${processedColors[i].text}');
          }
        } catch (e) {
          debugPrint('[PD][DEBUG] Error processing colors list: $e');
        }
      }

      // Process sizes
      if (variants.containsKey('sizes')) {
        try {
          final List<dynamic> sizesList = variants['sizes'];
          debugPrint('[PD][DEBUG] Processing ${sizesList.length} sizes');

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

                // Debug log the size map
                debugPrint(
                    '[PD][DEBUG] Size $i map: ${sizeMap.keys.join(", ")}');

                // Now check if this has the required 'text' field
                if (sizeMap.containsKey('text')) {
                  debugPrint('[PD][DEBUG] Adding size: ${sizeMap['text']}');
                  processedSizes.add(VariantOption.fromJson(sizeMap));
                } else {
                  debugPrint(
                      '[PD][DEBUG] Skipping invalid size format at index $i - missing text field');
                }
              } else {
                debugPrint(
                    '[PD][DEBUG] Skipping invalid size format at index $i - not a Map: ${size.runtimeType}');
              }
            } catch (e) {
              debugPrint('[PD][DEBUG] Error processing size at index $i: $e');
            }
          }

          // Add to the variant map
          variantMap['sizes'] = processedSizes;
          debugPrint('[PD][DEBUG] Processed ${processedSizes.length} sizes');
          // Log each processed size
          for (int i = 0; i < processedSizes.length; i++) {
            debugPrint(
                '[PD][DEBUG] Processed size $i: ${processedSizes[i].text}');
          }
        } catch (e) {
          debugPrint('[PD][DEBUG] Error processing sizes list: $e');
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
                } else {
                  debugPrint(
                      '[PD][DEBUG] Skipping invalid option format at index $i - missing text field');
                }
              } else {
                debugPrint(
                    '[PD][DEBUG] Skipping invalid option format at index $i - not a Map');
              }
            } catch (e) {
              debugPrint('[PD][DEBUG] Error processing option at index $i: $e');
            }
          }

          // Add to the variant map
          variantMap['otherOptions'] = processedOtherOptions;
        } catch (e) {
          debugPrint('[PD][DEBUG] Error processing otherOptions list: $e');
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

    // Final debug information
    if (result.variants != null) {
      debugPrint('[PD][DEBUG] Final result variants info:');
      if (result.variants!.containsKey('colors')) {
        debugPrint(
            '[PD][DEBUG] Final colors count: ${result.variants!['colors']!.length}');
        result.variants!['colors']!.forEach(
            (color) => debugPrint('[PD][DEBUG] Final color: ${color.text}'));
      }
      if (result.variants!.containsKey('sizes')) {
        debugPrint(
            '[PD][DEBUG] Final sizes count: ${result.variants!['sizes']!.length}');
        result.variants!['sizes']!.forEach(
            (size) => debugPrint('[PD][DEBUG] Final size: ${size.text}'));
      }
    }

    return result;
  }
  String formatPrice(double? price, String? currency) {
    if (price == null) return '';

    final formatter = NumberFormat('#,##0.00', 'tr_TR');
    String symbol = '₺';

    switch (currency) {
      case 'USD':
        symbol = '\$';
        break;
      case 'EUR':
        symbol = '€';
        break;
      case 'GBP':
        symbol = '£';
        break;
      case 'TRY':
      default:
        symbol = '₺';
        break;
    }

    return '${formatter.format(price)} $symbol';
  }

  String get formattedPrice {
    return formatPrice(price, currency);
  }

  String get formattedOriginalPrice {
    return formatPrice(originalPrice, currency);
  }
}
