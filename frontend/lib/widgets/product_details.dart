// lib/widgets/product_details.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/product_info.dart';
import '../models/variant_option.dart';
import '../services/cart_service.dart';
import '../services/favorites_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'cached_image_widget.dart';

class ProductDetailsBottomSheet extends StatefulWidget {
  final ProductInfo productInfo;

  const ProductDetailsBottomSheet({
    Key? key,
    required this.productInfo,
  }) : super(key: key);

  @override
  State<ProductDetailsBottomSheet> createState() =>
      _ProductDetailsBottomSheetState();
}

class _ProductDetailsBottomSheetState extends State<ProductDetailsBottomSheet> {
  final CartService _cartService = CartService();
  final FavoritesService _favoritesService = FavoritesService();
  bool _isInCart = false;
  bool _isInFavorites = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkProductStatus();
    _debugLogProductInfo();
  }

  void _debugLogProductInfo() {
    debugPrint('[PRODUCT_DETAILS] Product title: ${widget.productInfo.title}');
    debugPrint('[PRODUCT_DETAILS] Product brand: ${widget.productInfo.brand}');

    if (widget.productInfo.imageUrl != null) {
      debugPrint(
          '[PRODUCT_DETAILS] Product image URL: ${widget.productInfo.imageUrl}');
    } else {
      debugPrint('[PRODUCT_DETAILS] No product image URL available');
    }

    if (widget.productInfo.variants != null) {
      final variants = widget.productInfo.variants!;

      // Debug log for variants
      debugPrint('[PD][DEBUG] Variants data: ${variants.keys.join(", ")}');

      if (variants.containsKey('colors') && variants['colors']!.isNotEmpty) {
        debugPrint(
            '[PD][DEBUG] Color variants count: ${variants['colors']!.length}');
        for (final color in variants['colors']!) {
          debugPrint(
              '[PD][DEBUG] Color: ${color.text}, Selected: ${color.selected}, Value: ${color.value}');
        }
      } else {
        debugPrint('[PD][DEBUG] No color variants found');
      }

      if (variants.containsKey('sizes') && variants['sizes']!.isNotEmpty) {
        debugPrint(
            '[PD][DEBUG] Size variants count: ${variants['sizes']!.length}');
        for (final size in variants['sizes']!) {
          debugPrint(
              '[PD][DEBUG] Size: ${size.text}, Selected: ${size.selected}, Value: ${size.value}');

          // Try to parse the value if it's JSON
          if (size.value != null && size.value!.startsWith('{')) {
            try {
              final valueMap = jsonDecode(size.value!);
              debugPrint('[PD][DEBUG] Size value parsed: $valueMap');
            } catch (e) {
              debugPrint('[PD][DEBUG] Failed to parse size value: $e');
            }
          }
        }
      } else {
        debugPrint('[PD][DEBUG] No size variants found');
      }
    } else {
      debugPrint('[PD][DEBUG] No variants data available');
    }
  }

  Future<void> _checkProductStatus() async {
    setState(() {
      _isLoading = true;
    });

    final inCart = await _cartService.isInCart(widget.productInfo);
    final inFavorites =
        await _favoritesService.isInFavorites(widget.productInfo);

    setState(() {
      _isInCart = inCart;
      _isInFavorites = inFavorites;
      _isLoading = false;
    });
  }

  Future<void> _addToCart() async {
    setState(() {
      _isLoading = true;
    });

    final success = await _cartService.addToCart(widget.productInfo);

    setState(() {
      _isInCart = success;
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to cart'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add to cart'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeFromCart() async {
    setState(() {
      _isLoading = true;
    });

    final success = await _cartService.removeFromCart(widget.productInfo);

    setState(() {
      _isInCart = !success;
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from cart'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove from cart'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() {
      _isLoading = true;
    });

    bool success;
    if (_isInFavorites) {
      success = await _favoritesService.removeFromFavorites(widget.productInfo);
      if (success) {
        _isInFavorites = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from favorites'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      success = await _favoritesService.addToFavorites(widget.productInfo);
      if (success) {
        _isInFavorites = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to favorites'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildInfoRow(String label, String value, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: style,
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced color variant section with improved RGB color handling
  Widget _buildColorVariants(List<VariantOption> colorOptions) {
    debugPrint(
        '[PD][DEBUG] Building color variants: ${colorOptions.length} options');

    // Filter out nonsensical or placeholder options
    final filteredOptions = colorOptions.where((option) {
      final String lowerText = option.text.toLowerCase().trim();

      // Log each option for debugging
      debugPrint('[PD][DEBUG] Checking color option: "$lowerText"');

      // Skip options that don't look like real colors or are UI elements
      if (lowerText.contains('select') ||
          lowerText.contains('choose') ||
          lowerText.contains('preference') ||
          lowerText.contains('privacy') ||
          lowerText.contains('company logo') ||
          lowerText.contains('i\'d rather not say')) {
        debugPrint('[PD][DEBUG] Filtering out non-color option: "$lowerText"');
        return false;
      }

      return true;
    }).toList();

    // If no valid options after filtering, don't show the section
    if (filteredOptions.isEmpty) {
      debugPrint('[PD][DEBUG] No valid color options after filtering');
      return const SizedBox.shrink();
    }

    debugPrint(
        '[PD][DEBUG] Displaying ${filteredOptions.length} color options');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Colors',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: filteredOptions.map((option) {
            final String colorText = option.text;
            final bool isSelected = option.selected;

            // Try to parse RGB color from value if it exists
            Color? colorFromRGB;
            if (option.value != null && option.value!.contains('rgb')) {
              colorFromRGB = _parseRgbColor(option.value!);
              debugPrint(
                  '[PD][DEBUG] Parsed RGB color for $colorText: $colorFromRGB');
            }

            // Check if the variant has an image URL
            final bool hasImageUrl = option.value != null &&
                (option.value!.startsWith('http') ||
                    option.value!.startsWith('//'));

            // Use parsed RGB color if available, otherwise try to extract from name
            final Color displayColor =
                colorFromRGB ?? _extractColorFromName(colorText) ?? Colors.grey;

            // If using image URL
            if (hasImageUrl) {
              final imageUrl = _fixImageUrl(option.value!);
              debugPrint(
                  '[PD][DEBUG] Using image URL for color $colorText: $imageUrl');

              return Stack(
                children: [
                  // Color swatch with image
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected color: $colorText')),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              isSelected ? Colors.black : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: CachedImageWidget(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          brandName: widget.productInfo.brand,
                          colorName: colorText,
                        ),
                      ),
                    ),
                  ),

                  // Selection indicator
                  if (isSelected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // Color name below swatch
                  Positioned(
                    bottom: -20,
                    left: 0,
                    right: 0,
                    child: Text(
                      colorText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }
            // If using color
            else {
              return Column(
                children: [
                  // Color swatch
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected color: $colorText')),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: displayColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isSelected ? Colors.black : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Center(
                              child: Icon(
                                Icons.check,
                                color: _isLightColor(displayColor)
                                    ? Colors.black
                                    : Colors.white,
                                size: 20,
                              ),
                            )
                          : null,
                    ),
                  ),

                  // Color name
                  SizedBox(height: 4),
                  SizedBox(
                    width: 52,
                    child: Text(
                      colorText,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade800,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }
          }).toList(),
        ),
        SizedBox(height: 24), // Add some space below color section
      ],
    );
  }

  // Enhanced size variant display for Zara
  Widget _buildSizeVariants(List<VariantOption> sizeOptions) {
    debugPrint(
        '[PD][DEBUG] Building size variants: ${sizeOptions.length} options');

    // Filter out nonsensical or placeholder options
    final filteredOptions = sizeOptions.where((option) {
      final String lowerText = option.text.toLowerCase().trim();

      // Log each option for debugging
      debugPrint('[PD][DEBUG] Checking size option: "$lowerText"');

      // Skip options that look like placeholders or form fields
      if (lowerText.contains('select') ||
          lowerText.contains('choose') ||
          lowerText.contains('i\'d rather not say')) {
        debugPrint('[PD][DEBUG] Filtering out non-size option: "$lowerText"');
        return false;
      }

      return true;
    }).toList();

    // If no valid options after filtering, don't show the section
    if (filteredOptions.isEmpty) {
      debugPrint('[PD][DEBUG] No valid size options after filtering');
      return const SizedBox.shrink();
    }

    debugPrint('[PD][DEBUG] Displaying ${filteredOptions.length} size options');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Sizes',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filteredOptions.map((option) {
            // Parse inStock information from value
            bool isInStock =
                true; // Default to true unless explicitly marked false

            if (option.value != null) {
              try {
                // Check different formats of how stock info might be stored
                if (option.value!.contains('"inStock"') ||
                    option.value!.contains("'inStock'")) {
                  // For the JSON format from Zara extractor
                  final valueMap =
                      jsonDecode(option.value!) as Map<String, dynamic>;
                  isInStock = valueMap['inStock'] ?? true;
                  debugPrint(
                      '[PD][DEBUG] Size ${option.text} inStock status: $isInStock (from JSON)');
                } else if (option.value!.contains('out of stock') ||
                    option.value!.contains('unavailable') ||
                    option.value!.contains('sold out')) {
                  // Text-based indicators
                  isInStock = false;
                  debugPrint(
                      '[PD][DEBUG] Size ${option.text} marked as out of stock (from text)');
                }
              } catch (e) {
                debugPrint(
                    '[PD][DEBUG] Error parsing size value for ${option.text}: $e');
                // If parse fails, assume it's in stock
              }
            }

            return InkWell(
              onTap: isInStock
                  ? () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Selected size: ${option.text}')),
                      );
                    }
                  : () {
                      // Show a message that the size is unavailable
                      HapticFeedback.heavyImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Size ${option.text} is out of stock'),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    },
              borderRadius: BorderRadius.circular(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: !isInStock
                        ? Colors.grey.shade300
                        : option.selected
                            ? Colors.black
                            : Colors.grey.shade300,
                    width: option.selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: !isInStock
                      ? Colors.grey.shade100
                      : option.selected
                          ? Colors.black.withOpacity(0.05)
                          : Colors.white,
                ),
                child: Stack(
                  children: [
                    Text(
                      option.text,
                      style: TextStyle(
                        fontWeight: option.selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: !isInStock
                            ? Colors.grey.shade400
                            : option.selected
                                ? Colors.black
                                : Colors.black87,
                        decoration:
                            !isInStock ? TextDecoration.lineThrough : null,
                      ),
                    ),

                    // Show a small indicator for out of stock sizes
                    if (!isInStock)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.remove,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatAvailability(String? availability) {
    if (availability == null) return 'In Stock';

    if (availability.contains('schema.org/InStock')) {
      return 'In Stock';
    } else if (availability.contains('schema.org/OutOfStock')) {
      return 'Out of Stock';
    } else if (availability.contains('schema.org/LimitedAvailability')) {
      return 'Limited Availability';
    } else if (availability.contains('schema.org/PreOrder')) {
      return 'Pre-Order';
    }

    return availability;
  }

  @override
  Widget build(BuildContext context) {
    final productHasBrand = widget.productInfo.brand != null &&
        widget.productInfo.brand!.isNotEmpty;
    final isZara = widget.productInfo.brand?.toLowerCase() == 'zara' ||
        widget.productInfo.url.toLowerCase().contains('zara.com');

    // Log initial variant state
    debugPrint('[PD][DEBUG] Building product details');
    if (widget.productInfo.variants != null) {
      debugPrint(
          '[PD][DEBUG] Has variants: ${widget.productInfo.variants!.keys.join(", ")}');
      if (widget.productInfo.variants!.containsKey('colors')) {
        debugPrint(
            '[PD][DEBUG] Colors count: ${widget.productInfo.variants!["colors"]?.length ?? 0}');
      }
      if (widget.productInfo.variants!.containsKey('sizes')) {
        debugPrint(
            '[PD][DEBUG] Sizes count: ${widget.productInfo.variants!["sizes"]?.length ?? 0}');
      }
    } else {
      debugPrint('[PD][DEBUG] No variants available');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and close button
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.productInfo.title ?? 'Product Details',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),

          // Product details
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image with improved handling
                  if (widget.productInfo.imageUrl != null)
                    Container(
                      height: 240,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedImageWidget(
                          imageUrl: _fixImageUrl(widget.productInfo.imageUrl!),
                          fit: BoxFit.contain,
                          brandName: widget.productInfo.brand,
                          productTitle: widget.productInfo.title,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Brand info (if available)
                  if (productHasBrand)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.productInfo.brand!,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Price information
                  _buildInfoRow('Price:', widget.productInfo.formattedPrice,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  if (widget.productInfo.originalPrice != null)
                    _buildInfoRow('Original Price:',
                        widget.productInfo.formattedOriginalPrice,
                        style: const TextStyle(
                            decoration: TextDecoration.lineThrough)),

                  // Availability if present
                  if (widget.productInfo.availability != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Text(
                            'Availability:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _formatAvailability(
                                          widget.productInfo.availability) ==
                                      'In Stock'
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatAvailability(
                                  widget.productInfo.availability),
                              style: TextStyle(
                                color: _formatAvailability(
                                            widget.productInfo.availability) ==
                                        'In Stock'
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Color variants with improved display
                  if (widget.productInfo.variants != null &&
                      widget.productInfo.variants!.containsKey('colors') &&
                      widget.productInfo.variants!['colors']!.isNotEmpty)
                    _buildColorVariants(widget.productInfo.variants!['colors']!)
                  else
                    Container(), // Empty container when no colors

                  // Size variants with improved display
                  if (widget.productInfo.variants != null &&
                      widget.productInfo.variants!.containsKey('sizes') &&
                      widget.productInfo.variants!['sizes']!.isNotEmpty)
                    _buildSizeVariants(widget.productInfo.variants!['sizes']!)
                  else
                    Container(), // Empty container when no sizes

                  // SKU if available
                  if (widget.productInfo.sku != null &&
                      widget.productInfo.sku!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'SKU: ${widget.productInfo.sku}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),

                  // Description - only show if not empty and not null
                  if (widget.productInfo.description != null &&
                      widget.productInfo.description!.trim().isNotEmpty &&
                      !widget.productInfo.description!
                          .contains('schema.org')) ...[
                    const SizedBox(height: 24),
                    const Text('Description',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      widget.productInfo.description!,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    _isInFavorites ? Icons.favorite : Icons.favorite_border,
                    color: _isInFavorites ? Colors.red : null,
                  ),
                  label: Text(_isInFavorites ? 'Saved' : 'Favorite'),
                  onPressed: _isLoading ? null : _toggleFavorite,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _isInCart
                        ? ElevatedButton.icon(
                            icon: const Icon(Icons.remove_shopping_cart),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                            ),
                            label: const Text('Remove'),
                            onPressed: _removeFromCart,
                          )
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.shopping_cart),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            label: const Text('Add to Cart'),
                            onPressed: _addToCart,
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to fix image URLs
  String _fixImageUrl(String url) {
    // Handle protocol-relative URLs (//media.gucci.com/...)
    if (url.startsWith('//')) {
      return 'https:$url';
    }

    // Handle relative URLs (without domain)
    if (url.startsWith('/') && !url.startsWith('//')) {
      // Determine the domain based on URL patterns
      String domain = 'www.gucci.com';
      if (url.contains('/tr/')) {
        domain = 'www.gucci.com/tr';
      } else if (widget.productInfo.url.contains('zara.com')) {
        domain = 'www.zara.com';
      }

      return 'https://$domain$url';
    }

    return url;
  }

  // Helper function to parse RGB color string
  Color? _parseRgbColor(String value) {
    if (!value.contains('rgb')) return null;

    try {
      // Format: rgb(R, G, B)
      final rgbRegex = RegExp(r'rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)');
      final match = rgbRegex.firstMatch(value);

      if (match != null && match.groupCount >= 3) {
        final r = int.parse(match.group(1)!);
        final g = int.parse(match.group(2)!);
        final b = int.parse(match.group(3)!);
        return Color.fromRGBO(r, g, b, 1.0);
      }
    } catch (e) {
      debugPrint('[PD][DEBUG] Failed to parse RGB value: $e');
    }

    return null;
  }

  // Extract a color from a color name
  Color? _extractColorFromName(String colorName) {
    final Map<String, Color> commonColors = {
      'black': Colors.black,
      'white': Colors.white,
      'red': Colors.red.shade800,
      'blue': Colors.blue.shade800,
      'navy': Colors.indigo.shade900,
      'green': Colors.green.shade800,
      'olive': const Color.fromARGB(255, 16, 82, 16),
      'yellow': Colors.amber,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'pink': Colors.pink,
      'grey': Colors.grey,
      'gray': Colors.grey,
      'silver': Colors.grey.shade300,
      'gold': Color(0xFFD4AF37),
      'brown': Color(0xFF795548),
      'tan': Color(0xFFD2B48C),
      'beige': Color(0xFFF5F5DC),
      'ivory': Color(0xFFFFFFF0),
      'cream': Color(0xFFFFFDD0),
      'khaki': Color(0xFFC3B091),
      'maroon': Color(0xFF800000),
      'burgundy': Color(0xFF800020),
      'teal': Color(0xFF008080),
      'turquoise': Color(0xFF40E0D0),
      'violet': Color(0xFF8000FF),
      'lavender': Color(0xFFE6E6FA),
      'magenta': Color(0xFFFF00FF),
      'coral': Color(0xFFFF7F50),
      'mint': Color(0xFF98FB98),
      'rose': Color(0xFFFF007F),
      'mustard': Color(0xFFE1AD01),
      'taupe': Color(0xFF483C32),
      'natural': Color(0xFFE8D4AD),
      'ecru': Color(0xFFD3D3A4),
    };

    // Convert to lowercase for case-insensitive matching
    final lowerColorName = colorName.toLowerCase();

    // Check exact match
    for (final entry in commonColors.entries) {
      if (lowerColorName == entry.key) {
        return entry.value;
      }
    }

    // Check partial match (color name might be like "Dark Blue" or "Navy Blue")
    for (final entry in commonColors.entries) {
      if (lowerColorName.contains(entry.key)) {
        // For partial matches, we might want to modify the color based on modifiers
        if (lowerColorName.contains('dark') ||
            lowerColorName.contains('deep')) {
          return _darkenColor(entry.value);
        } else if (lowerColorName.contains('light') ||
            lowerColorName.contains('pale')) {
          return _lightenColor(entry.value);
        }
        return entry.value;
      }
    }

    // No match found
    return null;
  }

  // Darken a color
  Color _darkenColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
  }

  // Lighten a color
  Color _lightenColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
  }

  bool _isLightColor(Color color) {
    // Calculate the perceived brightness
    final brightness =
        (299 * color.red + 587 * color.green + 114 * color.blue) / 1000;
    return brightness > 128;
  }
}
