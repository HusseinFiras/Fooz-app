// widgets/homescreenwidgets/main_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../services/data_service.dart';
import '../../screens/webview_screen.dart';
import '../../constants/theme_constants.dart';

class MainBanner extends StatefulWidget {
  const MainBanner({Key? key}) : super(key: key);

  @override
  _MainBannerState createState() => _MainBannerState();
}

class _MainBannerState extends State<MainBanner> {
  int _realIndex = 0;
  Timer? _bannerTimer;
  late final PageController _pageController;
  final DataService _dataService = DataService();

  // Banner data with corresponding site indices
  final List<Map<String, dynamic>> _banners = [
    {
      'image': 'assets/images/gucci_bg.jpg',
      'gradient': [Color(0xFF1A237E), Color(0xFF3949AB)],
      'siteIndex': 0, // Gucci
    },
    {
      'image': 'assets/images/cartier_bg.jpeg',
      'siteIndex': 3, // Cartier
    },
    {
      'image': 'assets/images/swarovski_bg.jpg',
      'gradient': [Color(0xFF880E4F), Color(0xFFC2185B)],
      'siteIndex': 4, // Swarovski
    },
    {
      'image': 'assets/images/pandora_bg.jpg',
      'gradient': [Color(0xFF4A148C), Color(0xFF7B1FA2)],
      'siteIndex': 10, // Pandora
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1000);
    _realIndex = 1000 % _banners.length;
    _startBannerTimer();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _banners.length > 1) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _pageController.page!.round() + 1,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pageController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      // Set the background color to match the app's background
      color: LuxuryTheme.neutralOffWhite,
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Container(
        // Further reduced height
        height: 210,
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Stack(
          children: [
            // Clip with rounded corners
            ClipRRect(
              // Added rounded corners with 16 radius
              borderRadius: BorderRadius.circular(16),
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _realIndex = index % _banners.length;
                  });
                },
                itemBuilder: (context, index) {
                  final actualIndex = index % _banners.length;
                  final banner = _banners[actualIndex];
                  return GestureDetector(
                    onTap: () {
                      // Navigate to the corresponding site when banner is tapped
                      _navigateToSite(context, banner['siteIndex']);
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ShaderMask(
                          shaderCallback: (rect) {
                            return LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withOpacity(0.6),
                                Colors.transparent,
                              ],
                            ).createShader(rect);
                          },
                          blendMode: BlendMode.darken,
                          child: Image.asset(
                            banner['image'],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        
                        AnimatedContainer(
                          duration: Duration(milliseconds: 800),
                          decoration: BoxDecoration(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Indicator dots
            Positioned(
              bottom: 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_banners.length, (i) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.only(left: 4),
                    height: 8,
                    width: i == _realIndex ? 16 : 8,
                    decoration: BoxDecoration(
                      color: i == _realIndex ? Colors.white : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}