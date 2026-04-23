import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/domain/entities/app_user.dart';

import 'signup_screen.dart';
import 'school_chooser_screen.dart';
import '../../dashboard/screens/admin_dashboard_screen.dart';
import '../../dashboard/screens/staff_dashboard_screen.dart';
import '../../dashboard/screens/super_admin_dashboard_screen.dart';
import '../../dashboard/screens/parent_dashboard_screen.dart';
import '../../dashboard/screens/finance_dashboard_screen.dart';
import 'waiting_activation_screen.dart';

class EnhancedLoginScreen extends ConsumerStatefulWidget {
  const EnhancedLoginScreen({super.key});

  @override
  ConsumerState<EnhancedLoginScreen> createState() => _EnhancedLoginScreenState();
}

class _EnhancedLoginScreenState extends ConsumerState<EnhancedLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Dark theme colors - match main application
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.25, end: 0.55).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _entryController.dispose();
    _glowController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authResult = await ref.read(authProvider.notifier).signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (!authResult.success || authResult.session == null) {
        setState(() {
          _errorMessage = authResult.error ?? 'Login failed';
          _isLoading = false;
        });
        return;
      }

      final session = authResult.session!;

      // Debug: Print session info
      print('Login Debug - User: ${session.email}');
      print('Login Debug - Role: ${session.role}');
      print('Login Debug - School ID: ${session.schoolId}');
      print('Login Debug - Memberships: ${session.memberships.length}');
      print('Login Debug - Is Active: ${session.isActive}');

      if (!session.isActive) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaitingActivationScreen()));
        return;
      }

      // Multi-tenant routing: if the user belongs to more than one school
      // (active or inactive) and no preferred school was resolved, bounce them to the
      // School Chooser. This allows users to see all their schools and activation status.
      // Super admins skip this -- they aren't bound to a specific tenant.
      final allMemberships = session.memberships;
      final needsChooser = session.role != UserRole.SUPER_ADMIN &&
          session.schoolId == null &&
          allMemberships.length > 1;
      
      print('Login Debug - Needs Chooser: $needsChooser');
      
      if (needsChooser) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SchoolChooserScreen(
              routeBuilder: (m) => _routeForRole(m.primaryRole),
            ),
          ),
        );
        return;
      }

      // Handle case where user has no valid role but has memberships
      if (session.role == UserRole.NONE) {
        if (session.memberships.isEmpty) {
          setState(() {
            _errorMessage = 'Your account does not have a valid role. Please contact your administrator.';
            _isLoading = false;
          });
          return;
        } else if (session.memberships.length == 1) {
          // User has one membership, route using that role
          final membership = session.memberships.first;
          _routeByRole(membership.primaryRole);
          return;
        } else {
          // User has multiple memberships, show chooser
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SchoolChooserScreen(
                routeBuilder: (m) => _routeForRole(m.primaryRole),
              ),
            ),
          );
          return;
        }
      }

      _routeByRole(session.role);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _routeForRole(UserRole role) {
    switch (role) {
      case UserRole.SUPER_ADMIN:
        return '/super-admin-dashboard';
      case UserRole.ADMIN:
        return '/admin-dashboard';
      case UserRole.FINANCE:
        return '/finance-dashboard';
      case UserRole.STAFF:
        return '/staff-dashboard';
      case UserRole.PARENT:
        return '/parent-dashboard';
      case UserRole.NONE:
        return '/login';
    }
  }

  void _routeByRole(UserRole role) {
      if (role == UserRole.SUPER_ADMIN) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SuperAdminDashboardScreen()));
      } else if (role == UserRole.ADMIN) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
      } else if (role == UserRole.FINANCE) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FinanceDashboardScreen()));
      } else if (role == UserRole.STAFF) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StaffDashboardScreen()));
      } else if (role == UserRole.PARENT) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ParentDashboardScreen()));
      } else {
        setState(() {
          _errorMessage = 'Your account does not have a valid role.';
          _isLoading = false;
        });
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // Ambient radial glow behind the card
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (_, __) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 0.9,
                    colors: [
                      _accentBlue.withOpacity(_glowAnimation.value * 0.22),
                      _bgDark,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                  const SizedBox(height: 40),
                  // Logo and Title
                  Column(
                    children: [
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (_, child) => Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: _accentBlue
                                    .withOpacity(_glowAnimation.value * 0.6),
                                blurRadius: 32,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset('assets/images/eazyschool.png',
                              height: 96),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Eazy School 360', style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                        letterSpacing: 0.3,
                      )),
                      const SizedBox(height: 6),
                      const Text('School Management System', style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      )),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: _cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      style: const TextStyle(color: _textPrimary),
                      cursorColor: _accentBlue,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'Enter your email',
                        labelStyle: const TextStyle(color: _textSecondary),
                        floatingLabelStyle: const TextStyle(color: _textPrimary),
                        hintStyle: const TextStyle(color: _textSecondary),
                        prefixIcon: const Icon(Icons.email_outlined, color: _textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accentBlue, width: 2)),
                        filled: true,
                        fillColor: _bgDark,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      enabled: !_isLoading,
                      style: const TextStyle(color: _textPrimary),
                      cursorColor: _accentBlue,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        labelStyle: const TextStyle(color: _textSecondary),
                        floatingLabelStyle: const TextStyle(color: _textPrimary),
                        hintStyle: const TextStyle(color: _textSecondary),
                        prefixIcon: const Icon(Icons.lock_outlined, color: _textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          color: _textSecondary,
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accentBlue, width: 2)),
                        filled: true,
                        fillColor: _bgDark,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Error Message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Color(0xFFB91C1C).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFB91C1C).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: _textSecondary, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Login Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? ", style: TextStyle(color: _textSecondary, fontSize: 12)),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                          child: const Text('Register School', style: TextStyle(color: _accentBlue, fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      Text(
                        '© ${DateTime.now().year} Eazy School 360. All rights reserved.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Powered by ',
                              style: TextStyle(
                                  color: _textSecondary, fontSize: 11)),
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              colors: [
                                Color(0xFF4CAF50),
                                Color(0xFF8B5CF6),
                              ],
                            ).createShader(b),
                            child: const Text(
                              'Avail404',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
