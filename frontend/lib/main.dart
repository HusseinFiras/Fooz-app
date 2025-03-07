// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

void main() {
  // Initialize binding first
  WidgetsFlutterBinding.ensureInitialized();
  
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
          secondary: const Color(0xFFE0B872), // Gold accent
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
          bodyLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w400),
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
          indicatorColor: const Color(0xFFE0B872).withOpacity(0.2),
        ),
      ),
      home: const HomePage(), // Changed from HomeScreen to HomePage
    );
  }
}