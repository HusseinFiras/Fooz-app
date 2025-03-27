// lib/screens/brands_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/data_service.dart';
import '../services/url_handler_service.dart';
import 'webview_screen.dart';
import '../constants/theme_constants.dart';

// Import widget components
import '../widgets/brandscreenwidgets/url_search_widget.dart';
import '../widgets/brandscreenwidgets/category_tabs_widget.dart';
import '../widgets/brandscreenwidgets/brand_grid_widget.dart';

class BrandsScreen extends StatefulWidget {
  const BrandsScreen({Key? key}) : super(key: key);

  @override
  _BrandsScreenState createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  final ScrollController _scrollController = ScrollController();

  // Selected tab index
  int _selectedCategoryIndex = 0;
  
  // Categories
  final List<String> _categories = ['All Brands', 'Luxury', 'Fashion', 'Accessories']; 
  
  // Brand data for different categories - populated from DataService in initState
  late List<List<Map<String, dynamic>>> _brandsByCategory;
  
  @override
  void initState() {
    super.initState();
    _initializeBrandCategories();
  }
  
  // Initialize brand categories using retail sites from DataService
  void _initializeBrandCategories() {
    final allBrands = _dataService.retailSites.map((site) {
      return {
        'name': site['name'] ?? '',
        'url': site['url'] ?? '',
        'logoAsset': 'assets/images/brands/${_getBrandImageName(site['name'] ?? '')}.png',
      };
    }).toList();
    
    // Define luxury brands
    final luxuryBrands = allBrands.where((brand) => 
      ['Gucci', 'Cartier', 'Miu Miu', 'Beymen'].contains(brand['name'])
    ).toList();
    
    // Define fashion brands
    final fashionBrands = allBrands.where((brand) => 
      ['Zara', 'Stradivarius', 'Guess', 'Mango', 'Bershka', 'Massimo Dutti', 
       'Victoria\'s Secret', 'Nocturne', 'Ipekyol', 'Sandro', 'Manc', 'Deep Atelier', 'Lacoste'].contains(brand['name'])
    ).toList();
    
    // Define accessories brands
    final accessoriesBrands = allBrands.where((brand) => 
      ['Swarovski', 'Pandora', 'Blue Diamond'].contains(brand['name'])
    ).toList();
    
    _brandsByCategory = [
      allBrands,         // All brands
      luxuryBrands,      // Luxury brands
      fashionBrands,     // Fashion brands
      accessoriesBrands, // Accessories brands
    ];
  }
  
  // Helper method to convert brand name to filename format
  String _getBrandImageName(String brandName) {
    return brandName.toLowerCase().replaceAll(' ', '_').replaceAll('\'', '');
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleCategorySelected(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });
  }

  void _navigateToSite(BuildContext context, String brandName) {
    // Find the brand in DataService if it exists
    int siteIndex = -1;
    for (int i = 0; i < _dataService.retailSites.length; i++) {
      if (_dataService.retailSites[i]['name']!.toLowerCase() == brandName.toLowerCase()) {
        siteIndex = i;
        break;
      }
    }
    
    // If brand not found in DataService, show a message
    if (siteIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coming soon: $brandName'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: LuxuryTheme.textCharcoal,
        ),
      );
      return;
    }
    
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
        transitionDuration: Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxuryTheme.neutralOffWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Brands',
          style: TextStyle(
            fontFamily: 'DM Serif Display',
            color: LuxuryTheme.textCharcoal,
            fontWeight: FontWeight.w500,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL Search Widget
          UrlSearchWidget(),
          
          // Category Tabs Widget
          CategoryTabsWidget(
            categories: _categories,
            selectedIndex: _selectedCategoryIndex,
            onCategorySelected: _handleCategorySelected,
          ),
          
          // Brand Grid - Expanded to fill remaining space
          Expanded(
            child: BrandGridWidget(
              brands: _brandsByCategory[_selectedCategoryIndex],
              onBrandTapped: _navigateToSite,
            ),
          ),
        ],
      ),
    );
  }
}