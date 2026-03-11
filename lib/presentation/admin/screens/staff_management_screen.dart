import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eazy_school_360/core/providers/auth_provider.dart';
import 'package:eazy_school_360/data/repositories/staff_management_repository.dart';
import 'package:eazy_school_360/data/repositories/leave_application_repository.dart';
import 'package:eazy_school_360/data/repositories/permission_request_repository.dart';
import 'package:eazy_school_360/domain/entities/staff_profile.dart';
import 'package:eazy_school_360/domain/entities/app_user.dart';
import 'package:eazy_school_360/presentation/admin/screens/add_staff_screen.dart';
import 'package:eazy_school_360/presentation/admin/screens/staff_details_screen.dart';
import 'package:eazy_school_360/presentation/admin/screens/bulk_staff_upload_screen.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  String _searchQuery = '';
  StaffType? _filterStaffType;
  UserStatus? _filterStatus;
  final _searchController = TextEditingController();

  // Dark theme colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardDark = Color(0xFF161B22);
  static const Color _accentBlue = Color(0xFF4CAF50);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;

    if (session == null || !session.isAdmin || session.schoolId == null) {
      return const Scaffold(backgroundColor: _bgDark, body: Center(child: Text('Access Denied', style: TextStyle(color: _textPrimary))));
    }

    final staffAsyncValue = ref.watch(schoolStaffProvider(session.schoolId!));

    return Scaffold(
      backgroundColor: _bgDark,
      body: Column(
        children: [
          _buildHeader(context, isDesktop),
          Expanded(
            child: staffAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _accentBlue)),
              error: (error, stack) => _buildErrorState(context, session.schoolId!, error),
              data: (staffList) {
                final filteredStaff = _filterStaff(staffList);
                return _buildContent(context, staffList, filteredStaff, isDesktop, isTablet);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, isDesktop ? 20 : 16, isDesktop ? 24 : 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Staff Management', style: TextStyle(fontSize: isDesktop ? 24 : 20, fontWeight: FontWeight.bold, color: _textPrimary)),
                  const SizedBox(height: 4),
                  const Text('Manage all school staff members', style: TextStyle(color: _textSecondary, fontSize: 13)),
                ],
              ),
              _buildAddButton(context, isDesktop),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, bool isDesktop) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'single') {
          _navigateToAddStaff(context);
        } else if (value == 'bulk') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const BulkStaffUploadScreen()));
        }
      },
      offset: const Offset(0, 40),
      color: _cardDark,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'single',
          child: Row(
            children: [
              Icon(Icons.person_add_rounded, color: _textSecondary, size: 18),
              SizedBox(width: 12),
              Text('Add Single Staff', style: TextStyle(color: _textPrimary)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'bulk',
          child: Row(
            children: [
              Icon(Icons.upload_file_rounded, color: _textSecondary, size: 18),
              SizedBox(width: 12),
              Text('Bulk Upload (Excel)', style: TextStyle(color: _textPrimary)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _accentBlue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            if (isDesktop) ...[
              const SizedBox(width: 8),
              const Text('Add Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDesktop) {
    return Row(
      children: [
        Expanded(flex: isDesktop ? 3 : 2, child: _buildSearchField()),
        const SizedBox(width: 12),
        if (isDesktop) ...[
          SizedBox(width: 140, child: _buildStaffTypeFilter()),
          const SizedBox(width: 12),
          SizedBox(width: 140, child: _buildStatusFilter()),
        ] else ...[
          _buildFilterButton(),
        ],
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 42,
      decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: _textPrimary, fontSize: 13),
        decoration: const InputDecoration(
          hintText: 'Search by name, ID, or email...',
          hintStyle: TextStyle(color: _textSecondary, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: _textSecondary, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Container(
      height: 42,
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.filter_list, color: _textSecondary, size: 20),
        color: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'all', child: Text('All Staff', style: TextStyle(color: _textPrimary))),
          const PopupMenuItem(value: 'teaching', child: Text('Teaching', style: TextStyle(color: _textPrimary))),
          const PopupMenuItem(value: 'nonTeaching', child: Text('Non-Teaching', style: TextStyle(color: _textPrimary))),
        ],
        onSelected: (value) {
          setState(() {
            if (value == 'all') _filterStaffType = null;
            else if (value == 'teaching') _filterStaffType = StaffType.TEACHING;
            else if (value == 'nonTeaching') _filterStaffType = StaffType.NON_TEACHING;
          });
        },
      ),
    );
  }

  Widget _buildStaffTypeFilter() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StaffType?>(
          value: _filterStaffType,
          isExpanded: true,
          dropdownColor: _cardDark,
          hint: const Text('All Types', style: TextStyle(color: _textSecondary, fontSize: 13)),
          icon: const Icon(Icons.keyboard_arrow_down, color: _textSecondary, size: 18),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Types', style: TextStyle(color: _textPrimary, fontSize: 13))),
            ...StaffType.values.map((type) => DropdownMenuItem(value: type, child: Text(_getStaffTypeLabel(type), style: const TextStyle(color: _textPrimary, fontSize: 13)))),
          ],
          onChanged: (value) => setState(() => _filterStaffType = value),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserStatus?>(
          value: _filterStatus,
          isExpanded: true,
          dropdownColor: _cardDark,
          hint: const Text('All Status', style: TextStyle(color: _textSecondary, fontSize: 13)),
          icon: const Icon(Icons.keyboard_arrow_down, color: _textSecondary, size: 18),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Status', style: TextStyle(color: _textPrimary, fontSize: 13))),
            ...UserStatus.values.map((status) => DropdownMenuItem(value: status, child: Text(_getStatusLabel(status), style: const TextStyle(color: _textPrimary, fontSize: 13)))),
          ],
          onChanged: (value) => setState(() => _filterStatus = value),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<StaffProfile> allStaff, List<StaffProfile> filteredStaff, bool isDesktop, bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          _buildStatsRow(allStaff, isDesktop, isTablet),
          const SizedBox(height: 16),
          _buildSearchAndFilters(isDesktop),
          const SizedBox(height: 16),
          // Staff Count
          Text('Showing ${filteredStaff.length} of ${allStaff.length} staff', style: const TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          // Staff Grid
          _buildStaffGrid(filteredStaff, isDesktop, isTablet),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<StaffProfile> staffList, bool isDesktop, bool isTablet) {
    final totalStaff = staffList.length;
    final activeStaff = staffList.where((s) => s.status == UserStatus.ACTIVE).length;
    final teachingStaff = staffList.where((s) => s.staffType == StaffType.TEACHING).length;
    final nonTeachingStaff = staffList.where((s) => s.staffType == StaffType.NON_TEACHING).length;

    final stats = [
      {'title': 'Total Staff', 'value': '$totalStaff', 'icon': Icons.people_alt_rounded, 'color': const Color(0xFF8B5CF6)},
      {'title': 'Active', 'value': '$activeStaff', 'icon': Icons.verified_user_rounded, 'color': const Color(0xFFF59E0B)},
      {'title': 'Teaching', 'value': '$teachingStaff', 'icon': Icons.school_rounded, 'color': const Color(0xFF10B981)},
      {'title': 'Non-Teaching', 'value': '$nonTeachingStaff', 'icon': Icons.work_rounded, 'color': const Color(0xFFEF4444)},
    ];

    // Use 2x2 grid for mobile, horizontal row for tablet/desktop
    if (!isDesktop && !isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard(stats[0]['title'] as String, stats[0]['value'] as String, stats[0]['icon'] as IconData, stats[0]['color'] as Color)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(stats[1]['title'] as String, stats[1]['value'] as String, stats[1]['icon'] as IconData, stats[1]['color'] as Color)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(stats[2]['title'] as String, stats[2]['value'] as String, stats[2]['icon'] as IconData, stats[2]['color'] as Color)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(stats[3]['title'] as String, stats[3]['value'] as String, stats[3]['icon'] as IconData, stats[3]['color'] as Color)),
            ],
          ),
        ],
      );
    }

    return Row(
      children: stats
          .map(
            (stat) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: stat == stats.last ? 0 : 12),
                child: _buildStatCard(stat['title'] as String, stat['value'] as String, stat['icon'] as IconData, stat['color'] as Color),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _borderColor)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffGrid(List<StaffProfile> staffList, bool isDesktop, bool isTablet) {
    if (staffList.isEmpty) {
      return _buildEmptyState();
    }

    // Use ListView for mobile to avoid fixed aspect ratio overflow issues
    if (!isDesktop && !isTablet) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: staffList.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildStaffCard(staffList[index]),
        ),
      );
    }

    final crossAxisCount = isDesktop ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isDesktop ? 1.8 : 1.6,
      ),
      itemCount: staffList.length,
      itemBuilder: (context, index) => _buildStaffCard(staffList[index]),
    );
  }

  Widget _buildStaffCard(StaffProfile staff) {
    final statusColor = staff.status == UserStatus.ACTIVE ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final statusLabel = staff.status == UserStatus.ACTIVE ? 'Active' : 'Inactive';
    final typeColor = staff.staffType == StaffType.TEACHING ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6);
    final typeLabel = staff.staffType == StaffType.TEACHING ? 'Teaching' : 'Non-Teaching';
    final session = ref.watch(currentSessionProvider);
    final avatarColor = _getAvatarColor(staff.name);

    return Material(
      color: _cardDark,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffDetailsScreen(staff: staff))),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _borderColor)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Row 1: Avatar + Name/Designation
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [avatarColor, avatarColor.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(_getInitials(staff.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(staff.name, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(staff.designation ?? 'Staff', style: const TextStyle(color: _textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              // Status indicator dot
              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 10),
            // Row 2: Email
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.email_outlined, color: _textSecondary, size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(staff.email, style: const TextStyle(color: _textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
            const SizedBox(height: 10),
            // Row 3: Role tags
            Wrap(spacing: 6, runSpacing: 4, children: [
              _buildTag(statusLabel, statusColor),
              _buildTag(typeLabel, typeColor),
              if (staff.department.isNotEmpty) _buildTag(staff.department, const Color(0xFF6B7280)),
            ]),
            const SizedBox(height: 10),
            // Row 4: Leave/Permission counts with icons
            if (session?.schoolId != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
                child: _buildLeavePermissionSummary(session!.schoolId!, staff.userId),
              ),
            const SizedBox(height: 10),
            // Row 5: Action buttons (Call + Delete)
            Row(children: [
              Expanded(child: _buildCardActionBtn(Icons.phone_rounded, 'Call', const Color(0xFF10B981), () {
                // TODO: Implement call functionality
              })),
              const SizedBox(width: 8),
              Expanded(child: _buildCardActionBtn(Icons.delete_outline_rounded, 'Remove', const Color(0xFFEF4444), () {
                _showDeleteConfirmation(staff);
              })),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildCardActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(StaffProfile staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Remove Staff', style: TextStyle(color: _textPrimary)),
        content: Text('Are you sure you want to remove ${staff.name}?', style: const TextStyle(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final session = ref.read(currentSessionProvider);
              if (session?.schoolId != null) {
                try {
                  await ref.read(staffManagementRepositoryProvider).deleteStaff(session!.schoolId!, staff.userId, session.uid);
                  ref.invalidate(schoolStaffProvider(session.schoolId!));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${staff.name} removed successfully'), backgroundColor: const Color(0xFF10B981)));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)));
                }
              }
            },
            child: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  Widget _buildLeavePermissionSummary(String schoolId, String userId) {
    final leavesAsync = ref.watch(staffLeaveApplicationsProvider((
      schoolId: schoolId,
      applicantId: userId,
    )));
    final permissionsAsync = ref.watch(staffPermissionRequestsProvider((
      schoolId: schoolId,
      applicantId: userId,
    )));

    final leaveCount = leavesAsync.valueOrNull?.length ?? 0;
    final approvedLeaves = leavesAsync.valueOrNull?.where((l) => l.status.name == 'APPROVED').length ?? 0;
    final permissionCount = permissionsAsync.valueOrNull?.length ?? 0;
    final approvedPermissions = permissionsAsync.valueOrNull?.where((p) => p.status.name == 'APPROVED').length ?? 0;

    return Row(
      children: [
        const Icon(Icons.event_note_rounded, color: Color(0xFF3B82F6), size: 13),
        const SizedBox(width: 4),
        Text('$approvedLeaves/$leaveCount leaves', style: const TextStyle(color: _textSecondary, fontSize: 10)),
        const SizedBox(width: 12),
        const Icon(Icons.access_time_rounded, color: Color(0xFF8B5CF6), size: 13),
        const SizedBox(width: 4),
        Text('$approvedPermissions/$permissionCount perms', style: const TextStyle(color: _textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _cardDark, shape: BoxShape.circle),
            child: const Icon(Icons.people_outline, size: 48, color: _textSecondary),
          ),
          const SizedBox(height: 20),
          const Text('No Staff Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          const Text('Add staff members to get started', style: TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String schoolId, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error Loading Staff', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(error.toString(), style: const TextStyle(color: _textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => ref.invalidate(schoolStaffProvider(schoolId)),
            style: ElevatedButton.styleFrom(backgroundColor: _accentBlue),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  List<StaffProfile> _filterStaff(List<StaffProfile> staffList) {
    return staffList.where((staff) {
      if (_searchQuery.isNotEmpty) {
        final matchesSearch = staff.name.toLowerCase().contains(_searchQuery) ||
            staff.email.toLowerCase().contains(_searchQuery) ||
            staff.employeeId.toLowerCase().contains(_searchQuery);
        if (!matchesSearch) return false;
      }
      if (_filterStaffType != null && staff.staffType != _filterStaffType) return false;
      if (_filterStatus != null && staff.status != _filterStatus) return false;
      return true;
    }).toList();
  }

  void _navigateToAddStaff(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screen = MediaQuery.of(context).size;
            final dialogWidth = screen.width >= 1200
                ? 980.0
                : (screen.width >= 900 ? screen.width * 0.85 : screen.width * 0.96);
            final dialogHeight = screen.height * 0.92;

            return SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: const AddStaffScreen(),
            );
          },
        ),
      ),
    );
  }

  String _getStaffTypeLabel(StaffType type) {
    switch (type) {
      case StaffType.TEACHING: return 'Teaching';
      case StaffType.NON_TEACHING: return 'Non-Teaching';
    }
  }

  String _getStatusLabel(UserStatus status) {
    switch (status) {
      case UserStatus.ACTIVE: return 'Active';
      case UserStatus.DISABLED: return 'Inactive';
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF3B82F6), const Color(0xFF10B981), const Color(0xFFF59E0B),
      const Color(0xFFEF4444), const Color(0xFF8B5CF6), const Color(0xFFEC4899),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}
