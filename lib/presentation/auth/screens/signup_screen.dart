import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/repositories/auth_repository.dart';
import 'enhanced_login_screen.dart';
import 'waiting_activation_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
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
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  // Dark theme tokens (match dashboard)
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimaryDark = Color(0xFFE6EDF3);
  static const Color _textSecondaryDark = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController!, curve: Curves.easeOut));
    _animationController?.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _pageController.dispose();
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

  void _nextStep() {
    if (_currentStep == 0) {
      if (_schoolNameController.text.isEmpty) { _showError('Please enter school name'); return; }
      if (_schoolAddressController.text.isEmpty) { _showError('Please enter school address'); return; }
    }
    setState(() => _currentStep = 1);
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _previousStep() {
    setState(() => _currentStep = 0);
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_adminPasswordController.text != _confirmPasswordController.text) { _showError('Passwords do not match'); return; }
    setState(() => _isLoading = true);
    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signUpWithEmailAndPassword(
        email: _adminEmailController.text.trim(),
        password: _adminPasswordController.text,
        schoolName: _schoolNameController.text.trim(),
        schoolAddress: _schoolAddressController.text.trim(),
        schoolPhone: _schoolPhoneController.text.trim(),
        schoolWebsite: _schoolWebsiteController.text.trim(),
        adminName: _adminNameController.text.trim(),
      );
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaitingActivationScreen()));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: _bgDark,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: _bgDark,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
            child: responsive.isWeb ? _buildWebLayout(responsive, colorScheme) : _buildMobileLayout(responsive, colorScheme),
          ),
        ),
      ),
    );
  }

  Widget _buildWebLayout(ResponsiveHelper responsive, ColorScheme colorScheme) {
    return Row(children: [
      Expanded(flex: 4, child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: AppColors.primaryGradient)),
        child: Center(child: Padding(
          padding: EdgeInsets.all(responsive.largeSpacing),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(Icons.school_rounded, size: responsive.responsive(mobile: 60, tablet: 80, desktop: 100), color: Colors.white),
            ),
            SizedBox(height: responsive.largeSpacing),
            Text('Register Your School', style: TextStyle(fontSize: responsive.responsive(mobile: 24, tablet: 32, desktop: 40), fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: responsive.spacing),
            Text('Join thousands of schools using\nEazy School 360', style: TextStyle(fontSize: responsive.responsive(mobile: 14, tablet: 16, desktop: 18), color: Colors.white.withOpacity(0.9)), textAlign: TextAlign.center),
            SizedBox(height: responsive.largeSpacing * 2),
            _buildStepIndicator(responsive, isWeb: true),
          ]),
        )),
      )),
      Expanded(flex: 5, child: Center(child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: EdgeInsets.all(responsive.largeSpacing),
        child: _buildFormCard(responsive, colorScheme),
      ))),
    ]);
  }

  Widget _buildMobileLayout(ResponsiveHelper responsive, ColorScheme colorScheme) {
    return Column(children: [
      _buildMobileHeader(responsive, colorScheme),
      Padding(padding: EdgeInsets.symmetric(horizontal: responsive.spacing, vertical: responsive.smallSpacing), child: _buildStepIndicator(responsive, isWeb: false)),
      Expanded(child: SingleChildScrollView(padding: EdgeInsets.all(responsive.spacing), child: _buildFormCard(responsive, colorScheme))),
    ]);
  }

  Widget _buildMobileHeader(ResponsiveHelper responsive, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(responsive.spacing),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded), style: IconButton.styleFrom(backgroundColor: colorScheme.primary.withOpacity(0.1))),
        SizedBox(width: responsive.spacing),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Register School', style: TextStyle(fontSize: responsive.responsive(mobile: 20, tablet: 24), fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(_currentStep == 0 ? 'School Information' : 'Admin Account', style: TextStyle(fontSize: responsive.responsive(mobile: 13, tablet: 14), color: AppColors.textSecondary)),
        ])),
      ]),
    );
  }

  Widget _buildStepIndicator(ResponsiveHelper responsive, {required bool isWeb}) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _buildStepDot(0, 'School Info', responsive, isWeb),
      Container(width: responsive.responsive(mobile: 40, tablet: 60, desktop: 80), height: 2, color: _currentStep >= 1 ? (isWeb ? Colors.white : AppColors.primary) : (isWeb ? Colors.white.withOpacity(0.3) : AppColors.border)),
      _buildStepDot(1, 'Admin Account', responsive, isWeb),
    ]);
  }

  Widget _buildStepDot(int step, String label, ResponsiveHelper responsive, bool isWeb) {
    final isActive = _currentStep >= step;
    final activeColor = isWeb ? Colors.white : AppColors.primary;
    final inactiveColor = isWeb ? Colors.white.withOpacity(0.3) : AppColors.border;
    return Column(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: isActive ? activeColor : Colors.transparent, border: Border.all(color: isActive ? activeColor : inactiveColor, width: 2), shape: BoxShape.circle),
        child: Center(child: isActive && _currentStep > step
          ? Icon(Icons.check, size: 18, color: isWeb ? AppColors.primary : Colors.white)
          : Text('${step + 1}', style: TextStyle(color: isActive ? (isWeb ? AppColors.primary : Colors.white) : (isWeb ? Colors.white.withOpacity(0.5) : AppColors.textSecondary), fontWeight: FontWeight.bold))),
      ),
      SizedBox(height: responsive.smallSpacing),
      Text(label, style: TextStyle(fontSize: 12, color: isActive ? (isWeb ? Colors.white : AppColors.textPrimary) : (isWeb ? Colors.white.withOpacity(0.5) : AppColors.textSecondary), fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
    ]);
  }

  Widget _buildFormCard(ResponsiveHelper responsive, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(responsive.largeSpacing),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(responsive.borderRadius * 1.5),
        border: Border.all(color: _borderColor),
      ),
      child: Form(key: _formKey, child: SizedBox(
        height: responsive.responsive(mobile: 420, tablet: 440, desktop: 460),
        child: PageView(controller: _pageController, physics: const NeverScrollableScrollPhysics(), children: [_buildSchoolInfoForm(responsive), _buildAdminInfoForm(responsive)]),
      )),
    );
  }

  Widget _buildSchoolInfoForm(ResponsiveHelper responsive) {
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('School Information', style: TextStyle(fontSize: responsive.responsive(mobile: 20, tablet: 22), fontWeight: FontWeight.bold, color: _textPrimaryDark)),
      SizedBox(height: responsive.smallSpacing),
      Text('Enter your school details', style: TextStyle(fontSize: responsive.responsive(mobile: 14, tablet: 15), color: _textSecondaryDark)),
      SizedBox(height: responsive.largeSpacing),
      _buildTextField(controller: _schoolNameController, label: 'School Name', hint: 'Enter school name', icon: Icons.school_outlined, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
      SizedBox(height: responsive.spacing),
      _buildTextField(controller: _schoolAddressController, label: 'Address', hint: 'Enter school address', icon: Icons.location_on_outlined, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
      SizedBox(height: responsive.spacing),
      _buildTextField(controller: _schoolPhoneController, label: 'Phone (Optional)', hint: 'Enter phone number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
      SizedBox(height: responsive.spacing),
      _buildTextField(controller: _schoolWebsiteController, label: 'Website (Optional)', hint: 'Enter website URL', icon: Icons.language_outlined, keyboardType: TextInputType.url),
      SizedBox(height: responsive.largeSpacing),
      SizedBox(height: responsive.buttonHeight, child: ElevatedButton(onPressed: _nextStep, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Continue'), const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, size: 20)]))),
    ]));
  }

  Widget _buildAdminInfoForm(ResponsiveHelper responsive) {
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Admin Account', style: TextStyle(fontSize: responsive.responsive(mobile: 20, tablet: 22), fontWeight: FontWeight.bold, color: _textPrimaryDark)),
      SizedBox(height: responsive.smallSpacing),
      Text('Create your admin account', style: TextStyle(fontSize: responsive.responsive(mobile: 14, tablet: 15), color: _textSecondaryDark)),
      SizedBox(height: responsive.largeSpacing),
      _buildTextField(controller: _adminNameController, label: 'Full Name', hint: 'Enter your name', icon: Icons.person_outline, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
      SizedBox(height: responsive.spacing),
      _buildTextField(controller: _adminEmailController, label: 'Email', hint: 'Enter your email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (v) { if (v?.isEmpty ?? true) return 'Required'; if (!v!.contains('@')) return 'Invalid email'; return null; }),
      SizedBox(height: responsive.spacing),
      _buildTextField(controller: _adminPasswordController, label: 'Password', hint: 'Create a password', icon: Icons.lock_outline, obscureText: _obscurePassword, suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)), validator: (v) { if (v?.isEmpty ?? true) return 'Required'; if (v!.length < 6) return 'Min 6 characters'; return null; }),
      SizedBox(height: responsive.spacing),
      _buildTextField(controller: _confirmPasswordController, label: 'Confirm Password', hint: 'Confirm your password', icon: Icons.lock_outline, obscureText: _obscureConfirmPassword, suffixIcon: IconButton(icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)), validator: (v) { if (v?.isEmpty ?? true) return 'Required'; if (v != _adminPasswordController.text) return 'Passwords do not match'; return null; }),
      SizedBox(height: responsive.largeSpacing),
      Row(children: [
        Expanded(child: SizedBox(height: responsive.buttonHeight, child: OutlinedButton(onPressed: _previousStep, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.arrow_back_rounded, size: 20), const SizedBox(width: 8), const Text('Back')])))),
        SizedBox(width: responsive.spacing),
        Expanded(flex: 2, child: SizedBox(height: responsive.buttonHeight, child: ElevatedButton(onPressed: _isLoading ? null : _signup, child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Account')))),
      ]),
      SizedBox(height: responsive.spacing),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Already have an account? ', style: const TextStyle(color: _textSecondaryDark)),
        TextButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EnhancedLoginScreen())),
          child: const Text('Sign In', style: TextStyle(color: _accentBlue)),
        ),
      ]),
    ]));
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, required IconData icon, TextInputType? keyboardType, bool obscureText = false, Widget? suffixIcon, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: _textPrimaryDark),
      cursorColor: _accentBlue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _textSecondaryDark),
        floatingLabelStyle: const TextStyle(color: _textPrimaryDark),
        hintStyle: const TextStyle(color: _textSecondaryDark),
        prefixIcon: Icon(icon, color: _textSecondaryDark),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _cardDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accentBlue, width: 2)),
      ),
    );
  }
}
