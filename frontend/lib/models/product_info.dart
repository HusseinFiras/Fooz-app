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
    // Debug logging for better variant tracing
    debugPrint(
        '[ProductInfo] Processing JSON: isProductPage=${json['isProductPage']}, title=${json['title']}');

    // Process variants
    Map<String, List<VariantOption>>? variantMap;
    if (json['variants'] != null) {
      debugPrint('[ProductInfo] Processing variants data');
      variantMap = {};

      // Process colors
      if (json['variants']['colors'] != null) {
        final colorsList = json['variants']['colors'] as List;
        debugPrint('[ProductInfo] Processing ${colorsList.length} colors');

        variantMap['colors'] =
            List<VariantOption>.from(colorsList.map((variant) {
          // Log each color for debugging
          debugPrint(
              '[ProductInfo] Color: text=${variant['text']}, selected=${variant['selected']}, value=${variant['value']}');
          return VariantOption.fromJson(variant);
        }));
      }

      // Process sizes
      if (json['variants']['sizes'] != null) {
        final sizesList = json['variants']['sizes'] as List;
        debugPrint('[ProductInfo] Processing ${sizesList.length} sizes');

        variantMap['sizes'] = List<VariantOption>.from(sizesList.map((variant) {
          // Log each size for debugging
          debugPrint(
              '[ProductInfo] Size: text=${variant['text']}, selected=${variant['selected']}, value=${variant['value']}');
          return VariantOption.fromJson(variant);
        }));
      }

      // Process other options
      if (json['variants']['otherOptions'] != null) {
        variantMap['otherOptions'] = List<VariantOption>.from(
            (json['variants']['otherOptions'] as List)
                .map((variant) => VariantOption.fromJson(variant)));
      }
    }

    // Log the final variant data
    if (variantMap != null) {
      debugPrint(
          '[ProductInfo] Final variant map: ${variantMap.keys.join(", ")}');
      if (variantMap.containsKey('colors')) {
        debugPrint(
            '[ProductInfo] Final colors count: ${variantMap['colors']?.length}');
      }
      if (variantMap.containsKey('sizes')) {
        debugPrint(
            '[ProductInfo] Final sizes count: ${variantMap['sizes']?.length}');
      }
    }

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
