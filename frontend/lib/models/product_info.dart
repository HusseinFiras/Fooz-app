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

    // Process variants
    Map<String, List<VariantOption>>? variantMap;
    if (json.containsKey('variants')) {
      variantMap = {};
      final variants = json['variants'];

      // Process colors
      if (variants.containsKey('colors')) {
        final List<dynamic> colorsList = variants['colors'];
        debugPrint('[PD][DEBUG] Processing ${colorsList.length} colors');

        // Create a list for the processed colors
        final List<VariantOption> processedColors = [];

        // Process each color manually to ensure proper handling
        for (int i = 0; i < colorsList.length; i++) {
          final color = colorsList[i];
          try {
            processedColors.add(VariantOption.fromJson(color));
          } catch (e) {
            debugPrint('[PD][DEBUG] Error processing color at index $i: $e');
          }
        }

        // Add to the variant map
        variantMap['colors'] = processedColors;
        debugPrint('[PD][DEBUG] Processed ${processedColors.length} colors');
      }

      // Process sizes
      if (variants.containsKey('sizes')) {
        final List<dynamic> sizesList = variants['sizes'];
        debugPrint('[PD][DEBUG] Processing ${sizesList.length} sizes');

        // Create a list for the processed sizes
        final List<VariantOption> processedSizes = [];

        // Process each size manually to ensure proper handling
        for (int i = 0; i < sizesList.length; i++) {
          final size = sizesList[i];
          try {
            processedSizes.add(VariantOption.fromJson(size));
          } catch (e) {
            debugPrint('[PD][DEBUG] Error processing size at index $i: $e');
          }
        }

        // Add to the variant map
        variantMap['sizes'] = processedSizes;
        debugPrint('[PD][DEBUG] Processed ${processedSizes.length} sizes');
      }

      // Similar handling for otherOptions if needed
    }

    // Create the ProductInfo with properly processed variants
    return ProductInfo(
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
