// lib/services/cart_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_info.dart';

class CartService {
  static const String _cartKey = 'shopping_cart';
  
  // Get all items in the cart
  Future<List<ProductInfo>> getCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getStringList(_cartKey) ?? [];
      
      return cartJson.map((item) {
        final Map<String, dynamic> productMap = jsonDecode(item);
        return ProductInfo.fromJson(productMap);
      }).toList();
    } catch (e) {
      debugPrint('Error loading cart items: $e');
      return [];
    }
  }
  
  // Add a product to the cart
  Future<bool> addToCart(ProductInfo product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getStringList(_cartKey) ?? [];
      
      // Check if product already exists in cart
      final existingProductIndex = _findProductIndex(cartJson, product);
      
      if (existingProductIndex != -1) {
        // Product already exists, replace it with updated one
        cartJson[existingProductIndex] = jsonEncode(_productToJson(product));
      } else {
        // Add new product
        cartJson.add(jsonEncode(_productToJson(product)));
      }
      
      return await prefs.setStringList(_cartKey, cartJson);
    } catch (e) {
      debugPrint('Error adding to cart: $e');
      return false;
    }
  }
  
  // Remove a product from the cart
  Future<bool> removeFromCart(ProductInfo product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getStringList(_cartKey) ?? [];
      
      final existingProductIndex = _findProductIndex(cartJson, product);
      
      if (existingProductIndex != -1) {
        cartJson.removeAt(existingProductIndex);
        return await prefs.setStringList(_cartKey, cartJson);
      }
      
      return true; // Product wasn't in cart, so removal is "successful"
    } catch (e) {
      debugPrint('Error removing from cart: $e');
      return false;
    }
  }
  
  // Check if a product is in the cart
  Future<bool> isInCart(ProductInfo product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getStringList(_cartKey) ?? [];
      
      return _findProductIndex(cartJson, product) != -1;
    } catch (e) {
      debugPrint('Error checking cart: $e');
      return false;
    }
  }
  
  // Clear the entire cart
  Future<bool> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setStringList(_cartKey, []);
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      return false;
    }
  }
  
  // Get the number of items in the cart
  Future<int> getCartItemCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getStringList(_cartKey) ?? [];
      return cartJson.length;
    } catch (e) {
      debugPrint('Error getting cart count: $e');
      return 0;
    }
  }
  
  // Helper method to find a product in the cart
  int _findProductIndex(List<String> cartJson, ProductInfo product) {
    for (int i = 0; i < cartJson.length; i++) {
      try {
        final Map<String, dynamic> productMap = jsonDecode(cartJson[i]);
        final cartProduct = ProductInfo.fromJson(productMap);
        
        // Compare by URL or unique identifier if available
        if (cartProduct.url == product.url) {
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