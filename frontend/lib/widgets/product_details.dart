// lib/widgets/product_details.dart
import 'package:flutter/material.dart';
import '../models/product_info.dart';
import '../models/variant_option.dart';
import '../services/cart_service.dart';
import '../services/favorites_service.dart';

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

  Widget _buildVariantSection(
      BuildContext context, String title, List<VariantOption> options) {
    // Enhanced filtering of nonsensical options
    final filteredOptions = options.where((option) {
      final String lowerText = option.text.toLowerCase().trim();

      // Skip options that look like country codes, honorifics, or form fields
      if (option.text.startsWith('+') ||
          lowerText.contains('mr.') ||
          lowerText.contains('ms.') ||
          lowerText.contains('mrs.') ||
          lowerText.contains('select') ||
          lowerText.contains('availability') ||
          lowerText.contains('quality') ||
          lowerText.contains('characteristics') ||
          lowerText.contains('i\'d rather not say')) {
        return false;
      }

      return true;
    }).toList();

    // If no valid options after filtering, don't show the section
    if (filteredOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filteredOptions.map((option) {
            // For colors
            if (title == 'Colors' &&
                option.value != null &&
                option.value!.startsWith('rgb')) {
              // Try to parse the color
              Color? color;
              try {
                final rgbValues =
                    RegExp(r'rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)')
                        .firstMatch(option.value!);
                if (rgbValues != null) {
                  color = Color.fromRGBO(
                    int.parse(rgbValues.group(1)!),
                    int.parse(rgbValues.group(2)!),
                    int.parse(rgbValues.group(3)!),
                    1.0,
                  );
                }
              } catch (e) {
                debugPrint('Error parsing color: $e');
              }

              return InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Selected color: ${option.text}')),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color ?? Colors.grey,
                    border: Border.all(
                      color: option.selected ? Colors.black : Colors.grey,
                      width: option.selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: option.selected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            } else if (title == 'Colors' &&
                option.value != null &&
                option.value!.startsWith('http')) {
              // If the color value is an image URL
              return InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Selected color: ${option.text}')),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: option.selected ? Colors.black : Colors.grey,
                      width: option.selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.network(
                      option.value!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: Colors.grey[300]),
                    ),
                  ),
                ),
              );
            } else {
              // For sizes and other variants
              return InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Selected ${title.toLowerCase().substring(0, title.length - 1)}: ${option.text}')),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: option.selected ? Colors.black : Colors.grey[300]!,
                      width: option.selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: option.selected
                        ? Colors.black.withOpacity(0.05)
                        : Colors.white,
                  ),
                  child: Text(
                    option.text,
                    style: TextStyle(
                      fontWeight:
                          option.selected ? FontWeight.bold : FontWeight.normal,
                      color: option.selected ? Colors.black : Colors.black87,
                    ),
                  ),
                ),
              );
            }
          }).toList(),
        ),
        const SizedBox(height: 8),
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

    return 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
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
                        child: Image.network(
                          widget.productInfo.imageUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.broken_image, size: 50),
                                  const SizedBox(height: 8),
                                  Text('Image could not be loaded',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Price information
                  _buildInfoRow('Price:', widget.productInfo.formattedPrice,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  if (widget.productInfo.originalPrice != null)
                    _buildInfoRow('Original Price:',
                        widget.productInfo.formattedOriginalPrice,
                        style: const TextStyle(
                            decoration: TextDecoration.lineThrough)),
                  const SizedBox(height: 16),

                  // Color variants
                  if (widget.productInfo.variants != null &&
                      widget.productInfo.variants!.containsKey('colors') &&
                      widget.productInfo.variants!['colors']!.isNotEmpty)
                    _buildVariantSection(context, 'Colors',
                        widget.productInfo.variants!['colors']!),

                  // Size variants
                  if (widget.productInfo.variants != null &&
                      widget.productInfo.variants!.containsKey('sizes') &&
                      widget.productInfo.variants!['sizes']!.isNotEmpty)
                    _buildVariantSection(context, 'Sizes',
                        widget.productInfo.variants!['sizes']!),

                  // Description - only show if not empty and not null
                  if (widget.productInfo.description != null &&
                      widget.productInfo.description!.trim().isNotEmpty &&
                      !widget.productInfo.description!
                          .contains('schema.org')) ...[
                    const SizedBox(height: 16),
                    const Text('Description:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.productInfo.description!),
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
}
