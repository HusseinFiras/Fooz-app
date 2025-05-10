// lib/widgets/product_details.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math'; // Add import for min function
import '../models/product_info.dart';
import '../models/variant_option.dart';
import '../services/cart_service.dart';
import '../services/favorites_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'cached_image_widget.dart';
import '../screens/webview_screen.dart'; // Import WebView screen

class ProductDetailsBottomSheet extends StatefulWidget {
  final ProductInfo productInfo;
  final bool fromCart;
  final bool fromWebView; // Add this parameter
  final Function? onProductUpdated; // Add callback for notifying parent

  const ProductDetailsBottomSheet({
    Key? key,
    required this.productInfo,
    this.fromCart = false,
    this.fromWebView = false, // Default to false
    this.onProductUpdated, // Optional callback
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
  
  // Track selected variants
  String? _selectedColorText;
  String? _selectedSizeText;
  VariantOption? _selectedColor;
  VariantOption? _selectedSize;
  bool _selectionChanged = false; // Track if user has changed selections
  
  // Track color-specific URLs for Pandora products
  Map<String, String> _colorUrls = {};
  String? _selectedColorUrl;

  @override
  void initState() {
    super.initState();
    _checkProductStatus();
    _logBasicProductInfo();
    _initSelectedVariants();
    _extractColorUrls();
  }

  void _initSelectedVariants() {
    // Initialize selected variants from product info's preselected variants
    if (widget.productInfo.variants != null) {
      final variants = widget.productInfo.variants!;
      
      // Debug: Log all variant keys to see what's available
      debugPrint('[PD] Available variant types: ${variants.keys.join(', ')}');
      
      // Find initially selected color
      if (variants.containsKey('colors') && variants['colors'] != null) {
        debugPrint('[PD] Found ${variants['colors']!.length} colors in ProductInfo');
        // Log the first few colors for debugging
        for (int i = 0; i < min(variants['colors']!.length, 3); i++) {
          final color = variants['colors']![i];
          debugPrint('[PD] Color ${i+1}: ${color.text}, selected: ${color.selected}, value: ${color.value}');
        }
        
        for (final color in variants['colors']!) {
          if (color.selected) {
            _selectedColor = color;
            _selectedColorText = color.text;
            debugPrint('[PD] Selected color: ${color.text}');
            break;
          }
        }
      } else {
        debugPrint('[PD] ⚠️ No colors found in ProductInfo');
      }
      
      // Find initially selected size
      if (variants.containsKey('sizes') && variants['sizes'] != null) {
        debugPrint('[PD] Found ${variants['sizes']!.length} sizes in ProductInfo');
        // Log the first few sizes for debugging
        for (int i = 0; i < min(variants['sizes']!.length, 3); i++) {
          final size = variants['sizes']![i];
          debugPrint('[PD] Size ${i+1}: ${size.text}, selected: ${size.selected}, value: ${size.value}');
        }
        
        for (final size in variants['sizes']!) {
          if (size.selected) {
            _selectedSize = size;
            _selectedSizeText = size.text;
            debugPrint('[PD] Selected size: ${size.text}');
            break;
          }
        }
      } else {
        debugPrint('[PD] ⚠️ No sizes found in ProductInfo');
      }
    } else {
      debugPrint('[PD] ⚠️ No variants data in ProductInfo');
    }
  }

  void _logBasicProductInfo() {
    debugPrint('[PD] Product loaded: ${widget.productInfo.title}');
    
    if (widget.productInfo.variants != null) {
      final variants = widget.productInfo.variants!;
      
      // Log basic variant information
      if (variants.containsKey('colors') && variants['colors'] != null) {
        debugPrint('[PD] Found ${variants['colors']!.length} color variants');
      }

      if (variants.containsKey('sizes') && variants['sizes'] != null) {
        debugPrint('[PD] Found ${variants['sizes']!.length} size variants');
      }
    } else {
      debugPrint('[PD] No variants data available');
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

    // Create a copy of the product info with selected variants
    final productWithSelections = _getProductWithSelectedVariants();

    // If product is already in cart, update it instead of adding a duplicate
    if (_isInCart) {
      // Remove existing version first
      await _cartService.removeFromCart(widget.productInfo);
    }
    
    // Add the product with current selections
    final success = await _cartService.addToCart(productWithSelections);

    setState(() {
      _isInCart = success;
      _isLoading = false;
      _selectionChanged = false; // Reset selection changed flag
    });

    // Notify parent if callback exists
    if (widget.onProductUpdated != null) {
      widget.onProductUpdated!();
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added to cart with ${_getVariantSelectionSummary()}'),
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

  // Helper method to create a new ProductInfo with the selected variants
  ProductInfo _getProductWithSelectedVariants() {
    // Start with a copy of the original variants
    Map<String, List<VariantOption>> selectedVariants = {};
    
    if (widget.productInfo.variants != null) {
      // Copy existing variants
      widget.productInfo.variants!.forEach((key, variantList) {
        // Create a new list to avoid modifying the original
        selectedVariants[key] = List<VariantOption>.from(variantList);
      });
    } else {
      selectedVariants = {};
    }
    
    // Update with selected variants
    if (_selectedColor != null && selectedVariants.containsKey('colors')) {
      selectedVariants['colors'] = selectedVariants['colors']!.map((option) {
        return VariantOption(
          text: option.text,
          selected: option.text == _selectedColorText,
          value: option.value,
        );
      }).toList();
    }
    
    if (_selectedSize != null && selectedVariants.containsKey('sizes')) {
      selectedVariants['sizes'] = selectedVariants['sizes']!.map((option) {
        return VariantOption(
          text: option.text,
          selected: option.text == _selectedSizeText,
          value: option.value,
        );
      }).toList();
    }
    
    // Create a new ProductInfo with the updated selections
    return ProductInfo(
      isProductPage: widget.productInfo.isProductPage,
      title: widget.productInfo.title,
      price: widget.productInfo.price,
      originalPrice: widget.productInfo.originalPrice,
      currency: widget.productInfo.currency,
      imageUrl: widget.productInfo.imageUrl,
      description: widget.productInfo.description,
      sku: widget.productInfo.sku,
      availability: widget.productInfo.availability,
      brand: widget.productInfo.brand,
      extractionMethod: widget.productInfo.extractionMethod,
      url: widget.productInfo.url,
      success: widget.productInfo.success,
      variants: selectedVariants,
    );
  }

  // Helper method to get a text summary of the selected variants
  String _getVariantSelectionSummary() {
    List<String> selections = [];
    
    if (_selectedColorText != null) {
      selections.add('Color: $_selectedColorText');
    }
    
    if (_selectedSizeText != null) {
      selections.add('Size: $_selectedSizeText');
    }
    
    return selections.isEmpty ? 'no selections' : selections.join(', ');
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

    // Notify parent if callback exists
    if (widget.onProductUpdated != null) {
      widget.onProductUpdated!();
    }

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

    // Get the product with current selections
    final productWithSelections = _getProductWithSelectedVariants();
    bool success;

    if (_isInFavorites) {
      // Remove from favorites
      success = await _favoritesService.removeFromFavorites(widget.productInfo);
      if (success) {
        _isInFavorites = false;
        _selectionChanged = false; // Reset selection changed flag
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from favorites'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Add to favorites with selected variants
      success = await _favoritesService.addToFavorites(productWithSelections);
      if (success) {
        _isInFavorites = true;
        _selectionChanged = false; // Reset selection changed flag
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to favorites'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    // Notify parent if callback exists
    if (widget.onProductUpdated != null) {
      widget.onProductUpdated!();
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Update the cart or favorites when selection changes
  Future<void> _updateProductWithSelections() async {
    if (!_selectionChanged) return; // Only update if selections were changed
    
    // Create updated product with the new selections
    final updatedProduct = _getProductWithSelectedVariants();
    
    // If item is in cart, update it
    if (_isInCart) {
      // First remove the old version
      await _cartService.removeFromCart(widget.productInfo);
      // Then add the updated version
      await _cartService.addToCart(updatedProduct);
      debugPrint('[PD] Updated cart item with new selections');
    }
    
    // If item is in favorites, update it
    if (_isInFavorites) {
      await _favoritesService.removeFromFavorites(widget.productInfo);
      await _favoritesService.addToFavorites(updatedProduct);
      debugPrint('[PD] Updated favorite item with new selections');
    }
    
    _selectionChanged = false; // Reset the flag
    
    // Notify parent if callback exists
    if (widget.onProductUpdated != null) {
      widget.onProductUpdated!();
    }
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
    debugPrint('[PD] Building UI for ${colorOptions.length} color options');

    // Filter out nonsensical or placeholder options
    final filteredOptions = colorOptions.where((option) {
      final String lowerText = option.text.toLowerCase().trim();

      // Skip options that don't look like real colors or are UI elements
      if (lowerText.contains('select') ||
          lowerText.contains('choose') ||
          lowerText.contains('preference') ||
          lowerText.contains('privacy') ||
          lowerText.contains('company logo') ||
          lowerText.contains('i\'d rather not say')) {
        return false;
      }

      return true;
    }).toList();

    // If no valid options after filtering, don't show the section
    if (filteredOptions.isEmpty) {
      debugPrint('[PD] No valid color options to display');
      return const SizedBox.shrink();
    }

    // For Zara products, try to extract and display all listed colors
    bool isZara = widget.productInfo.brand?.toLowerCase() == 'zara' ||
        widget.productInfo.url.toLowerCase().contains('zara.com');
        
    // For Stradivarius products
    bool isStradivarius = widget.productInfo.brand?.toLowerCase() == 'stradivarius' ||
        widget.productInfo.url.toLowerCase().contains('stradivarius.com');
        
    // For Pandora products - special handling for metals as colors
    bool isPandora = widget.productInfo.brand?.toLowerCase() == 'pandora' ||
        widget.productInfo.url.toLowerCase().contains('pandora.net');
        
    // For Pandora products, we'll only show the selected color
    List<VariantOption> displayOptions = filteredOptions;
    
    // Special handling for Pandora - only show selected color
    if (isPandora) {
      // Find the selected color
      final selectedOptions = filteredOptions.where((option) => option.selected).toList();
      
      // If we found a selected color, only show that one
      if (selectedOptions.isNotEmpty) {
        displayOptions = selectedOptions;
        debugPrint('[PD] Pandora: Showing only selected color: ${selectedOptions.first.text}');
      } else if (_selectedColorText != null) {
        // If we have a selected color in state but not in the options, find it
        final matchingOptions = filteredOptions.where((option) => 
          option.text == _selectedColorText).toList();
        
        if (matchingOptions.isNotEmpty) {
          displayOptions = matchingOptions;
          debugPrint('[PD] Pandora: Showing only matched color: ${matchingOptions.first.text}');
        } else {
          // Show the first color if no selected color found
          displayOptions = [filteredOptions.first];
          debugPrint('[PD] Pandora: No selected color found, showing first color');
        }
      } else {
        // Show the first color if no selected color found
        displayOptions = [filteredOptions.first];
        debugPrint('[PD] Pandora: No selected color found, showing first color');
      }
    }
        
    // Special title for metals if this is Pandora
    String sectionTitle = 'Colors';
    if (isPandora) {
      sectionTitle = 'Colors';
      
      if (filteredOptions.first.text.toLowerCase().contains('gold') ||
          filteredOptions.first.text.toLowerCase().contains('silver') ||
          filteredOptions.first.text.toLowerCase().contains('metal') ||
          filteredOptions.first.text.toLowerCase().contains('altın') ||
          filteredOptions.first.text.toLowerCase().contains('gümüş')) {
        sectionTitle = 'Metal';
      }
      
      debugPrint('[PD] Displaying Pandora colors/metals');
      
      // Debug logging for Pandora color variants
      if (filteredOptions.isNotEmpty) {
        debugPrint('[PD] First Pandora color option details:');
        for (var option in filteredOptions) {
          if (option.value != null) {
            debugPrint('[PD] Color: ${option.text}, Value type: ${option.value!.startsWith('{') ? 'JSON' : 'String'}');
            if (option.value!.startsWith('{')) {
              try {
                final colorData = jsonDecode(option.value!);
                debugPrint('[PD] Color data: ${colorData['colorName']}, class: ${colorData['colorClass']}, image: ${colorData['imageUrl'] != null ? 'available' : 'none'}');
              } catch (e) {
                debugPrint('[PD] Failed to parse color JSON: $e');
              }
            }
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Text(
                sectionTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (_selectedColorText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    '($_selectedColorText)',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: displayOptions.map((option) {
            final String colorText = option.text;
            final bool isSelected = colorText == _selectedColorText;

            // Try to parse RGB color from value if it exists
            Color? colorFromRGB;
            if (option.value != null && option.value!.contains('rgb')) {
              colorFromRGB = _parseRgbColor(option.value!);
            }

            // Check if the variant has an image URL or JSON color data
            bool hasImageUrl = false;
            String? imageUrl;
            String? colorClassName;
            
            // Process JSON data if available (used by Pandora)
            if (option.value != null && option.value!.startsWith('{')) {
              try {
                final colorData = jsonDecode(option.value!);
                
                // Extract image URL
                if (colorData['imageUrl'] != null && colorData['imageUrl'].toString().isNotEmpty) {
                  imageUrl = colorData['imageUrl'].toString();
                  hasImageUrl = true;
                }
                
                // Extract color class name for Pandora colors
                if (colorData['colorClass'] != null) {
                  colorClassName = colorData['colorClass'].toString();
                  debugPrint('[PD] Found color class: $colorClassName for $colorText');
                }
              } catch (e) {
                debugPrint('[PD] Error parsing color JSON: $e');
              }
            } 
            // Check for direct image URL
            else if (option.value != null && 
                (option.value!.startsWith('http') || option.value!.startsWith('//'))) {
              imageUrl = option.value;
              hasImageUrl = true;
            }
            
            // For Pandora: Apply color based on class name or color text
            if (isPandora) {
              final lowerColorText = colorText.toLowerCase();
              
              // First try to use colorClassName if available
              if (colorClassName != null) {
                if (colorClassName == 'red') {
                  colorFromRGB = Colors.red.shade600;
                } else if (colorClassName == 'black') {
                  colorFromRGB = Colors.black;
                } else if (colorClassName == 'pink') {
                  colorFromRGB = Colors.pink.shade300;
                } else if (colorClassName == 'clear') {
                  colorFromRGB = Colors.white;
                }
              }
              // Fallback to text-based matching
              else if (lowerColorText.contains('red') || lowerColorText.contains('kırmızı')) {
                colorFromRGB = Colors.red.shade600;
              } else if (lowerColorText.contains('black') || lowerColorText.contains('siyah')) {
                colorFromRGB = Colors.black;
              } else if (lowerColorText.contains('pink') || lowerColorText.contains('pembe')) {
                colorFromRGB = Colors.pink.shade300;
              } else if (lowerColorText.contains('clear') || lowerColorText.contains('şeffaf')) {
                colorFromRGB = Colors.white;
              } else if (lowerColorText.contains('silver') || lowerColorText.contains('gümüş')) {
                colorFromRGB = Color(0xFFCCCCCC);
              } else if (lowerColorText.contains('gold') || lowerColorText.contains('altın')) {
                colorFromRGB = Color(0xFFD4AF37);
              } else if (lowerColorText.contains('rose gold') || lowerColorText.contains('pembe altın')) {
                colorFromRGB = Color(0xFFB76E79);
              }
              
              // If we couldn't determine the color yet, use a mapping based on the Turkish color names
              if (colorFromRGB == null) {
                // Map between Turkish color names and colors
                final Map<String, Color> turkishColorMap = {
                  'kırmızı': Colors.red.shade600,
                  'siyah': Colors.black,
                  'pembe': Colors.pink.shade300,
                  'şeffaf': Colors.white,
                  'gümüş': Color(0xFFCCCCCC),
                  'altın': Color(0xFFD4AF37),
                  'mavi': Colors.blue.shade600,
                  'yeşil': Colors.green.shade600,
                  'sarı': Colors.yellow.shade600,
                  'mor': Colors.purple.shade600,
                  'turuncu': Colors.orange.shade600,
                  'kahverengi': Colors.brown.shade600,
                  'bej': Color(0xFFF5F5DC),
                  'gri': Colors.grey,
                };
                
                // Check color text against Turkish color map
                for (final entry in turkishColorMap.entries) {
                  if (lowerColorText.contains(entry.key)) {
                    colorFromRGB = entry.value;
                    break;
                  }
                }
              }
            }

            // Use parsed RGB color if available, otherwise try to extract from name
            final Color displayColor =
                colorFromRGB ?? _extractColorFromName(colorText) ?? Colors.grey;

            // If using image URL - this is for sites like Stradivarius or Pandora that provide color/metal images
            if (hasImageUrl && imageUrl != null) {
              final fixedImageUrl = _fixImageUrl(imageUrl);
              
              // For Pandora, we'll use color swatches directly instead of trying to load images
              if (isPandora) {
                return Column(
                  children: [
                    // Color swatch
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedColorText = colorText;
                          _selectedColor = option;
                          _selectionChanged = true; // Mark that a change was made
                          
                          // For Pandora: Store selected color URL if available
                          if (_colorUrls.containsKey(colorText)) {
                            _selectedColorUrl = _colorUrls[colorText];
                            debugPrint('[PD] Selected Pandora color URL: $_selectedColorUrl');
                            
                            // TODO: In a future implementation, could fetch sizes for this specific color
                            // _updateSizesForSelectedColor(_selectedColorUrl);
                          }
                        });
                        
                        // Update cart/favorites immediately if selection changes
                        _updateProductWithSelections();
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Selected ${isPandora && sectionTitle == 'Metal' ? "metal" : "color"}: $colorText')),
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
                            color: isSelected ? Colors.black : Colors.grey.shade300,
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

              // For other sites, use the image approach
              return Stack(
                children: [
                  // Color swatch with image
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedColorText = colorText;
                        _selectedColor = option;
                        _selectionChanged = true; // Mark that a change was made
                        
                        // For Pandora: Store selected color URL if available
                        if (isPandora && _colorUrls.containsKey(colorText)) {
                          _selectedColorUrl = _colorUrls[colorText];
                          debugPrint('[PD] Selected Pandora color URL: $_selectedColorUrl');
                          
                          // TODO: In a future implementation, could fetch sizes for this specific color
                          // _updateSizesForSelectedColor(_selectedColorUrl);
                        }
                      });
                      
                      // Update cart/favorites immediately if selection changes
                      _updateProductWithSelections();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected ${isPandora && sectionTitle == 'Metal' ? "metal" : "color"}: $colorText')),
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
                          imageUrl: fixedImageUrl,
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
                      setState(() {
                        _selectedColorText = colorText;
                        _selectedColor = option;
                        _selectionChanged = true; // Mark that a change was made
                        
                        // For Pandora: Store selected color URL if available
                        if (isPandora && _colorUrls.containsKey(colorText)) {
                          _selectedColorUrl = _colorUrls[colorText];
                          debugPrint('[PD] Selected Pandora color URL: $_selectedColorUrl');
                          
                          // TODO: In a future implementation, could fetch sizes for this specific color
                          // _updateSizesForSelectedColor(_selectedColorUrl);
                        }
                      });
                      
                      // Update cart/favorites immediately if selection changes
                      _updateProductWithSelections();
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected ${isPandora && sectionTitle == 'Metal' ? "metal" : "color"}: $colorText')),
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

  // Enhanced size variant display
  Widget _buildSizeVariants(List<VariantOption> sizeOptions) {
    debugPrint('[PD] Building UI for ${sizeOptions.length} size options');
    
    // For Pandora - check if we've parsed sizes already
    final isPandora = widget.productInfo.brand?.toLowerCase() == 'pandora' ||
        widget.productInfo.url.toLowerCase().contains('pandora.net');
    
    // Check if Zara product for specific debugging
    final isZara = widget.productInfo.brand?.toLowerCase() == 'zara' ||
        widget.productInfo.url.toLowerCase().contains('zara.com');
    
    if (isZara) {
      debugPrint('[PD] Zara product detected, logging size availability details:');
    }
    
    // Filter out nonsensical or placeholder options
    final filteredOptions = sizeOptions.where((option) {
      final String lowerText = option.text.toLowerCase().trim();

      // Skip options that look like placeholders or form fields
      if (lowerText.contains('select') ||
          lowerText.contains('choose') ||
          lowerText.contains('i\'d rather not say')) {
        return false;
      }

      return true;
    }).toList();

    debugPrint('[PD] Filtered to ${filteredOptions.length} valid size options');

    // If no valid options after filtering, don't show the section
    if (filteredOptions.isEmpty) {
      debugPrint('[PD] ⚠️ No valid size options to display');
      return const SizedBox.shrink();
    }
    
    // Size label specific to Pandora
    String sectionTitle = 'Sizes';
    if (isPandora) {
      sectionTitle = 'Ring Size';
      
      // Check if this is likely a bracelet rather than a ring
      if (widget.productInfo.title != null &&
          (widget.productInfo.title!.toLowerCase().contains('bracelet') ||
           widget.productInfo.title!.toLowerCase().contains('bileklik'))) {
        sectionTitle = 'Bracelet Size';
      }
    }

    // Dump all size options with their raw data for debugging
    if (isZara) {
      for (final option in filteredOptions) {
        debugPrint('[PD] Zara size ${option.text} - raw value: ${option.value}');
        final isInStockValue = option.isInStock; // Use the getter directly
        debugPrint('[PD] Zara size ${option.text} - isInStock: $isInStockValue');
        
        // Check if we can parse the value JSON
        if (option.value != null) {
          try {
            final Map<String, dynamic> valueData = jsonDecode(option.value!);
            final jsonInStock = valueData['inStock'] ?? true;
            debugPrint('[PD] Parsed JSON for size ${option.text}: inStock=$jsonInStock');
            
            // Check for discrepancy
            if (isInStockValue != jsonInStock) {
              debugPrint('[PD] ⚠️ Discrepancy for size ${option.text}: getter=$isInStockValue, parsed=$jsonInStock');
            }
          } catch (e) {
            debugPrint('[PD] Failed to parse JSON for size ${option.text}: $e');
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Text(
                sectionTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (_selectedSizeText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    '($_selectedSizeText)',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filteredOptions.map((option) {
            // IMPORTANT CHANGE: For Zara products, use the isInStock getter directly
            // instead of trying to parse the JSON again, which could lead to inconsistencies
            bool isInStock = isZara ? option.isInStock : true;
            String? sizeValue;
            String? sizeAttr;
            
            // For non-Zara products, or as a fallback, still parse the JSON
            if (!isZara && option.value != null) {
              try {
                // Parse the JSON value
                final valueMap = jsonDecode(option.value!) as Map<String, dynamic>;
                
                // Get the inStock value directly from the JSON
                isInStock = valueMap['inStock'] ?? true;
                
                // For Pandora, get the size value and attribute
                if (isPandora) {
                  sizeValue = valueMap['sizeValue']?.toString();
                  sizeAttr = valueMap['sizeAttr']?.toString();
                  
                  // Log size information for debugging
                  debugPrint('[PD] Pandora size ${option.text}: inStock=$isInStock, sizeValue=$sizeValue');
                }
              } catch (e) {
                // If parse fails, assume it's in stock
                debugPrint('[PD] Error parsing size value: $e');
              }
            }

            // For Zara, log the final decision about size availability
            if (isZara) {
              debugPrint('[PD] Zara size ${option.text}: UI will show as ${isInStock ? "IN STOCK" : "OUT OF STOCK"}');
            }

            final bool isSelected = option.text == _selectedSizeText;

            return InkWell(
              onTap: isInStock
                  ? () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedSizeText = option.text;
                        _selectedSize = option;
                        _selectionChanged = true; // Mark that a change was made
                      });
                      
                      // Update cart/favorites immediately if selection changes
                      _updateProductWithSelections();
                      
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
                        : isSelected
                            ? Colors.black
                            : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: !isInStock
                      ? Colors.grey.shade100
                      : isSelected
                          ? Colors.black.withOpacity(0.05)
                          : Colors.white,
                ),
                child: Stack(
                  children: [
                    // Size text with proper styling
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option.text,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: !isInStock
                                ? Colors.grey.shade400
                                : isSelected
                                    ? Colors.black
                                    : Colors.black87,
                            decoration:
                                !isInStock ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
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
        
        // Add note for Pandora sizes
        if (isPandora)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Size guide
                InkWell(
                  onTap: () {
                    if (_selectedColorUrl != null) {
                      // Show a tooltip about size guide
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Size guide is available on Pandora\'s website'),
                          action: SnackBarAction(
                            label: 'OK',
                            onPressed: () {},
                          ),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          "Need sizing help?",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Out of stock indicator explanation
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Out of stock',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        
        // For Zara, add an out of stock indicator explanation regardless
        if (isZara) 
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  'Out of stock',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
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

  // Add method to open product URL in WebView
  void _openInWebView() {
    final url = widget.productInfo.url;
    if (url.isEmpty) return;
    
    final Uri uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    
    // Extract the site name from the domain for use in the WebView title
    final String domain = uri.host;
    final String siteName = _extractSiteNameFromDomain(domain);
    
    Navigator.pop(context); // Close the bottom sheet first
    
    // Navigate to WebView with the product URL
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          initialSiteIndex: 0, // Default value
          initialUrl: uri.toString(),
        ),
      ),
    );
  }
  
  // Helper method to extract a user-friendly site name from domain
  String _extractSiteNameFromDomain(String domain) {
    // Remove www. prefix if present
    String cleanDomain = domain.startsWith('www.') 
        ? domain.substring(4) 
        : domain;
    
    // Extract the main domain part (e.g. zara.com from zara.com.tr)
    List<String> parts = cleanDomain.split('.');
    if (parts.length >= 2) {
      // For common domains like zara.com, return capitalized "Zara"
      String siteName = parts[0];
      return siteName.substring(0, 1).toUpperCase() + siteName.substring(1);
    }
    
    // Fallback to whole domain if we can't extract it properly
    return cleanDomain;
  }

  @override
  Widget build(BuildContext context) {
    final productHasBrand = widget.productInfo.brand != null &&
        widget.productInfo.brand!.isNotEmpty;
    final isZara = widget.productInfo.brand?.toLowerCase() == 'zara' ||
        widget.productInfo.url.toLowerCase().contains('zara.com');
    final isPandora = widget.productInfo.brand?.toLowerCase() == 'pandora' ||
        widget.productInfo.url.toLowerCase().contains('pandora.net');

    // Check if product has color variants
    final hasColorVariants = widget.productInfo.variants != null &&
        widget.productInfo.variants!.containsKey('colors') &&
        widget.productInfo.variants!['colors'] != null &&
        widget.productInfo.variants!['colors']!.isNotEmpty;
    
    // Check if product has size variants
    final hasSizeVariants = widget.productInfo.variants != null &&
        widget.productInfo.variants!.containsKey('sizes') &&
        widget.productInfo.variants!['sizes'] != null &&
        widget.productInfo.variants!['sizes']!.isNotEmpty;

    // Log basic product details for the UI
    debugPrint('[PD] Building product details UI for: ${widget.productInfo.title}');
    debugPrint('[PD] Product has color variants: $hasColorVariants');
    debugPrint('[PD] Product has size variants: $hasSizeVariants');
    
    // Pandora-specific debug logging
    if (isPandora) {
      debugPrint('[PD] 💍 Pandora product detected');
      
      if (widget.productInfo.variants != null) {
        final variants = widget.productInfo.variants!;
        
        // Log variants again at build time
        debugPrint('[PD] Pandora variants at build time: ${variants.keys.join(', ')}');
        
        // Check colors
        if (variants.containsKey('colors') && variants['colors']!.isNotEmpty) {
          debugPrint('[PD] Pandora has ${variants['colors']!.length} colors/metals at build time');
        } else {
          debugPrint('[PD] ⚠️ Pandora has no colors/metals at build time');
        }
        
        // Check sizes
        if (variants.containsKey('sizes') && variants['sizes']!.isNotEmpty) {
          debugPrint('[PD] Pandora has ${variants['sizes']!.length} sizes at build time');
        } else {
          debugPrint('[PD] ⚠️ Pandora has no sizes at build time');
        }
      } else {
        debugPrint('[PD] ⚠️ Pandora product has no variants at build time');
      }
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
                onPressed: () {
                  // Ensure changes are saved before closing
                  _updateProductWithSelections().then((_) {
                    // Notify parent if callback exists
                    if (widget.onProductUpdated != null) {
                      widget.onProductUpdated!();
                    }
                    Navigator.pop(context);
                  });
                },
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

                  // Color variants with improved display - only show if the product actually has colors
                  if (hasColorVariants)
                    _buildColorVariants(widget.productInfo.variants!['colors']!)
                  else
                    Container(), // Empty container when no colors

                  // Size variants with improved display
                  if (hasSizeVariants)
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              children: [
                // View on Website button - only show when product has URL, 
                // opened from cart (meaning we want to see it on the website),
                // and NOT opened from WebView (since we're already on the website)
                if (widget.productInfo.url.isNotEmpty && 
                    widget.fromCart && 
                    !widget.fromWebView)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 8),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.public, size: 18),
                      label: Text('View on Website'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _openInWebView,
                    ),
                  ),
                
                // Existing add/remove from cart button
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
      debugPrint('[PD] Failed to parse RGB value: $e');
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

  // Extract URLs for each color variant (for Pandora products)
  void _extractColorUrls() {
    if (widget.productInfo.variants == null || 
        !widget.productInfo.variants!.containsKey('colors') ||
        widget.productInfo.variants!['colors'] == null) {
      return;
    }
    
    // Check if this is a Pandora product
    final isPandora = widget.productInfo.brand?.toLowerCase() == 'pandora' ||
        widget.productInfo.url.toLowerCase().contains('pandora.net');
    
    if (!isPandora) return;
    
    final colorVariants = widget.productInfo.variants!['colors']!;
    
    for (final colorOption in colorVariants) {
      if (colorOption.value != null && colorOption.value!.startsWith('{')) {
        try {
          final colorData = jsonDecode(colorOption.value!);
          if (colorData['href'] != null && colorData['href'].toString().isNotEmpty) {
            _colorUrls[colorOption.text] = colorData['href'].toString();
            
            // If this is the selected color, set the URL
            if (colorOption.selected) {
              _selectedColorUrl = colorData['href'].toString();
            }
            
            debugPrint('[PD] Extracted URL for ${colorOption.text}: ${colorData['href']}');
          }
        } catch (e) {
          debugPrint('[PD] Error parsing color data JSON: $e');
        }
      }
    }
    
    debugPrint('[PD] Extracted URLs for ${_colorUrls.length} colors');
  }
}
