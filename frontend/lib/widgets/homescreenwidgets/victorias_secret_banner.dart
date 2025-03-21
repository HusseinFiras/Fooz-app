import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/data_service.dart';

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
    // Muted pink color palette that matches the app design
    final Color mutedPink = Color(0xFFF8E1E7);        // Background color (keeping as is)
    final Color primaryPink = Color.fromARGB(255, 239, 126, 162);      // Muted pink for button and heading
    final Color textPink = Color.fromARGB(255, 239, 126, 162);         // Darker muted pink for text

    return Container(
      height: 350,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: mutedPink,
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
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryPink,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'FOZ PICKS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Victoria's Secret",
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: textPink,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Luxe Loungewear & Iconic Fragrances',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                        ),
                        SizedBox(height: 24),
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
                              backgroundColor: primaryPink,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              padding: EdgeInsets.zero,
                              elevation: 2,
                            ),
                            child: Center(
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
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
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