// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/data_service.dart';
import 'webview_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  final TextEditingController _linkController = TextEditingController();
  final FocusNode _linkFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // For retailer card animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

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

    // Setup fade-in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Start the animations
    _fadeController.forward();
  }

  @override
  void dispose() {
    _linkController.dispose();
    _linkFocusNode.dispose();
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToSite(int index) {
    // Add haptic feedback
    HapticFeedback.lightImpact();

    // Navigate to the WebView screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(initialSiteIndex: index),
      ),
    );
  }

  void _searchLink() {
    final link = _linkController.text.trim();
    if (link.isNotEmpty) {
      // Clear focus and collapse keyboard
      _linkFocusNode.unfocus();
      
      // Show a simple loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading product...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Here you could add logic to determine which store the link belongs to
      // For now, we'll just demonstrate the concept
      Future.delayed(const Duration(milliseconds: 1500), () {
        // Navigate to WebView with the provided URL
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewScreen(
              initialSiteIndex: 0, 
              initialUrl: link.startsWith('http') ? link : 'https://$link',
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove the appBar completely
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ListView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              // Add some top padding to replace the AppBar
              const SizedBox(height: 16),
              
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _linkController,
                    focusNode: _linkFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Paste product URL',
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchLink,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                    ),
                    onSubmitted: (_) => _searchLink(),
                  ),
                ),
              ),
              
              // Title section
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a Store',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w300,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse your favorite luxury retailers',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Retailer list
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _dataService.retailSites.length,
                itemBuilder: (context, index) {
                  final site = _dataService.retailSites[index];
                  
                  // Create a staggered animation effect
                  final staggeredDelay = Duration(milliseconds: 50 * index);
                  Future.delayed(staggeredDelay, () {
                    if (_fadeController.isCompleted) {
                      // Only apply the additional animation if the main fade is done
                    }
                  });
                  
                  return _buildRetailerCard(site, index);
                },
              ),
              
              // Add some bottom padding
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRetailerCard(Map<String, String> site, int index) {
    final name = site['name']!;
    
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.95, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        height: 140,
        margin: const EdgeInsets.only(bottom: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or gradient
              _brandBackgrounds.containsKey(name)
                  ? Image.asset(
                      _brandBackgrounds[name]!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: index % 2 == 0 ? Colors.grey[200] : Colors.white,
                      ),
                    ),
              
              // Overlay to ensure text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              
              // Content - Store name and Visit button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _navigateToSite(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Store name - positioned at top
                        Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: _brandBackgrounds.containsKey(name)
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                        
                        // Visit button - positioned at bottom right
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'VISIT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                      color: _brandBackgrounds.containsKey(name)
                                          ? Colors.white
                                          : Colors.black.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 12,
                                    color: _brandBackgrounds.containsKey(name)
                                        ? Colors.white
                                        : Colors.black.withOpacity(0.7),
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}