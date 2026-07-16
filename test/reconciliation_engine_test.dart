import 'package:flutter_test/flutter_test.dart';
import 'package:matching/models/transaction_record.dart';
import 'package:matching/services/reconciliation_engine.dart';

TransactionRecord tx(
  String id,
  String date,
  double amount, {
  String? doc,
  EntrySide side = EntrySide.unknown,
}) =>
    TransactionRecord(
      id: id,
      date: DateTime.parse(date),
      amount: amount,
      documentNumber: doc,
      side: side,
    );

void main() {
  const engine = ReconciliationEngine();

  test('يطابق رقم المستند والمبلغ رغم فرق التاريخ', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100, doc: 'INV-1')],
      right: [tx('r', '2026-01-03', 100, doc: 'INV1')],
      settings: const ReconciliationSettings(allowedDateDifferenceDays: 3),
    );
    expect(result.matchedCount, 1);
  });

  test('يرفض نفس رقم المستند عند اختلاف المبلغ', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100, doc: 'A1')],
      right: [tx('r', '2026-01-01', 120, doc: 'A1')],
      settings: const ReconciliationSettings(),
    );
    expect(result.matchedCount, 0);
  });

  test('يطابق بالمبلغ والتاريخ عند غياب المستند', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100)],
      right: [tx('r', '2026-01-02', 100)],
      settings: const ReconciliationSettings(allowedDateDifferenceDays: 2),
    );
    expect(result.matchedCount, 1);
  });

  test('لا يستخدم العملية المقابلة مرتين', () {
    final result = engine.reconcile(
      left: [
        tx('l1', '2026-01-01', 100),
        tx('l2', '2026-01-01', 100),
      ],
      right: [tx('r', '2026-01-01', 100)],
      settings: const ReconciliationSettings(),
    );
    expect(result.matchedCount, 1);
    expect(result.unmatchedCount, 1);
  });

  test('لا يطابق العملية نفسها عند رفع الملف ذاته مرتين', () {
    final record = tx(
      'same-file.xlsx-2',
      '2026-01-01',
      100,
      doc: 'INV-1',
      side: EntrySide.debit,
    );
    final result = engine.reconcile(
      left: [record],
      right: [record],
      settings: const ReconciliationSettings(),
    );
    expect(result.matchedCount, 0);
    expect(result.unmatchedCount, 2);
  });

  test('يرفض مدين مقابل مدين ويقبل مدين مقابل دائن', () {
    final sameSide = engine.reconcile(
      left: [
        tx('left', '2026-01-01', 100, doc: 'INV-1', side: EntrySide.debit),
      ],
      right: [
        tx('right', '2026-01-01', 100, doc: 'INV-1', side: EntrySide.debit),
      ],
      settings: const ReconciliationSettings(),
    );
    expect(sameSide.matchedCount, 0);

    final oppositeSides = engine.reconcile(
      left: [
        tx('left', '2026-01-01', 100, doc: 'INV-1', side: EntrySide.debit),
      ],
      right: [
        tx('right', '2026-01-01', 100, doc: 'INV-1', side: EntrySide.credit),
      ],
      settings: const ReconciliationSettings(),
    );
    expect(oppositeSides.matchedCount, 1);
  });
}
