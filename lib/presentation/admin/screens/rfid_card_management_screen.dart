import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../data/repositories/rfid_card_repository.dart';
import '../../../domain/entities/rfid_card.dart';

const Color _bgDark = Color(0xFF0D1117);
const Color _cardDark = Color(0xFF161B22);
const Color _accentGreen = Color(0xFF4CAF50);
const Color _accentBlue = Color(0xFF3B82F6);
const Color _accentRed = Color(0xFFEF4444);
const Color _textPrimary = Color(0xFFE6EDF3);
const Color _textSecondary = Color(0xFF8B949E);
const Color _borderColor = Color(0xFF30363D);

class RfidCardManagementScreen extends ConsumerStatefulWidget {
  const RfidCardManagementScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RfidCardManagementScreen> createState() =>
      _RfidCardManagementScreenState();
}

class _RfidCardManagementScreenState
    extends ConsumerState<RfidCardManagementScreen> {
  String? _selectedStaffId;
  Map<String, dynamic>? _selectedStaff;
  List<Map<String, dynamic>> _staffList = [];
  List<RfidCard> _staffCards = [];
  List<RfidCard> _availableCards = [];
  bool _isLoading = false;
  bool _isAssigning = false;
  String? get _schoolId => ref.read(currentSessionProvider)?.schoolId;

  final RfidCardRepository _rfidRepo = RfidCardRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form controllers
  final _primaryUuidController = TextEditingController();
  final _backupUuidController = TextEditingController();
  
  // Selected card UIDs from dropdown
  String? _selectedPrimaryCardUuid;
  String? _selectedBackupCardUuid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStaffList();
      _loadAvailableCards();
    });
  }

  @override
  void dispose() {
    _primaryUuidController.dispose();
    _backupUuidController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffList() async {
    if (_schoolId == null) return;
    setState(() => _isLoading = true);
    try {
      final snap = await _firestore
          .collection('schools')
          .doc(_schoolId)
          .collection('staff')
          .where('status', isEqualTo: 'ACTIVE')
          .orderBy('name')
          .get();
      
      if (mounted) {
        setState(() {
          _staffList = snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[RfidCardManagement] Error loading staff: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStaffCards(String staffId) async {
    if (_schoolId == null) return;
    setState(() => _isLoading = true);
    try {
      final cards = await _rfidRepo.getActiveCardsByStaff(_schoolId!, staffId);
      if (mounted) {
        setState(() {
          _staffCards = cards;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[RfidCardManagement] Error loading cards: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAvailableCards() async {
    if (_schoolId == null) return;
    try {
      // Load all active cards and filter client-side for unassigned ones
      // Note: Firestore doesn't support querying for null values directly
      final snap = await _firestore
          .collection('schools')
          .doc(_schoolId)
          .collection('rfid_cards')
          .where('isActive', isEqualTo: true)
          .orderBy('assignedAt', descending: true)
          .get();
      
      if (mounted) {
        setState(() {
          // Filter for cards without staffId (unassigned)
          // staffId is null when unassigned
          _availableCards = snap.docs
              .map((doc) => RfidCard.fromFirestore(doc.data(), doc.id))
              .where((card) => card.staffId == null)
              .toList();
        });
        
        print('[RfidCardManagement] Loaded ${_availableCards.length} available cards');
      }
    } catch (e) {
      print('[RfidCardManagement] Error loading available cards: $e');
    }
  }

  Future<void> _assignCard(RfidCardType cardType, String uuid) async {
    if (_selectedStaffId == null || _schoolId == null) return;
    
    print('[RfidCardManagement] Starting card assignment');
    print('[RfidCardManagement] School ID: $_schoolId');
    print('[RfidCardManagement] Staff ID: $_selectedStaffId');
    print('[RfidCardManagement] Staff Name: ${_selectedStaff!['name']}');
    print('[RfidCardManagement] Card Type: ${cardType.value}');
    print('[RfidCardManagement] UUID: ${uuid.trim()}');
    
    setState(() => _isAssigning = true);
    try {
      // Use existing mapRfidToStaff Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('mapRfidToStaff');
      
      print('[RfidCardManagement] Calling Cloud Function: mapRfidToStaff');
      final result = await callable.call({
        'schoolId': _schoolId!,
        'rfidTag': uuid.trim(),
        'staffId': _selectedStaffId!,
        'cardType': cardType.value,
        'staffName': (_selectedStaff!['name'] as String?) ?? '',
      });
      
      print('[RfidCardManagement] Cloud Function response: ${result.data}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cardType.displayName} assigned successfully'),
            backgroundColor: _accentGreen,
          ),
        );
        
        // Clear form selections
        setState(() {
          _selectedPrimaryCardUuid = null;
          _selectedBackupCardUuid = null;
          _primaryUuidController.clear();
          _backupUuidController.clear();
        });
        
        // Reload staff cards and available cards
        await _loadStaffCards(_selectedStaffId!);
        
        // Add small delay to ensure Firestore has propagated
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadAvailableCards();
      }
    } on FirebaseFunctionsException catch (e) {
      print('[RfidCardManagement] FirebaseFunctionsException:');
      print('[RfidCardManagement] Code: ${e.code}');
      print('[RfidCardManagement] Message: ${e.message}');
      print('[RfidCardManagement] Details: ${e.details}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message ?? e.code}'),
            backgroundColor: _accentRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('[RfidCardManagement] Unexpected error: $e');
      print('[RfidCardManagement] Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning card: $e'),
            backgroundColor: _accentRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  Future<void> _deactivateCard(String cardId) async {
    if (_schoolId == null) return;
    
    try {
      // First get the card to find its UUID
      final card = await _rfidRepo.getCardById(_schoolId!, cardId);
      if (card == null) {
        throw Exception('Card not found');
      }
      
      // Use existing unmapRfidCard Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('unmapRfidCard');
      
      print('[RfidCardManagement] Calling Cloud Function: unmapRfidCard');
      final result = await callable.call({
        'schoolId': _schoolId!,
        'rfidTag': card.uuid,
      });
      
      print('[RfidCardManagement] Cloud Function response: ${result.data}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card deactivated successfully'),
            backgroundColor: _accentGreen,
          ),
        );
        
        // Reload staff cards
        await _loadStaffCards(_selectedStaffId!);
        
        // Add small delay to ensure Firestore has propagated
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadAvailableCards();
      }
    } on FirebaseFunctionsException catch (e) {
      print('[RfidCardManagement] FirebaseFunctionsException: ${e.code} - ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message ?? e.code}'),
            backgroundColor: _accentRed,
          ),
        );
      }
    } catch (e) {
      print('[RfidCardManagement] Error deactivating card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deactivating card: $e'),
            backgroundColor: _accentRed,
          ),
        );
      }
    }
  }

  RfidCard? _getCardByType(RfidCardType type) {
    try {
      return _staffCards.firstWhere(
        (card) => card.cardType == type && card.isActive,
      );
    } catch (e) {
      try {
        return _staffCards.firstWhere(
          (card) => card.cardType == type,
        );
      } catch (e) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;
    final isMobile = screenWidth <= 600;

    return Scaffold(
      backgroundColor: _bgDark,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 28 : isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isMobile),
            SizedBox(height: isDesktop ? 24 : 16),
            _buildStaffSelector(isMobile),
            if (_isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 40 : 30),
                  child: CircularProgressIndicator(color: _accentGreen),
                ),
              )
            else if (_selectedStaff != null) ...[
              SizedBox(height: isDesktop ? 24 : 16),
              _buildStaffInfoCard(isMobile),
              SizedBox(height: isDesktop ? 24 : 16),
              _buildCardAssignmentSection(isMobile),
              SizedBox(height: isDesktop ? 24 : 16),
              _buildCardHistoryTable(isMobile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 8 : 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.nfc_rounded,
              color: Colors.white, size: isMobile ? 24 : 28),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RFID Card Management',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                'Assign and manage RFID cards for staff members',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 13,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildStaffSelector(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.person_search_rounded,
                color: _accentGreen, size: isMobile ? 18 : 20),
            SizedBox(width: isMobile ? 8 : 12),
            Text('Select Staff Member',
                style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16)),
          ]),
          SizedBox(height: isMobile ? 12 : 16),
          DropdownButtonFormField<String>(
            value: _selectedStaffId,
            decoration: InputDecoration(
              hintText: 'Choose staff member',
              hintStyle: TextStyle(color: _textSecondary),
              filled: true,
              fillColor: _bgDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _borderColor),
              ),
            ),
            dropdownColor: _cardDark,
            style: TextStyle(color: _textPrimary),
            items: _staffList.map((staff) {
              return DropdownMenuItem<String>(
                value: staff['id']?.toString(),
                child: Text(
                  '${staff['name'] ?? ''} - ${staff['employeeId'] ?? staff['id'] ?? ''}',
                  style: TextStyle(color: _textPrimary),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                final staff = _staffList.firstWhere(
                  (s) => s['id']?.toString() == value,
                  orElse: () => {},
                );
                setState(() {
                  _selectedStaffId = value;
                  _selectedStaff = staff;
                });
                _loadStaffCards(value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStaffInfoCard(bool isMobile) {
    final staff = _selectedStaff!;
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.badge_rounded,
                color: _accentBlue, size: isMobile ? 18 : 20),
            SizedBox(width: isMobile ? 8 : 12),
            Text('Staff Information',
                style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16)),
          ]),
          SizedBox(height: isMobile ? 12 : 16),
          _infoRow('Name', (staff['name'] as String?) ?? 'N/A', isMobile),
          _infoRow('Employee ID', (staff['employeeId'] as String?) ?? 'N/A', isMobile),
          _infoRow('Role', (staff['role'] as String?) ?? 'N/A', isMobile),
          _infoRow('Department', (staff['department'] as String?) ?? 'N/A', isMobile),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 8 : 10),
      child: Row(
        children: [
          SizedBox(
            width: isMobile ? 100 : 120,
            child: Text(label,
                style: TextStyle(color: _textSecondary, fontSize: isMobile ? 12 : 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: _textPrimary, fontSize: isMobile ? 12 : 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardAssignmentSection(bool isMobile) {
    final primaryCard = _getCardByType(RfidCardType.primary);
    final backupCard = _getCardByType(RfidCardType.backup);

    return Column(
      children: [
        _buildCardAssignmentCard(
          'Primary Card',
          Icons.credit_card_rounded,
          primaryCard,
          _primaryUuidController,
          RfidCardType.primary,
          isMobile,
        ),
        SizedBox(height: 16),
        _buildCardAssignmentCard(
          'Backup Card',
          Icons.credit_card_outlined,
          backupCard,
          _backupUuidController,
          RfidCardType.backup,
          isMobile,
        ),
      ],
    );
  }

  Widget _buildCardAssignmentCard(
    String title,
    IconData icon,
    RfidCard? card,
    TextEditingController controller,
    RfidCardType cardType,
    bool isMobile,
  ) {
    final isAssigned = card != null && card.isActive && card.uuid.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAssigned ? _accentGreen : _borderColor,
          width: isAssigned ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: isAssigned ? _accentGreen : _accentBlue, size: isMobile ? 18 : 20),
            SizedBox(width: isMobile ? 8 : 12),
            Text(title,
                style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16)),
            if (isAssigned) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Active',
                    style: TextStyle(color: _accentGreen, fontSize: isMobile ? 10 : 11)),
              ),
            ],
          ]),
          SizedBox(height: isMobile ? 12 : 16),
          if (isAssigned) ...[
            _infoRow('UUID', card.uuid, isMobile),
            _infoRow('Assigned Date',
                DateFormat('dd/MM/yyyy').format(card.assignedAt), isMobile),
            if (card.lastUsedAt != null)
              _infoRow('Last Used',
                  DateFormat('dd/MM/yyyy').format(card.lastUsedAt!), isMobile),
            SizedBox(height: isMobile ? 12 : 16),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.block_rounded, size: isMobile ? 16 : 18),
                  label: Text('Deactivate Card',
                      style: TextStyle(fontSize: isMobile ? 12 : 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _deactivateCard(card.id),
                ),
              ),
            ]),
          ] else ...[
            // Show available cards count
            if (_availableCards.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: isMobile ? 8 : 12),
                child: Text(
                  '${_availableCards.length} available card(s)',
                  style: TextStyle(
                    color: _accentGreen,
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            
            // Dropdown to select from available cards
            if (_availableCards.isNotEmpty)
              DropdownButtonFormField<String>(
                value: cardType == RfidCardType.primary
                    ? _selectedPrimaryCardUuid
                    : _selectedBackupCardUuid,
                decoration: InputDecoration(
                  hintText: 'Select Available Card',
                  hintStyle: TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  prefixIcon: Icon(Icons.credit_card, color: _accentBlue, size: 20),
                ),
                dropdownColor: _cardDark,
                style: TextStyle(color: _textPrimary, fontSize: isMobile ? 12 : 14),
                items: _availableCards.map((card) {
                  // Safely truncate UUID and ID
                  final uuidDisplay = card.uuid.length > 12 
                      ? '${card.uuid.substring(0, 12)}...' 
                      : card.uuid;
                  final idDisplay = card.id.length > 8 
                      ? card.id.substring(0, 8) 
                      : card.id;
                  
                  return DropdownMenuItem<String>(
                    value: card.uuid,
                    child: Text(
                      '$uuidDisplay (ID: $idDisplay)',
                      style: TextStyle(fontSize: isMobile ? 11 : 13),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    if (cardType == RfidCardType.primary) {
                      _selectedPrimaryCardUuid = value;
                    } else {
                      _selectedBackupCardUuid = value;
                    }
                  });
                },
              )
            else
              // Fallback to manual entry if no available cards
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Enter RFID Card UUID (No available cards)',
                  hintStyle: TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  prefixIcon: Icon(Icons.edit, color: _textSecondary, size: 20),
                ),
                style: TextStyle(color: _textPrimary),
              ),
            SizedBox(height: isMobile ? 12 : 16),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.add_rounded, size: isMobile ? 16 : 18),
                  label: Text('Assign Card',
                      style: TextStyle(fontSize: isMobile ? 12 : 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isAssigning
                      ? null
                      : () {
                          String? uuidToAssign;
                          
                          if (_availableCards.isNotEmpty) {
                            // Use selected card from dropdown
                            uuidToAssign = cardType == RfidCardType.primary
                                ? _selectedPrimaryCardUuid
                                : _selectedBackupCardUuid;
                            
                            if (uuidToAssign == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please select a card from the list'),
                                  backgroundColor: _accentRed,
                                ),
                              );
                              return;
                            }
                          } else {
                            // Use manual entry
                            uuidToAssign = controller.text.trim();
                            if (uuidToAssign.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please enter a UUID'),
                                  backgroundColor: _accentRed,
                                ),
                              );
                              return;
                            }
                          }
                          
                          _assignCard(cardType, uuidToAssign);
                          
                          // Clear selections
                          controller.clear();
                          setState(() {
                            if (cardType == RfidCardType.primary) {
                              _selectedPrimaryCardUuid = null;
                            } else {
                              _selectedBackupCardUuid = null;
                            }
                          });
                        },
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildCardHistoryTable(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.history_rounded,
                color: _accentBlue, size: isMobile ? 18 : 20),
            SizedBox(width: isMobile ? 8 : 12),
            Text('Card History',
                style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16)),
          ]),
          SizedBox(height: isMobile ? 12 : 16),
          if (_staffCards.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 20 : 30),
                child: Column(
                  children: [
                    Icon(Icons.credit_card_off_rounded,
                        color: _textSecondary.withOpacity(0.5),
                        size: isMobile ? 48 : 64),
                    SizedBox(height: isMobile ? 12 : 16),
                    Text('No cards assigned',
                        style: TextStyle(
                            color: _textSecondary,
                            fontSize: isMobile ? 14 : 16)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _staffCards.length,
              separatorBuilder: (_, __) => Divider(color: _borderColor, height: 1),
              itemBuilder: (ctx, index) {
                final card = _staffCards[index];
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(card.uuid,
                                style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: isMobile ? 12 : 13,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text('${card.cardType.displayName} • ${card.isActive ? 'Active' : 'Inactive'}',
                                style: TextStyle(
                                    color: card.isActive ? _accentGreen : _textSecondary,
                                    fontSize: isMobile ? 11 : 12)),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(card.assignedAt),
                        style: TextStyle(
                            color: _textSecondary, fontSize: isMobile ? 11 : 12),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
