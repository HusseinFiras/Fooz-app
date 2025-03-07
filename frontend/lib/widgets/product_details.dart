// lib/widgets/product_details.dart
import 'package:flutter/material.dart';
import '../models/product_info.dart';
import '../models/variant_option.dart';

class ProductDetailsBottomSheet extends StatelessWidget {
  final ProductInfo productInfo;

  const ProductDetailsBottomSheet({
    Key? key,
    required this.productInfo,
  }) : super(key: key);

  Widget _buildInfoRow(String label, String value,
      {TextStyle? style, TextOverflow textOverflow = TextOverflow.visible}) {
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
              overflow: textOverflow,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSection(
      BuildContext context, String title, List<VariantOption> options) {
    // Filter out nonsensical options (like country codes, honorifics, etc.)
    final filteredOptions = options.where((option) {
      // Skip options that look like country codes
      if (option.text.startsWith('+') &&
          RegExp(r'^\+\d+ ').hasMatch(option.text)) {
        return false;
      }

      // Skip honorifics and placeholder options
      final String lowerText = option.text.toLowerCase();
      if ([
            'mr.',
            'mrs.',
            'ms.',
            'miss',
            'dr.',
            'prof.',
            'select',
            'i\'d rather not say'
          ].contains(lowerText) ||
          lowerText.contains('select size') ||
          lowerText.contains('availability') ||
          lowerText.contains('quality') ||
          lowerText.contains('characteristics')) {
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
            // For colors, try to use the color value if it exists
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
              // For other variants or when no color value exists
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

  // Format availability string for better display
  String _formatAvailability(String? availability) {
    if (availability == null) return 'Unknown';

    // Convert schema.org format to user-friendly text
    if (availability == 'http://schema.org/InStock' ||
        availability == 'https://schema.org/InStock') {
      return 'In Stock';
    } else if (availability == 'http://schema.org/OutOfStock' ||
        availability == 'https://schema.org/OutOfStock') {
      return 'Out of Stock';
    } else if (availability == 'http://schema.org/LimitedAvailability' ||
        availability == 'https://schema.org/LimitedAvailability') {
      return 'Limited Availability';
    } else if (availability == 'http://schema.org/PreOrder' ||
        availability == 'https://schema.org/PreOrder') {
      return 'Pre-Order';
    } else if (availability.toLowerCase().contains('in stock')) {
      return 'In Stock';
    } else if (availability.toLowerCase().contains('out of stock')) {
      return 'Out of Stock';
    } else if (availability == 'Select' || availability.contains('select')) {
      return 'Check Store Availability';
    }

    return availability;
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
                  productInfo.title ?? 'Product Details',
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
                  if (productInfo.imageUrl != null)
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
                          productInfo.imageUrl!,
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
                  _buildInfoRow('Price:', productInfo.formattedPrice,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  if (productInfo.originalPrice != null)
                    _buildInfoRow(
                        'Original Price:', productInfo.formattedOriginalPrice,
                        style: const TextStyle(
                            decoration: TextDecoration.lineThrough)),
                  const SizedBox(height: 16),

                  // Color variants
                  if (productInfo.variants != null &&
                      productInfo.variants!.containsKey('colors') &&
                      productInfo.variants!['colors']!.isNotEmpty)
                    _buildVariantSection(
                        context, 'Colors', productInfo.variants!['colors']!),

                  // Size variants
                  if (productInfo.variants != null &&
                      productInfo.variants!.containsKey('sizes') &&
                      productInfo.variants!['sizes']!.isNotEmpty)
                    _buildVariantSection(
                        context, 'Sizes', productInfo.variants!['sizes']!),

                  // Other option variants
                  if (productInfo.variants != null &&
                      productInfo.variants!.containsKey('otherOptions') &&
                      productInfo.variants!['otherOptions']!.isNotEmpty)
                    _buildVariantSection(context, 'Options',
                        productInfo.variants!['otherOptions']!),

                  if (productInfo.variants == null ||
                      (productInfo.variants!['colors']?.isEmpty ?? true) &&
                          (productInfo.variants!['sizes']?.isEmpty ?? true) &&
                          (productInfo.variants!['otherOptions']?.isEmpty ??
                              true))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No variants available for this product',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic),
                      ),
                    ),

                  const Divider(height: 24),

                  // Additional product details
                  if (productInfo.brand != null)
                    _buildInfoRow('Brand:', productInfo.brand!),
                  if (productInfo.availability != null)
                    _buildInfoRow('Availability:',
                        _formatAvailability(productInfo.availability)),

                  // Description - only show if not empty and not null
                  if (productInfo.description != null &&
                      productInfo.description!.trim().isNotEmpty &&
                      !productInfo.description!.contains('schema.org')) ...[
                    const SizedBox(height: 16),
                    const Text('Description:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(productInfo.description!),
                  ],

                  // Technical info (hidden by default)
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text('Technical Information'),
                    initiallyExpanded: false,
                    children: [
                      _buildInfoRow('SKU:', productInfo.sku ?? 'Not available'),
                      _buildInfoRow('Extraction Method:',
                          productInfo.extractionMethod ?? 'Unknown'),
                      _buildInfoRow('URL:', productInfo.url,
                          textOverflow: TextOverflow.ellipsis),
                      // Add debugging info for image URL
                      _buildInfoRow(
                          'Image URL:', productInfo.imageUrl ?? 'None',
                          textOverflow: TextOverflow.ellipsis),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Save'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Product saved to favorites')),
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_cart),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('Add to Cart'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to cart')),
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
