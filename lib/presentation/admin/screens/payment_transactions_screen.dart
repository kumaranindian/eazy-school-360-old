import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/payment_transaction_repository.dart';
import '../../../domain/entities/payment_transaction.dart';

const Color _bgDark = Color(0xFF0F172A);
const Color _cardDark = Color(0xFF1E293B);
const Color _accentGreen = Color(0xFF10B981);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentRed = Color(0xFFEF4444);
const Color _accentAmber = Color(0xFFF59E0B);
const Color _textPrimary = Color(0xFFF1F5F9);
const Color _textSecondary = Color(0xFF94A3B8);
const Color _borderColor = Color(0xFF334155);

class PaymentTransactionsScreen extends ConsumerStatefulWidget {
  final String schoolId;

  const PaymentTransactionsScreen({
    super.key,
    required this.schoolId,
  });

  @override
  ConsumerState<PaymentTransactionsScreen> createState() =>
      _PaymentTransactionsScreenState();
}

class _PaymentTransactionsScreenState
    extends ConsumerState<PaymentTransactionsScreen> {
  PaymentStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showStats = true;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _endDate = DateTime.now();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accentBlue,
              surface: _cardDark,
              background: _bgDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.SUCCESS:
        return _accentGreen;
      case PaymentStatus.FAILED:
        return _accentRed;
      case PaymentStatus.PENDING:
        return _accentAmber;
      case PaymentStatus.INITIATED:
        return _accentBlue;
      case PaymentStatus.REFUNDED:
        return Colors.purple;
    }
  }

  IconData _getStatusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.SUCCESS:
        return Icons.check_circle;
      case PaymentStatus.FAILED:
        return Icons.error;
      case PaymentStatus.PENDING:
        return Icons.pending;
      case PaymentStatus.INITIATED:
        return Icons.hourglass_empty;
      case PaymentStatus.REFUNDED:
        return Icons.undo;
    }
  }

  IconData _getMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.CARD:
        return Icons.credit_card;
      case PaymentMethod.UPI:
        return Icons.qr_code;
      case PaymentMethod.NET_BANKING:
        return Icons.account_balance;
      case PaymentMethod.WALLET:
        return Icons.account_balance_wallet;
      case PaymentMethod.CASH:
        return Icons.money;
      case PaymentMethod.CHEQUE:
        return Icons.receipt_long;
      case PaymentMethod.BANK_TRANSFER:
        return Icons.swap_horiz;
      case PaymentMethod.OTHER:
        return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsStream = ref.watch(transactionsBySchoolProvider(widget.schoolId));

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _cardDark,
        elevation: 0,
        title: const Text(
          'Payment Transactions',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showStats ? Icons.list : Icons.analytics,
              color: _textPrimary,
            ),
            onPressed: () => setState(() => _showStats = !_showStats),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: _textPrimary),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateRangeSelector(),
          if (_showStats) _buildStatsSection(),
          Expanded(
            child: transactionsStream.when(
              data: (transactions) {
                final filtered = _filterTransactions(transactions);
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildTransactionsList(filtered);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: _accentBlue),
              ),
              error: (error, stack) => Center(
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: _accentRed),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range, color: _accentBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _startDate != null && _endDate != null
                  ? '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}'
                  : 'Select date range',
              style: const TextStyle(color: _textPrimary, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: _selectDateRange,
            child: const Text('Change', style: TextStyle(color: _accentBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_startDate == null || _endDate == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(paymentTransactionRepositoryProvider).getTransactionStats(
            widget.schoolId,
            _startDate!,
            _endDate!,
          ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transaction Summary',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Amount',
                      '₹${(stats['totalAmount'] ?? 0).toStringAsFixed(2)}',
                      _accentGreen,
                      Icons.currency_rupee,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Transactions',
                      '${stats['successfulTransactions'] ?? 0}',
                      _accentBlue,
                      Icons.receipt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Success Rate',
                      '${(stats['successRate'] ?? 0).toStringAsFixed(1)}%',
                      _accentGreen,
                      Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Failed',
                      '${stats['failedTransactions'] ?? 0}',
                      _accentRed,
                      Icons.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<PaymentTransaction> transactions) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(PaymentTransaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showTransactionDetails(transaction),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(transaction.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getStatusIcon(transaction.status),
                        color: _getStatusColor(transaction.status),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.studentName,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${transaction.studentId}',
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${transaction.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _getStatusColor(transaction.status),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(transaction.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            transaction.status.name,
                            style: TextStyle(
                              color: _getStatusColor(transaction.status),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _getMethodIcon(transaction.method),
                      color: _textSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      transaction.method.name,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      transaction.gateway == PaymentGateway.RAZORPAY
                          ? Icons.payment
                          : Icons.store,
                      color: _textSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      transaction.gateway.name,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd MMM, hh:mm a').format(transaction.createdAt),
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (transaction.razorpayPaymentId != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _bgDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          color: _textSecondary,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Payment ID: ${transaction.razorpayPaymentId}',
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: _textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No transactions found',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  List<PaymentTransaction> _filterTransactions(List<PaymentTransaction> transactions) {
    var filtered = transactions;

    if (_selectedStatus != null) {
      filtered = filtered.where((t) => t.status == _selectedStatus).toList();
    }

    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((t) {
        return t.createdAt.isAfter(_startDate!) &&
            t.createdAt.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Filter Transactions', style: TextStyle(color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<PaymentStatus?>(
              value: _selectedStatus,
              dropdownColor: _cardDark,
              decoration: const InputDecoration(
                labelText: 'Status',
                labelStyle: TextStyle(color: _textSecondary),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...PaymentStatus.values.map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.name),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(PaymentTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Transaction Details', style: TextStyle(color: _textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Transaction ID', transaction.id),
              _buildDetailRow('Student', transaction.studentName),
              _buildDetailRow('Student ID', transaction.studentId),
              _buildDetailRow('Amount', '₹${transaction.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Status', transaction.status.name),
              _buildDetailRow('Method', transaction.method.name),
              _buildDetailRow('Gateway', transaction.gateway.name),
              if (transaction.razorpayOrderId != null)
                _buildDetailRow('Order ID', transaction.razorpayOrderId!),
              if (transaction.razorpayPaymentId != null)
                _buildDetailRow('Payment ID', transaction.razorpayPaymentId!),
              if (transaction.transactionRef != null)
                _buildDetailRow('Reference', transaction.transactionRef!),
              _buildDetailRow(
                'Created',
                DateFormat('dd MMM yyyy, hh:mm a').format(transaction.createdAt),
              ),
              if (transaction.completedAt != null)
                _buildDetailRow(
                  'Completed',
                  DateFormat('dd MMM yyyy, hh:mm a').format(transaction.completedAt!),
                ),
              if (transaction.errorMessage != null)
                _buildDetailRow('Error', transaction.errorMessage!, isError: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _accentBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isError ? _accentRed : _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
