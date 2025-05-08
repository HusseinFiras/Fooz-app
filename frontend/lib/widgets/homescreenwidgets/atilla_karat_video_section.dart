// lib/widgets/homescreenwidgets/atilla_karat_video_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../constants/theme_constants.dart';

class AtillaKaratVideoSection extends StatefulWidget {
  final Function(int, String) navigateToProduct;
  
  const AtillaKaratVideoSection({
    Key? key,
    required this.navigateToProduct,
  }) : super(key: key);
  
  @override
  _AtillaKaratVideoSectionState createState() => _AtillaKaratVideoSectionState();
}

class _AtillaKaratVideoSectionState extends State<AtillaKaratVideoSection> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isButtonPressed = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize with asset video
    _controller = VideoPlayerController.asset(
      'assets/video/atilla_karat.mp4',
    )..initialize().then((_) {
      setState(() {
        _isInitialized = true;
      });
      // Auto-play and loop video
      _controller.setLooping(true);
      _controller.play();
      _controller.setVolume(0.0); // Mute the video
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Refined color palette for this section
    final Color bgColor = Color(0xFFFCF7F5); // Softer, warmer off-white
    final Color accentColor = LuxuryTheme.primaryRosegold;
    final Color pressedColor = Color(0xFF8B2635); // Dark rose gold color for pressed state
    final Color textColor = LuxuryTheme.textCharcoal;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuxuryTheme.largeCardRadius), // Large rounded corners
        child: Container(
          color: bgColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with magazine-style typography
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'ATILLA KARAT',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'DM Serif Display', // Serif font for heading
                        letterSpacing: 0.5,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 20,
                      width: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LuxuryTheme.rosegoldGradient,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'EXCLUSIVE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.0,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Magazine cover style content - fixed height to ensure no overflow
              Container(
                height: 440, // Reduced height to prevent overflow
                child: Row(
                  children: [
                    // Left side for text content
                    Expanded(
                      flex: 5,
                      child: Container(
                        color: bgColor,
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top magazine-style masthead
                            Text(
                              'ATILLA KARAT × FOOZ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                fontFamily: 'Lato',
                                color: accentColor.withOpacity(0.8),
                              ),
                            ),
                            
                            SizedBox(height: 24),
                            
                            // Main title with serif font for elegance
                            Text(
                              'TIMELESS\nELEGANCE',
                              style: TextStyle(
                                fontSize: 32,
                                height: 0.9,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'DM Serif Display',
                                letterSpacing: -0.5,
                                color: textColor,
                              ),
                            ),
                            
                            SizedBox(height: 16),
                            
                            // Description
                            Text(
                              'Discover the exclusive collection of\nhandcrafted luxury jewelry',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Lato',
                                color: textColor.withOpacity(0.7),
                              ),
                            ),
                            
                            SizedBox(height: 28),
                            
                            // CTA Button with interactive effect
                            GestureDetector(
                              onTapDown: (_) {
                                setState(() {
                                  _isButtonPressed = true;
                                });
                              },
                              onTapUp: (_) {
                                HapticFeedback.lightImpact();
                                // Add a delay to make the effect more noticeable
                                Future.delayed(Duration(milliseconds: 200), () {
                                  if (mounted) {
                                    setState(() {
                                      _isButtonPressed = false;
                                    });
                                    widget.navigateToProduct(14, "https://www.bluediamond.com.tr/koleksiyon/atilla-karat-exclusive");
                                  }
                                });
                              },
                              onTapCancel: () {
                                setState(() {
                                  _isButtonPressed = false;
                                });
                              },
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: _isButtonPressed ? pressedColor.withOpacity(0.1) : Colors.transparent,
                                  border: Border.all(
                                    color: _isButtonPressed ? pressedColor : accentColor,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Text(
                                    'EXPLORE COLLECTION',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1,
                                      color: _isButtonPressed ? pressedColor : accentColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            Spacer(), // Push the footer to the bottom
                            
                            // Magazine style footer
                            Row(
                              children: [
                                Icon(
                                  Icons.diamond_outlined,
                                  size: 14,
                                  color: accentColor.withOpacity(0.6),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'A.K. × FOOZ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: accentColor.withOpacity(0.6),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Right side for video
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(LuxuryTheme.largeCardRadius),
                          bottomRight: Radius.circular(LuxuryTheme.largeCardRadius),
                        ),
                        child: Stack(
                          children: [
                            // Video
                            Positioned.fill(
                              child: _isInitialized
                                ? FittedBox(
                                    fit: BoxFit.cover,
                                    clipBehavior: Clip.hardEdge,
                                    child: SizedBox(
                                      width: _controller.value.size.width,
                                      height: _controller.value.size.height,
                                      child: VideoPlayer(_controller),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[300],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                            ),
                            
                            // Add subtle rosegold overlay for cohesion
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      accentColor.withOpacity(0.2),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Vertical "EXCLUSIVE PARTNER" text
                            Positioned(
                              top: 20,
                              right: 16,
                              child: RotatedBox(
                                quarterTurns: 1,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    'EXCLUSIVE PARTNER',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}