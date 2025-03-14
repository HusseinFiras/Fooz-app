import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/data_service.dart';
import '../services/url_handler_service.dart';
import 'webview_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  final UrlHandlerService _urlHandler = UrlHandlerService();
  final TextEditingController _linkController = TextEditingController();
  final FocusNode _linkFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _floatingActionButtonController;
  late AnimationController _searchBarAnimationController;
  late AnimationController _pulseAnimationController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Staggered card animations
  List<AnimationController> _cardAnimationControllers = [];
  List<Animation<double>> _cardScaleAnimations = [];
  List<Animation<double>> _cardOpacityAnimations = [];
  
  // URL validation states
  bool _isProcessingUrl = false;
  bool _isValidUrl = false;
  bool _isInvalidUrl = false;
  String _retailerName = "";
  bool _showFloatingSearchButton = false;
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['All Brands', 'Luxury', 'Fashion', 'Favorites'];

  // Brand categorization
  final List<String> _luxuryBrands = [
    'Gucci',
    'Cartier',
    'Swarovski',
    'Miu Miu',
    'Beymen',
    'Blue Diamond',
    'Lacoste',
    'Sandro',
    'Deep Atelier',
    'Mango'
  ];

  final List<String> _fashionBrands = [
    'Zara',
    'Stradivarius',
    'Guess',
    'Bershka',
    'Massimo Dutti',
    'Pandora',
    'Victoria\'s Secret',
    'Nocturne',
    'Ipekyol'
  ];

  // Favorite brands
  Set<String> _favoriteBrands = {};

  // For 3D tilt effect
  double _cardTiltX = 0;
  double _cardTiltY = 0;

  // Retailer background images
  final Map<String, String> _brandBackgrounds = {
    'Gucci': 'assets/images/gucci_bg.png',
    'Zara': 'assets/images/zara_bg.png',
    'Stradivarius': 'assets/images/stradivarius_bg.png',
    'Cartier': 'assets/images/cartier_bg.png',
    'Swarovski': 'assets/images/swarovski_bg.png',
    'Guess': 'assets/images/guess_bg.png',
    'Mango': 'assets/images/mango_bg.png',
    'Bershka': 'assets/images/bershka_bg.png',
  };

  @override
  void initState() {
    super.initState();

    // Load favorite brands
    _loadFavoriteBrands();

    // Main fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    // Floating Action Button animation
    _floatingActionButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _floatingActionButtonController,
      curve: Curves.easeInOut,
    );

    // Search bar slide animation
    _searchBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _searchBarAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Pulse animation for URL validation
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.07,
    ).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.elasticInOut,
      ),
    );

    // Initialization
    _scrollController.addListener(_handleScroll);
    _linkController.addListener(_validateUrlInput);
    
    // Start animations in sequence
    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      _searchBarAnimationController.forward();
    });

    // Initialize card animations with staggered timing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCardAnimations();
    });
  }

  Future<void> _loadFavoriteBrands() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteBrands = Set<String>.from(prefs.getStringList('favoriteBrands') ?? []);
    });
  }

  Future<void> _saveFavoriteBrands() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteBrands', _favoriteBrands.toList());
  }

  void _toggleFavorite(String brandName) {
    setState(() {
      if (_favoriteBrands.contains(brandName)) {
        _favoriteBrands.remove(brandName);
      } else {
        _favoriteBrands.add(brandName);
      }
    });
    _saveFavoriteBrands();
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_favoriteBrands.contains(brandName) 
          ? 'Added $brandName to favorites' 
          : 'Removed $brandName from favorites'
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: _favoriteBrands.contains(brandName) 
          ? Colors.green[700] 
          : Colors.grey[800],
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
    
    // If we're on the favorites tab, refresh animations
    if (_selectedCategoryIndex == 3) {
      _initializeCardAnimations();
    }
  }

  void _initializeCardAnimations() {
    // Clear any existing animations
    for (var controller in _cardAnimationControllers) {
      controller.dispose();
    }
    
    _cardAnimationControllers = [];
    _cardScaleAnimations = [];
    _cardOpacityAnimations = [];

    // Create animations for each card with staggered delays
    for (int i = 0; i < _dataService.retailSites.length; i++) {
      final cardController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      
      final scaleAnimation = Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: cardController,
        curve: Curves.easeOutCubic,
      ));
      
      final opacityAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: cardController,
        curve: Curves.easeInOut,
      ));
      
      _cardAnimationControllers.add(cardController);
      _cardScaleAnimations.add(scaleAnimation);
      _cardOpacityAnimations.add(opacityAnimation);
      
      // Start with staggered timing
      Future.delayed(Duration(milliseconds: 600 + (i * 70)), () {
        if (mounted) {
          cardController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _linkController.removeListener(_validateUrlInput);
    _linkController.dispose();
    _linkFocusNode.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _floatingActionButtonController.dispose();
    _searchBarAnimationController.dispose();
    _pulseAnimationController.dispose();
    
    for (var controller in _cardAnimationControllers) {
      controller.dispose();
    }
    
    super.dispose();
  }

  void _handleScroll() {
    final showButton = _scrollController.offset > 100;
    if (showButton != _showFloatingSearchButton) {
      setState(() {
        _showFloatingSearchButton = showButton;
      });

      if (showButton) {
        _floatingActionButtonController.forward();
      } else {
        _floatingActionButtonController.reverse();
      }
    }
  }

  void _navigateToSite(int index) {
    // Add haptic feedback with different patterns based on brand type
    if (_luxuryBrands.contains(_dataService.retailSites[index]['name'])) {
      HapticFeedback.mediumImpact(); // Premium feel for luxury brands
    } else {
      HapticFeedback.lightImpact(); // Standard feedback for other brands
    }

    // Navigate to the WebView screen
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => WebViewScreen(
          initialSiteIndex: index,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // Validates the URL as the user types
  void _validateUrlInput() {
    final text = _linkController.text.trim();
    
    // If text is empty, reset to neutral state
    if (text.isEmpty) {
      setState(() {
        _isValidUrl = false;
        _isInvalidUrl = false;
        _retailerName = "";
        _pulseAnimationController.reset();
      });
      return;
    }
    
    // Skip validation if already processing
    if (_isProcessingUrl) {
      return;
    }
    
    // Process the URL without navigating
    final result = _urlHandler.processUrl(text);
    
    setState(() {
      bool wasValid = _isValidUrl;
      _isValidUrl = result['isValid'];
      _isInvalidUrl = !result['isValid'] && text.isNotEmpty;
      _retailerName = result['retailerName'] ?? "";
      
      // Trigger pulse animation if validation state changed to valid
      if (!wasValid && _isValidUrl) {
        _pulseAnimationController.reset();
        _pulseAnimationController.forward();
      }
    });
  }

  // Process and navigate to the URL entered by the user
  void _processUrl() async {
    if (_isProcessingUrl) return; // Prevent multiple taps while processing
    
    setState(() {
      _isProcessingUrl = true;
    });
    
    final url = _linkController.text.trim();
    
    // Add a satisfying haptic feedback
    HapticFeedback.mediumImpact();
    
    // Clear focus and collapse keyboard
    _linkFocusNode.unfocus();
    
    // Process the URL
    final result = _urlHandler.processUrl(url);
    
    if (!result['isValid']) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['errorMessage']),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.redAccent,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      setState(() {
        _isProcessingUrl = false;
        _isInvalidUrl = true;
        _isValidUrl = false;
      });
      return;
    }
    
    // Show a success message with the retailer name
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Text('Opening ${result['retailerName']}...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green[700],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
    
    // Navigate to WebView with the processed URL
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => WebViewScreen(
          initialSiteIndex: result['retailerIndex'],
          initialUrl: result['normalizedUrl'],
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.3);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          
          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ).then((_) {
      // Reset processing state when returning from WebView
      setState(() {
        _isProcessingUrl = false;
        _validateUrlInput(); // Re-validate after returning
      });
    });
  }

  void _updateCardTilt(double dx, double dy, Size size) {
    // Calculate tilt angles based on touch position
    setState(() {
      _cardTiltX = (dy / size.height - 0.5) * 10; // -5 to 5 degrees
      _cardTiltY = -(dx / size.width - 0.5) * 10; // -5 to 5 degrees
    });
  }

  void _resetCardTilt() {
    setState(() {
      _cardTiltX = 0;
      _cardTiltY = 0;
    });
  }

  bool _shouldShowSite(String? siteName) {
    if (siteName == null) return false;
    
    switch (_selectedCategoryIndex) {
      case 1: // Luxury
        return _luxuryBrands.contains(siteName);
      case 2: // Fashion
        return _fashionBrands.contains(siteName);
      case 3: // Favorites
        return _favoriteBrands.contains(siteName);
      case 0: // All
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with subtle gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[50]!,
                  Colors.grey[100]!,
                  Colors.grey[50]!,
                ],
              ),
            ),
          ),
          
          // Decorative circles in the background
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              ),
            ),
          ),
          
          Positioned(
            bottom: -80,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Top padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 16),
                  ),
                  
                  // Search bar with animation
                  SliverToBoxAdapter(
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isValidUrl ? _pulseAnimation.value : 1.0,
                              child: child,
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isValidUrl 
                                  ? Colors.green.withOpacity(0.1) 
                                  : _isInvalidUrl 
                                      ? Colors.red.withOpacity(0.1) 
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.07),
                                  blurRadius: 16,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: _isValidUrl 
                                    ? Colors.green 
                                    : _isInvalidUrl 
                                        ? Colors.red 
                                        : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: _linkController,
                                  focusNode: _linkFocusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Paste product URL',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                    prefixIcon: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      child: Icon(
                                        Icons.link,
                                        color: _isValidUrl 
                                            ? Colors.green 
                                            : _isInvalidUrl 
                                                ? Colors.red 
                                                : Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                    suffixIcon: _isProcessingUrl
                                        ? Container(
                                            margin: const EdgeInsets.all(10),
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                _isValidUrl 
                                                    ? Colors.green 
                                                    : Theme.of(context).colorScheme.secondary,
                                              ),
                                            ),
                                          )
                                        : AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            child: IconButton(
                                              icon: Icon(
                                                _isValidUrl 
                                                    ? Icons.check_circle 
                                                    : Icons.search,
                                                size: 26,
                                              ),
                                              color: _isValidUrl 
                                                  ? Colors.green 
                                                  : _isInvalidUrl 
                                                      ? Colors.red 
                                                      : Theme.of(context).colorScheme.secondary,
                                              onPressed: _processUrl,
                                              splashRadius: 24,
                                            ),
                                          ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 16,
                                    ),
                                  ),
                                  onChanged: (_) => _validateUrlInput(),
                                  onSubmitted: (_) => _processUrl(),
                                  enabled: !_isProcessingUrl,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                
                                // Show retailer name with animation if URL is valid
                                AnimatedCrossFade(
                                  firstChild: const SizedBox.shrink(),
                                  secondChild: Padding(
                                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          size: 14,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Found: $_retailerName',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  crossFadeState: _isValidUrl && _retailerName.isNotEmpty
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  duration: const Duration(milliseconds: 300),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Title section with animation
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Discover Luxury',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w300,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Browse your favorite luxury and fashion retailers',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.black54,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Category selector with horizontal scroll
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 0, 16),
                        child: SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final isSelected = _selectedCategoryIndex == index;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _selectedCategoryIndex = index;
                                  });
                                  
                                  // Re-initialize card animations when category changes
                                  _initializeCardAnimations();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: isSelected 
                                        ? [
                                            BoxShadow(
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (index == 3 && isSelected)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 5),
                                            child: Icon(
                                              Icons.favorite,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          ),
                                        Text(
                                          _categories[index],
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.black54,
                                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (index == 3 && _favoriteBrands.isNotEmpty && !isSelected)
                                          Container(
                                            margin: const EdgeInsets.only(left: 5),
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.red.withOpacity(0.8),
                                            ),
                                            child: Center(
                                              child: Text(
                                                _favoriteBrands.length.toString(),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Retailer cards with staggered animations
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final site = _dataService.retailSites[index];
                          final name = site['name']!;
                          
                          // Skip items based on selected category
                          if (!_shouldShowSite(name)) {
                            return const SizedBox.shrink();
                          }
                          
                          // Check if animations are initialized
                          if (index >= _cardAnimationControllers.length) {
                            return const SizedBox.shrink();
                          }
                          
                          return AnimatedBuilder(
                            animation: _cardAnimationControllers[index],
                            builder: (context, child) {
                              return Opacity(
                                opacity: _cardOpacityAnimations[index].value,
                                child: Transform.scale(
                                  scale: _cardScaleAnimations[index].value,
                                  child: child,
                                ),
                              );
                            },
                            child: _buildEnhancedRetailerCard(site, index),
                          );
                        },
                        childCount: _dataService.retailSites.length,
                      ),
                    ),
                  ),
                  
                  // Empty state for favorites
                  if (_selectedCategoryIndex == 3 && _favoriteBrands.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        height: 200,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite_border,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No favorites yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 30),
                              child: Text(
                                'Tap the heart icon on any brand to add it to your favorites',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 30),
                  ),
                ],
              ),
            ),
          ),
          
          // Floating search button that appears when scrolling
          Positioned(
            bottom: 20,
            right: 20,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: AnimatedOpacity(
                opacity: _showFloatingSearchButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton(
                  onPressed: () {
                    // Scroll back to top with animation
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                    );
                    
                    // Focus on search bar
                    Future.delayed(const Duration(milliseconds: 300), () {
                      _linkFocusNode.requestFocus();
                    });
                  },
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  mini: false,
                  child: const Icon(Icons.search),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // This fixed version focuses specifically on the button area that's causing the overflow

Widget _buildEnhancedRetailerCard(Map<String, String> site, int index) {
  final name = site['name']!;
  final bool isLuxuryBrand = _luxuryBrands.contains(name);
  final bool isFavorite = _favoriteBrands.contains(name);
  
  return Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: GestureDetector(
      onTapDown: (details) {
        // Calculate the relative position for 3D effect
        final size = context.size ?? Size(0, 0);
        _updateCardTilt(details.localPosition.dx, details.localPosition.dy, size);
      },
      onTapUp: (_) => _resetCardTilt(),
      onTapCancel: () => _resetCardTilt(),
      onTap: () => _navigateToSite(index),
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateX(_cardTiltX * (math.pi / 180))
          ..rotateY(_cardTiltY * (math.pi / 180)),
        alignment: Alignment.center,
        child: Hero(
          tag: 'retailer_card_$index',
          child: Container(
            height: 175, // Adjusted height
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: isLuxuryBrand 
                      ? Theme.of(context).colorScheme.secondary.withOpacity(0.3)
                      : Colors.transparent,
                  blurRadius: 12,
                  spreadRadius: -2,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image with blur or gradient
                  _brandBackgrounds.containsKey(name)
                      ? ShaderMask(
                          shaderCallback: (rect) {
                            return LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withOpacity(0.9),
                                Colors.black.withOpacity(0.7),
                                Colors.black.withOpacity(0.5),
                              ],
                            ).createShader(rect);
                          },
                          blendMode: BlendMode.darken,
                          child: Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(_brandBackgrounds[name]!),
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isLuxuryBrand
                                  ? [
                                      const Color(0xFF1E1E1E),
                                      const Color(0xFF2D2D2D),
                                      const Color(0xFF3A3A3A),
                                    ]
                                  : [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                      Theme.of(context).colorScheme.primary.withOpacity(0.6),
                                    ],
                            ),
                          ),
                        ),
                  
                  // Subtle glass effect overlay
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 0.5,
                        sigmaY: 0.5,
                      ),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                  
                  // Content overlay with gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.2),
                        ],
                      ),
                    ),
                  ),
                  
                  // Favorite button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () {
                        _toggleFavorite(name);
                        // Prevent the card tap
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return ScaleTransition(scale: animation, child: child);
                          },
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            key: ValueKey<bool>(isFavorite),
                            color: isFavorite ? Colors.red : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Main content area with padding
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Brand name section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Brand name - moved up higher since we removed circles
                            Text(
                              name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32, // Larger font size
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            // Category tag - directly below the brand name
                            if (isLuxuryBrand && !_fashionBrands.contains(name))
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LUXURY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              )
                            else if (_fashionBrands.contains(name) && !_luxuryBrands.contains(name))
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'FASHION',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                            
                        // Explore button at the bottom
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'EXPLORE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Shimmer effect on hover (subtle shine)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: const [0, 0.3, 0.6, 1],
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}