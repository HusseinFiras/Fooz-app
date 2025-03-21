// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/debug_utils.dart';
import 'main_app.dart'; // Import the MainApp class

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
      systemNavigationBarColor: Colors.black,
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
        // Elegant color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E1E1E),
          brightness: Brightness.light,
          primary: const Color(0xFF1E1E1E),
          secondary: const Color(0xFFFF80AB), // Gold accent
          tertiary: const Color(0xFF6B6B6B),
        ),
        // Typography
        fontFamily: 'Montserrat',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w300),
          displayMedium: TextStyle(fontWeight: FontWeight.w300),
          displaySmall: TextStyle(fontWeight: FontWeight.w300),
          headlineMedium: TextStyle(fontWeight: FontWeight.w400),
          headlineSmall: TextStyle(fontWeight: FontWeight.w500),
          titleLarge: TextStyle(fontWeight: FontWeight.w500),
          bodyLarge:
              TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w400),
          bodyMedium:
              TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w400),
        ),
        // UI elements
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            fontSize: 18,
            color: Color(0xFF1E1E1E),
          ),
          iconTheme: IconThemeData(color: Color(0xFF1E1E1E)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E1E1E),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8F8),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: const Color.fromARGB(255, 244, 29, 136).withOpacity(0.2),
        ),
      ),
      home: const MainApp(), // MainApp is now properly imported
    );
  }
}
