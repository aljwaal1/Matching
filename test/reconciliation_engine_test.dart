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

  test('يطابق مدين الطرف الأول مع دائن الطرف الثاني', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100, doc: 'INV-1', side: EntrySide.debit)],
      right: [tx('r', '2026-01-02', 100, doc: 'INV1', side: EntrySide.credit)],
      settings: const ReconciliationSettings(mode: ReconciliationMode.parties),
    );
    expect(result.matchedCount, 1);
  });

  test('يرفض مدين مقابل مدين ويعرض السبب الحقيقي', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100, doc: 'A1', side: EntrySide.debit)],
      right: [tx('r', '2026-01-01', 100, doc: 'A1', side: EntrySide.debit)],
      settings: const ReconciliationSettings(mode: ReconciliationMode.parties),
    );
    expect(result.matchedCount, 0);
    expect(result.pairs.single.reason, contains('جهة الحركة'));
  });

  test('يرفض الجهة غير المحددة في مطابقة العملاء والموردين', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100)],
      right: [tx('r', '2026-01-01', 100)],
      settings: const ReconciliationSettings(mode: ReconciliationMode.parties),
    );
    expect(result.matchedCount, 0);
    expect(result.pairs.single.reason, contains('غير محددة'));
  });

  test('يسمح بالمبلغ والتاريخ دون جهة في مطابقة البنك', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100)],
      right: [tx('r', '2026-01-03', 100)],
      settings: const ReconciliationSettings(
        mode: ReconciliationMode.bank,
        allowedDateDifferenceDays: 3,
      ),
    );
    expect(result.matchedCount, 1);
  });

  test('يرفض تطابق رقم المستند إذا تجاوز فرق التاريخ المسموح', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100, doc: 'A1')],
      right: [tx('r', '2026-01-10', 100, doc: 'A1')],
      settings: const ReconciliationSettings(
        mode: ReconciliationMode.bank,
        allowedDateDifferenceDays: 3,
      ),
    );
    expect(result.matchedCount, 0);
    expect(result.pairs.single.reason, contains('فرق التاريخ'));
  });

  test('لا يطابق العملية نفسها حتى عند تغيير اسم الملف لأن الهوية من المحتوى', () {
    final record = tx('fingerprint-2', '2026-01-01', 100, side: EntrySide.debit);
    final result = engine.reconcile(
      left: [record],
      right: [record],
      settings: const ReconciliationSettings(mode: ReconciliationMode.parties),
    );
    expect(result.matchedCount, 0);
  });

  test('يعلق اختلاف رقم المستند في البنك عند اختيار المراجعة', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100, doc: 'A1')],
      right: [tx('r', '2026-01-01', 100, doc: 'B1')],
      settings: const ReconciliationSettings(
        mode: ReconciliationMode.bank,
        documentMismatchRule: DocumentMismatchRule.pending,
      ),
    );
    expect(result.pendingCount, 1);
    expect(result.unmatchedRight, isEmpty);
  });

  test('يرفض اختلاف رقم المستند في البنك افتراضياً', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100, doc: 'A1')],
      right: [tx('r', '2026-01-01', 100, doc: 'B1')],
      settings: const ReconciliationSettings(mode: ReconciliationMode.bank),
    );
    expect(result.matchedCount, 0);
    expect(result.pairs.single.reason, 'اختلاف رقم المستند');
    expect(result.unmatchedRight, hasLength(1));
  });

  test('يسمح بمطابقة البنك مع ملاحظة اختلاف المرجع', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100, doc: 'A1')],
      right: [tx('r', '2026-01-01', 100, doc: 'B1')],
      settings: const ReconciliationSettings(
        mode: ReconciliationMode.bank,
        documentMismatchRule: DocumentMismatchRule.matchedWithNote,
      ),
    );
    expect(result.matchedCount, 1);
    expect(result.pairs.single.reason, contains('اختلاف رقم المستند'));
  });

  test('يوضح غياب مرجع أحد طرفي مطابقة البنك', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100, doc: 'A1')],
      right: [tx('r', '2026-01-01', 100)],
      settings: const ReconciliationSettings(mode: ReconciliationMode.bank),
    );
    expect(result.matchedCount, 1);
    expect(result.pairs.single.reason, contains('غير متوفر في أحد الطرفين'));
  });

  test('يرفض اختلاف رقم المستند افتراضياً في مطابقة الأطراف', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100, doc: 'A1', side: EntrySide.debit)],
      right: [tx('r', '2026-01-01', 100, doc: 'B1', side: EntrySide.credit)],
      settings: const ReconciliationSettings(mode: ReconciliationMode.parties),
    );
    expect(result.matchedCount, 0);
    expect(result.pairs.single.reason, 'اختلاف رقم المستند');
  });

  test('يعلق اختلاف رقم المستند للمراجعة حسب اختيار المستخدم', () {
    final result = engine.reconcile(
      left: [tx('l', '2026-01-01', 100, doc: 'A1', side: EntrySide.debit)],
      right: [tx('r', '2026-01-01', 100, doc: 'B1', side: EntrySide.credit)],
      settings: const ReconciliationSettings(
        mode: ReconciliationMode.parties,
        documentMismatchRule: DocumentMismatchRule.pending,
      ),
    );
    expect(result.pendingCount, 1);
    expect(result.unmatchedRight, isEmpty);
  });

  test('لا يستخدم العملية المقابلة أكثر من مرة', () {
    final result = engine.reconcile(
      left: [tx('l1', '2026-01-01', 100), tx('l2', '2026-01-01', 100)],
      right: [tx('r', '2026-01-01', 100)],
      settings: const ReconciliationSettings(mode: ReconciliationMode.bank),
    );
    expect(result.matchedCount, 1);
    expect(result.unmatchedCount, 1);
  });
}
