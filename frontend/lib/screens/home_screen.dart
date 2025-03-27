// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/data_service.dart';
import '../services/url_handler_service.dart';
import '../constants/theme_constants.dart';
import 'webview_screen.dart';
import 'cart_screen.dart';
import '../widgets/homescreenwidgets/main_banner.dart';
import '../widgets/homescreenwidgets/featured_brands.dart';
import '../widgets/homescreenwidgets/victorias_secret_banner.dart';
import '../widgets/homescreenwidgets/atilla_karat_video_section.dart';
import '../widgets/homescreenwidgets/popular_brands.dart';
// Import the renamed component (previously price_drop_alerts.dart)
import '../widgets/homescreenwidgets/fashion_brand_grid.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  final UrlHandlerService _urlHandlerService = UrlHandlerService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<State> _pageKey = GlobalKey<State>();
  bool _initialLoadComplete = false;
  
  // Animation controllers
  late final AnimationController _fadeInController;
  late final AnimationController _slideController;
  late final AnimationController _scaleController;
  
  // Featured products for state management
  final List<Map<String, dynamic>> _featuredProducts = [
    {
      'id': '1',
      'title': 'Gucci Flora Gorgeous Gardenia',
      'price': 1250.0,
      'currency': 'USD',
      'isFavorite': false,
      'imageUrl': 'assets/images/gucci_bg.png',
      'badgeText': 'New',
    },
    {
      'id': '2',
      'currency': 'USD',
      'isFavorite': false,
      'imageUrl': 'assets/images/zara_bg.png',
      'badgeText': 'Popular',
    },
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize all animation controllers
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Start animations
    _fadeInController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToSite(int index) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return WebViewScreen(initialSiteIndex: index);
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
  
  void _navigateToSpecificProduct(int siteIndex, String productUrl) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return WebViewScreen(initialSiteIndex: siteIndex, initialUrl: productUrl);
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
  
  void _navigateToCart() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CartScreen()),
    );
  }
  
  void _toggleFavorite(int index) {
    setState(() {
      _featuredProducts[index]['isFavorite'] = !_featuredProducts[index]['isFavorite'];
    });
  }

  // Process the URL in a separate method
  void _processUrl(String url) {
    if (url.isNotEmpty) {
      // Process the URL using your URL handler service
      final result = _urlHandlerService.processUrl(url);
      
      if (result['isValid']) {
        // Navigate to the product page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewScreen(
              initialSiteIndex: result['retailerIndex'],
              initialUrl: result['normalizedUrl'],
            ),
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['errorMessage'] ?? 'Invalid URL'),
            backgroundColor: LuxuryTheme.textCharcoal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Animations
    final fadeAnimation = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    );
    
    final slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    final scaleAnimation = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
    ));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        // Using CustomScrollView to allow the AppBar to scroll away
        body: CustomScrollView(
          controller: _scrollController,
          physics: BouncingScrollPhysics(),
          slivers: [
            // SliverAppBar with rosegold accents
            SliverAppBar(
              backgroundColor: Colors.white,
              floating: true,
              snap: true,
              elevation: 0,
              leadingWidth: 120,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Text(
                  'FOOZ',
                  style: TextStyle(
                    fontFamily: 'DM Serif Display',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: LuxuryTheme.primaryRosegold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              actions: [
                // Only keep the shopping bag icon
                IconButton(
                  icon: Icon(
                    Icons.shopping_bag_outlined,
                    color: LuxuryTheme.primaryRosegold,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _navigateToCart();
                  },
                ),
              ],
            ),
            
            // Main content in a SliverList
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: fadeAnimation,
                child: SlideTransition(
                  position: slideAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: Column(
                      children: [
                        // Main banner with navigation functionality
                        MainBanner(),
                        
                        // Featured brands with navigation
                        FeaturedBrands(),
                        
                        // Atilla Karat section with updated rosegold theme
                        AtillaKaratVideoSection(
                          navigateToProduct: _navigateToSpecificProduct,
                        ),
                        
                        // Victoria's Secret banner with updated rosegold theme
                        VictoriasSecretBanner(
                          navigateToSite: _navigateToSite,
                          dataService: _dataService,
                        ),
                        
                        // Renamed from Price Drop Alerts to Curated Selections
                        FashionBrandGrid(
                          dataService: _dataService,
                        ),
                        
                        // Popular brands section
                        PopularBrandsSection(
                          navigateToSite: _navigateToSite,
                          dataService: _dataService,
                        ),
                        
                        // Add bottom padding to avoid content being covered by bottom navigation bar
                        SizedBox(height: 24),
                      ],
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