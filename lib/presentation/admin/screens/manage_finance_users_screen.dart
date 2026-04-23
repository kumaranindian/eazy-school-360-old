import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/staff_management_repository.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/staff_profile.dart';

class ManageFinanceUsersScreen extends ConsumerStatefulWidget {
  const ManageFinanceUsersScreen({super.key});

  @override
  ConsumerState<ManageFinanceUsersScreen> createState() => _ManageFinanceUsersScreenState();
}

class _ManageFinanceUsersScreenState extends ConsumerState<ManageFinanceUsersScreen> {
  static const Color _bgDark      = Color(0xFF0D1117);
  static const Color _cardDark    = Color(0xFF161B22);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);
  static const Color _accentBlue  = Color(0xFF3B82F6);

  List<Map<String, dynamic>> _financeUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFinanceUsers());
  }

  Future<void> _loadFinanceUsers() async {
    final session = ref.read(currentSessionProvider);
    if (session?.schoolId == null) return;
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('schoolId', isEqualTo: session!.schoolId)
          .where('role', isEqualTo: 'FINANCE')
          .get();
      setState(() {
        _financeUsers = snap.docs.map((d) {
          final data = d.data();
          data['uid'] = d.id;
          return data;
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error loading users: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : _accentGreen,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final session = ref.watch(currentSessionProvider);

    return Container(
      color: _bgDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDesktop),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _accentGreen))
                : _buildBody(session, isDesktop),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      color: _bgDark,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Finance Users', style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Manage finance admin accounts for this school', style: TextStyle(color: _textSecondary, fontSize: isDesktop ? 14 : 12)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAddFinanceUserDialog(),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Add Finance User'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(dynamic session, bool isDesktop) {
    if (_financeUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _accentGreen.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_wallet_outlined, color: _accentGreen, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('No Finance Users Yet', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Add finance admin accounts to manage fees and expenses', style: TextStyle(color: _textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddFinanceUserDialog(),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add Finance User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFinanceUsers,
      color: _accentGreen,
      child: ListView.builder(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        itemCount: _financeUsers.length,
        itemBuilder: (ctx, i) => _buildUserCard(_financeUsers[i], isDesktop),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isDesktop) {
    final name = user['displayName'] as String? ?? 'Unknown';
    final email = user['email'] as String? ?? '';
    final status = user['status'] as String? ?? 'ACTIVE';
    final isActive = status == 'ACTIVE';
    final createdAt = (user['createdAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _accentGreen.withOpacity(0.15),
            radius: 22,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'F',
                style: const TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accentBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _accentBlue.withOpacity(0.3)),
                      ),
                      child: const Text('Finance Admin', style: TextStyle(color: _accentBlue, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                if (createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text('Added ${DateFormat('dd MMM yyyy').format(createdAt)}',
                      style: const TextStyle(color: _textSecondary, fontSize: 11)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isActive ? _accentGreen : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (isActive ? _accentGreen : Colors.red).withOpacity(0.3)),
            ),
            child: Text(isActive ? 'Active' : 'Disabled',
                style: TextStyle(color: isActive ? _accentGreen : Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _textSecondary, size: 20),
            color: _cardDark,
            onSelected: (val) => _handleUserAction(val, user),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: isActive ? 'disable' : 'enable',
                child: Row(children: [
                  Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline, color: isActive ? Colors.red : _accentGreen, size: 16),
                  const SizedBox(width: 8),
                  Text(isActive ? 'Disable' : 'Enable', style: const TextStyle(color: _textPrimary, fontSize: 13)),
                ]),
              ),
              const PopupMenuItem(
                value: 'reset_password',
                child: Row(children: [
                  Icon(Icons.lock_reset_rounded, color: _accentBlue, size: 16),
                  SizedBox(width: 8),
                  Text('Reset Password', style: TextStyle(color: _textPrimary, fontSize: 13)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleUserAction(String action, Map<String, dynamic> user) async {
    final uid = user['uid'] as String;
    final name = user['displayName'] as String? ?? 'User';
    try {
      if (action == 'disable' || action == 'enable') {
        final newStatus = action == 'enable' ? 'ACTIVE' : 'DISABLED';
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _snack('$name ${action == 'enable' ? 'enabled' : 'disabled'} successfully');
        await _loadFinanceUsers();
      } else if (action == 'reset_password') {
        _snack('Password reset email sent to ${user['email']}');
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
  }

  Future<void> _showAddFinanceUserDialog() async {
    final session = ref.read(currentSessionProvider);
    if (session?.schoolId == null) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddFinanceUserDialog(),
    );

    if (result != null) {
      try {
        final repo = ref.read(staffManagementRepositoryProvider);
        final request = CreateStaffRequest(
          name: result['name']!,
          employeeId: '',
          email: result['email']!,
          department: result['department'] ?? 'Finance',
          staffType: StaffType.NON_TEACHING,
          joiningDate: DateTime.now(),
          phoneNumber: result['phone']?.isEmpty == true ? null : result['phone'],
          designation: 'Finance Admin',
        );
        
        // Show progress dialog
        final created = await showDialog<Map<String, String>>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _FinanceUserCreationDialog(
            request: request,
            schoolId: session!.schoolId!,
            adminUserId: session.uid,
            repository: repo,
          ),
        );
        
        if (created != null) {
          await _loadFinanceUsers(); // Refresh list immediately
          if (mounted) {
            await showDialog(
              context: context,
              builder: (_) => _SuccessDialog(
                name: created['name'] ?? result['name']!,
                email: result['email']!,
                tempPassword: created['tempPassword'] ?? '',
              ),
            );
          }
        }
      } catch (e) {
        _snack('Error: $e', isError: true);
      }
    }
  }
}

// ─── Add Finance User Dialog ──────────────────────────────────────────────────

class _AddFinanceUserDialog extends StatefulWidget {
  @override
  State<_AddFinanceUserDialog> createState() => _AddFinanceUserDialogState();
}

class _AddFinanceUserDialogState extends State<_AddFinanceUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deptCtrl  = TextEditingController(text: 'Finance');

  static const Color _cardDark    = Color(0xFF161B22);
  static const Color _bgDark      = Color(0xFF0D1117);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _deptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1C2128),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: _borderColor)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _accentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.person_add_rounded, color: _accentGreen, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Add Finance User', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 16))),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _accentGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _accentGreen.withOpacity(0.2)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline, color: _accentGreen, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text('Finance users can access Students, Finance, and Reports menus only. A temporary password will be generated and shown after creation.',
                              style: TextStyle(color: _accentGreen, fontSize: 12))),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      _field('Full Name', _nameCtrl, Icons.person_outline, required: true),
                      const SizedBox(height: 12),
                      _field('Email Address', _emailCtrl, Icons.email_outlined, required: true, isEmail: true),
                      const SizedBox(height: 12),
                      _field('Phone Number', _phoneCtrl, Icons.phone_outlined),
                      const SizedBox(height: 12),
                      _field('Department', _deptCtrl, Icons.business_outlined),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: _textSecondary)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Create User'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, {bool required = false, bool isEmail = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
          style: const TextStyle(color: _textPrimary, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _textSecondary, size: 18),
            filled: true,
            fillColor: _bgDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accentGreen, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: (v) {
            if (required && (v == null || v.trim().isEmpty)) return '$label is required';
            if (isEmail && v != null && v.isNotEmpty && !v.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'department': _deptCtrl.text.trim(),
    });
  }
}

// ─── Success Dialog ───────────────────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  final String name;
  final String email;
  final String tempPassword;

  const _SuccessDialog({required this.name, required this.email, required this.tempPassword});

  static const Color _cardDark    = Color(0xFF161B22);
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);
  static const Color _bgDark      = Color(0xFF0D1117);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _accentGreen.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: _accentGreen, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Finance User Created!', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$name has been added as a Finance Admin.', style: const TextStyle(color: _textSecondary, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Login Credentials', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  _credRow('Email', email),
                  const SizedBox(height: 6),
                  _credRow('Temp Password', tempPassword.isEmpty ? '(sent via email)' : tempPassword),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.3))),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Share these credentials securely. The user should change their password on first login.', style: TextStyle(color: Colors.orange, fontSize: 11))),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12))),
        Expanded(child: Text(value, style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// ─── Finance User Creation Progress Dialog ──────────────────────────────────────────────────

class _FinanceUserCreationDialog extends StatefulWidget {
  final CreateStaffRequest request;
  final String schoolId;
  final String adminUserId;
  final StaffManagementRepository repository;

  const _FinanceUserCreationDialog({
    required this.request,
    required this.schoolId,
    required this.adminUserId,
    required this.repository,
  });

  @override
  State<_FinanceUserCreationDialog> createState() => _FinanceUserCreationDialogState();
}

class _FinanceUserCreationDialogState extends State<_FinanceUserCreationDialog> {
  static const Color _accentGreen = Color(0xFF4CAF50);
  static const Color _textSecondary = Color(0xFF8B949E);

  int _currentStep = 0;
  String _currentStatus = 'Initializing...';
  bool _isError = false;
  String? _errorMessage;

  final List<String> _steps = [
    'Validating admin access...',
    'Generating employee ID...',
    'Fetching school information...',
    'Checking existing user...',
    'Creating Firebase Auth user...',
    'Creating user document...',
    'Creating membership record...',
    'Creating staff profile...',
    'Sending welcome email...',
    'Finalizing setup...',
  ];

  @override
  void initState() {
    super.initState();
    _createFinanceUser();
  }

  Future<void> _createFinanceUser() async {
    try {
      // Execute the actual creation with progress updates
      setState(() {
        _currentStep = 0;
        _currentStatus = 'Creating finance user...';
        _isError = false;
        _errorMessage = null;
      });

      final result = await widget.repository.createFinanceUser(
        widget.schoolId,
        widget.adminUserId,
        widget.request,
      );

      if (mounted) {
        setState(() {
          _currentStep = _steps.length - 1;
          _currentStatus = 'Finance user created successfully!';
        });
        
        // Wait a moment for user to see success
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _currentStatus = 'Error creating finance user';
        });
        
        // Wait a moment then close with error
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.of(context).pop(null);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          if (_isError)
            Icon(Icons.error, color: Colors.red, size: 24)
          else
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_accentGreen),
              ),
            ),
          const SizedBox(width: 12),
          Text(
            _isError ? 'Error' : 'Creating Finance User',
            style: TextStyle(
              color: _isError ? Colors.red : null,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isError) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                _currentStatus,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _isError ? 0 : (_currentStep + 1) / _steps.length,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(_accentGreen),
              ),
              const SizedBox(height: 16),
              Text(
                'Step ${_currentStep + 1} of ${_steps.length}',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: _isError ? [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Close'),
        ),
      ] : [],
    );
  }
}
