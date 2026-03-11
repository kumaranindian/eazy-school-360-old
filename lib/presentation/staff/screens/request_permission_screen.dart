import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/permission_request_repository.dart';
import 'package:eazy_school_360/data/repositories/permission_type_repository.dart';
import 'package:eazy_school_360/data/repositories/staff_management_repository.dart';
import 'package:eazy_school_360/domain/entities/permission_request.dart';
import 'package:eazy_school_360/domain/entities/permission_type.dart';

class RequestPermissionScreen extends ConsumerStatefulWidget {
  const RequestPermissionScreen({super.key});

  @override
  ConsumerState<RequestPermissionScreen> createState() => _RequestPermissionScreenState();
}

class _RequestPermissionScreenState extends ConsumerState<RequestPermissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _remarksController = TextEditingController();

  // Dark theme tokens (match dashboard)
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  String? _selectedPermissionTypeId;
  DateTime? _requestDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isLoading = false;
  String? _errorMessage;
  int _calculatedDurationMinutes = 0;
  int _remainingPermissions = 0; // Track remaining for validation

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(() {
      if (mounted) setState(() {});
    });
    _remarksController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    if (session == null || !session.isStaff || session.schoolId == null) {
      return const Scaffold(body: Center(child: Text('Access Denied')));
    }

    final configAsyncValue = ref.watch(permissionConfigProvider(session.schoolId!));

    return Scaffold(
      backgroundColor: _bgDark,
      body: configAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
        error: (error, stack) => _buildErrorState(context, session.schoolId!, error),
        data: (config) {
          if (config == null) {
            return _buildNotConfiguredState();
          }
          if (!config.isActive) {
            return _buildDisabledState();
          }
          return _buildContent(context, config, session.schoolId!, session.uid, isDesktop);
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String schoolId, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFB91C1C).withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 24),
            const Text('Error Loading Configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 8),
            Text(error.toString(), style: const TextStyle(color: _textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.refresh(permissionConfigProvider(schoolId)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotConfiguredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.settings_rounded, size: 64, color: _accentBlue),
            ),
            const SizedBox(height: 24),
            const Text('Not Configured', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 8),
            Text('Permission requests are not configured for your school', style: const TextStyle(color: _textSecondary, fontSize: 16), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.block_rounded, size: 64, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            const Text('Currently Disabled', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 8),
            Text('Permission requests are currently disabled by your administrator', style: const TextStyle(color: _textSecondary, fontSize: 16), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PermissionConfig config, String schoolId, String userId, bool isDesktop) {
    // Fetch permission types
    final permissionTypesAsync = ref.watch(activePermissionTypesProvider(schoolId));
    
    return permissionTypesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
      error: (error, stack) => _buildErrorState(context, schoolId, error),
      data: (permissionTypes) {
        if (permissionTypes.isEmpty) {
          return _buildNoPermissionTypesState();
        }
        return _buildStepperContent(context, config, schoolId, userId, isDesktop, permissionTypes);
      },
    );
  }

  Widget _buildNoPermissionTypesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.category_rounded, size: 64, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            const Text('No Permission Types', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 8),
            const Text('No permission types have been configured for your school.\nPlease contact your administrator.', 
              style: TextStyle(color: _textSecondary, fontSize: 16), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperContent(BuildContext context, PermissionConfig config, String schoolId, String userId, bool isDesktop, List<PermissionType> permissionTypes) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step 1: Permission Type Selection
                _buildStepHeader(1, 'Select Permission Type', _selectedPermissionTypeId != null),
                const SizedBox(height: 12),
                _buildPermissionTypeSelection(permissionTypes, config),
                const SizedBox(height: 24),
                
                // Step 2: Date & Time
                _buildStepHeader(2, 'Select Date & Time', _requestDate != null && _startTime != null && _endTime != null),
                const SizedBox(height: 12),
                _buildDateTimeCard(),
                const SizedBox(height: 24),
                
                // Step 3: Request Details
                _buildStepHeader(3, 'Provide Details', _reasonController.text.trim().length >= 10),
                const SizedBox(height: 12),
                _buildDetailsCard(),
                const SizedBox(height: 24),
                
                // Error Message
                if (_errorMessage != null) ...[
                  _buildErrorMessage(),
                  const SizedBox(height: 16),
                ],
                
                // Submit Button
                _buildSubmitButton(config),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader(int step, String title, bool isComplete) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isComplete ? _accentBlue : _cardDark,
            shape: BoxShape.circle,
            border: Border.all(color: isComplete ? _accentBlue : _borderColor, width: 2),
          ),
          child: Center(
            child: isComplete
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text('$step', style: const TextStyle(color: _textSecondary, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  Widget _buildPermissionTypeSelection(List<PermissionType> permissionTypes, PermissionConfig config) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal scrollable list of permission types
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: permissionTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final permissionType = permissionTypes[index];
                final isSelected = _selectedPermissionTypeId == permissionType.id;
                return _buildPermissionTypeChip(permissionType, isSelected);
              },
            ),
          ),
          if (_selectedPermissionTypeId != null) ...[
            const SizedBox(height: 16),
            const Divider(color: _borderColor, height: 1),
            const SizedBox(height: 16),
            _buildSelectedPermissionInfo(
              permissionTypes.firstWhere((pt) => pt.id == _selectedPermissionTypeId),
              config,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionTypeChip(PermissionType permissionType, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPermissionTypeId = permissionType.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _accentBlue.withOpacity(0.15) : _bgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _accentBlue : _borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: isSelected ? _accentBlue : _textSecondary,
                  size: 18,
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: _accentBlue, size: 18),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permissionType.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? _accentBlue : _textPrimary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${permissionType.defaultLimit}/month',
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPermissionInfo(PermissionType permissionType, PermissionConfig config) {
    final session = ref.watch(currentSessionProvider);
    if (session?.schoolId == null) return const SizedBox.shrink();

    final staffAsync = ref.watch(staffByUserIdProvider((schoolId: session!.schoolId!, userId: session.uid)));
    return staffAsync.when(
      loading: () => _buildPermissionInfoRow(permissionType, config, 0, permissionType.defaultLimit),
      error: (_, __) => _buildPermissionInfoRow(permissionType, config, 0, permissionType.defaultLimit),
      data: (staff) {
        if (staff == null) {
          return _buildPermissionInfoRow(permissionType, config, 0, permissionType.defaultLimit);
        }

        final currentMonth = PermissionCalculator.getCurrentMonth();
        final usageAsync = ref.watch(monthlyPermissionTypeUsageCountFlexibleProvider((
          schoolId: session.schoolId!,
          staffId: staff.id,
          applicantId: session.uid,
          permissionTypeId: permissionType.id,
          month: currentMonth,
        )));

        return usageAsync.when(
          loading: () => _buildPermissionInfoRow(permissionType, config, 0, permissionType.defaultLimit),
          error: (_, __) => _buildPermissionInfoRow(permissionType, config, 0, permissionType.defaultLimit),
          data: (availed) {
            final safeAvailed = availed < 0 ? 0 : availed;
            final remainingRaw = permissionType.defaultLimit - safeAvailed;
            final remaining = remainingRaw < 0 ? 0 : remainingRaw;
            return _buildPermissionInfoRow(permissionType, config, safeAvailed, remaining);
          },
        );
      },
    );
  }
  
  Widget _buildPermissionInfoRow(PermissionType permissionType, PermissionConfig config, int availed, int remaining) {
    return Column(
      children: [
        // Row 1: Monthly Limit, Max Duration, Approval Type
        Row(
          children: [
            Expanded(child: _buildInfoItem(Icons.calendar_month, 'Monthly Limit', '${permissionType.defaultLimit}')),
            Expanded(child: _buildInfoItem(Icons.timer, 'Max Duration', config.maxDurationDisplayText)),
            Expanded(child: _buildInfoItem(
              config.requiresApproval ? Icons.approval : Icons.check_circle,
              'Approval',
              config.requiresApproval ? 'Required' : 'Auto',
            )),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Availed, Remaining
        Row(
          children: [
            Expanded(child: _buildInfoItem(Icons.check_circle_outline, 'Availed', '$availed')),
            Expanded(child: _buildInfoItem(
              Icons.hourglass_empty,
              'Remaining',
              '$remaining',
              valueColor: remaining > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            )),
            const Expanded(child: SizedBox()), // Empty space for alignment
          ],
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Icon(icon, color: _accentBlue, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? _textPrimary)),
      ],
    );
  }

  Widget _buildDateTimeCard() {
    return _buildSectionCard(
      'Date & Time',
      Icons.schedule_rounded,
      [
        _buildDateField('Permission Date', _requestDate, () => _selectDate(context)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTimeField('Start Time', _startTime, () => _selectStartTime(context))),
            const SizedBox(width: 16),
            Expanded(child: _buildTimeField('End Time', _endTime, () => _selectEndTime(context))),
          ],
        ),
        if (_calculatedDurationMinutes > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_accentBlue.withOpacity(0.12), _accentBlue.withOpacity(0.04)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _accentBlue, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.timer_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDurationDisplayText(_calculatedDurationMinutes),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary),
                      ),
                      const Text('Total Duration', style: TextStyle(fontSize: 13, color: _textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '$label *',
          labelStyle: const TextStyle(color: _textSecondary),
          floatingLabelStyle: const TextStyle(color: _textPrimary),
          prefixIcon: const Icon(Icons.calendar_today_rounded, color: _textSecondary, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accentBlue, width: 2)),
          filled: true,
          fillColor: _cardDark,
        ),
        child: Text(
          date != null ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}' : 'Select date',
          style: TextStyle(color: date != null ? _textPrimary : _textSecondary),
        ),
      ),
    );
  }

  Widget _buildTimeField(String label, TimeOfDay? time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '$label *',
          labelStyle: const TextStyle(color: _textSecondary),
          floatingLabelStyle: const TextStyle(color: _textPrimary),
          prefixIcon: const Icon(Icons.access_time_rounded, color: _textSecondary, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accentBlue, width: 2)),
          filled: true,
          fillColor: _cardDark,
        ),
        child: Text(
          time != null ? time.format(context) : 'Select time',
          style: TextStyle(color: time != null ? _textPrimary : _textSecondary),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _buildSectionCard(
      'Request Details',
      Icons.description_rounded,
      [
        TextFormField(
          controller: _reasonController,
          style: const TextStyle(color: _textPrimary),
          cursorColor: _accentBlue,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Reason for Permission *',
            hintText: 'Please provide a reason',
            labelStyle: const TextStyle(color: _textSecondary),
            floatingLabelStyle: const TextStyle(color: _textPrimary),
            hintStyle: const TextStyle(color: _textSecondary),
            prefixIcon: const Icon(Icons.edit_note_rounded, color: _textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accentBlue, width: 2)),
            filled: true,
            fillColor: _cardDark,
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Please provide a reason';
            if (value.trim().length < 10) return 'Please provide more detail (at least 10 characters)';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _remarksController,
          style: const TextStyle(color: _textPrimary),
          cursorColor: _accentBlue,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Additional Remarks (Optional)',
            hintText: 'Any additional information',
            labelStyle: const TextStyle(color: _textSecondary),
            floatingLabelStyle: const TextStyle(color: _textPrimary),
            hintStyle: const TextStyle(color: _textSecondary),
            prefixIcon: const Icon(Icons.comment_rounded, color: _textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accentBlue, width: 2)),
            filled: true,
            fillColor: _cardDark,
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFB91C1C).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB91C1C).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: _textSecondary, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(PermissionConfig config) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading || !_canSubmit() ? null : () => _submitPermissionRequest(config),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _borderColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Submit Permission Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: _accentBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _requestDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _accentBlue, surface: _cardDark, onSurface: _textPrimary),
            dialogBackgroundColor: _cardDark,
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _requestDate = date;
        _calculateDuration();
        _validateTiming();
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _accentBlue, surface: _cardDark, onSurface: _textPrimary),
            dialogBackgroundColor: _cardDark,
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _startTime = time;
        _calculateDuration();
        _validateTiming();
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start time first'), backgroundColor: Colors.orange),
      );
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: _accentBlue, surface: _cardDark, onSurface: _textPrimary),
            dialogBackgroundColor: _cardDark,
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _endTime = time;
        _calculateDuration();
        _validateTiming();
      });
    }
  }

  void _calculateDuration() {
    if (_requestDate != null && _startTime != null && _endTime != null) {
      final startDateTime = DateTime(_requestDate!.year, _requestDate!.month, _requestDate!.day, _startTime!.hour, _startTime!.minute);
      final endDateTime = DateTime(_requestDate!.year, _requestDate!.month, _requestDate!.day, _endTime!.hour, _endTime!.minute);
      setState(() => _calculatedDurationMinutes = endDateTime.difference(startDateTime).inMinutes);
    } else {
      setState(() => _calculatedDurationMinutes = 0);
    }
  }

  Future<void> _validateTiming() async {
    if (_requestDate == null || _startTime == null || _endTime == null) {
      setState(() => _errorMessage = null);
      return;
    }

    final session = ref.read(currentSessionProvider);
    if (session?.schoolId == null) return;

    final configAsyncValue = ref.read(permissionConfigProvider(session!.schoolId!));
    configAsyncValue.whenData((config) async {
      if (config != null) {
        final startDateTime = DateTime(_requestDate!.year, _requestDate!.month, _requestDate!.day, _startTime!.hour, _startTime!.minute);
        final endDateTime = DateTime(_requestDate!.year, _requestDate!.month, _requestDate!.day, _endTime!.hour, _endTime!.minute);
        String? validationError = PermissionCalculator.validatePermissionTiming(_requestDate!, startDateTime, endDateTime, config);
        
        // Validate against remaining permission count
        if (validationError == null && _selectedPermissionTypeId != null) {
          try {
            final staffProfile = await ref.read(staffByUserIdProvider((schoolId: session.schoolId!, userId: session.uid)).future);
            if (staffProfile != null) {
              final currentMonth = PermissionCalculator.getCurrentMonth();
              final availed = await ref.read(monthlyPermissionTypeUsageCountFlexibleProvider((
                schoolId: session.schoolId!,
                staffId: staffProfile.id,
                applicantId: session.uid,
                permissionTypeId: _selectedPermissionTypeId!,
                month: currentMonth,
              )).future);
              
              final permissionTypes = await ref.read(activePermissionTypesProvider(session.schoolId!).future);
              final permissionType = permissionTypes.firstWhere(
                (pt) => pt.id == _selectedPermissionTypeId,
                orElse: () => permissionTypes.first,
              );
              
              final remaining = (permissionType.defaultLimit - availed).clamp(0, permissionType.defaultLimit);
              _remainingPermissions = remaining;
              
              if (remaining <= 0) {
                validationError = 'No remaining permission quota for this month. You have used all $availed permissions.';
              }
            }
          } catch (e) {
            // Ignore errors in validation, let server-side handle it
          }
        }
        
        if (mounted) {
          setState(() => _errorMessage = validationError);
        }
      }
    });
  }

  bool _canSubmit() {
    return _selectedPermissionTypeId != null && 
           _requestDate != null && 
           _startTime != null && 
           _endTime != null && 
           _calculatedDurationMinutes > 0 && 
           _errorMessage == null && 
           _reasonController.text.trim().isNotEmpty;
  }

  String _getDurationDisplayText(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  Future<void> _submitPermissionRequest(PermissionConfig config) async {
    if (!_formKey.currentState!.validate() || !_canSubmit()) return;

    final session = ref.read(currentSessionProvider);
    if (session?.schoolId == null) {
      _showError('Session expired. Please login again.');
      return;
    }

    final staffProfile = await ref.read(staffByUserIdProvider((schoolId: session!.schoolId!, userId: session.uid)).future);
    if (staffProfile == null) {
      _showError('Staff profile not found. Please contact administrator.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startDateTime = DateTime(_requestDate!.year, _requestDate!.month, _requestDate!.day, _startTime!.hour, _startTime!.minute);
      final endDateTime = DateTime(_requestDate!.year, _requestDate!.month, _requestDate!.day, _endTime!.hour, _endTime!.minute);

      final request = CreatePermissionRequest(
        requestDate: _requestDate!,
        startTime: startDateTime,
        endTime: endDateTime,
        permissionTypeId: _selectedPermissionTypeId!,
        reason: _reasonController.text.trim(),
        remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      );

      await ref.read(permissionRequestRepositoryProvider).createPermissionRequest(session.schoolId!, session.uid, staffProfile.id, request);

      if (mounted) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          setState(() {
            _selectedPermissionTypeId = null;
            _requestDate = null;
            _startTime = null;
            _endTime = null;
            _calculatedDurationMinutes = 0;
            _errorMessage = null;
          });
          _reasonController.clear();
          _remarksController.clear();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission request submitted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _errorMessage = message);
  }
}
