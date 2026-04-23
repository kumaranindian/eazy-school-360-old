import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/membership.dart';

/// Shown after a successful login when the user has more than one active
/// membership. The user picks which school to enter; that choice is
/// persisted as their `defaultSchoolId` so subsequent logins skip this
/// screen unless they switch schools from the app bar.
class SchoolChooserScreen extends ConsumerStatefulWidget {
  /// Where to navigate after a school is successfully selected.
  final String Function(Membership selected) routeBuilder;

  const SchoolChooserScreen({
    super.key,
    required this.routeBuilder,
  });

  @override
  ConsumerState<SchoolChooserScreen> createState() =>
      _SchoolChooserScreenState();
}

class _SchoolChooserScreenState extends ConsumerState<SchoolChooserScreen> {
  String? _busySchoolId;

  // Dark theme colors - match main application
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final memberships = (session?.memberships ?? const <Membership>[])
        .toList(); // Show ALL memberships, active and inactive

    // Sort: most recently accessed first, then by joined date.
    memberships.sort((a, b) {
      final la = a.lastAccessedAt ?? a.joinedAt;
      final lb = b.lastAccessedAt ?? b.joinedAt;
      return lb.compareTo(la);
    });

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Icon(Icons.account_tree_rounded,
                      size: 56, color: _accentBlue),
                  const SizedBox(height: 16),
                  Text(
                    'Choose a school',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session?.email == null
                        ? 'Select which school you want to work in.'
                        : '${session!.email} has access to ${memberships.length} schools.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (memberships.isEmpty)
                    _emptyState()
                  else
                    ...memberships.map(_buildMembershipCard),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).signOut();
                      if (!mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login', (_) => false);
                    },
                    icon: const Icon(Icons.logout, color: _textSecondary),
                    label: const Text('Sign out',
                        style: TextStyle(color: _textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipCard(Membership m) {
    final rolesText = m.roles.map(_roleLabel).join('  ');
    final isBusy = _busySchoolId == m.schoolId;
    final isActive = m.isActive && m.schoolIsActive;
    final subtitle = m.lastAccessedAt != null
        ? 'Last opened ${DateFormat('dd MMM yyyy').format(m.lastAccessedAt!)}'
        : 'Joined ${DateFormat('dd MMM yyyy').format(m.joinedAt)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive 
              ? _borderColor
              : Theme.of(context).colorScheme.error.withOpacity(0.3),
          width: isActive ? 1 : 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isBusy || !isActive ? null : () => _select(m),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? _accentBlue.withOpacity(0.15)
                        : Theme.of(context).colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isActive ? Icons.school_rounded : Icons.school_outlined,
                    color: isActive 
                        ? _accentBlue
                        : Theme.of(context).colorScheme.error,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.schoolName.isEmpty ? m.schoolId : m.schoolName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (!isActive) _pill('PENDING', Theme.of(context).colorScheme.error),
                          if (!isActive) const SizedBox(width: 6),
                          if (m.isOwner) _pill('OWNER', Theme.of(context).colorScheme.secondary),
                          if (m.isOwner) const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              rolesText,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: _textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 11,
                            color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                isBusy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                      )
                    : Icon(
                        !isActive ? Icons.block : Icons.arrow_forward_ios,
                        size: 16, 
                        color: !isActive 
                            ? Theme.of(context).colorScheme.error.withOpacity(0.6)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      );

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Text(
          'You do not have access to any active school yet.\n\n'
          'If you have pending schools, please wait for admin approval.\n'
          'Contact support: hi@avail404.com for assistance.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 14,
          ),
        ),
      );

  Future<void> _select(Membership m) async {
    // Check if school is inactive
    if (!m.isActive || !m.schoolIsActive) {
      setState(() => _busySchoolId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${m.schoolName} is currently pending activation.\n\n'
          'Please wait for administrator approval.\n'
          'Contact support: hi@avail404.com for assistance.'
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 5),
      ));
      return;
    }

    setState(() => _busySchoolId = m.schoolId);
    try {
      final result =
          await ref.read(authProvider.notifier).switchSchool(m.schoolId);
      if (!mounted) return;
      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${result.error ?? 'Failed to open school'}\n\nContact support: hi@avail404.com'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ));
        return;
      }
      final route = widget.routeBuilder(m);
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } finally {
      if (mounted) setState(() => _busySchoolId = null);
    }
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
