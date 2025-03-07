// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../services/data_service.dart';
import 'webview_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;

  // Colors for the gradient backgrounds
  final List<List<Color>> _gradients = [
    [const Color(0xFFF8F9FA), const Color(0xFFE9ECEF)],
    [const Color(0xFFFFF8E1), const Color(0xFFFFECB3)],
    [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
    [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
    [const Color(0xFFFCE4EC), const Color(0xFFF8BBD0)],
    [const Color(0xFFEDE7F6), const Color(0xFFD1C4E9)],
  ];

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

    // Setup scale animation for card press
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Start the animations
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luxury Retailers'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Luxury Price Checker',
                applicationVersion: '1.0.0',
                applicationIcon: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                children: [
                  const Text(
                    'Compare prices across luxury retail websites and track product details easily.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant header section
          Container(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a Store',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Browse your favorite luxury retailers',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Grid of site cards with animation
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio:
                      0.80, // Reduced from 0.85 to give more vertical space
                ),
                itemCount: _dataService.retailSites.length,
                itemBuilder: (context, index) {
                  // Create a staggered animation effect
                  final staggeredDelay = Duration(milliseconds: 50 * index);
                  Future.delayed(staggeredDelay, () {
                    if (_fadeController.isCompleted) {
                      // Only apply the additional animation if the main fade is done
                      // This avoids animation conflicts
                    }
                  });

                  final site = _dataService.retailSites[index];
                  return _buildSiteCard(site, index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(Map<String, String> site, int index) {
    // Use a stable but random-looking gradient for each card
    final gradientIndex = index % _gradients.length;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Hero(
        tag: 'site_${site['name']}',
        child: Material(
          borderRadius: BorderRadius.circular(16),
          elevation: 4,
          shadowColor: Colors.black26,
          child: InkWell(
            onTap: () => _navigateToSite(index),
            onHover: (isHovering) {
              if (isHovering) {
                _scaleController.forward();
              } else {
                _scaleController.reverse();
              }
            },
            borderRadius: BorderRadius.circular(16),
            splashColor:
                Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            highlightColor:
                Theme.of(context).colorScheme.secondary.withOpacity(0.05),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _gradients[gradientIndex],
                ),
              ),
              child: ClipRect(
                // Add ClipRect to prevent overflow painting
                child: LayoutBuilder(builder: (context, constraints) {
                  // Calculate appropriate sizes based on available space
                  final availableHeight = constraints.maxHeight;
                  final logoSize =
                      availableHeight * 0.5; // 50% of height for logo

                  return Padding(
                    padding: const EdgeInsets.all(10.0), // Reduced padding
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo container with subtle shadow
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 0,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              site['name']![0],
                              style: TextStyle(
                                fontSize:
                                    logoSize * 0.45, // Proportional font size
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                            height: availableHeight *
                                0.05), // 5% of height for spacing
                        Flexible(
                          child: Text(
                            site['name']!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Shop Now',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToSite(int index) {
    // Use try-catch for the haptic feedback to avoid potential errors
    try {
      HapticFeedback.lightImpact(); // Add haptic feedback
    } catch (e) {
      // Silently handle any haptic feedback errors
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WebViewScreen(initialSiteIndex: index),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}
