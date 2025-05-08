// widgets/homescreenwidgets/featured_brands.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/data_service.dart';
import '../../screens/webview_screen.dart';

class FeaturedBrands extends StatefulWidget {
  const FeaturedBrands({Key? key}) : super(key: key);

  @override
  _FeaturedBrandsState createState() => _FeaturedBrandsState();
}

class _FeaturedBrandsState extends State<FeaturedBrands> {
  final DataService _dataService = DataService();

  // Featured brand circles with site indices from DataService
  late final List<Map<String, dynamic>> _featuredBrands;
  
  @override
  void initState() {
    super.initState();
    // Initialize featured brands with correct site indices
    _featuredBrands = [
      {
        'color': Colors.black,
        'gradient': [Colors.white, Colors.white],
        'hasLogo': true,
        'logoAsset': 'assets/images/miumiu_logo.jpeg',
        'paddingValue': 10.0,
        'siteIndex': _findSiteIndexByName('Miu Miu'), // Dynamically find the correct index
      },
      {
        'color': Colors.black,
        'gradient': [Colors.white, Colors.white],
        'hasLogo': true,
        'logoAsset': 'assets/images/sandro_logo.png',
        'paddingValue': 10.0,
        'siteIndex': _findSiteIndexByName('Sandro'), // Dynamically find the correct index
      },
      {
        'color': Colors.black,
        'gradient': [Colors.white, Colors.white],
        'hasLogo': true,
        'logoAsset': 'assets/images/Beymen_logo.png',
        'paddingValue': 8.0,
        'siteIndex': _findSiteIndexByName('Beymen'), // Dynamically find the correct index
      },
    ];
  }

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

  // Method to find the site index by name
  int _findSiteIndexByName(String brandName) {
    for (int i = 0; i < _dataService.retailSites.length; i++) {
      if (_dataService.retailSites[i]['name']!.toLowerCase() == brandName.toLowerCase()) {
        return i;
      }
    }
    return 0; // Default to first site if not found
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: BouncingScrollPhysics(),
        children: List.generate(_featuredBrands.length, (index) {
          final brand = _featuredBrands[index];
          return TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 800 + (index * 200)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 110,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Navigate to the associated site
                        _navigateToSite(context, brand['siteIndex'] as int);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[200]!, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              spreadRadius: 0,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(brand['paddingValue']),
                            child: Image.asset(
                              brand['logoAsset'],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
            
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}