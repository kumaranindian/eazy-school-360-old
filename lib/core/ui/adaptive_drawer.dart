import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../theme/responsive_theme.dart';
import 'responsive_layout.dart';
import 'app_scaffold.dart';

/// Adaptive drawer that changes behavior based on screen size
/// Provides consistent navigation across different form factors
class AdaptiveDrawer extends StatelessWidget {
  final List<NavigationItem> navigationItems;
  final UserSession? userSession;
  final bool isRail;
  final VoidCallback? onItemTap;

  const AdaptiveDrawer({
    Key? key,
    required this.navigationItems,
    this.userSession,
    this.isRail = false,
    this.onItemTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isRail) {
      return _buildNavigationRail(context);
    }

    return ResponsiveLayout(
      mobile: _buildMobileDrawer(context),
      tablet: _buildTabletDrawer(context),
      desktop: _buildDesktopDrawer(context),
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: navigationItems.map((item) {
                return _buildDrawerItem(context, item);
              }).toList(),
            ),
          ),
          _buildDrawerFooter(context),
        ],
      ),
    );
  }

  Widget _buildTabletDrawer(BuildContext context) {
    return Drawer(
      width: 320,
      child: Column(
        children: [
          _buildDrawerHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: navigationItems.map((item) {
                return _buildExpandedDrawerItem(context, item);
              }).toList(),
            ),
          ),
          _buildDrawerFooter(context),
        ],
      ),
    );
  }

  Widget _buildDesktopDrawer(BuildContext context) {
    return Container(
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
      child: Column(
        children: [
          _buildDrawerHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: navigationItems.map((item) {
                return _buildExpandedDrawerItem(context, item);
              }).toList(),
            ),
          ),
          _buildDrawerFooter(context),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    return NavigationRail(
      selectedIndex: _getSelectedIndex(),
      onDestinationSelected: (index) {
        navigationItems[index].onTap?.call();
        onItemTap?.call();
      },
      labelType: NavigationRailLabelType.all,
      destinations: navigationItems.map((item) {
        return NavigationRailDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.selectedIcon ?? item.icon),
          label: Text(item.label),
        );
      }).toList(),
      leading: _buildRailHeader(context),
      trailing: _buildRailFooter(context),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (userSession != null) ...[
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: Text(
                    userSession!.displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  userSession!.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getRoleDisplayName(userSession!.role.name),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.school,
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Eazy School 360',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRailHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (userSession != null) ...[
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                userSession!.displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ] else ...[
            Icon(
              Icons.school,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, NavigationItem item) {
    return ListTile(
      leading: Icon(
        item.isSelected ? (item.selectedIcon ?? item.icon) : item.icon,
        color: item.isSelected 
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        item.label,
        style: TextStyle(
          color: item.isSelected 
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
          fontWeight: item.isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: item.badge,
      selected: item.isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      onTap: () {
        item.onTap?.call();
        onItemTap?.call();
        if (ResponsiveBreakpoints.isMobile(context)) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  Widget _buildExpandedDrawerItem(BuildContext context, NavigationItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(
          item.isSelected ? (item.selectedIcon ?? item.icon) : item.icon,
          color: item.isSelected 
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: item.isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
            fontWeight: item.isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: item.badge,
        selected: item.isSelected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: () {
          item.onTap?.call();
          onItemTap?.call();
          if (ResponsiveBreakpoints.isMobile(context)) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Widget _buildDrawerFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Version 1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Icon(
        Icons.settings_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  int _getSelectedIndex() {
    for (int i = 0; i < navigationItems.length; i++) {
      if (navigationItems[i].isSelected) {
        return i;
      }
    }
    return 0;
  }

  String _getRoleDisplayName(String role) {
    switch (role.toUpperCase()) {
      case 'SUPER_ADMIN':
        return 'System Administrator';
      case 'ADMIN':
        return 'School Administrator';
      case 'STAFF':
        return 'Staff Member';
      default:
        return role;
    }
  }
}
