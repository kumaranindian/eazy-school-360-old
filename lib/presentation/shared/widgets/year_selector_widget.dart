import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/academic_year_repository.dart';
import '../../../domain/entities/academic_year.dart';
import 'searchable_dropdown.dart';

/// Reusable widget for selecting academic or fiscal year
class YearSelectorWidget extends ConsumerWidget {
  final String schoolId;
  final String? selectedYearCode;
  final void Function(String?) onYearChanged;
  final YearType yearType;
  final String? label;
  final bool showLabel;

  const YearSelectorWidget({
    super.key,
    required this.schoolId,
    required this.selectedYearCode,
    required this.onYearChanged,
    this.yearType = YearType.academic,
    this.label,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearsAsync = yearType == YearType.academic
        ? ref.watch(schoolAcademicYearsProvider(schoolId))
        : ref.watch(schoolFiscalYearsProvider(schoolId));

    return yearsAsync.when(
      loading: () => const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('Error loading years: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
      data: (years) {
        if (years.isEmpty) {
          return Text(
            'No ${yearType.name} years found. Please initialize years.',
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          );
        }

        final yearCodes = years.map((y) => yearType == YearType.academic 
            ? (y as AcademicYear).yearCode 
            : (y as FiscalYear).yearCode).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLabel && label != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  label!,
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            SearchableDropdown<String>(
              value: selectedYearCode,
              items: yearCodes,
              itemLabel: (code) => '${yearType == YearType.academic ? "Academic" : "Fiscal"} Year $code',
              onChanged: onYearChanged,
              hint: 'Select ${yearType == YearType.academic ? "Academic" : "Fiscal"} Year',
            ),
          ],
        );
      },
    );
  }
}

enum YearType { academic, fiscal }

/// Compact year selector for toolbar/header use
class CompactYearSelector extends ConsumerWidget {
  final String schoolId;
  final String? selectedYearCode;
  final void Function(String?) onYearChanged;
  final YearType yearType;

  const CompactYearSelector({
    super.key,
    required this.schoolId,
    required this.selectedYearCode,
    required this.onYearChanged,
    this.yearType = YearType.academic,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearsAsync = yearType == YearType.academic
        ? ref.watch(schoolAcademicYearsProvider(schoolId))
        : ref.watch(schoolFiscalYearsProvider(schoolId));

    return yearsAsync.when(
      loading: () => const SizedBox(width: 120, height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => const SizedBox.shrink(),
      data: (years) {
        if (years.isEmpty) return const SizedBox.shrink();

        final yearCodes = years.map((y) => yearType == YearType.academic 
            ? (y as AcademicYear).yearCode 
            : (y as FiscalYear).yearCode).toList();

        return Container(
          constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
          height: 36,
          child: SearchableDropdown<String>(
            value: selectedYearCode,
            items: yearCodes,
            itemLabel: (code) => code,
            onChanged: onYearChanged,
            hint: yearType == YearType.academic ? 'AY' : 'FY',
          ),
        );
      },
    );
  }
}
