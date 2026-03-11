/// Unit tests for the two-screen fee payment flow and template download logic.
library;

import 'package:flutter_test/flutter_test.dart';

// ── Helpers mirroring production logic ────────────────────────────────────────

double balanceForType(Map<String, dynamic> d, String type) {
  switch (type) {
    case 'Admission Fee':        return (d['stuBalAdmissionFees'] as num?)?.toDouble() ?? 0;
    case 'Exam Fee':             return (d['stuBalExamFees'] as num?)?.toDouble() ?? 0;
    case 'Tution Fee':           return (d['stuBalTutionFees'] as num?)?.toDouble() ?? 0;
    case 'Van Fee':              return (d['stuBalVanFees'] as num?)?.toDouble() ?? 0;
    case 'Arrear Admission Fee': return (d['balanceArrearAdmissionFees'] as num?)?.toDouble() ?? 0;
    case 'Arrear Exam Fee':      return (d['balanceArrearExamFees'] as num?)?.toDouble() ?? 0;
    case 'Arrear Tution Fee':    return (d['balanceArrearTuitionFees'] as num?)?.toDouble() ?? 0;
    case 'Arrear Van Fee':       return (d['balanceArrearVanFees'] as num?)?.toDouble() ?? 0;
    default: return 0;
  }
}

String? validateAmount(String input, double balance) {
  final amount = double.tryParse(input.trim());
  if (amount == null || amount <= 0) return 'Enter a valid payment amount';
  if (amount > balance) return 'Amount exceeds balance due';
  return null;
}

Map<String, double> buildUpdateMap(Map<String, dynamic> d, String feeType, double amount) {
  double n(String k) => (d[k] as num?)?.toDouble() ?? 0;
  final upd = <String, double>{};
  switch (feeType) {
    case 'Admission Fee':
      upd['stuPaidAdmissionFees'] = n('stuPaidAdmissionFees') + amount;
      upd['stuBalAdmissionFees']  = n('stuBalAdmissionFees')  - amount;
      break;
    case 'Exam Fee':
      upd['stuPaidExamFees'] = n('stuPaidExamFees') + amount;
      upd['stuBalExamFees']  = n('stuBalExamFees')  - amount;
      break;
    case 'Tution Fee':
      upd['stuPaidTutionFees'] = n('stuPaidTutionFees') + amount;
      upd['stuBalTutionFees']  = n('stuBalTutionFees')  - amount;
      break;
    case 'Van Fee':
      upd['studPaidVanFees'] = n('studPaidVanFees') + amount;
      upd['stuBalVanFees']   = n('stuBalVanFees')   - amount;
      break;
    case 'Arrear Admission Fee':
      upd['stuPaidArrearAdmissionFees'] = n('stuPaidArrearAdmissionFees') + amount;
      upd['balanceArrearAdmissionFees'] = n('balanceArrearAdmissionFees') - amount;
      break;
    case 'Arrear Exam Fee':
      upd['stuPaidArrearExamFees'] = n('stuPaidArrearExamFees') + amount;
      upd['balanceArrearExamFees'] = n('balanceArrearExamFees') - amount;
      break;
    case 'Arrear Tution Fee':
      upd['stuPaidArrearTutionFees']  = n('stuPaidArrearTutionFees') + amount;
      upd['balanceArrearTuitionFees'] = n('balanceArrearTuitionFees') - amount;
      break;
    case 'Arrear Van Fee':
      upd['stuPaidArrearVanFees'] = n('stuPaidArrearVanFees') + amount;
      upd['balanceArrearVanFees'] = n('balanceArrearVanFees') - amount;
      break;
  }
  upd['stuPaidTotalFees'] = n('stuPaidTotalFees') + amount;
  upd['stuBalTotalFees']  = n('stuBalTotalFees')  - amount;
  return upd;
}

Map<String, double> computeDerivedFields({
  required double classTuitionFees, required double classExamFees,
  required double stuPendingFees,   required double stuConcessionFees,
  required double stuTotalVanFees,  required double stuPaidTutionFees,
  required double stuPaidExamFees,  required double studPaidVanFees,
  required double stuPaidTotalFees,
}) {
  final stuTotalTutionFees = classTuitionFees;
  final stuTotalExamFees   = classExamFees;
  final stuTotalFees       = stuTotalTutionFees + stuTotalExamFees + stuTotalVanFees;
  final stuBalTutionFees   = stuTotalTutionFees + stuPendingFees - stuConcessionFees - stuPaidTutionFees;
  final stuBalExamFees     = stuTotalExamFees - stuPaidExamFees;
  final stuBalVanFees      = stuTotalVanFees - studPaidVanFees;
  final stuBalTotalFees    = (stuTotalTutionFees + stuTotalExamFees + stuTotalVanFees + stuPendingFees)
                              - stuConcessionFees - stuPaidTotalFees;
  return {
    'stuTotalTutionFees': stuTotalTutionFees, 'stuTotalExamFees': stuTotalExamFees,
    'stuTotalFees': stuTotalFees, 'stuBalTutionFees': stuBalTutionFees,
    'stuBalExamFees': stuBalExamFees, 'stuBalVanFees': stuBalVanFees,
    'stuBalTotalFees': stuBalTotalFees,
  };
}

int nextBillId(bool isEmpty, int lastId) => isEmpty ? 1 : lastId + 1;

// ── Test data ─────────────────────────────────────────────────────────────────

final _studentData = {
  'stuBalAdmissionFees': 1000.0, 'stuBalExamFees': 600.0,
  'stuBalTutionFees': 5000.0,    'stuBalVanFees': 1200.0,
  'balanceArrearAdmissionFees': 500.0, 'balanceArrearExamFees': 300.0,
  'balanceArrearTuitionFees': 4000.0,  'balanceArrearVanFees': 800.0,
};

final _basePayData = {
  'stuPaidTutionFees': 2000.0,  'stuBalTutionFees': 5000.0,
  'stuPaidExamFees': 0.0,       'stuBalExamFees': 600.0,
  'stuPaidAdmissionFees': 0.0,  'stuBalAdmissionFees': 1000.0,
  'studPaidVanFees': 0.0,       'stuBalVanFees': 1200.0,
  'stuPaidArrearTutionFees': 0.0,  'balanceArrearTuitionFees': 4000.0,
  'stuPaidArrearExamFees': 0.0,    'balanceArrearExamFees': 300.0,
  'stuPaidArrearAdmissionFees': 0.0, 'balanceArrearAdmissionFees': 500.0,
  'stuPaidArrearVanFees': 0.0,   'balanceArrearVanFees': 800.0,
  'stuPaidTotalFees': 2000.0,    'stuBalTotalFees': 7800.0,
};

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Balance lookup per fee type', () {
    test('Admission Fee', () => expect(balanceForType(_studentData, 'Admission Fee'), equals(1000.0)));
    test('Exam Fee',      () => expect(balanceForType(_studentData, 'Exam Fee'),      equals(600.0)));
    test('Tution Fee',    () => expect(balanceForType(_studentData, 'Tution Fee'),    equals(5000.0)));
    test('Van Fee',       () => expect(balanceForType(_studentData, 'Van Fee'),       equals(1200.0)));
    test('Arrear Admission Fee', () => expect(balanceForType(_studentData, 'Arrear Admission Fee'), equals(500.0)));
    test('Arrear Exam Fee',      () => expect(balanceForType(_studentData, 'Arrear Exam Fee'),      equals(300.0)));
    test('Arrear Tution Fee',    () => expect(balanceForType(_studentData, 'Arrear Tution Fee'),    equals(4000.0)));
    test('Arrear Van Fee',       () => expect(balanceForType(_studentData, 'Arrear Van Fee'),       equals(800.0)));
    test('unknown type returns 0', () => expect(balanceForType(_studentData, 'Select Fees Type'), equals(0.0)));
    test('missing field returns 0', () => expect(balanceForType({}, 'Tution Fee'), equals(0.0)));
  });

  group('isArrear flag', () {
    bool isArrear(String t) => t.startsWith('Arrear');
    test('regular fees not arrear', () {
      for (final t in ['Admission Fee', 'Exam Fee', 'Tution Fee', 'Van Fee']) {
        expect(isArrear(t), isFalse);
      }
    });
    test('arrear fees flagged correctly', () {
      for (final t in ['Arrear Admission Fee', 'Arrear Exam Fee', 'Arrear Tution Fee', 'Arrear Van Fee']) {
        expect(isArrear(t), isTrue);
      }
    });
  });

  group('Amount validation', () {
    test('empty string invalid',       () => expect(validateAmount('', 1000),     isNotNull));
    test('zero invalid',               () => expect(validateAmount('0', 1000),    isNotNull));
    test('negative invalid',           () => expect(validateAmount('-100', 1000), isNotNull));
    test('exceeds balance invalid',    () => expect(validateAmount('1500', 1000), isNotNull));
    test('equals balance valid',       () => expect(validateAmount('1000', 1000), isNull));
    test('less than balance valid',    () => expect(validateAmount('500', 1000),  isNull));
    test('decimal amount valid',       () => expect(validateAmount('999.99', 1000), isNull));
    test('non-numeric invalid',        () => expect(validateAmount('abc', 1000),  isNotNull));
  });

  group('Payment update map – regular fees', () {
    test('Tution Fee updates paid/balance', () {
      final upd = buildUpdateMap(_basePayData, 'Tution Fee', 1000.0);
      expect(upd['stuPaidTutionFees'], equals(3000.0));
      expect(upd['stuBalTutionFees'],  equals(4000.0));
      expect(upd['stuPaidTotalFees'],  equals(3000.0));
      expect(upd['stuBalTotalFees'],   equals(6800.0));
    });
    test('Exam Fee updates correctly', () {
      final upd = buildUpdateMap(_basePayData, 'Exam Fee', 300.0);
      expect(upd['stuPaidExamFees'], equals(300.0));
      expect(upd['stuBalExamFees'],  equals(300.0));
    });
    test('Admission Fee updates correctly', () {
      final upd = buildUpdateMap(_basePayData, 'Admission Fee', 500.0);
      expect(upd['stuPaidAdmissionFees'], equals(500.0));
      expect(upd['stuBalAdmissionFees'],  equals(500.0));
    });
    test('Van Fee updates correctly', () {
      final upd = buildUpdateMap(_basePayData, 'Van Fee', 600.0);
      expect(upd['studPaidVanFees'], equals(600.0));
      expect(upd['stuBalVanFees'],   equals(600.0));
    });
    test('full payment clears balance to zero', () {
      final upd = buildUpdateMap(_basePayData, 'Exam Fee', 600.0);
      expect(upd['stuBalExamFees'], equals(0.0));
    });
  });

  group('Payment update map – arrear fees', () {
    test('Arrear Tution Fee updates arrear fields', () {
      final upd = buildUpdateMap(_basePayData, 'Arrear Tution Fee', 2000.0);
      expect(upd['stuPaidArrearTutionFees'],  equals(2000.0));
      expect(upd['balanceArrearTuitionFees'], equals(2000.0));
      expect(upd['stuPaidTotalFees'],          equals(4000.0));
    });
    test('Arrear Exam Fee updates arrear fields', () {
      final upd = buildUpdateMap(_basePayData, 'Arrear Exam Fee', 150.0);
      expect(upd['stuPaidArrearExamFees'], equals(150.0));
      expect(upd['balanceArrearExamFees'], equals(150.0));
    });
    test('Arrear Admission Fee updates correctly', () {
      final upd = buildUpdateMap(_basePayData, 'Arrear Admission Fee', 250.0);
      expect(upd['stuPaidArrearAdmissionFees'],  equals(250.0));
      expect(upd['balanceArrearAdmissionFees'],  equals(250.0));
    });
    test('Arrear Van Fee updates correctly', () {
      final upd = buildUpdateMap(_basePayData, 'Arrear Van Fee', 400.0);
      expect(upd['stuPaidArrearVanFees'], equals(400.0));
      expect(upd['balanceArrearVanFees'], equals(400.0));
    });
    test('total paid/balance always updated', () {
      for (final t in ['Tution Fee', 'Exam Fee', 'Arrear Tution Fee', 'Van Fee']) {
        final upd = buildUpdateMap(_basePayData, t, 100.0);
        expect(upd.containsKey('stuPaidTotalFees'), isTrue);
        expect(upd.containsKey('stuBalTotalFees'),  isTrue);
      }
    });
  });

  group('Bill number sequencing', () {
    test('first bill is #1 when empty', () => expect(nextBillId(true, 0), equals(1)));
    test('increments last ID by 1',     () => expect(nextBillId(false, 42), equals(43)));
    test('sequential bills increment',  () {
      int cur = 1;
      for (int i = 0; i < 5; i++) cur = nextBillId(false, cur);
      expect(cur, equals(6));
    });
  });

  group('Template sheet column definitions', () {
    const feeStructureHeaders = ['classInRoman', 'classTutionFees', 'classExamFees'];
    const studentFeeHeaders = [
      'stuId', 'stuName', 'stuClass', 'stuSection',
      'stuPendingFees', 'stuConcessionFees', 'isStuAvailVan', 'stuTotalVanFees',
      'stuPaidTutionFees', 'stuPaidExamFees', 'studPaidVanFees', 'stuPaidTotalFees',
      'phoneNumber', 'stuBillDetails',
    ];

    test('FEE_STRUCTURE has 3 columns',    () => expect(feeStructureHeaders.length, equals(3)));
    test('FEE_STRUCTURE col 0 = classInRoman', () => expect(feeStructureHeaders[0], equals('classInRoman')));
    test('STUDENT_FEE_DETAILS has 14 columns', () => expect(studentFeeHeaders.length, equals(14)));
    test('stuId at col 0',          () => expect(studentFeeHeaders[0], equals('stuId')));
    test('stuPendingFees at col 4', () => expect(studentFeeHeaders[4], equals('stuPendingFees')));
    test('isStuAvailVan at col 6',  () => expect(studentFeeHeaders[6], equals('isStuAvailVan')));
    test('stuPaidTutionFees at col 8', () => expect(studentFeeHeaders[8], equals('stuPaidTutionFees')));
    test('stuPaidTotalFees at col 11', () => expect(studentFeeHeaders[11], equals('stuPaidTotalFees')));
    test('stuBillDetails at col 13',   () => expect(studentFeeHeaders[13], equals('stuBillDetails')));
  });

  group('Derived field computation (upload sheet)', () {
    test('fresh student has full balance', () {
      final r = computeDerivedFields(
        classTuitionFees: 6000, classExamFees: 600,
        stuPendingFees: 0, stuConcessionFees: 0, stuTotalVanFees: 0,
        stuPaidTutionFees: 0, stuPaidExamFees: 0, studPaidVanFees: 0, stuPaidTotalFees: 0,
      );
      expect(r['stuTotalFees'],    equals(6600.0));
      expect(r['stuBalTutionFees'], equals(6000.0));
      expect(r['stuBalTotalFees'],  equals(6600.0));
    });
    test('partial payment reduces balance', () {
      final r = computeDerivedFields(
        classTuitionFees: 6000, classExamFees: 600,
        stuPendingFees: 0, stuConcessionFees: 0, stuTotalVanFees: 0,
        stuPaidTutionFees: 3000, stuPaidExamFees: 300, studPaidVanFees: 0, stuPaidTotalFees: 3300,
      );
      expect(r['stuBalTutionFees'], equals(3000.0));
      expect(r['stuBalTotalFees'],  equals(3300.0));
    });
    test('concession reduces balance', () {
      final r = computeDerivedFields(
        classTuitionFees: 6000, classExamFees: 600,
        stuPendingFees: 0, stuConcessionFees: 1000, stuTotalVanFees: 0,
        stuPaidTutionFees: 0, stuPaidExamFees: 0, studPaidVanFees: 0, stuPaidTotalFees: 0,
      );
      expect(r['stuBalTutionFees'], equals(5000.0));
      expect(r['stuBalTotalFees'],  equals(5600.0));
    });
    test('pending fees add to balance', () {
      final r = computeDerivedFields(
        classTuitionFees: 6000, classExamFees: 600,
        stuPendingFees: 500, stuConcessionFees: 0, stuTotalVanFees: 0,
        stuPaidTutionFees: 0, stuPaidExamFees: 0, studPaidVanFees: 0, stuPaidTotalFees: 0,
      );
      expect(r['stuBalTutionFees'], equals(6500.0));
      expect(r['stuBalTotalFees'],  equals(7100.0));
    });
    test('van fees included in totals', () {
      final r = computeDerivedFields(
        classTuitionFees: 6000, classExamFees: 600,
        stuPendingFees: 0, stuConcessionFees: 0, stuTotalVanFees: 1200,
        stuPaidTutionFees: 0, stuPaidExamFees: 0, studPaidVanFees: 0, stuPaidTotalFees: 0,
      );
      expect(r['stuTotalFees'],    equals(7800.0));
      expect(r['stuBalVanFees'],   equals(1200.0));
    });
    test('fully paid student has zero balance', () {
      final r = computeDerivedFields(
        classTuitionFees: 6000, classExamFees: 600,
        stuPendingFees: 0, stuConcessionFees: 0, stuTotalVanFees: 0,
        stuPaidTutionFees: 6000, stuPaidExamFees: 600, studPaidVanFees: 0, stuPaidTotalFees: 6600,
      );
      expect(r['stuBalTutionFees'], equals(0.0));
      expect(r['stuBalTotalFees'],  equals(0.0));
    });
    test('total = paid + balance (invariant)', () {
      final r = computeDerivedFields(
        classTuitionFees: 6000, classExamFees: 600,
        stuPendingFees: 0, stuConcessionFees: 0, stuTotalVanFees: 0,
        stuPaidTutionFees: 2000, stuPaidExamFees: 200, studPaidVanFees: 0, stuPaidTotalFees: 2200,
      );
      expect(r['stuTotalFees'], equals(6600.0));
      expect(r['stuBalTotalFees'], equals(4400.0));
    });
  });

  group('Fee type list completeness', () {
    const feeTypes = [
      'Select Fees Type',
      'Admission Fee', 'Exam Fee', 'Tution Fee', 'Van Fee',
      'Arrear Admission Fee', 'Arrear Exam Fee', 'Arrear Tution Fee', 'Arrear Van Fee',
    ];
    test('9 entries total', () => expect(feeTypes.length, equals(9)));
    test('4 regular fee types', () {
      final regular = feeTypes.where((t) => !t.startsWith('Arrear') && t != 'Select Fees Type').toList();
      expect(regular.length, equals(4));
    });
    test('4 arrear fee types', () {
      final arrear = feeTypes.where((t) => t.startsWith('Arrear')).toList();
      expect(arrear.length, equals(4));
    });
    test('every regular fee has an arrear counterpart', () {
      final regular = feeTypes.where((t) => !t.startsWith('Arrear') && t != 'Select Fees Type').toList();
      for (final t in regular) {
        expect(feeTypes.contains('Arrear $t'), isTrue, reason: 'Missing Arrear $t');
      }
    });
  });
}
