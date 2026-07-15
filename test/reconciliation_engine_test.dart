import 'package:flutter_test/flutter_test.dart';
import 'package:matching/models/transaction_record.dart';
import 'package:matching/services/reconciliation_engine.dart';

TransactionRecord record({
  required String id,
  required String date,
  required double amount,
  String? document,
}) {
  return TransactionRecord(
    id: id,
    date: DateTime.parse(date),
    amount: amount,
    documentNumber: document,
  );
}

void main() {
  const engine = ReconciliationEngine();

  test('يطابق رقم المستند والمبلغ حتى مع اختلاف التاريخ', () {
    final result = engine.reconcile(
      left: [record(id: 'L1', date: '2026-01-01', amount: 100, document: 'A-10')],
      right: [record(id: 'R1', date: '2026-01-08', amount: 100, document: 'A10')],
    );

    expect(result.matchedCount, 1);
    expect(result.unmatchedCount, 0);
  });

  test('يظهر نفس رقم المستند مع مبلغ مختلف كغير متطابق واضح', () {
    final result = engine.reconcile(
      left: [record(id: 'L1', date: '2026-01-01', amount: 100, document: 'A10')],
      right: [record(id: 'R1', date: '2026-01-01', amount: 120, document: 'A-10')],
    );

    expect(result.matchedCount, 0);
    expect(result.unmatchedCount, 1);
    expect(result.pairs.single.right?.id, 'R1');
    expect(result.pairs.single.reason, contains('المبلغ مختلف'));
  });

  test('لا يطابق عند اختلاف رقم المستند الموجود في الطرفين', () {
    final result = engine.reconcile(
      left: [record(id: 'L1', date: '2026-01-01', amount: 100, document: 'A10')],
      right: [record(id: 'R1', date: '2026-01-01', amount: 100, document: 'B10')],
    );

    expect(result.matchedCount, 0);
    expect(result.unmatchedCount, 2);
  });

  test('يطابق بالمبلغ والتاريخ عند غياب رقم المستند', () {
    final result = engine.reconcile(
      left: [record(id: 'L1', date: '2026-01-01', amount: 250)],
      right: [record(id: 'R1', date: '2026-01-03', amount: 250)],
      settings: const ReconciliationSettings(allowedDateDifferenceDays: 3),
    );

    expect(result.matchedCount, 1);
  });

  test('يرفض المطابقة عندما يتجاوز فرق التاريخ الحد المسموح', () {
    final result = engine.reconcile(
      left: [record(id: 'L1', date: '2026-01-01', amount: 250)],
      right: [record(id: 'R1', date: '2026-01-05', amount: 250)],
      settings: const ReconciliationSettings(allowedDateDifferenceDays: 3),
    );

    expect(result.matchedCount, 0);
    expect(result.unmatchedCount, 2);
  });

  test('لا يستخدم العملية المقابلة أكثر من مرة', () {
    final result = engine.reconcile(
      left: [
        record(id: 'L1', date: '2026-01-01', amount: 100),
        record(id: 'L2', date: '2026-01-01', amount: 100),
      ],
      right: [record(id: 'R1', date: '2026-01-01', amount: 100)],
    );

    expect(result.matchedCount, 1);
    expect(result.unmatchedCount, 1);
  });

  test('يطابق القيم الواقعة على جانبي حدود فهرس المبلغ', () {
    final result = engine.reconcile(
      left: [record(id: 'L1', date: '2026-01-01', amount: 100.0009)],
      right: [record(id: 'R1', date: '2026-01-01', amount: 100.0011)],
      settings: const ReconciliationSettings(amountTolerance: 0.001),
    );

    expect(result.matchedCount, 1);
    expect(result.unmatchedCount, 0);
  });

  test('يرفض سماحية مبلغ غير موجبة', () {
    expect(
      () => engine.reconcile(
        left: const [],
        right: const [],
        settings: const ReconciliationSettings(amountTolerance: 0),
      ),
      throwsArgumentError,
    );
  });
}
