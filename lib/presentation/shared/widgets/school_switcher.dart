import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/membership.dart';
import '../../auth/screens/enhanced_login_screen.dart';

/// Compact dropdown that lets a user with multiple active memberships
/// switch the active school without signing out.
///
/// Drop this into any `AppBar.actions` list:
/// ```dart
/// AppBar(actions: const [SchoolSwitcher(), SizedBox(width: 8)])
/// ```
///
/// Renders nothing when the user only has one active membership — there's
/// nothing to switch to.
class SchoolSwitcher extends ConsumerWidget {
  final Color? textColor;
  final bool showLabel;

  const SchoolSwitcher({
    super.key,
    this.textColor,
    this.showLabel = true,
  });

  // Dark theme colors - match main application
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);
  static const Color _accentAmber = Color(0xFFFFB020);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const SizedBox.shrink();

    final memberships = session.memberships;
    // Hide only if the user truly has just one school total (nothing to
    // switch to and nothing pending to show).
    if (memberships.length <= 1) return const SizedBox.shrink();

    final active = memberships
        .where((m) => m.isActive && m.schoolIsActive)
        .toList();
    final pending = memberships
        .where((m) => !(m.isActive && m.schoolIsActive))
        .toList();

    final currentId = session.schoolId;
    final currentName = session.activeMembership?.schoolName ??
        (active
                .where((m) => m.schoolId == currentId)
                .map((m) => m.schoolName)
                .firstOrNull ??
            (active.isNotEmpty ? active.first.schoolName : 'Select School'));

    final color = textColor ?? _textPrimary;

    return PopupMenuButton<String>(
      tooltip: 'Switch school',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      color: _cardDark,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _borderColor),
      ),
      itemBuilder: (ctx) => [
        if (active.isNotEmpty)
          const PopupMenuItem<String>(
            enabled: false,
            height: 30,
            child: Text(
              'ACTIVE SCHOOLS',
              style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8),
            ),
          ),
        ...active.map((m) => PopupMenuItem<String>(
              value: m.schoolId,
              child: _buildMenuTile(context, m,
                  isCurrent: m.schoolId == currentId, isPending: false),
            )),
        if (pending.isNotEmpty) ...[
          const PopupMenuDivider(height: 8),
          const PopupMenuItem<String>(
            enabled: false,
            height: 30,
            child: Text(
              'PENDING ACTIVATION',
              style: TextStyle(
                  color: _accentAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8),
            ),
          ),
          ...pending.map((m) => PopupMenuItem<String>(
                value: 'pending:${m.schoolId}',
                enabled: false,
                child: _buildMenuTile(context, m,
                    isCurrent: false, isPending: true),
              )),
        ],
      ],
      onSelected: (schoolId) async {
        if (schoolId.startsWith('pending:')) return;
        if (schoolId == currentId) return;
        await _switch(context, ref, schoolId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apartment_rounded, size: 16, color: _accentBlue),
            if (showLabel) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  currentName.isEmpty ? 'Select School' : currentName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: _textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    Membership m, {
    required bool isCurrent,
    required bool isPending,
  }) {
    final rolesText = m.roles.map(_roleLabel).join(' • ');
    final name = m.schoolName.isEmpty ? m.schoolId : m.schoolName;
    final Color iconColor = isPending
        ? _accentAmber
        : (isCurrent ? _accentBlue : _textSecondary);
    final IconData iconData = isPending
        ? Icons.hourglass_top_rounded
        : (isCurrent ? Icons.check_circle_rounded : Icons.school_rounded);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(iconData, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isPending ? _textSecondary : _textPrimary,
                            fontSize: 13,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w600),
                      ),
                    ),
                    if (isPending) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentAmber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('PENDING',
                            style: TextStyle(
                                color: _accentAmber,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                if (rolesText.isNotEmpty)
                  Text(rolesText,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _switch(
      BuildContext context, WidgetRef ref, String schoolId) async {
    // Fire-and-wait switch. On success we pop all routes and land on the
    // login screen which will then re-route to the right dashboard for the
    // newly-active role. This avoids trying to guess the navigation stack
    // for every caller.
    final messenger = ScaffoldMessenger.of(context);
    final result =
        await ref.read(authProvider.notifier).switchSchool(schoolId);
    if (!context.mounted) return;
    if (!result.success) {
      messenger.showSnackBar(SnackBar(
        content: Text('${result.error ?? 'Failed to switch school'}\n\nContact support: hi@avail404.com'),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 5),
      ));
      return;
    }

    // Rebuild navigation against the new role.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EnhancedLoginScreen()),
      (_) => false,
    );
  }

  String _roleLabel(UserRole r) {
    switch (r) {
      case UserRole.SUPER_ADMIN:
        return 'Super Admin';
      case UserRole.ADMIN:
        return 'Admin';
      case UserRole.FINANCE:
        return 'Finance';
      case UserRole.STAFF:
        return 'Staff';
      case UserRole.PARENT:
        return 'Parent';
      case UserRole.NONE:
        return '—';
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
