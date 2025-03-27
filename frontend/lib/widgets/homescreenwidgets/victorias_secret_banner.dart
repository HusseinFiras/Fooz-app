// widgets/homescreenwidgets/victorias_secret_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/data_service.dart';
import '../../constants/theme_constants.dart'; // Import our theme constants

class VictoriasSecretBanner extends StatelessWidget {
  final Function(int) navigateToSite;
  final DataService dataService;

  const VictoriasSecretBanner({
    Key? key,
    required this.navigateToSite,
    required this.dataService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Updated colors to match our theme
    final Color bgColor = LuxuryTheme.accentLightBlush;      // Soft blush background
    final Color accentColor = LuxuryTheme.primaryRosegold;   // Rosegold for buttons and accents
    final Color textColor = LuxuryTheme.textCharcoal;        // Charcoal for text

    return Container(
      height: 350,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LuxuryTheme.largeCardRadius),
        boxShadow: LuxuryTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuxuryTheme.largeCardRadius),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: bgColor,
              ),
            ),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // "FOZ PICKS" label with rosegold background
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LuxuryTheme.rosegoldGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'FOOZ PICKS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        // Brand name with serif font
                        Text(
                          "Victoria's Secret",
                          style: TextStyle(
                            fontFamily: 'DM Serif Display',
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: accentColor,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Luxe Loungewear & Iconic Fragrances',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            color: textColor,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 24),
                        // Shop button with rosegold gradient
                        Container(
                          width: 160,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              int vsIndex = dataService.retailSites.indexWhere(
                                (site) => site['name'] == "Victoria's Secret"
                              );
                              if (vsIndex != -1) {
                                navigateToSite(vsIndex);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              padding: EdgeInsets.zero,
                              elevation: 0,
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: LuxuryTheme.rosegoldGradient,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.3),
                                    offset: Offset(0, 2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Container(
                                height: 44,
                                alignment: Alignment.center,
                                child: Text(
                                  "SHOP COLLECTION",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(LuxuryTheme.largeCardRadius),
                      bottomRight: Radius.circular(LuxuryTheme.largeCardRadius),
                    ),
                    child: Image.asset(
                      'assets/images/vs_product.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerLeft,
                      height: double.infinity,
                      width: double.infinity,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}