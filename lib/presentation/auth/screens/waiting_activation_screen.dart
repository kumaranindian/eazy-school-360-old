import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../dashboard/screens/admin_dashboard_screen.dart';
import 'enhanced_login_screen.dart';

class WaitingActivationScreen extends ConsumerStatefulWidget {
  /// When set, the screen treats THIS specific school as the one waiting for
  /// activation. Used after a user adds a 2nd school to an account that was
  /// previously activated — we must check the new school's state, not the
  /// user's already-true global `isActive`.
  final String? pendingSchoolId;
  final String? pendingSchoolName;

  const WaitingActivationScreen({
    super.key,
    this.pendingSchoolId,
    this.pendingSchoolName,
  });

  @override
  ConsumerState<WaitingActivationScreen> createState() =>
      _WaitingActivationScreenState();
}

class _WaitingActivationScreenState extends ConsumerState<WaitingActivationScreen>
    with TickerProviderStateMixin {
  // Dark theme colors - match main application
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _accentAmber = Color(0xFFFFB020);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final AnimationController _fadeController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _rotateAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _isChecking = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(_rotateController);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      // Use Firebase Auth as the source of truth — the Riverpod session can
      // legitimately be null right after signup (we signed the user up but
      // never went through AuthNotifier.signIn). Only send the user back to
      // login if there is genuinely no Firebase user.
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _signOutToLogin();
        return;
      }

      // When a specific school is pending (e.g. user added a 2nd school to
      // an already-active account), we MUST check THAT school's activation
      // — `users/{uid}.isActive` is already true from the first school.
      bool activated;
      final pendingId = widget.pendingSchoolId;
      if (pendingId != null && pendingId.isNotEmpty) {
        final schoolDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(pendingId)
            .get();
        final membershipDoc = await FirebaseFirestore.instance
            .collection('userMemberships')
            .doc(firebaseUser.uid)
            .collection('schools')
            .doc(pendingId)
            .get();
        final schoolActive = schoolDoc.data()?['isActive'] == true;
        final membershipActive = membershipDoc.data()?['isActive'] == true;
        activated = schoolActive && membershipActive;
      } else {
        // Classic first-signup flow: check the user-level activation.
        final authRepo = ref.read(authRepositoryProvider);
        final appUser = await authRepo.getUserDetails(firebaseUser.uid);
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        final status = (userDoc.data()?['status'] as String?)?.toUpperCase();
        final flagActive = userDoc.data()?['isActive'] == true;
        activated =
            flagActive || status == 'ACTIVE' || (appUser?.isActive ?? false);
      }

      if (!activated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: _cardDark,
              content: Text(
                'Still pending. We will notify you once activated.',
                style: TextStyle(color: _textPrimary),
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Account/school is active now. For the 2nd-school flow we must also
      // switch the auth context so the dashboard loads the newly-activated
      // school (not the original one).
      if (pendingId != null && pendingId.isNotEmpty) {
        try {
          await ref.read(authProvider.notifier).switchSchool(pendingId);
        } catch (_) {/* non-fatal; we still navigate below */}
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _cardDark,
            content: Text(
              'Could not check status: $e',
              style: const TextStyle(color: _textPrimary),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _signOutToLogin() async {
    await ref.read(authProvider.notifier).signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EnhancedLoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final email = session?.email ?? FirebaseAuth.instance.currentUser?.email ?? '';
    // Prefer the explicit pendingSchoolName passed by signup (2nd-school flow
    // where session might still point at the originally-active school).
    final schoolName = widget.pendingSchoolName ??
        session?.activeMembership?.schoolName ??
        (session?.memberships.isNotEmpty == true
            ? session!.memberships.first.schoolName
            : '');

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAnimatedBadge(),
                      const SizedBox(height: 32),
                      const Text(
                        'Account Pending Activation',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        schoolName.isEmpty
                            ? 'Your account is awaiting approval.'
                            : '"$schoolName" is awaiting administrator approval.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildInfoCard(email),
                      const SizedBox(height: 24),
                      _buildTimelineSteps(),
                      const SizedBox(height: 28),
                      _buildActions(),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: _signOutToLogin,
                        icon: const Icon(Icons.logout_rounded,
                            color: _textSecondary, size: 18),
                        label: const Text(
                          'Sign out',
                          style: TextStyle(color: _textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBadge() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating outer ring
          RotationTransition(
            turns: _rotateAnimation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _accentAmber.withOpacity(0.25),
                  width: 2,
                ),
                gradient: SweepGradient(
                  colors: [
                    _accentAmber.withOpacity(0.0),
                    _accentAmber.withOpacity(0.0),
                    _accentAmber.withOpacity(0.6),
                    _accentAmber.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.6, 0.85, 1.0],
                ),
              ),
            ),
          ),
          // Pulsing glow
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentAmber.withOpacity(0.08),
              ),
            ),
          ),
          // Inner badge
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _cardDark,
              border: Border.all(color: _accentAmber.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _accentAmber.withOpacity(0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: _accentAmber,
              size: 44,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String email) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    color: _accentBlue, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Signed in as',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            email.isEmpty ? '—' : email,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: _borderColor, height: 1),
          const SizedBox(height: 14),
          const Text(
            'Your registration has been received. Our team will review and activate your school account shortly. You will be able to log in once approved.',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSteps() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          _timelineRow(
            icon: Icons.check_circle_rounded,
            color: _accentBlue,
            title: 'Registration submitted',
            subtitle: 'We received your details',
            isDone: true,
          ),
          _connector(done: true),
          _timelineRow(
            icon: Icons.pending_actions_rounded,
            color: _accentAmber,
            title: 'Pending review',
            subtitle: 'Administrator is reviewing your account',
            isDone: false,
            isActive: true,
          ),
          _connector(done: false),
          _timelineRow(
            icon: Icons.rocket_launch_rounded,
            color: _textSecondary,
            title: 'Access granted',
            subtitle: 'Sign in and start using Eazy School 360',
            isDone: false,
          ),
        ],
      ),
    );
  }

  Widget _timelineRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDone,
    bool isActive = false,
  }) {
    Widget leading = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(isDone || isActive ? 0.18 : 0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(isDone || isActive ? 0.6 : 0.25),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 16),
    );

    if (isActive) {
      leading = ScaleTransition(scale: _pulseAnimation, child: leading);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDone || isActive ? _textPrimary : _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                    color: _textSecondary, fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _connector({required bool done}) => Container(
        margin: const EdgeInsets.only(left: 15),
        height: 18,
        width: 2,
        color: done ? _accentBlue.withOpacity(0.5) : _borderColor,
      );

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isChecking ? null : _checkStatus,
            icon: _isChecking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_isChecking ? 'Checking...' : 'Check status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _accentBlue.withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: _cardDark,
                  content: Text(
                    'Contact support: hi@avail404.com',
                    style: TextStyle(color: _textPrimary),
                  ),
                  duration: Duration(seconds: 4),
                ),
              );
            },
            icon: const Icon(Icons.support_agent_rounded, size: 18),
            label: const Text('Contact support'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textPrimary,
              side: const BorderSide(color: _borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
