// lib/models/product_info.dart
import 'package:intl/intl.dart';

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
    // Process variants
    Map<String, List<VariantOption>>? variantMap;
    if (json['variants'] != null) {
      variantMap = {};

      // Process colors
      if (json['variants']['colors'] != null) {
        variantMap['colors'] = List<VariantOption>.from(
            (json['variants']['colors'] as List)
                .map((variant) => VariantOption.fromJson(variant)));
      }

      // Process sizes
      if (json['variants']['sizes'] != null) {
        variantMap['sizes'] = List<VariantOption>.from(
            (json['variants']['sizes'] as List)
                .map((variant) => VariantOption.fromJson(variant)));
      }

      // Process other options
      if (json['variants']['otherOptions'] != null) {
        variantMap['otherOptions'] = List<VariantOption>.from(
            (json['variants']['otherOptions'] as List)
                .map((variant) => VariantOption.fromJson(variant)));
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