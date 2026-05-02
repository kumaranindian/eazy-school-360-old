import 'package:cloud_firestore/cloud_firestore.dart';

/// Catalog of fee categories (buckets) that a school uses to organise its
/// fees. There are four built‑in categories that map to the legacy payment
/// flow (ADMISSION, TUITION, EXAM, VAN). Schools can also add custom
/// categories such as "SPORTS", "LIBRARY", "LAB" and assign them to one
/// or more classes. Every term in [FeeStructureV2] can reference one of
/// these categories via [FeeTerm.category]; the FeeCollectionScreen then
/// dynamically renders an input field per category that is relevant to the
/// student's class.
class FeeCategory {
  /// Stable identifier used both as the document id and as the key inside
  /// [FeePayment.customCategoryAmounts] for non‑standard categories.
  ///
  /// Standard categories use the reserved codes:
  ///   - `ADMISSION`
  ///   - `TUITION`
  ///   - `EXAM`
  ///   - `VAN`
  ///
  /// Custom categories should use UPPER_SNAKE_CASE (e.g. `SPORTS_FEE`).
  final String code;

  /// Human readable label, e.g. "Sports Fee".
  final String name;

  /// Optional description shown in the admin UI.
  final String description;

  /// Whether this is one of the four reserved standard categories. Standard
  /// categories cannot be deleted and always map to the matching field on
  /// [FeePayment]. Custom categories are stored under
  /// [FeePayment.customCategoryAmounts].
  final bool isStandard;

  /// Disable a category without deleting it. Inactive categories are hidden
  /// from new fee structures and the payment screen but historical payments
  /// keep their existing references.
  final bool isActive;

  /// Restricts the category to a specific subset of classes. An empty list
  /// means the category is available to *all* classes.
  final List<String> applicableClassIds;

  /// Display order for the admin UI and the payment screen (lower first).
  final int sortOrder;

  /// Default amount for this fee category. Used as a suggested amount when
  /// creating fee structures. Can be overridden per term.
  final double defaultAmount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FeeCategory({
    required this.code,
    required this.name,
    this.description = '',
    this.isStandard = false,
    this.isActive = true,
    this.applicableClassIds = const [],
    this.sortOrder = 100,
    this.defaultAmount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// The four standard categories every school starts with. These are
  /// inserted automatically the first time the categories collection is
  /// read so the UI is never empty.
  static const List<FeeCategory> defaults = [
    FeeCategory(
      code: 'ADMISSION',
      name: 'Admission Fee',
      isStandard: true,
      sortOrder: 10,
    ),
    FeeCategory(
      code: 'TUITION',
      name: 'Tuition Fee',
      isStandard: true,
      sortOrder: 20,
    ),
    FeeCategory(
      code: 'EXAM',
      name: 'Exam Fee',
      isStandard: true,
      sortOrder: 30,
    ),
    FeeCategory(
      code: 'VAN',
      name: 'Van Fee',
      isStandard: true,
      sortOrder: 40,
    ),
  ];

  /// Whether the category is applicable to the given [className]. A
  /// category is applicable when its allow‑list is empty (= all classes)
  /// or contains the class explicitly.
  bool appliesTo(String className) =>
      applicableClassIds.isEmpty || applicableClassIds.contains(className);

  /// The Firestore field name on [FeePayment] for the four standard
  /// categories. Returns `null` for custom categories — those are stored
  /// inside the `customCategoryAmounts` map.
  String? get standardPaymentField {
    switch (code) {
      case 'ADMISSION':
        return 'admissionFeePaid';
      case 'TUITION':
        return 'tuitionFeePaid';
      case 'EXAM':
        return 'examFeePaid';
      case 'VAN':
        return 'vanFeePaid';
      default:
        return null;
    }
  }

  factory FeeCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeeCategory.fromMap(doc.id, data);
  }

  factory FeeCategory.fromMap(String code, Map<String, dynamic> data) {
    return FeeCategory(
      code: code,
      name: data['name']?.toString() ?? code,
      description: data['description']?.toString() ?? '',
      isStandard: data['isStandard'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      applicableClassIds: (data['applicableClassIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 100,
      defaultAmount: (data['defaultAmount'] as num?)?.toDouble() ?? 0,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
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
        'name': name,
        'description': description,
        'isStandard': isStandard,
        'isActive': isActive,
        'applicableClassIds': applicableClassIds,
        'sortOrder': sortOrder,
        'defaultAmount': defaultAmount,
      };

  FeeCategory copyWith({
    String? code,
    String? name,
    String? description,
    bool? isStandard,
    bool? isActive,
    List<String>? applicableClassIds,
    int? sortOrder,
    double? defaultAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      FeeCategory(
        code: code ?? this.code,
        name: name ?? this.name,
        description: description ?? this.description,
        isStandard: isStandard ?? this.isStandard,
        isActive: isActive ?? this.isActive,
        applicableClassIds: applicableClassIds ?? this.applicableClassIds,
        sortOrder: sortOrder ?? this.sortOrder,
        defaultAmount: defaultAmount ?? this.defaultAmount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
