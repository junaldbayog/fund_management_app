import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/trading_journal_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/menu_screen.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage service
  await StorageService().init();

  runApp(const FundManagerApp());
}

class FundManagerApp extends StatelessWidget {
  const FundManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JPB Capital',
      themeMode: ThemeMode.dark,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: const AppScaffold(child: LoginScreen()),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
          color: Color(0xFF00d293),
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          height: 1.3,
          color: Color(0xFF2C3E50),
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          height: 1.4,
          color: Color(0xFF2C3E50),
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.5,
          color: Color(0xFF2C3E50),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.5,
          color: Color(0xFF2C3E50),
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          height: 1.4,
          color: Color(0xFF2C3E50),
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00d293),
        primary: const Color(0xFF00d293),
        secondary: const Color(0xFF26A69A),
        background: Colors.white,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: Color(0xFF2C3E50),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
          color: Color(0xFF00d293),
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          height: 1.3,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          height: 1.4,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.5,
          color: Colors.white70,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.5,
          color: Colors.white70,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          height: 1.4,
          color: Colors.white,
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: const Color(0xFF00d293),
        primary: const Color(0xFF00d293),
        secondary: const Color(0xFF26A69A),
        background: const Color(0xFF121212),
        surface: const Color(0xFF1E1E1E),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xFF1E1E1E),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: const Color(0xFF00d293),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white70,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white54,
        ),
      ),
    );
  }
}

class AppScaffold extends StatelessWidget {
  final Widget child;

  const AppScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/jpb-capital-logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: child,
    );
  }
} 