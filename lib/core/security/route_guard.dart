import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'role_guard_service.dart';
import 'role_policy.dart';

/// Route Guard Widget
/// Protects routes based on user role and permissions
class RouteGuard extends ConsumerWidget {
  final Widget child;
  final String route;
  final UIModule? requiredModule;
  final BackendAction? requiredAction;
  final String? requiredSchoolId;
  final Widget? fallbackWidget;

  const RouteGuard({
    Key? key,
    required this.child,
    required this.route,
    this.requiredModule,
    this.requiredAction,
    this.requiredSchoolId,
    this.fallbackWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    
    // Show loading while session is being initialized
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final roleGuard = ref.watch(roleGuardServiceProvider);

    // Check authentication
    if (!roleGuard.isAuthenticated) {
      return _buildAccessDenied(context, 'Authentication required');
    }

    // Check route access
    if (!roleGuard.canAccessRoute(route)) {
      return _buildAccessDenied(context, 'Route access denied');
    }

    // Check UI module access
    if (requiredModule != null && !roleGuard.hasUIAccess(requiredModule!)) {
      return _buildAccessDenied(context, 'Module access denied');
    }

    // Check backend action permission
    if (requiredAction != null && !roleGuard.canPerformAction(requiredAction!)) {
      return _buildAccessDenied(context, 'Action not permitted');
    }

    // Check school access
    if (requiredSchoolId != null && !roleGuard.canAccessSchool(requiredSchoolId)) {
      return _buildAccessDenied(context, 'School access denied');
    }

    // All checks passed, render child
    return child;
  }

  Widget _buildAccessDenied(BuildContext context, String reason) {
    if (fallbackWidget != null) {
      return fallbackWidget!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.block,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              reason,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feature Guard Widget
/// Conditionally shows/hides UI elements based on permissions
class FeatureGuard extends ConsumerWidget {
  final Widget child;
  final UIModule? requiredModule;
  final BackendAction? requiredAction;
  final String? requiredSchoolId;
  final Widget? fallbackWidget;
  final bool hideWhenDenied;

  const FeatureGuard({
    Key? key,
    required this.child,
    this.requiredModule,
    this.requiredAction,
    this.requiredSchoolId,
    this.fallbackWidget,
    this.hideWhenDenied = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleGuard = ref.watch(roleGuardServiceProvider);

    // Check authentication
    if (!roleGuard.isAuthenticated) {
      return hideWhenDenied ? const SizedBox.shrink() : (fallbackWidget ?? const SizedBox.shrink());
    }

    // Check UI module access
    if (requiredModule != null && !roleGuard.hasUIAccess(requiredModule!)) {
      return hideWhenDenied ? const SizedBox.shrink() : (fallbackWidget ?? const SizedBox.shrink());
    }

    // Check backend action permission
    if (requiredAction != null && !roleGuard.canPerformAction(requiredAction!)) {
      return hideWhenDenied ? const SizedBox.shrink() : (fallbackWidget ?? const SizedBox.shrink());
    }

    // Check school access
    if (requiredSchoolId != null && !roleGuard.canAccessSchool(requiredSchoolId)) {
      return hideWhenDenied ? const SizedBox.shrink() : (fallbackWidget ?? const SizedBox.shrink());
    }

    // All checks passed, render child
    return child;
  }
}

/// Role-based Navigation Guard
class NavigationGuard {
  static bool canNavigateTo(WidgetRef ref, String route) {
    final roleGuard = ref.read(roleGuardServiceProvider);
    return roleGuard.canAccessRoute(route);
  }

  static void navigateWithGuard(
    BuildContext context,
    WidgetRef ref,
    String route,
    Widget destination, {
    VoidCallback? onAccessDenied,
  }) {
    final roleGuard = ref.read(roleGuardServiceProvider);
    
    if (roleGuard.canAccessRoute(route)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => destination),
      );
    } else {
      if (onAccessDenied != null) {
        onAccessDenied();
      } else {
        _showAccessDeniedDialog(context);
      }
    }
  }

  static void _showAccessDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text('You do not have permission to access this feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Role-based Menu Item
class RoleBasedMenuItem extends ConsumerWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final UIModule? requiredModule;
  final BackendAction? requiredAction;

  const RoleBasedMenuItem({
    Key? key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.requiredModule,
    this.requiredAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureGuard(
      requiredModule: requiredModule,
      requiredAction: requiredAction,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}

/// Role-based Button
class RoleBasedButton extends ConsumerWidget {
  final String text;
  final VoidCallback onPressed;
  final UIModule? requiredModule;
  final BackendAction? requiredAction;
  final ButtonStyle? style;
  final Widget? icon;

  const RoleBasedButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.requiredModule,
    this.requiredAction,
    this.style,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureGuard(
      requiredModule: requiredModule,
      requiredAction: requiredAction,
      child: icon != null
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: icon!,
              label: Text(text),
              style: style,
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: style,
              child: Text(text),
            ),
    );
  }
}

/// Role-based FloatingActionButton
class RoleBasedFAB extends ConsumerWidget {
  final VoidCallback onPressed;
  final Widget child;
  final UIModule? requiredModule;
  final BackendAction? requiredAction;

  const RoleBasedFAB({
    Key? key,
    required this.onPressed,
    required this.child,
    this.requiredModule,
    this.requiredAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureGuard(
      requiredModule: requiredModule,
      requiredAction: requiredAction,
      child: FloatingActionButton(
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
