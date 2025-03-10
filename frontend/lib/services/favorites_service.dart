// lib/services/favorites_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_info.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorites_list';
  
  // Get all items in favorites
  Future<List<ProductInfo>> getFavoriteItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
      
      return favoritesJson.map((item) {
        final Map<String, dynamic> productMap = jsonDecode(item);
        return ProductInfo.fromJson(productMap);
      }).toList();
    } catch (e) {
      debugPrint('Error loading favorite items: $e');
      return [];
    }
  }
  
  // Add a product to favorites
  Future<bool> addToFavorites(ProductInfo product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
      
      // Check if product already exists in favorites
      final existingProductIndex = _findProductIndex(favoritesJson, product);
      
      if (existingProductIndex != -1) {
        // Product already exists, replace it with updated one
        favoritesJson[existingProductIndex] = jsonEncode(_productToJson(product));
      } else {
        // Add new product
        favoritesJson.add(jsonEncode(_productToJson(product)));
      }
      
      return await prefs.setStringList(_favoritesKey, favoritesJson);
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
      return false;
    }
  }
  
  // Remove a product from favorites
  Future<bool> removeFromFavorites(ProductInfo product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
      
      final existingProductIndex = _findProductIndex(favoritesJson, product);
      
      if (existingProductIndex != -1) {
        favoritesJson.removeAt(existingProductIndex);
        return await prefs.setStringList(_favoritesKey, favoritesJson);
      }
      
      return true; // Product wasn't in favorites, so removal is "successful"
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
      return false;
    }
  }
  
  // Check if a product is in favorites
  Future<bool> isInFavorites(ProductInfo product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
      
      return _findProductIndex(favoritesJson, product) != -1;
    } catch (e) {
      debugPrint('Error checking favorites: $e');
      return false;
    }
  }
  
  // Clear all favorites
  Future<bool> clearFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setStringList(_favoritesKey, []);
    } catch (e) {
      debugPrint('Error clearing favorites: $e');
      return false;
    }
  }
  
  // Get the number of items in favorites
  Future<int> getFavoriteItemCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
      return favoritesJson.length;
    } catch (e) {
      debugPrint('Error getting favorites count: $e');
      return 0;
    }
  }
  
  // Helper method to find a product in favorites
  int _findProductIndex(List<String> favoritesJson, ProductInfo product) {
    for (int i = 0; i < favoritesJson.length; i++) {
      try {
        final Map<String, dynamic> productMap = jsonDecode(favoritesJson[i]);
        final favoriteProduct = ProductInfo.fromJson(productMap);
        
        // Compare by URL or unique identifier if available
        if (favoriteProduct.url == product.url) {
          return i;
        }
      } catch (e) {
        debugPrint('Error parsing product at index $i: $e');
      }
    }
    return -1;
  }
  
  // Helper method to convert ProductInfo to a Map for storage
  // This ensures we're only storing what we need and avoiding circular references
  Map<String, dynamic> _productToJson(ProductInfo product) {
    return {
      'isProductPage': product.isProductPage,
      'title': product.title,
      'price': product.price,
      'originalPrice': product.originalPrice,
      'currency': product.currency,
      'imageUrl': product.imageUrl,
      'description': product.description,
      'sku': product.sku,
      'availability': product.availability,
      'brand': product.brand,
      'extractionMethod': product.extractionMethod,
      'url': product.url,
      'success': product.success,
      // We simplify variants storage to avoid complex nested objects
      'variants': product.variants != null ? {
        'colors': product.variants!['colors']?.map((v) => {
          'text': v.text,
          'selected': v.selected,
          'value': v.value,
        }).toList(),
        'sizes': product.variants!['sizes']?.map((v) => {
          'text': v.text,
          'selected': v.selected,
          'value': v.value,
        }).toList(),
        'otherOptions': product.variants!['otherOptions']?.map((v) => {
          'text': v.text,
          'selected': v.selected,
          'value': v.value,
        }).toList(),
      } : null,
    };
  }
}