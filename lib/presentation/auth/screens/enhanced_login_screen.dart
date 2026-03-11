import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/domain/entities/app_user.dart';

import 'signup_screen.dart';
import '../../dashboard/screens/admin_dashboard_screen.dart';
import '../../dashboard/screens/staff_dashboard_screen.dart';
import '../../dashboard/screens/super_admin_dashboard_screen.dart';
import '../../dashboard/screens/parent_dashboard_screen.dart';
import 'waiting_activation_screen.dart';

class EnhancedLoginScreen extends ConsumerStatefulWidget {
  const EnhancedLoginScreen({super.key});

  @override
  ConsumerState<EnhancedLoginScreen> createState() => _EnhancedLoginScreenState();
}

class _EnhancedLoginScreenState extends ConsumerState<EnhancedLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Dark theme tokens (match dashboard)
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void dispose() {
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

      if (!session.isActive) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaitingActivationScreen()));
        return;
      }

      final role = session.role;
      if (role == UserRole.SUPER_ADMIN) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SuperAdminDashboardScreen()));
      } else if (role == UserRole.ADMIN) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // Logo and Title
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset('assets/images/eazyschool.png', height: 100),
                      ),
                      const SizedBox(height: 16),
                      const Text('Eazy School 360', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary)),
                      const SizedBox(height: 6),
                      const Text('School Management System', style: TextStyle(color: _textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
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
                        fillColor: _cardDark,
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
                        fillColor: _cardDark,
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
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      Text('© ${DateTime.now().year} Eazy School 360. All rights reserved.', textAlign: TextAlign.center, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Powered by ', style: TextStyle(color: _textSecondary, fontSize: 11)),
                          Image.asset('assets/images/logo.png', height: 20),
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
    );
  }
}
