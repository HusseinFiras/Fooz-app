// widgets/homescreenwidgets/akkooo_picks.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AkkoooPicksSection extends StatelessWidget {
  const AkkoooPicksSection({Key? key}) : super(key: key);

  // Featured products data
  final List<Map<String, dynamic>> _featuredProducts = const [
    {
      'id': '1',
      'title': 'Gucci Flora Gorgeous Gardenia',
      'price': 1250.0,
      'currency': 'USD',
      'isFavorite': false,
      'imageUrl': 'assets/images/products/gucci_shoes.jpg',
      'badgeText': 'New',
    },
    {
      'id': '2',
      'title': 'Zara J\'adore Eau de Parfum',
      'price': 980.0,
      'currency': 'USD',
      'isFavorite': false,
      'imageUrl': 'assets/images/products/zara_bag.jpg',
      'badgeText': 'Popular',
    },
  ];

  // Method to toggle favorite (needs to be implemented in the parent and passed down)
  void _toggleFavorite(int index, Function(int) onToggle) {
    HapticFeedback.lightImpact();
    onToggle(index);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section with animation - styled to match Price Drop Alerts
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Animated icon with gold theme
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (value * 0.2),
                          child: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFE0B872).withOpacity(0.8), Color(0xFFE0B872)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFE0B872).withOpacity(0.3),
                                  blurRadius: 10 * value,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    // Section title and subtitle
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FOOZ Picks',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Curated premium selections',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // View all button with matching style to Price Drops
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade100, Colors.grey.shade200],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'View all',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Product grid with staggered animations
          Row(
            children: List.generate(_featuredProducts.length, (index) {
              final product = _featuredProducts[index];
              
              return Expanded(
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 800 + (index * 300)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: ProductCard(
                    product: product,
                    index: index,
                    onToggleFavorite: (index) => _toggleFavorite(index, (idx) {
                      // This would normally call back to the parent to update the state
                    }),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// A separate ProductCard widget with updated design to match Price Drops
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int index;
  final Function(int) onToggleFavorite;

  const ProductCard({
    Key? key,
    required this.product,
    required this.index,
    required this.onToggleFavorite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        right: index.isEven ? 8.0 : 0.0,
        left: index.isOdd ? 8.0 : 0.0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20), // Matched with Price Drops
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image with badge and favorite button
            Stack(
              children: [
                // Image with consistent height and corner radius
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    height: 180, // Same height as Price Drops
                    width: double.infinity,
                    color: Colors.grey[50],
                    child: Image.asset(
                      product['imageUrl'],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                
                // Badge if available - style matching Price Drops
                if (product['badgeText'] != null)
                  Positioned(
                    top: 15, // Same position as Price Drops
                    left: 15,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        product['badgeText'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // Favorite button
                Positioned(
                  top: 15, // Same position as brand badge in Price Drops
                  right: 15,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: Icon(
                          product['isFavorite'] 
                              ? Icons.favorite 
                              : Icons.favorite_border,
                          key: ValueKey<bool>(product['isFavorite']),
                          color: product['isFavorite'] 
                              ? Colors.red 
                              : Colors.black,
                          size: 18,
                        ),
                      ),
                      onPressed: () => onToggleFavorite(index),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            
            // Product info - with padding matching Price Drops
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['title'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product['price'].toStringAsFixed(0)} ${product['currency']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Button with matching style to Price Drops
                  Container(
                    width: double.infinity,
                    height: 40, // Same height as Shop Now
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black, Colors.black.withOpacity(0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(25),
                        splashColor: Colors.grey.withOpacity(0.2),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                        },
                        child: Center(
                          child: Text(
                            'Add to Cart',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}