// lib/widgets/brandscreenwidgets/brand_grid_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/data_service.dart';
import '../../constants/theme_constants.dart';

class CachedBrandLogo extends StatelessWidget {
  final String assetPath;
  final String brandName;
  
  const CachedBrandLogo({
    Key? key, 
    required this.assetPath,
    required this.brandName,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      // Special handling for Miu Miu - try both possible filenames
      brandName == 'Miu Miu' 
          ? 'assets/images/brands/miumiu.png'
          : assetPath,
      // Use cacheWidth to optimize memory usage
      cacheWidth: 200,
      // Set gapless playback to true to prevent flicker during reload
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to text when image is not available
        return Text(
          brandName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            fontFamily: 'Lato',
            color: LuxuryTheme.textCharcoal,
          ),
        );
      },
    );
  }
}

class BrandGridWidget extends StatelessWidget {
  final List<Map<String, dynamic>> brands;
  final Function(BuildContext, String) onBrandTapped;

  const BrandGridWidget({
    Key? key,
    required this.brands,
    required this.onBrandTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LuxuryTheme.neutralOffWhite.withOpacity(0.5),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.0,
          crossAxisSpacing: 4, // Slightly increased spacing
          mainAxisSpacing: 4,  // Slightly increased spacing
        ),
        padding: EdgeInsets.all(4),
        // Use physics to keep scroll position
        physics: AlwaysScrollableScrollPhysics(),
        itemCount: brands.length,
        itemBuilder: (context, index) {
          final brand = brands[index];
          final isUnderMaintenance = brand['maintenance'] == true;
          final brandName = brand['name'] as String;
          
          return GestureDetector(
            onTap: isUnderMaintenance
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onBrandTapped(context, brandName);
                  },
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 1, // Light shadow
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8), // More rounded corners
                side: BorderSide(
                  color: LuxuryTheme.primaryRosegold, // Full rose gold border
                  width: 1.5,
                ),
              ),
              color: Colors.white,
              child: Stack(
                children: [
                  // Brand logo or name centered
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: brand['logoAsset'] != null && brand['logoAsset'].toString().isNotEmpty
                          ? CachedBrandLogo(
                              assetPath: brand['logoAsset'],
                              brandName: brandName,
                            )
                          : Text(
                              brandName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'Lato',
                                color: LuxuryTheme.textCharcoal,
                              ),
                            ),
                    ),
                  ),
                  
                  // Maintenance overlay if needed
                  if (isUnderMaintenance)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.engineering,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Maintenance',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Lato',
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}