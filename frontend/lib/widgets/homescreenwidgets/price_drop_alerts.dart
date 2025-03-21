// widgets/homescreenwidgets/price_drop_alerts.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/data_service.dart';
import '../../screens/webview_screen.dart';

class PriceDropAlertsSection extends StatelessWidget {
  final DataService dataService;

  const PriceDropAlertsSection({
    Key? key,
    required this.dataService,
  }) : super(key: key);

  // Sample data for price drops
  final List<Map<String, dynamic>> _priceDropItems = const [
    {
      'id': 'pd1',
      'brand': 'Gucci',
      'title': 'Horsebit 1955 Mini Bag',
      'imageUrl': 'assets/images/products/gucci_bag.jpeg',
      'currentPrice': 1850.0,
      'originalPrice': 2300.0,
      'currency': 'USD',
      'discount': 20, // percentage
      'siteIndex': 0, // Gucci index
      'productUrl': 'https://www.gucci.com/tr/en_gb/pr/women/handbags/mini-bags-for-women/horsebit-1955-mini-bag-p-7017742VAAG6638'
    },
    {
      'id': 'pd2',
      'brand': 'Cartier',
      'title': 'Love Bracelet',
      'imageUrl': 'assets/images/products/love_bracelet.jpg',
      'currentPrice': 5800.0,
      'originalPrice': 6700.0,
      'currency': 'USD',
      'discount': 13, // percentage
      'siteIndex': 3, // Cartier index
      'productUrl': 'https://www.cartier.com/en-us/jewelry/bracelets/love-bracelet-B6035517.html'
    },
    {
      'id': 'pd3',
      'brand': 'Swarovski',
      'title': 'Stella Watch',
      'imageUrl': 'assets/images/products/watch_me.png',
      'currentPrice': 249.0,
      'originalPrice': 349.0,
      'currency': 'USD',
      'discount': 28, // percentage
      'siteIndex': 4, // Swarovski index
      'productUrl': 'https://www.swarovski.com/en-TR/p-5376071/Stella-Watch-Leather-strap-White-Rose-gold-tone-PVD/'
    },
    {
      'id': 'pd4',
      'brand': 'Zara',
      'title': 'Oversized Wool Coat',
      'imageUrl': 'assets/images/products/OIP_me.jpeg',
      'currentPrice': 119.0,
      'originalPrice': 199.0,
      'currency': 'USD',
      'discount': 40, // percentage
      'siteIndex': 1, // Zara index
      'productUrl': 'https://www.zara.com/tr/en/share/-p04661073.html'
    },
  ];

  void _navigateToProduct(BuildContext context, int siteIndex, String productUrl) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return WebViewScreen(
            initialSiteIndex: siteIndex,
            initialUrl: productUrl,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = Offset(1.0, 0.0);
          var end = Offset.zero;
          var curve = Curves.easeOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  String _formatPrice(double price, String currency) {
    return '${price.toStringAsFixed(0)} $currency';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Added more margin at the bottom specifically
      margin: EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section with animation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Animated price drop icon
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
                                colors: [Colors.red.shade400, Colors.redAccent.shade700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 10 * value,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_downward,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    // Section title
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price Drop Alerts',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Luxury for less, limited time only',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // View all button with custom styling
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
                      // Navigate to all price drops page
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

          // Price drop items carousel with staggered animation - further increased height
          SizedBox(
            height: 360, // Increased by an additional 30px to fix the 22px overflow
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 8),
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              itemCount: _priceDropItems.length,
              itemBuilder: (context, index) {
                final item = _priceDropItems[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 800 + (index * 150)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(50 * (1 - value), 0),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: _buildPriceDropCard(context, item, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceDropCard(BuildContext context, Map<String, dynamic> item, int index) {
    // Calculate savings amount
    final savingsAmount = (item['originalPrice'] as double) - (item['currentPrice'] as double);
    
    return GestureDetector(
      onTap: () => _navigateToProduct(
        context,
        item['siteIndex'] as int,
        item['productUrl'] as String,
      ),
      child: Container(
        width: 230, // Slightly wider for better content display
        margin: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            // Product image with discount badge
            Stack(
              children: [
                // Product image with optimal height
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    height: 180, // Restored original height to show full image
                    width: double.infinity,
                    child: Image.asset(
                      item['imageUrl'] as String,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                
                // Premium discount badge
                Positioned(
                  top: 15,
                  left: 15,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade600, Colors.red.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_downward_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item['discount']}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Brand logo/name badge
                Positioned(
                  top: 15,
                  right: 15,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item['brand'] as String,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Product details
            Padding(
              padding: const EdgeInsets.all(15), // Full padding for better spacing
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product title
                  Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Price information with strike-through
                  Row(
                    children: [
                      // Current price
                      Text(
                        _formatPrice(item['currentPrice'] as double, item['currency'] as String),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      
                      const SizedBox(width: 10),
                      
                      // Original price with strike-through
                      Text(
                        _formatPrice(item['originalPrice'] as double, item['currency'] as String),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade600,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  
                  // Savings amount with comfortable spacing
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Save ${_formatPrice(savingsAmount, item['currency'] as String)}',
                      style: TextStyle(
                        fontSize: 14, // Comfortable reading size
                        fontWeight: FontWeight.w500,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // "Shop Now" button with appropriate padding
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15), // Restored original padding
              child: Container(
                width: double.infinity,
                height: 40, // Standard button height for better tap targets
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
                    onTap: () => _navigateToProduct(
                      context,
                      item['siteIndex'] as int,
                      item['productUrl'] as String,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Shop Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}