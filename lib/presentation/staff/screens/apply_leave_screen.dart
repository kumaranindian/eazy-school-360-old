import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/leave_application_repository.dart';
import 'package:eazy_school_360/data/repositories/leave_configuration_repository.dart';
import 'package:eazy_school_360/data/repositories/staff_management_repository.dart';
import 'package:eazy_school_360/domain/entities/leave_application.dart';
import 'package:eazy_school_360/domain/entities/leave_type_config.dart';
import 'package:eazy_school_360/domain/entities/leave_balance.dart';

class ApplyLeaveScreen extends ConsumerStatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> {
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

  String? _selectedLeaveTypeId;
  DateTime? _startDate;
  DateTime? _endDate;
  List<DateTime> _calculatedLeaveDates = <DateTime>[];
  int _totalWorkingDays = 0;
  int _remainingDays = 0; // Track remaining days for validation
  bool _isLoading = false;
  String? _errorMessage;

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
      return const Scaffold(
        body: Center(child: Text('Access Denied')),
      );
    }

    final leaveTypesAsyncValue = ref.watch(activeSchoolLeaveTypesProvider(session.schoolId!));

    return Scaffold(
      backgroundColor: _bgDark,
      body: leaveTypesAsyncValue.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _accentBlue),
        ),
        error: (error, stack) => _buildErrorState(context, session.schoolId!, error),
        data: (leaveTypes) {
          if (leaveTypes.isEmpty) {
            return _buildEmptyState();
          }
          return _buildContent(context, leaveTypes, isDesktop);
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
              decoration: BoxDecoration(
                color: const Color(0xFFB91C1C).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error Loading Leave Types',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary),
            ),
            const SizedBox(height: 8),
            Text(error.toString(), style: const TextStyle(color: _textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.refresh(activeSchoolLeaveTypesProvider(schoolId)),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy_rounded, size: 64, color: _accentBlue),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Leave Types Available',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Please contact your administrator to set up leave types',
              style: const TextStyle(color: _textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<LeaveTypeConfig> leaveTypes, bool isDesktop) {
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
                // Step 1: Leave Type Selection
                _buildStepHeader(1, 'Select Leave Type', _selectedLeaveTypeId != null),
                const SizedBox(height: 12),
                _buildLeaveTypeSelection(leaveTypes),
                const SizedBox(height: 24),
                
                // Step 2: Select Dates
                _buildStepHeader(2, 'Select Dates', _startDate != null && _endDate != null),
                const SizedBox(height: 12),
                _buildDateSelection(),
                const SizedBox(height: 24),
                
                // Step 3: Leave Details
                _buildStepHeader(3, 'Provide Details', _reasonController.text.trim().length >= 10),
                const SizedBox(height: 12),
                _buildLeaveDetails(),
                const SizedBox(height: 24),
                
                // Error Message
                if (_errorMessage != null) ...[
                  _buildErrorMessage(),
                  const SizedBox(height: 16),
                ],
                
                // Submit Button
                _buildSubmitButton(),
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
            color: isComplete ? const Color(0xFF10B981) : _accentBlue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: isComplete
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '$step',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveTypeSelection(List<LeaveTypeConfig> leaveTypes) {
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
          // Horizontal scrollable list of leave types
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: leaveTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final leaveType = leaveTypes[index];
                final isSelected = _selectedLeaveTypeId == leaveType.id;
                return _buildLeaveTypeChip(leaveType, isSelected);
              },
            ),
          ),
          if (_selectedLeaveTypeId != null) ...[
            const SizedBox(height: 16),
            const Divider(color: _borderColor, height: 1),
            const SizedBox(height: 16),
            _buildSelectedLeaveInfo(leaveTypes.firstWhere((lt) => lt.id == _selectedLeaveTypeId)),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaveTypeChip(LeaveTypeConfig leaveType, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLeaveTypeId = leaveType.id;
          _calculateLeaveDays();
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
                  leaveType.isPaid ? Icons.paid_rounded : Icons.money_off_rounded,
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
                  leaveType.name,
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
                  '${leaveType.annualQuota} days/yr',
                  style: const TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedLeaveInfo(LeaveTypeConfig leaveType) {
    final session = ref.watch(currentSessionProvider);
    if (session?.schoolId == null) return const SizedBox.shrink();
    
    final currentAcademicYear = AcademicYear.getCurrentAcademicYear();
    
    // Query availed days directly from leaves collection (source of truth)
    final availedAsync = ref.watch(availedLeaveDaysProvider((
      schoolId: session!.schoolId!,
      applicantId: session.uid,
      leaveTypeId: leaveType.id,
      academicYear: currentAcademicYear,
    )));
    
    return availedAsync.when(
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(color: _accentBlue, strokeWidth: 2),
      )),
      error: (_, __) => _buildLeaveInfoRow(leaveType, 0, leaveType.annualQuota),
      data: (availed) {
        final remaining = (leaveType.annualQuota - availed).clamp(0, leaveType.annualQuota);
        return _buildLeaveInfoRow(leaveType, availed, remaining);
      },
    );
  }
  
  Widget _buildLeaveInfoRow(LeaveTypeConfig leaveType, int availed, int remaining) {
    return Column(
      children: [
        // Row 1: Annual Quota, Max/Request, Type
        Row(
          children: [
            Expanded(child: _buildInfoItem(Icons.calendar_today, 'Annual Quota', '${leaveType.annualQuota} days')),
            Expanded(child: _buildInfoItem(Icons.event_note, 'Max/Request', '${leaveType.maxDaysPerRequest} days')),
            Expanded(child: _buildInfoItem(
              leaveType.isPaid ? Icons.attach_money : Icons.money_off,
              'Type',
              leaveType.isPaid ? 'Paid' : 'Unpaid',
            )),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Availed, Remaining
        Row(
          children: [
            Expanded(child: _buildInfoItem(Icons.check_circle_outline, 'Availed', '$availed days')),
            Expanded(child: _buildInfoItem(
              Icons.hourglass_empty,
              'Remaining',
              '$remaining days',
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

  Widget _buildDateSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDateButton('Start Date', _startDate, () => _selectStartDate(context)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateButton('End Date', _endDate, () => _selectEndDate(context)),
              ),
            ],
          ),
          if (_totalWorkingDays > 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accentBlue.withOpacity(0.15), _accentBlue.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available, color: _accentBlue, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_totalWorkingDays Working Day${_totalWorkingDays > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
                      ),
                      const Text(
                        'Weekends & holidays excluded',
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: _bgDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: date != null ? _accentBlue : _borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: date != null ? _accentBlue : _textSecondary, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary)),
                const SizedBox(height: 2),
                Text(
                  date != null
                      ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                      : 'Select',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: date != null ? _textPrimary : _textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _reasonController,
            style: const TextStyle(color: _textPrimary),
            cursorColor: _accentBlue,
            decoration: InputDecoration(
              labelText: 'Reason for Leave *',
              hintText: 'Please provide a detailed reason',
              labelStyle: const TextStyle(color: _textSecondary),
              floatingLabelStyle: const TextStyle(color: _textPrimary),
              hintStyle: const TextStyle(color: _textSecondary),
              prefixIcon: const Icon(Icons.edit_note_rounded, color: _textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accentBlue, width: 2)),
              filled: true,
              fillColor: _bgDark,
            ),
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please provide a reason for leave';
              }
              if (value.trim().length < 10) {
                return 'Please provide at least 10 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _remarksController,
            style: const TextStyle(color: _textPrimary),
            cursorColor: _accentBlue,
            decoration: InputDecoration(
              labelText: 'Additional Remarks (Optional)',
              hintText: 'Any additional information',
              labelStyle: const TextStyle(color: _textSecondary),
              floatingLabelStyle: const TextStyle(color: _textPrimary),
              hintStyle: const TextStyle(color: _textSecondary),
              prefixIcon: const Icon(Icons.comment_rounded, color: _textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accentBlue, width: 2)),
              filled: true,
              fillColor: _bgDark,
            ),
            maxLines: 2,
          ),
        ],
      ),
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
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: _textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading || !_canSubmit() ? null : _submitLeaveApplication,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _borderColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Submit Leave Application',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
        _startDate = date;
        if (_endDate != null && _endDate!.isBefore(date)) {
          _endDate = null;
        }
        _calculateLeaveDays();
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start date first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
        _endDate = date;
        _calculateLeaveDays();
      });
    }
  }

  Future<void> _calculateLeaveDays() async {
    if (_startDate == null || _endDate == null || _selectedLeaveTypeId == null) {
      setState(() {
        _calculatedLeaveDates = [];
        _totalWorkingDays = 0;
        _remainingDays = 0;
        _errorMessage = null;
      });
      return;
    }

    final session = ref.read(currentSessionProvider);
    if (session?.schoolId == null) return;

    try {
      // Get holidays for the date range
      final holidays = await ref.read(schoolHolidaysProvider({
        'schoolId': session!.schoolId!,
        'startDate': _startDate,
        'endDate': _endDate,
      }).future);

      // Get existing leave applications for overlap check
      final existingApplications = await ref.read(staffLeaveApplicationsProvider((
        schoolId: session.schoolId!,
        applicantId: session.uid,
      )).future);

      // Calculate leave dates
      final leaveDates = LeaveDateCalculator.calculateLeaveDates(
        _startDate!,
        _endDate!,
        holidays,
      );

      // Validate dates
      String? validationError = LeaveDateCalculator.validateLeaveDates(
        _startDate!,
        _endDate!,
        holidays,
        existingApplications,
      );

      // Get leave type config to check quota
      final leaveTypes = await ref.read(activeSchoolLeaveTypesProvider(session.schoolId!).future);
      final leaveType = leaveTypes.firstWhere(
        (lt) => lt.id == _selectedLeaveTypeId,
        orElse: () => leaveTypes.first,
      );

      // Get availed days and calculate remaining
      final currentAcademicYear = AcademicYear.getCurrentAcademicYear();
      final availed = await ref.read(availedLeaveDaysProvider((
        schoolId: session.schoolId!,
        applicantId: session.uid,
        leaveTypeId: _selectedLeaveTypeId!,
        academicYear: currentAcademicYear,
      )).future);
      
      final remaining = (leaveType.annualQuota - availed).clamp(0, leaveType.annualQuota);

      // Validate against remaining balance
      if (validationError == null && remaining <= 0) {
        validationError = 'No remaining leave balance for ${leaveType.name}. You have used all $availed days.';
      } else if (validationError == null && leaveDates.length > remaining) {
        validationError = 'Insufficient leave balance. Requesting ${leaveDates.length} days but only $remaining days remaining.';
      }

      setState(() {
        _calculatedLeaveDates = leaveDates;
        _totalWorkingDays = leaveDates.length;
        _remainingDays = remaining;
        _errorMessage = validationError;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error calculating leave days: ${e.toString()}';
        _calculatedLeaveDates = [];
        _totalWorkingDays = 0;
        _remainingDays = 0;
      });
    }
  }

  bool _canSubmit() {
    return _selectedLeaveTypeId != null &&
        _startDate != null &&
        _endDate != null &&
        _totalWorkingDays > 0 &&
        _errorMessage == null &&
        _reasonController.text.trim().isNotEmpty;
  }

  Future<void> _submitLeaveApplication() async {
    if (!_formKey.currentState!.validate() || !_canSubmit()) {
      return;
    }

    final session = ref.read(currentSessionProvider);
    if (session?.schoolId == null) {
      _showError('Session expired. Please login again.');
      return;
    }

    // Get staff profile
    final staffProfile = await ref.read(staffByUserIdProvider((
      schoolId: session!.schoolId!,
      userId: session.uid,
    )).future);

    if (staffProfile == null) {
      _showError('Staff profile not found. Please contact administrator.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final request = CreateLeaveApplicationRequest(
        leaveTypeId: _selectedLeaveTypeId!,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
        remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      );

      await ref.read(leaveApplicationRepositoryProvider).createLeaveApplication(
        session.schoolId!,
        session.uid,
        staffProfile.id,
        request,
      );

      if (mounted) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          setState(() {
            _selectedLeaveTypeId = null;
            _startDate = null;
            _endDate = null;
            _totalWorkingDays = 0;
            _errorMessage = null;
          });
          _reasonController.clear();
          _remarksController.clear();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });
    }
  }
}
