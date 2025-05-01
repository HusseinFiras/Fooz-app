// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import '../models/product_info.dart';
import 'cached_image_widget.dart';

class ProductCard extends StatelessWidget {
  final ProductInfo productInfo;
  final VoidCallback onTap;

  const ProductCard({
    Key? key,
    required this.productInfo,
    required this.onTap,
  }) : super(key: key);

  // Extract brand from product info or URL
  String? _extractBrand() {
    if (productInfo.brand != null && productInfo.brand!.isNotEmpty) {
      return productInfo.brand;
    }

    // Extract from URL if not explicitly set
    final url = productInfo.url.toLowerCase();

    // Check against known brand URLs
    final brandMatches = {
      'gucci.com': 'Gucci',
      'louisvuitton.com': 'Louis Vuitton',
      'zara.com': 'Zara',
      'stradivarius.com': 'Stradivarius',
      'cartier.com': 'Cartier',
      'swarovski.com': 'Swarovski',
      'guess': 'Guess',
      'mango.com': 'Mango',
      'bershka.com': 'Bershka',
      'massimodutti': 'Massimo Dutti',
      'deepatelier': 'Deep Atelier',
      'pandora': 'Pandora',
      'miumiu': 'Miu Miu',
      'victoriassecret': 'Victoria\'s Secret',
      'nocturne': 'Nocturne',
      'beymen': 'Beymen',
      'lacoste': 'Lacoste',
      'mancofficial': 'Manc',
      'ipekyol': 'Ipekyol',
      'sandro': 'Sandro',
    };

    for (final entry in brandMatches.entries) {
      if (url.contains(entry.key)) {
        return entry.value;
      }
    }

    // Extract from title if possible
    if (productInfo.title != null) {
      final title = productInfo.title!.toLowerCase();
      for (final entry in brandMatches.entries) {
        if (title.contains(entry.key) ||
            title.contains(entry.value.toLowerCase())) {
          return entry.value;
        }
      }
    }

    return null;
  }

  // Helper method to fix image URLs
  String _fixImageUrl(String url) {
    // Handle protocol-relative URLs (//media.gucci.com/...)
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final brandName = _extractBrand();

    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Product thumbnail with branded fallback
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: productInfo.imageUrl != null
                      ? CachedImageWidget(
                          imageUrl: _fixImageUrl(productInfo.imageUrl!),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          brandName: brandName,
                          productTitle: productInfo.title,
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: brandName != null
                                ? Text(
                                    brandName[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  )
                                : const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 30,
                                    color: Colors.grey,
                                  ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      productInfo.title ?? 'Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          productInfo.formattedPrice,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        if (productInfo.originalPrice != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            productInfo.formattedOriginalPrice,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Display a badge with brand name if available for better identification
                    if (brandName != null && brandName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            brandName,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // View details button
              Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
