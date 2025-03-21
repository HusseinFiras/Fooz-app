// widgets/homescreenwidgets/popular_brands.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/data_service.dart';
import '../../screens/webview_screen.dart';

class PopularBrandsSection extends StatelessWidget {
  final Function(int) navigateToSite;
  final DataService dataService;

  const PopularBrandsSection({
    Key? key,
    required this.navigateToSite,
    required this.dataService,
  }) : super(key: key);

  void _navigateToSpecificBrand(BuildContext context, int siteIndex) {
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
    // Featured brand (Zara)
    final featuredBrand = {
      'name': 'Zara',
      'imageAsset': 'assets/images/zara_bg.png',
      'siteIndex': 1, // Index in the data service
    };

    // List of brands for the horizontal scroll
    final horizontalBrands = [
      {
        'name': 'Massimo Dutti',
        'imageAsset': 'assets/images/massimodutti.jpg',
        'siteIndex': 8, // Index in the data service
      },
      {
        'name': 'Stradivarius',
        'imageAsset': 'assets/images/stradivarius.jpg',
        'siteIndex': 2, // Index in the data service
      },
      {
        'name': 'OYSHO',
        'imageAsset': 'assets/images/bershka.jpg', // Using Bershka as placeholder
        'siteIndex': 7, // Index in the data service (using Bershka as placeholder)
      },
      {
        'name': 'Guess',
        'imageAsset': 'assets/images/guess.jpg',
        'siteIndex': 5, // Index in the data service
      },
      {
        'name': 'Mango',
        'imageAsset': 'assets/images/mango.jpg',
        'siteIndex': 6, // Index in the data service
      },
    ];

    return Container(
      margin: EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured Brand - ZARA (without text overlay)
          GestureDetector(
            onTap: () => _navigateToSpecificBrand(context, featuredBrand['siteIndex'] as int),
            child: Container(
              height: 240,
              margin: EdgeInsets.symmetric(horizontal: 8),
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  featuredBrand['imageAsset'] as String,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          
          // Horizontal scrolling brands (without text overlay)
          Container(
            height: 180,
            margin: EdgeInsets.only(top: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              itemCount: horizontalBrands.length,
              itemBuilder: (context, index) {
                final brand = horizontalBrands[index];
                return GestureDetector(
                  onTap: () => _navigateToSpecificBrand(context, brand['siteIndex'] as int),
                  child: Container(
                    width: MediaQuery.of(context).size.width / 2.5, // Show ~2.5 items at once
                    margin: EdgeInsets.only(
                      left: index == 0 ? 8 : 4,
                      right: index == horizontalBrands.length - 1 ? 8 : 4,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        brand['imageAsset'] as String,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}