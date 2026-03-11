import 'package:flutter/material.dart';
import '../theme/responsive_theme.dart';

/// Responsive layout builder that adapts to screen size
/// Provides consistent breakpoint-based layouts across the app
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? compact;
  final Widget? medium;
  final Widget? expanded;

  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.compact,
    this.medium,
    this.expanded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use new naming convention if provided
        if (compact != null || medium != null || expanded != null) {
          if (constraints.maxWidth < ResponsiveTheme.mobileBreakpoint) {
            return compact ?? mobile;
          } else if (constraints.maxWidth < ResponsiveTheme.tabletBreakpoint) {
            return medium ?? tablet ?? mobile;
          } else {
            return expanded ?? desktop ?? tablet ?? mobile;
          }
        }

        // Legacy naming convention
        if (constraints.maxWidth < ResponsiveTheme.mobileBreakpoint) {
          return mobile;
        } else if (constraints.maxWidth < ResponsiveTheme.tabletBreakpoint) {
          return tablet ?? mobile;
        } else {
          return desktop ?? tablet ?? mobile;
        }
      },
    );
  }
}

/// Responsive value provider - returns different values based on screen size
class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  T getValue(BuildContext context) {
    if (ResponsiveBreakpoints.isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    } else if (ResponsiveBreakpoints.isTablet(context)) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }
}

/// Responsive padding utility
class ResponsivePadding {
  static EdgeInsets all(BuildContext context) {
    return ResponsiveValue<EdgeInsets>(
      mobile: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(24),
      desktop: const EdgeInsets.all(32),
    ).getValue(context);
  }

  static EdgeInsets horizontal(BuildContext context) {
    return ResponsiveValue<EdgeInsets>(
      mobile: const EdgeInsets.symmetric(horizontal: 16),
      tablet: const EdgeInsets.symmetric(horizontal: 24),
      desktop: const EdgeInsets.symmetric(horizontal: 32),
    ).getValue(context);
  }

  static EdgeInsets vertical(BuildContext context) {
    return ResponsiveValue<EdgeInsets>(
      mobile: const EdgeInsets.symmetric(vertical: 16),
      tablet: const EdgeInsets.symmetric(vertical: 24),
      desktop: const EdgeInsets.symmetric(vertical: 32),
    ).getValue(context);
  }

  static EdgeInsets content(BuildContext context) {
    return ResponsiveValue<EdgeInsets>(
      mobile: const EdgeInsets.all(16),
      tablet: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      desktop: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
    ).getValue(context);
  }
}

/// Responsive spacing utility
class ResponsiveSpacing {
  static double small(BuildContext context) {
    return ResponsiveValue<double>(
      mobile: 8,
      tablet: 12,
      desktop: 16,
    ).getValue(context);
  }

  static double medium(BuildContext context) {
    return ResponsiveValue<double>(
      mobile: 16,
      tablet: 20,
      desktop: 24,
    ).getValue(context);
  }

  static double large(BuildContext context) {
    return ResponsiveValue<double>(
      mobile: 24,
      tablet: 32,
      desktop: 40,
    ).getValue(context);
  }

  static double extraLarge(BuildContext context) {
    return ResponsiveValue<double>(
      mobile: 32,
      tablet: 48,
      desktop: 64,
    ).getValue(context);
  }
}

/// Responsive grid utility
class ResponsiveGrid {
  static int getColumns(BuildContext context) {
    return ResponsiveValue<int>(
      mobile: 1,
      tablet: 2,
      desktop: 3,
    ).getValue(context);
  }

  static int getColumnsForCards(BuildContext context) {
    return ResponsiveValue<int>(
      mobile: 1,
      tablet: 2,
      desktop: 4,
    ).getValue(context);
  }

  static double getAspectRatio(BuildContext context) {
    return ResponsiveValue<double>(
      mobile: 1.2,
      tablet: 1.4,
      desktop: 1.6,
    ).getValue(context);
  }

  static double getCrossAxisSpacing(BuildContext context) {
    return ResponsiveSpacing.medium(context);
  }

  static double getMainAxisSpacing(BuildContext context) {
    return ResponsiveSpacing.medium(context);
  }
}

/// Responsive container with max width constraints
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final bool center;

  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.center = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? 
      ResponsiveValue<double>(
        mobile: double.infinity,
        tablet: 800,
        desktop: 1200,
      ).getValue(context);

    Widget content = Container(
      constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
      padding: padding ?? ResponsivePadding.content(context),
      child: child,
    );

    if (center && ResponsiveBreakpoints.isDesktop(context)) {
      content = Center(child: content);
    }

    return content;
  }
}

/// Responsive text scaling
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? scaleFactor;

  const ResponsiveText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.scaleFactor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scale = scaleFactor ?? ResponsiveValue<double>(
      mobile: 1.0,
      tablet: 1.1,
      desktop: 1.2,
    ).getValue(context);

    return Text(
      text,
      style: style?.copyWith(fontSize: (style?.fontSize ?? 14) * scale),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Responsive icon sizing
class ResponsiveIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;

  const ResponsiveIcon(
    this.icon, {
    Key? key,
    this.color,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? ResponsiveValue<double>(
      mobile: 24,
      tablet: 28,
      desktop: 32,
    ).getValue(context);

    return Icon(
      icon,
      color: color,
      size: effectiveSize,
    );
  }
}
