import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/responsive_theme.dart';
import 'responsive_layout.dart';
import 'adaptive_drawer.dart';
import 'responsive_app_bar.dart';

/// Standardized scaffold with responsive behavior
/// Adapts layout based on screen size and user role
class AppScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final List<NavigationItem>? navigationItems;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;

  const AppScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.navigationItems,
    this.floatingActionButton,
    this.drawer,
    this.actions,
    this.showBackButton = false,
    this.onBackPressed,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    
    return ResponsiveLayout(
      mobile: _buildMobileLayout(context, session),
      tablet: _buildTabletLayout(context, session),
      desktop: _buildDesktopLayout(context, session),
    );
  }

  Widget _buildMobileLayout(BuildContext context, session) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: ResponsiveAppBar(
        title: title,
        actions: actions,
        showBackButton: showBackButton,
        onBackPressed: onBackPressed,
      ),
      drawer: navigationItems != null 
        ? AdaptiveDrawer(
            navigationItems: navigationItems!,
            userSession: session,
          )
        : drawer,
      body: SafeArea(
        child: ResponsiveContainer(
          child: body,
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: navigationItems != null && navigationItems!.length <= 5
        ? _buildBottomNavigation(context)
        : null,
    );
  }

  Widget _buildTabletLayout(BuildContext context, session) {
    if (navigationItems != null && navigationItems!.length > 3) {
      // Use drawer for complex navigation
      return _buildDrawerLayout(context, session);
    } else {
      // Use bottom navigation for simple navigation
      return _buildMobileLayout(context, session);
    }
  }

  Widget _buildDesktopLayout(BuildContext context, session) {
    if (navigationItems != null) {
      return _buildSideNavigationLayout(context, session);
    } else {
      return _buildDrawerLayout(context, session);
    }
  }

  Widget _buildDrawerLayout(BuildContext context, session) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: ResponsiveAppBar(
        title: title,
        actions: actions,
        showBackButton: showBackButton,
        onBackPressed: onBackPressed,
      ),
      drawer: navigationItems != null 
        ? AdaptiveDrawer(
            navigationItems: navigationItems!,
            userSession: session,
          )
        : drawer,
      body: SafeArea(
        child: ResponsiveContainer(
          child: body,
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildSideNavigationLayout(BuildContext context, session) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          // Side navigation
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
            ),
            child: AdaptiveDrawer(
              navigationItems: navigationItems!,
              userSession: session,
              isRail: true,
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                ResponsiveAppBar(
                  title: title,
                  actions: actions,
                  showBackButton: showBackButton,
                  onBackPressed: onBackPressed,
                  showMenuButton: false,
                ),
                Expanded(
                  child: SafeArea(
                    child: ResponsiveContainer(
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget? _buildBottomNavigation(BuildContext context) {
    if (navigationItems == null || navigationItems!.isEmpty) return null;

    return NavigationBar(
      destinations: navigationItems!.map((item) {
        return NavigationDestination(
          icon: Icon(item.icon),
          label: item.label,
        );
      }).toList(),
      onDestinationSelected: (index) {
        navigationItems![index].onTap?.call();
      },
    );
  }
}

/// Navigation item model for consistent navigation
class NavigationItem {
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final VoidCallback? onTap;
  final bool isSelected;
  final String? route;
  final Widget? badge;

  const NavigationItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.onTap,
    this.isSelected = false,
    this.route,
    this.badge,
  });

  NavigationItem copyWith({
    String? label,
    IconData? icon,
    IconData? selectedIcon,
    VoidCallback? onTap,
    bool? isSelected,
    String? route,
    Widget? badge,
  }) {
    return NavigationItem(
      label: label ?? this.label,
      icon: icon ?? this.icon,
      selectedIcon: selectedIcon ?? this.selectedIcon,
      onTap: onTap ?? this.onTap,
      isSelected: isSelected ?? this.isSelected,
      route: route ?? this.route,
      badge: badge ?? this.badge,
    );
  }
}
