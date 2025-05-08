// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'constants/theme_constants.dart';
import 'utils/debug_utils.dart';
import 'main_app.dart';

/// Initialize clean debugging throughout the app
void initializeDebugging() {
  // Only enable detailed logs in debug mode
  if (kReleaseMode) {
    DebugLog.setLogLevel(DebugLog.ERROR); // Only errors in release
  } else {
    // Set log level based on your needs
    DebugLog.setLogLevel(DebugLog.INFO);

    // Enable only categories you want to see
    DebugLog.toggleCategory(DebugLog.PRODUCT, true);
    DebugLog.toggleCategory(DebugLog.WEBVIEW, true);
    DebugLog.toggleCategory(DebugLog.NETWORK, false);
    DebugLog.toggleCategory(DebugLog.UI, false);

    // Filter out WebView noise
    DebugLog.setFilterWebViewLogs(true);

    // Customize logger appearance
    DebugLog.setShowTimestamps(true);
    DebugLog.setMaxLogLength(300);

    // Override Flutter's verbose debug logs
    _overrideFlutterLogs();
  }

  DebugLog.i('Debugging initialized', category: DebugLog.GENERAL);
}

/// Override Flutter's default logging behavior for cleaner console
void _overrideFlutterLogs() {
  // Save original printer and replace with filtered version
  final originalPrinter = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    // Skip messages we don't want to see
    if (message == null) return;

    // Filter out unwanted Flutter logs
    final String msg = message.trim();
    final List<String> filterPhrases = [
      'The following assertion was thrown',
      'flutter:',
      'Warning:',
      'Error caught by',
      'constraints.debugAssertIsValid',
      'The specific RenderFlex',
      'Debug services',
      'Reloaded',
      'Syncing files',
      'Another exception was thrown',
      'This was caught by the framework',
      'Hot restart',
      'Ignoring header',
      '═══',
      '◉ ',
      '◢◤',
      'Another exception',
      'setState() called',
      'Restarted',
      'Handler',
      'WebViewController'
    ];

    // Check for filtered phrases
    if (filterPhrases.any((phrase) => msg.contains(phrase))) {
      return; // Skip these messages
    }

    // Print using the original printer
    originalPrinter(message, wrapWidth: wrapWidth);
  };
}

void main() {
  // Initialize binding first
  WidgetsFlutterBinding.ensureInitialized();

  // Configure image cache for better performance
  PaintingBinding.instance.imageCache.maximumSize = 200; // Default is 100
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB, default is 10 MB

  // Initialize clean debugging
  initializeDebugging();

  // Then set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: LuxuryTheme.textCharcoal,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luxury Price Checker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Elegant color scheme using our new theme constants
        colorScheme: ColorScheme.fromSeed(
          seedColor: LuxuryTheme.primaryRosegold,
          brightness: Brightness.light,
          primary: LuxuryTheme.primaryRosegold,
          secondary: LuxuryTheme.lightRosegold,
          tertiary: LuxuryTheme.accentBlush,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          background: LuxuryTheme.neutralOffWhite,
          surface: Colors.white,
        ),
        
        // Typography - Using Google Fonts
        fontFamily: GoogleFonts.lato().fontFamily,
        textTheme: TextTheme(
          displayLarge: GoogleFonts.dmSerifDisplay(fontWeight: FontWeight.w300),
          displayMedium: GoogleFonts.dmSerifDisplay(fontWeight: FontWeight.w300),
          displaySmall: GoogleFonts.dmSerifDisplay(fontWeight: FontWeight.w300),
          headlineMedium: GoogleFonts.dmSerifDisplay(fontWeight: FontWeight.w400),
          headlineSmall: GoogleFonts.dmSerifDisplay(fontWeight: FontWeight.w500),
          titleLarge: GoogleFonts.dmSerifDisplay(fontWeight: FontWeight.w500),
          bodyLarge: GoogleFonts.lato(fontWeight: FontWeight.w400),
          bodyMedium: GoogleFonts.lato(fontWeight: FontWeight.w400),
        ),
        
        // UI elements
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: LuxuryTheme.textCharcoal,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.dmSerifDisplay(
            fontWeight: FontWeight.w500,
            fontSize: 20,
            color: LuxuryTheme.textCharcoal,
          ),
          iconTheme: const IconThemeData(color: LuxuryTheme.textCharcoal),
        ),
        
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: LuxuryTheme.primaryRosegold,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LuxuryTheme.buttonRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: LuxuryTheme.primaryRosegold,
            side: const BorderSide(color: LuxuryTheme.primaryRosegold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LuxuryTheme.buttonRadius),
            ),
          ),
        ),
        
        cardTheme: CardTheme(
          elevation: 4,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LuxuryTheme.cardRadius),
          ),
        ),
        
        scaffoldBackgroundColor: LuxuryTheme.neutralOffWhite,
        
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: LuxuryTheme.primaryRosegold.withOpacity(0.2),
          labelTextStyle: MaterialStateProperty.all(
            GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      home: const MainApp(),
    );
  }
}