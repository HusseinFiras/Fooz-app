// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import '../models/product_info.dart';

class ProductCard extends StatelessWidget {
  final ProductInfo productInfo;
  final VoidCallback onTap;

  const ProductCard({
    Key? key,
    required this.productInfo,
    required this.onTap,
  }) : super(key: key);

  Widget _buildVariantIndicator(String type, int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == 'Colors' ? Icons.palette : Icons.straighten,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              // Product thumbnail
              if (productInfo.imageUrl != null)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      productInfo.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported);
                      },
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_bag, size: 30),
                ),
              const SizedBox(width: 12),

              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      productInfo.title ?? '',
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
                    if (productInfo.variants != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (productInfo.variants!['colors']?.isNotEmpty ??
                              false)
                            _buildVariantIndicator(
                              'Colors',
                              productInfo.variants!['colors']!.length,
                              Colors.red[400]!,
                            ),
                          if (productInfo.variants!['sizes']?.isNotEmpty ??
                              false)
                            _buildVariantIndicator(
                              'Sizes',
                              productInfo.variants!['sizes']!.length,
                              Colors.blue[400]!,
                            ),
                        ],
                      ),
                    ],
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