import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/responsive_theme.dart';
import 'responsive_layout.dart';

/// Responsive AppBar that adapts to screen size and user context
class ResponsiveAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool showMenuButton;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ResponsiveAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.onBackPressed,
    this.showMenuButton = true,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    
    return AppBar(
      title: _buildTitle(context),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: ResponsiveBreakpoints.isDesktop(context) ? 0 : 1,
      scrolledUnderElevation: 1,
      centerTitle: ResponsiveBreakpoints.isMobile(context),
      leading: _buildLeading(context),
      automaticallyImplyLeading: showMenuButton,
      actions: _buildActions(context, session),
      titleSpacing: ResponsiveBreakpoints.isDesktop(context) ? 32 : 16,
    );
  }

  Widget _buildTitle(BuildContext context) {
    return ResponsiveLayout(
      mobile: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
        overflow: TextOverflow.ellipsis,
      ),
      tablet: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall,
        overflow: TextOverflow.ellipsis,
      ),
      desktop: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading;
    
    if (showBackButton) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
      );
    }
    
    return null;
  }

  List<Widget> _buildActions(BuildContext context, session) {
    final List<Widget> actionWidgets = [];
    
    // Add custom actions
    if (actions != null) {
      actionWidgets.addAll(actions!);
    }
    
    // Add user menu if session exists
    if (session != null) {
      actionWidgets.add(_buildUserMenu(context, session));
    }
    
    return actionWidgets;
  }

  Widget _buildUserMenu(BuildContext context, session) {
    return ResponsiveLayout(
      mobile: _buildMobileUserMenu(context, session),
      tablet: _buildTabletUserMenu(context, session),
      desktop: _buildDesktopUserMenu(context, session),
    );
  }

  Widget _buildMobileUserMenu(BuildContext context, session) {
    return PopupMenuButton<String>(
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          session.displayName.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      onSelected: (value) => _handleMenuAction(context, value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    session.role.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined),
              SizedBox(width: 12),
              Text('Settings'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout),
              SizedBox(width: 12),
              Text('Sign Out'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletUserMenu(BuildContext context, session) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // User info
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              session.role.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Avatar with menu
        PopupMenuButton<String>(
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              session.displayName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          onSelected: (value) => _handleMenuAction(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline),
                  SizedBox(width: 12),
                  Text('Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined),
                  SizedBox(width: 12),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 12),
                  Text('Sign Out'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopUserMenu(BuildContext context, session) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User info card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    session.displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      session.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      session.role.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onSelected: (value) => _handleMenuAction(context, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline),
                          SizedBox(width: 12),
                          Text('Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined),
                          SizedBox(width: 12),
                          Text('Settings'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout),
                          SizedBox(width: 12),
                          Text('Sign Out'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'profile':
        // Navigate to profile screen
        break;
      case 'settings':
        // Navigate to settings screen
        break;
      case 'logout':
        // Handle logout
        _handleLogout(context);
        break;
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement actual logout
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
