import 'package:flutter/material.dart';

/// Material 3 Design System Implementation
/// Professional, enterprise-grade theme with role-specific accents
class ResponsiveTheme {
  // Breakpoint definitions
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  
  // Base color palette - neutral with professional accents
  static const Color _primaryBlue = Color(0xFF1976D2);
  static const Color _surfaceGrey = Color(0xFFF5F5F5);
  static const Color _backgroundWhite = Color(0xFFFFFFFF);
  static const Color _onSurfaceGrey = Color(0xFF424242);
  static const Color _outlineGrey = Color(0xFFE0E0E0);
  
  // Role-specific accent colors
  static const Color superAdminAccent = Color(0xFF6A1B9A); // Deep Purple
  static const Color adminAccent = Color(0xFF1976D2);      // Blue
  static const Color staffAccent = Color(0xFF388E3C);      // Green
  
  /// Get theme data for the application
  static ThemeData getThemeData({Color? roleAccent}) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: roleAccent ?? _primaryBlue,
      brightness: Brightness.light,
      surface: _surfaceGrey,
      background: _backgroundWhite,
      onSurface: _onSurfaceGrey,
      outline: _outlineGrey,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      
      // Typography scale - consistent across all screens
      textTheme: _buildTextTheme(),
      
      // Component themes
      appBarTheme: _buildAppBarTheme(colorScheme),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        margin: const EdgeInsets.all(8),
      ),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      outlinedButtonTheme: _buildOutlinedButtonTheme(colorScheme),
      textButtonTheme: _buildTextButtonTheme(colorScheme),
      inputDecorationTheme: _buildInputDecorationTheme(colorScheme),
      navigationBarTheme: _buildNavigationBarTheme(colorScheme),
      drawerTheme: _buildDrawerTheme(),
      
      // Layout spacing
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  /// Professional typography scale
  static TextTheme _buildTextTheme() {
    return const TextTheme(
      // Display styles - for hero content
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.16,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.22,
      ),
      
      // Headline styles - for section headers
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.29,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.33,
      ),
      
      // Title styles - for card headers, dialog titles
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.50,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      
      // Body styles - for main content
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.50,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
      ),
      
      // Label styles - for buttons, tabs
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.45,
      ),
    );
  }

  static AppBarTheme _buildAppBarTheme(ColorScheme colorScheme) {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      centerTitle: false,
    );
  }


  static ElevatedButtonThemeData _buildElevatedButtonTheme(ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 1,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(ColorScheme colorScheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: colorScheme.outline),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme(ColorScheme colorScheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme(ColorScheme colorScheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  static NavigationBarThemeData _buildNavigationBarTheme(ColorScheme colorScheme) {
    return NavigationBarThemeData(
      elevation: 1,
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      labelTextStyle: MaterialStateProperty.all(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  static DrawerThemeData _buildDrawerTheme() {
    return const DrawerThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
    );
  }

  /// Get role-specific theme
  static ThemeData getRoleTheme(String role) {
    Color accent;
    switch (role.toUpperCase()) {
      case 'SUPER_ADMIN':
        accent = superAdminAccent;
        break;
      case 'ADMIN':
        accent = adminAccent;
        break;
      case 'STAFF':
        accent = staffAccent;
        break;
      default:
        accent = _primaryBlue;
    }
    return getThemeData(roleAccent: accent);
  }
}

/// Responsive breakpoint utilities
class ResponsiveBreakpoints {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveTheme.mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveTheme.mobileBreakpoint && 
           width < ResponsiveTheme.tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveTheme.tabletBreakpoint;
  }

  static bool isCompact(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveTheme.mobileBreakpoint;
  }

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveTheme.mobileBreakpoint && 
           width < ResponsiveTheme.tabletBreakpoint;
  }

  static bool isExpanded(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveTheme.tabletBreakpoint;
  }
}
