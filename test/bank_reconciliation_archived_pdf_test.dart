import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:matching/models/bank_reconciliation.dart';
import 'package:matching/services/bank_reconciliation_pdf_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates PDF from archived reconciliation without matching result', () async {
    final original = BankReconciliationStatement(
      accountName: 'الحساب البنكي',
      period: DateTime(2026, 7),
      bookBalance: 48088325.92,
      bankBalance: 40277467.62,
      items: const [],
      bookSourceName: 'دفاتر الشركة',
      bankSourceName: 'كشف البنك',
      matchingResult: null,
    );
    final archived = BankReconciliationStatement.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(original.toJson())) as Map,
      ),
    );

    expect(archived.matchingResult, isNull);
    final bytes = await const BankReconciliationPdfBuilder().build(
      companyName: 'دفاتر الشركة',
      bankName: 'الحساب البنكي',
      statement: archived,
    );

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
