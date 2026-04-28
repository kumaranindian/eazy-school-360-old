import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/student_fee_ledger_repository.dart';
import '../../../domain/entities/student_fee_ledger.dart';
import 'student_fee_ledger_detail_screen.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class StudentFeeLedgerListScreen extends ConsumerStatefulWidget {
  const StudentFeeLedgerListScreen({super.key});

  @override
  ConsumerState<StudentFeeLedgerListScreen> createState() =>
      _StudentFeeLedgerListScreenState();
}

class _StudentFeeLedgerListScreenState
    extends ConsumerState<StudentFeeLedgerListScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = 'ALL'; // ALL | UNPAID | PARTIAL | PAID | OVERDUE

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final schoolId = session?.schoolId;
    if (schoolId == null) {
      return const Scaffold(
        backgroundColor: _bgDark,
        body: Center(
          child: Text('Access Denied', style: TextStyle(color: _textPrimary)),
        ),
      );
    }

    final ledgersAsync = ref.watch(studentFeeLedgersProvider(schoolId));

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        title: const Text('Student Fee Ledgers',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _textPrimary),
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: ledgersAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _accentGreen)),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: _textSecondary)),
              ),
              data: (all) {
                final filtered = _applyFilters(all);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No ledgers match your filters.',
                        style: TextStyle(color: _textSecondary)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LedgerTile(
                    ledger: filtered[i],
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StudentFeeLedgerDetailScreen(
                          schoolId: schoolId,
                          ledgerId: filtered[i].id,
                        ),
                      ));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<StudentFeeLedger> _applyFilters(List<StudentFeeLedger> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return all.where((l) {
      if (q.isNotEmpty) {
        final hay = '${l.studentName} ${l.studentId} ${l.className} '
                '${l.section} ${l.feeStructureName}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      switch (_filter) {
        case 'UNPAID':
          return l.totalPaid == 0;
        case 'PARTIAL':
          return l.totalPaid > 0 && l.totalPending > 0;
        case 'PAID':
          return l.totalPending <= 0;
        case 'OVERDUE':
          return l.totalOverdue > 0;
        default:
          return true;
      }
    }).toList();
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: _textPrimary),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by student name, ID, or class…',
              hintStyle: const TextStyle(color: _textSecondary),
              prefixIcon:
                  const Icon(Icons.search, color: _textSecondary, size: 20),
              filled: true,
              fillColor: _cardDark,
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
                borderSide: const BorderSide(color: _accentGreen),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in const [
                  'ALL',
                  'UNPAID',
                  'PARTIAL',
                  'PAID',
                  'OVERDUE'
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: _accentGreen,
                      backgroundColor: _cardDark,
                      labelStyle: TextStyle(
                          color:
                              _filter == f ? Colors.white : _textPrimary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.ledger, required this.onTap});

  final StudentFeeLedger ledger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final pct = ledger.totalAssigned == 0
        ? 0.0
        : (ledger.totalPaid / ledger.totalAssigned).clamp(0.0, 1.0);
    final overdue = ledger.totalOverdue > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: overdue ? _accentRed.withOpacity(0.4) : _borderColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _accentBlue.withOpacity(0.2),
              child: Text(
                ledger.studentName.isNotEmpty
                    ? ledger.studentName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: _accentBlue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ledger.studentName,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (overdue)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _accentRed.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OVERDUE',
                            style: TextStyle(
                                color: _accentRed,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${ledger.className} • ${ledger.section} • ${ledger.feeStructureName}',
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: _bgDark,
                      valueColor: AlwaysStoppedAnimation(
                          ledger.totalPending <= 0
                              ? _accentGreen
                              : (overdue ? _accentRed : _accentAmber)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Paid: ${money.format(ledger.totalPaid)}',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        'Pending: ${money.format(ledger.totalPending)}',
                        style: TextStyle(
                          color: ledger.totalPending <= 0
                              ? _accentGreen
                              : _accentAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: _textSecondary),
          ],
        ),
      ),
    );
  }
}
