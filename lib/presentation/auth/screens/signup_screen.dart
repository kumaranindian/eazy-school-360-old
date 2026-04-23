import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/tenant_provisioning_service.dart';
import '../widgets/provisioning_progress_dialog.dart';
import 'enhanced_login_screen.dart';
import 'waiting_activation_screen.dart';

/// Sign-up / school registration screen.
///
/// Intentionally mirrors the [EnhancedLoginScreen] look & feel:
///   * centered single-card layout on a dark scaffold
///   * Eazy School logo + tagline on top
///   * dark, high-contrast form fields with a green accent
///
/// The flow is a two-step wizard (school info -> admin account) inside the
/// same card, switched with a fade+slide animation.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  // --- Dark theme tokens (match login / dashboard) ---------------------------
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);
  static const Color _errorRed = Color(0xFFEF4444);

  // --- Form state ------------------------------------------------------------
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  final _schoolNameController = TextEditingController();
  final _schoolAddressController = TextEditingController();
  final _schoolPhoneController = TextEditingController();
  final _schoolWebsiteController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;
  String? _errorMessage;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _schoolNameController.dispose();
    _schoolAddressController.dispose();
    _schoolPhoneController.dispose();
    _schoolWebsiteController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Step transitions
  // ---------------------------------------------------------------------------

  void _goToStep2() {
    if (!(_step1Key.currentState?.validate() ?? false)) return;
    setState(() {
      _errorMessage = null;
      _currentStep = 1;
    });
  }

  void _goToStep1() {
    setState(() {
      _errorMessage = null;
      _currentStep = 0;
    });
  }

  // ---------------------------------------------------------------------------
  // Business logic
  // ---------------------------------------------------------------------------

  Future<void> _signup() async {
    if (!(_step2Key.currentState?.validate() ?? false)) return;
    if (_adminPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final result = await authRepository.signUpWithEmailAndPassword(
        email: _adminEmailController.text.trim(),
        password: _adminPasswordController.text,
        schoolName: _schoolNameController.text.trim(),
        schoolAddress: _schoolAddressController.text.trim(),
        schoolPhone: _schoolPhoneController.text.trim(),
        schoolWebsite: _schoolWebsiteController.text.trim(),
        adminName: _adminNameController.text.trim(),
      );
      if (!mounted) return;
      await _runProvisioningThenContinue(result);
    } on SchoolNameAlreadyExistsException catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _currentStep = 0; // bounce back to school-name field
      });
    } on EmailAlreadyRegisteredException catch (_) {
      if (!mounted) return;
      final accepted = await _promptAddSchoolToExistingAccount();
      if (accepted == true) await _addSchoolToExistingAccount();
    } catch (e) {
      setState(() => _errorMessage = _cleanError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSchoolToExistingAccount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authRepository = ref.read(authRepositoryProvider);
      final result = await authRepository.signUpAdditionalSchool(
        email: _adminEmailController.text.trim(),
        password: _adminPasswordController.text,
        schoolName: _schoolNameController.text.trim(),
        schoolAddress: _schoolAddressController.text.trim(),
        schoolPhone: _schoolPhoneController.text.trim(),
        schoolWebsite: _schoolWebsiteController.text.trim(),
        adminName: _adminNameController.text.trim(),
      );
      if (!mounted) return;
      await _runProvisioningThenContinue(result);
    } on SchoolNameAlreadyExistsException catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _currentStep = 0;
      });
    } catch (e) {
      setState(() => _errorMessage = _cleanError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Runs the per-tenant provisioning pipeline for a freshly created school
  /// and shows a modal dialog with real-time per-step status. Once the dialog
  /// is dismissed, the user is sent to the waiting-activation screen.
  Future<void> _runProvisioningThenContinue(SignupResult result) async {
    final service = TenantProvisioningService();
    // Use a broadcast stream so the dialog can subscribe after the emission
    // has started without losing events. [Stream.asBroadcastStream] caches
    // the subscription for us.
    final stream = service
        .provisionSchool(
          schoolId: result.schoolId,
          createdByUid: result.uid,
        )
        .asBroadcastStream();

    await ProvisioningProgressDialog.show(
      context: context,
      stream: stream,
      schoolName: _schoolNameController.text.trim(),
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WaitingActivationScreen(
          pendingSchoolId: result.schoolId,
          pendingSchoolName: _schoolNameController.text.trim(),
        ),
      ),
    );
  }

  Future<bool?> _promptAddSchoolToExistingAccount() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _borderColor),
        ),
        title: const Text(
          'Email already registered',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '"${_adminEmailController.text.trim()}" is already used by another '
          'school on Eazy School 360.\n\nWould you like to add '
          '"${_schoolNameController.text.trim()}" to the same account?',
          style: const TextStyle(color: _textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Use different email',
                style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add school'),
          ),
        ],
      ),
    );
  }

  String _cleanError(Object e) =>
      e.toString().replaceAll('Exception: ', '').trim();

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStepIndicator(),
                    const SizedBox(height: 20),
                    _buildFormCard(),
                    const SizedBox(height: 16),
                    _buildSignInLink(),
                    const SizedBox(height: 8),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Header ----------------------------------------------------------------

  Widget _buildHeader() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset('assets/images/eazyschool.png', height: 84),
        ),
        const SizedBox(height: 14),
        const Text(
          'Register Your School',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Join thousands of schools using Eazy School 360',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  // --- Step indicator --------------------------------------------------------

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(1, active: _currentStep >= 0, done: _currentStep > 0),
        _stepConnector(active: _currentStep > 0),
        _stepDot(2, active: _currentStep >= 1, done: false),
      ],
    );
  }

  Widget _stepDot(int n, {required bool active, required bool done}) {
    final color = active ? _accentBlue : _borderColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: active ? _accentBlue : _cardDark,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text(
                  '$n',
                  style: TextStyle(
                    color: active ? Colors.white : _textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          n == 1 ? 'School' : 'Admin',
          style: TextStyle(
            fontSize: 11,
            color: active ? _textPrimary : _textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _stepConnector({required bool active}) => Container(
        width: 48,
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: active ? _accentBlue : _borderColor,
      );

  // --- Form card (step 1 / step 2 with switcher) -----------------------------

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: Offset(_currentStep == 0 ? -0.05 : 0.05, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: _currentStep == 0 ? _buildSchoolStep() : _buildAdminStep(),
      ),
    );
  }

  Widget _buildSchoolStep() {
    return Form(
      key: _step1Key,
      child: Column(
        key: const ValueKey('step-school'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
              title: 'School Information',
              subtitle: 'Tell us about your school'),
          const SizedBox(height: 16),
          _textField(
            controller: _schoolNameController,
            label: 'School Name',
            hint: 'Enter school name',
            icon: Icons.school_outlined,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'School name is required' : null,
          ),
          const SizedBox(height: 14),
          _textField(
            controller: _schoolAddressController,
            label: 'Address',
            hint: 'Enter school address',
            icon: Icons.location_on_outlined,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Address is required' : null,
          ),
          const SizedBox(height: 14),
          _textField(
            controller: _schoolPhoneController,
            label: 'Phone (Optional)',
            hint: 'Enter phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          _textField(
            controller: _schoolWebsiteController,
            label: 'Website (Optional)',
            hint: 'https://yourschool.com',
            icon: Icons.language_outlined,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _goToStep2,
              style: _primaryButtonStyle(),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStep() {
    return Form(
      key: _step2Key,
      child: Column(
        key: const ValueKey('step-admin'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
              title: 'Admin Account',
              subtitle: 'Create your administrator login'),
          const SizedBox(height: 16),
          _textField(
            controller: _adminNameController,
            label: 'Full Name',
            hint: 'Enter your name',
            icon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 14),
          _textField(
            controller: _adminEmailController,
            label: 'Email',
            hint: 'Enter your email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(v.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _textField(
            controller: _adminPasswordController,
            label: 'Password',
            hint: 'Create a password',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: _textSecondary),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _textField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _signup(),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: _textSecondary),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _adminPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _goToStep1,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textPrimary,
                      side: const BorderSide(color: _borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Back',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: _primaryButtonStyle(),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Shared field + styles -------------------------------------------------

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: !_isLoading,
      style: const TextStyle(color: _textPrimary),
      cursorColor: _accentBlue,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _textSecondary),
        floatingLabelStyle: const TextStyle(color: _textPrimary),
        hintStyle: const TextStyle(color: _textSecondary),
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _bgDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accentBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _errorRed, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() => ElevatedButton.styleFrom(
        backgroundColor: _accentBlue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _accentBlue.withOpacity(0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFB91C1C).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB91C1C).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _errorRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: _textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // --- Footer bits -----------------------------------------------------------

  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account? ',
            style: TextStyle(color: _textSecondary, fontSize: 13)),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EnhancedLoginScreen()),
                  ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Sign In',
            style: TextStyle(
              color: _accentBlue,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          '© ${DateTime.now().year} Eazy School 360. All rights reserved.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Powered by ',
                style: TextStyle(color: _textSecondary, fontSize: 11)),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF8B5CF6)],
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE6EDF3),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
        ),
      ],
    );
  }
}
