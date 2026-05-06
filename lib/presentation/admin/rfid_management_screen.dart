import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../data/models/rfid_card.dart';
import '../../data/repositories/rfid_repository.dart';

// Providers
final rfidRepositoryProvider = Provider<RfidRepository>((ref) {
  return RfidRepository(FirebaseFunctions.instance);
});

final rfidCardsProvider = FutureProvider.family<RfidCardsResponse, String>((ref, schoolId) async {
  final repository = ref.watch(rfidRepositoryProvider);
  return repository.listRfidCards(schoolId);
});

class RfidManagementScreen extends ConsumerStatefulWidget {
  final String schoolId;

  const RfidManagementScreen({
    super.key,
    required this.schoolId,
  });

  @override
  ConsumerState<RfidManagementScreen> createState() => _RfidManagementScreenState();
}

class _RfidManagementScreenState extends ConsumerState<RfidManagementScreen> {
  bool _showAssignedOnly = false;

  @override
  Widget build(BuildContext context) {
    final rfidCardsAsync = ref.watch(rfidCardsProvider(widget.schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('RFID Card Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(rfidCardsProvider(widget.schoolId));
            },
          ),
        ],
      ),
      body: rfidCardsAsync.when(
        data: (response) {
          if (!response.success || response.data == null) {
            return Center(
              child: Text(response.message ?? 'Failed to load RFID cards'),
            );
          }

          final data = response.data!;
          final cards = _showAssignedOnly 
              ? data.cards.where((c) => c.isAssigned).toList()
              : data.cards;

          return Column(
            children: [
              // Stats cards
              _buildStatsCards(data),
              // Filter toggle
              _buildFilterToggle(),
              // Cards list
              Expanded(
                child: cards.isEmpty
                    ? _buildEmptyState()
                    : _buildCardsList(cards),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRegisterCardDialog,
        child: const Icon(Icons.add_card),
      ),
    );
  }

  Widget _buildStatsCards(RfidCardsData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Total Cards',
              value: data.totalCards.toString(),
              icon: Icons.credit_card,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Assigned',
              value: data.assignedCards.toString(),
              icon: Icons.check_circle,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Unassigned',
              value: data.unassignedCards.toString(),
              icon: Icons.unpublished,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Switch(
            value: _showAssignedOnly,
            onChanged: (value) {
              setState(() {
                _showAssignedOnly = value;
              });
            },
          ),
          const Text('Show assigned only'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _showAssignedOnly ? 'No assigned cards found' : 'No RFID cards found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          if (!_showAssignedOnly)
            Text(
              'Register a card using the device or add one manually',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardsList(List<RfidCard> cards) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return _RfidCardTile(
          card: card,
          onMap: () => _showMapDialog(card),
          onUnmap: card.isAssigned ? () => _unmapCard(card) : null,
        );
      },
    );
  }

  void _showRegisterCardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register RFID Card'),
        content: const Text('To register a new RFID card, use the physical device to scan the card. The card will appear in this list automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMapDialog(RfidCard card) {
    showDialog(
      context: context,
      builder: (context) => _MapRfidDialog(
        card: card,
        schoolId: widget.schoolId,
        onMap: (staffId, studentId) async {
          try {
            if (staffId != null) {
              await ref.read(rfidRepositoryProvider).mapRfidToStaff(
                schoolId: widget.schoolId,
                rfidTag: card.rfidTag,
                staffId: staffId,
              );
            } else if (studentId != null) {
              await ref.read(rfidRepositoryProvider).mapRfidToStudent(
                schoolId: widget.schoolId,
                rfidTag: card.rfidTag,
                studentId: studentId,
              );
            }
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('RFID card mapped successfully')),
              );
              ref.invalidate(rfidCardsProvider(widget.schoolId));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to map card: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _unmapCard(RfidCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unmap RFID Card'),
        content: Text('Are you sure you want to unmap ${card.rfidTag}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unmap'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(rfidRepositoryProvider).unmapRfidCard(
          schoolId: widget.schoolId,
          rfidTag: card.rfidTag,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('RFID card unmapped successfully')),
          );
          ref.invalidate(rfidCardsProvider(widget.schoolId));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to unmap card: $e')),
          );
        }
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RfidCardTile extends StatelessWidget {
  final RfidCard card;
  final VoidCallback onMap;
  final VoidCallback? onUnmap;

  const _RfidCardTile({
    required this.card,
    required this.onMap,
    this.onUnmap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: card.isAssigned ? Colors.green : Colors.orange,
          child: Icon(
            card.isAssigned ? Icons.check : Icons.unpublished,
            color: Colors.white,
          ),
        ),
        title: Text(
          card.rfidTag,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.assignedPersonName),
            Text(
              card.assignmentType,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: onMap,
              tooltip: 'Map to person',
            ),
            if (onUnmap != null)
              IconButton(
                icon: const Icon(Icons.person_remove),
                onPressed: onUnmap,
                tooltip: 'Unmap',
              ),
          ],
        ),
      ),
    );
  }
}

class _MapRfidDialog extends StatefulWidget {
  final RfidCard card;
  final String schoolId;
  final Function(String? staffId, String? studentId) onMap;

  const _MapRfidDialog({
    required this.card,
    required this.schoolId,
    required this.onMap,
  });

  @override
  State<_MapRfidDialog> createState() => _MapRfidDialogState();
}

class _MapRfidDialogState extends State<_MapRfidDialog> {
  String _selectedType = 'staff';
  String? _selectedStaffId;
  String? _selectedStudentId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Map ${widget.card.rfidTag}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Map to:'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'staff',
                  label: Text('Staff'),
                ),
                ButtonSegment(
                  value: 'student',
                  label: Text('Student'),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                  _selectedStaffId = null;
                  _selectedStudentId = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedType == 'staff')
              _buildStaffDropdown()
            else
              _buildStudentDropdown(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canSubmit() ? _handleSubmit : null,
          child: const Text('Map'),
        ),
      ],
    );
  }

  Widget _buildStaffDropdown() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('staff')
          .where('status', isEqualTo: 'ACTIVE')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No active staff found');
        }

        return DropdownButtonFormField<String>(
          hint: const Text('Select staff'),
          value: _selectedStaffId,
          items: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text(data['name']?.toString() ?? data['displayName']?.toString() ?? 'Unknown'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedStaffId = value;
            });
          },
        );
      },
    );
  }

  Widget _buildStudentDropdown() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('students')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No students found');
        }

        return DropdownButtonFormField<String>(
          hint: const Text('Select student'),
          value: _selectedStudentId,
          items: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text(data['studentName']?.toString() ?? data['name']?.toString() ?? 'Unknown'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedStudentId = value;
            });
          },
        );
      },
    );
  }

  bool _canSubmit() {
    if (_selectedType == 'staff') {
      return _selectedStaffId != null;
    } else {
      return _selectedStudentId != null;
    }
  }

  void _handleSubmit() {
    widget.onMap(
      _selectedType == 'staff' ? _selectedStaffId : null,
      _selectedType == 'student' ? _selectedStudentId : null,
    );
  }
}
