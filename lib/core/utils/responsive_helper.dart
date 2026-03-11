import 'package:flutter/material.dart';

/// Responsive breakpoints for different screen sizes
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1800;
}

/// Helper class for responsive design
class ResponsiveHelper {
  final BuildContext context;
  
  ResponsiveHelper(this.context);
  
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  
  bool get isMobile => screenWidth < ResponsiveBreakpoints.mobile;
  bool get isTablet => screenWidth >= ResponsiveBreakpoints.mobile && screenWidth < ResponsiveBreakpoints.tablet;
  bool get isDesktop => screenWidth >= ResponsiveBreakpoints.tablet && screenWidth < ResponsiveBreakpoints.desktop;
  bool get isLargeDesktop => screenWidth >= ResponsiveBreakpoints.desktop;
  
  bool get isWeb => screenWidth >= ResponsiveBreakpoints.tablet;
  bool get isMobileOrTablet => screenWidth < ResponsiveBreakpoints.tablet;
  
  /// Get responsive value based on screen size
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    if (isLargeDesktop && largeDesktop != null) return largeDesktop;
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }
  
  /// Get responsive padding
  EdgeInsets get screenPadding {
    return EdgeInsets.symmetric(
      horizontal: responsive<double>(
        mobile: 16,
        tablet: 24,
        desktop: 48,
        largeDesktop: 64,
      ),
      vertical: responsive<double>(
        mobile: 16,
        tablet: 20,
        desktop: 24,
        largeDesktop: 32,
      ),
    );
  }
  
  /// Get max content width for centered layouts
  double get maxContentWidth {
    return responsive<double>(
      mobile: screenWidth,
      tablet: 600,
      desktop: 800,
      largeDesktop: 1000,
    );
  }
  
  /// Get grid cross axis count
  int get gridCrossAxisCount {
    return responsive<int>(
      mobile: 2,
      tablet: 3,
      desktop: 4,
      largeDesktop: 5,
    );
  }
  
  /// Get card aspect ratio
  double get cardAspectRatio {
    return responsive<double>(
      mobile: 1.1,
      tablet: 1.2,
      desktop: 1.3,
      largeDesktop: 1.4,
    );
  }
  
  /// Get font scale factor
  double get fontScale {
    return responsive<double>(
      mobile: 1.0,
      tablet: 1.05,
      desktop: 1.1,
      largeDesktop: 1.15,
    );
  }
  
  /// Get icon size
  double get iconSize {
    return responsive<double>(
      mobile: 24,
      tablet: 28,
      desktop: 32,
      largeDesktop: 36,
    );
  }
  
  /// Get spacing
  double get spacing {
    return responsive<double>(
      mobile: 16,
      tablet: 20,
      desktop: 24,
      largeDesktop: 32,
    );
  }
  
  /// Get small spacing
  double get smallSpacing {
    return responsive<double>(
      mobile: 8,
      tablet: 10,
      desktop: 12,
      largeDesktop: 16,
    );
  }
  
  /// Get large spacing
  double get largeSpacing {
    return responsive<double>(
      mobile: 24,
      tablet: 32,
      desktop: 40,
      largeDesktop: 48,
    );
  }
  
  /// Get border radius
  double get borderRadius {
    return responsive<double>(
      mobile: 12,
      tablet: 14,
      desktop: 16,
      largeDesktop: 20,
    );
  }
  
  /// Get button height
  double get buttonHeight {
    return responsive<double>(
      mobile: 48,
      tablet: 52,
      desktop: 56,
      largeDesktop: 60,
    );
  }
  
  /// Get input field height
  double get inputHeight {
    return responsive<double>(
      mobile: 52,
      tablet: 56,
      desktop: 60,
      largeDesktop: 64,
    );
  }
}

/// Extension for easy access to ResponsiveHelper
extension ResponsiveContext on BuildContext {
  ResponsiveHelper get responsive => ResponsiveHelper(this);
}

/// Responsive widget that builds different layouts based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ResponsiveHelper responsive) mobile;
  final Widget Function(BuildContext context, ResponsiveHelper responsive)? tablet;
  final Widget Function(BuildContext context, ResponsiveHelper responsive)? desktop;
  
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    
    if (responsive.isDesktop || responsive.isLargeDesktop) {
      return (desktop ?? tablet ?? mobile)(context, responsive);
    }
    if (responsive.isTablet) {
      return (tablet ?? mobile)(context, responsive);
    }
    return mobile(context, responsive);
  }
}

/// Centered content wrapper with max width
class CenteredContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  
  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });
  
  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? responsive.maxContentWidth,
        ),
        padding: padding ?? responsive.screenPadding,
        child: child,
      ),
    );
  }
}
