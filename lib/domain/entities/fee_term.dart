import 'package:cloud_firestore/cloud_firestore.dart';

enum LateFeeType { FIXED, PERCENTAGE, DAILY }

class LateFeeRule {
  final bool enabled;
  final LateFeeType type;
  final double amount;
  final int graceDays;
  final double? maxLateFee;

  const LateFeeRule({
    this.enabled = false,
    this.type = LateFeeType.FIXED,
    this.amount = 0,
    this.graceDays = 0,
    this.maxLateFee,
  });

  factory LateFeeRule.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const LateFeeRule();
    return LateFeeRule(
      enabled: data['enabled'] as bool? ?? false,
      type: _parseType(data['type']),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      graceDays: (data['graceDays'] as num?)?.toInt() ?? 0,
      maxLateFee: (data['maxLateFee'] as num?)?.toDouble(),
    );
  }

  static LateFeeType _parseType(dynamic v) {
    final s = v?.toString().toUpperCase() ?? 'FIXED';
    return LateFeeType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => LateFeeType.FIXED,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'type': type.name,
        'amount': amount,
        'graceDays': graceDays,
        if (maxLateFee != null) 'maxLateFee': maxLateFee,
      };

  LateFeeRule copyWith({
    bool? enabled,
    LateFeeType? type,
    double? amount,
    int? graceDays,
    double? maxLateFee,
  }) =>
      LateFeeRule(
        enabled: enabled ?? this.enabled,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        graceDays: graceDays ?? this.graceDays,
        maxLateFee: maxLateFee ?? this.maxLateFee,
      );
}

class ReminderConfig {
  final bool enabled;
  final List<int> beforeDueDays;
  final bool onDueDate;
  final List<int> afterDueDays;
  final List<String> channels; // WHATSAPP, SMS, EMAIL

  const ReminderConfig({
    this.enabled = true,
    this.beforeDueDays = const [7, 3, 1],
    this.onDueDate = true,
    this.afterDueDays = const [1, 3, 7, 15],
    this.channels = const ['WHATSAPP'],
  });

  factory ReminderConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const ReminderConfig();
    return ReminderConfig(
      enabled: data['enabled'] as bool? ?? true,
      beforeDueDays: (data['beforeDueDays'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [7, 3, 1],
      onDueDate: data['onDueDate'] as bool? ?? true,
      afterDueDays: (data['afterDueDays'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 3, 7, 15],
      channels: (data['channels'] as List?)?.map((e) => e.toString()).toList() ?? const ['WHATSAPP'],
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'beforeDueDays': beforeDueDays,
        'onDueDate': onDueDate,
        'afterDueDays': afterDueDays,
        'channels': channels,
      };

  ReminderConfig copyWith({
    bool? enabled,
    List<int>? beforeDueDays,
    bool? onDueDate,
    List<int>? afterDueDays,
    List<String>? channels,
  }) =>
      ReminderConfig(
        enabled: enabled ?? this.enabled,
        beforeDueDays: beforeDueDays ?? this.beforeDueDays,
        onDueDate: onDueDate ?? this.onDueDate,
        afterDueDays: afterDueDays ?? this.afterDueDays,
        channels: channels ?? this.channels,
      );
}

class FeeComponent {
  final String name;
  final double amount;

  const FeeComponent({required this.name, required this.amount});

  factory FeeComponent.fromMap(Map<String, dynamic> data) => FeeComponent(
        name: data['name']?.toString() ?? '',
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount};
}

class FeeTerm {
  final String id;
  final String termName;
  final int sequence;
  final double amount;
  final DateTime dueDate;
  final LateFeeRule lateFee;
  final ReminderConfig reminderConfig;
  final List<FeeComponent> components;

  /// Fee category code (e.g. 'TUITION', 'EXAM', 'VAN', 'ADMISSION', or any
  /// custom category like 'SPORTS_FEE'). Used by the payment flow to decide
  /// which input bucket this term contributes to. Defaults to 'TUITION' so
  /// that legacy terms saved before this field existed keep working.
  final String category;

  const FeeTerm({
    required this.id,
    required this.termName,
    required this.sequence,
    required this.amount,
    required this.dueDate,
    this.lateFee = const LateFeeRule(),
    this.reminderConfig = const ReminderConfig(),
    this.components = const [],
    this.category = 'TUITION',
  });

  factory FeeTerm.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeeTerm.fromMap(doc.id, data);
  }

  factory FeeTerm.fromMap(String id, Map<String, dynamic> data) {
    return FeeTerm(
      id: id,
      termName: data['termName']?.toString() ?? '',
      sequence: (data['sequence'] as num?)?.toInt() ?? 0,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      dueDate: _parseDate(data['dueDate']) ?? DateTime.now(),
      lateFee: LateFeeRule.fromMap(data['lateFee'] as Map<String, dynamic>?),
      reminderConfig: ReminderConfig.fromMap(data['reminderConfig'] as Map<String, dynamic>?),
      components: ((data['components'] as List?) ?? [])
          .map((e) => FeeComponent.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      category: (data['category']?.toString().toUpperCase().trim().isNotEmpty ?? false)
          ? data['category'].toString().toUpperCase().trim()
          : 'TUITION',
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Map<String, dynamic> toFirestore() => {
        'termName': termName,
        'sequence': sequence,
        'amount': amount,
        'dueDate': Timestamp.fromDate(dueDate),
        'lateFee': lateFee.toMap(),
        'reminderConfig': reminderConfig.toMap(),
        'components': components.map((c) => c.toMap()).toList(),
        'category': category,
      };

  FeeTerm copyWith({
    String? id,
    String? termName,
    int? sequence,
    double? amount,
    DateTime? dueDate,
    LateFeeRule? lateFee,
    ReminderConfig? reminderConfig,
    List<FeeComponent>? components,
    String? category,
  }) =>
      FeeTerm(
        id: id ?? this.id,
        termName: termName ?? this.termName,
        sequence: sequence ?? this.sequence,
        amount: amount ?? this.amount,
        dueDate: dueDate ?? this.dueDate,
        lateFee: lateFee ?? this.lateFee,
        reminderConfig: reminderConfig ?? this.reminderConfig,
        components: components ?? this.components,
        category: category ?? this.category,
      );
}
