// lib/widgets/homescreenwidgets/fashion_brand_grid.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/data_service.dart';
import '../../screens/webview_screen.dart';
import '../../constants/theme_constants.dart';

class FashionBrandGrid extends StatelessWidget {
  final DataService dataService;

  const FashionBrandGrid({
    Key? key,
    required this.dataService,
  }) : super(key: key);

  // Updated brand data with your final selected brands (with empty names)
  final List<Map<String, dynamic>> _brandData = const [
    {
      'name': '', // Deep Atelier
      'siteIndex': 9, // Update with correct index in dataService for Deep Atelier
      'imageAsset': 'assets/images/deep_a.jpg', // Will be replaced by you
      'textColor': Colors.white,
      'textPosition': {'left': 20.0, 'top': 15.0},
      'textSize': 22.0,
    },
    {
      'name': '', // Nocturne
      'siteIndex': 13, // Update with correct index in dataService for Nocturne
      'imageAsset': 'assets/images/nocturne.jpg', // Will be replaced by you
      'textColor': Colors.black,
      'textPosition': {'right': 20.0, 'top': 15.0},
      'textSize': 22.0,
    },
    {
      'name': '', // Ipekyol
      'siteIndex': 18, // Update with correct index in dataService for Ipekyol
      'imageAsset': 'assets/images/ipekyol.jpg', // Will be replaced by you
      'textColor': Colors.black,
      'textPosition': {'left': 20.0, 'bottom': 15.0},
      'textSize': 22.0,
    },
    {
      'name': '', // Manc
      'siteIndex': 17, // Update with correct index in dataService for Manc
      'imageAsset': 'assets/images/manc.jpg', // Will be replaced by you
      'textColor': Colors.white,
      'textPosition': {'right': 20.0, 'bottom': 15.0},
      'textSize': 22.0,
    },
    {
      'name': '', // Blue Diamond
      'siteIndex': 15, // Update with correct index in dataService for Blue Diamond
      'imageAsset': 'assets/images/blue.jpg', // Will be replaced by you
      'textColor': Colors.white,
      'textPosition': {'left': 20.0, 'bottom': 15.0},
      'textSize': 22.0,
    },
    {
      'name': '', // Lacoste
      'siteIndex': 16, // Update with correct index in dataService for Lacoste
      'imageAsset': 'assets/images/lacoste.jpg', // Will be replaced by you
      'textColor': Colors.white,
      'textPosition': {'right': 20.0, 'bottom': 15.0},
      'textSize': 22.0,
    },
  ];

  void _navigateToSite(BuildContext context, int siteIndex) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return WebViewScreen(initialSiteIndex: siteIndex);
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

  @override
  Widget build(BuildContext context) {
    // Calculate screen width and fix the overflow issue
    final screenWidth = MediaQuery.of(context).size.width;
    // Subtract all horizontal padding and margins to prevent overflow
    final itemWidth = (screenWidth - 10) / 2; // Adjusted width calculation for the separator
    
    // Increased heights for all rows to make images bigger
    final firstRowHeight = itemWidth * 0.7; // Taller rectangular aspect ratio
    final itemHeight = itemWidth * 1.2; // Taller square aspect ratio for rows 2-3

    // Border radius for rounded corners
    final double cornerRadius = 12.0;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 0), // Reduced vertical padding
      color: LuxuryTheme.neutralOffWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add section header with elegant styling
          Padding(
            padding: EdgeInsets.only(left: 16, bottom: 16, top: 8, right: 16),
            child: Row(
              children: [
                Text(
                  'FEATURED BRANDS',
                  style: TextStyle(
                    fontFamily: 'DM Serif Display',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: LuxuryTheme.textCharcoal,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 1,
                    color: LuxuryTheme.primaryRosegold.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
          
          // Custom grid layout with adjusted width calculations and increased heights
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4), // Reduced padding
            child: Column(
              children: [
                // First row: Deep Atelier and Nocturne (rectangular) with separator
                Row(
                  children: [
                    // Apply rounded corners to first item in first row (top-left corner)
                    _buildBrandItem(
                      context, 
                      _brandData[0], 
                      itemWidth, 
                      firstRowHeight, 
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(cornerRadius))
                    ),
                    // Thin vertical separator
                    Container(
                      width: 1,
                      height: firstRowHeight,
                      color: Colors.white, // Light separator color
                    ),
                    // Apply rounded corners to second item in first row (top-right corner)
                    _buildBrandItem(
                      context, 
                      _brandData[1], 
                      itemWidth, 
                      firstRowHeight,
                      borderRadius: BorderRadius.only(topRight: Radius.circular(cornerRadius))
                    ),
                  ],
                ),
                SizedBox(height: 1), // Thinner gap between rows
                // Second row: Ipekyol and Manc (square)
                Row(
                  children: [
                    _buildBrandItem(context, _brandData[2], itemWidth, itemHeight),
                    // Thin vertical separator
                    Container(
                      width: 1,
                      height: itemHeight,
                      color: Colors.white, // Light separator color
                    ),
                    _buildBrandItem(context, _brandData[3], itemWidth, itemHeight),
                  ],
                ),
                SizedBox(height: 1), // Thinner gap between rows
                // Third row: Blue Diamond and Lacoste (square)
                Row(
                  children: [
                    // Apply rounded corners to first item in last row (bottom-left corner)
                    _buildBrandItem(
                      context, 
                      _brandData[4], 
                      itemWidth, 
                      itemHeight,
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(cornerRadius))
                    ),
                    // Thin vertical separator
                    Container(
                      width: 1,
                      height: itemHeight,
                      color: Colors.white, // Light separator color
                    ),
                    // Apply rounded corners to second item in last row (bottom-right corner)
                    _buildBrandItem(
                      context, 
                      _brandData[5], 
                      itemWidth, 
                      itemHeight,
                      borderRadius: BorderRadius.only(bottomRight: Radius.circular(cornerRadius))
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

  Widget _buildBrandItem(
    BuildContext context, 
    Map<String, dynamic> brand, 
    double width, 
    double height, 
    {BorderRadius borderRadius = BorderRadius.zero}
  ) {
    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.symmetric(horizontal: 0), // Removed horizontal margin
      child: GestureDetector(
        onTap: () => _navigateToSite(context, brand['siteIndex']),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Brand image - made larger with BoxFit.cover
              Image.asset(
                brand['imageAsset'],
                fit: BoxFit.cover,
                width: width,
                height: height,
              ),
              
              // Optional subtle overlay for better text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.4), // Increased opacity for better text visibility
                    ],
                    stops: [0.5, 1.0],
                  ),
                ),
              ),
              
              // Brand name text removed as requested
            ],
          ),
        ),
      ),
    );
  }
}