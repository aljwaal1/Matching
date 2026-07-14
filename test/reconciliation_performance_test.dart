import 'package:flutter_test/flutter_test.dart';
import 'package:matching/models/transaction_record.dart';
import 'package:matching/services/reconciliation_engine.dart';

void main() {
  test('يطابق عشرة آلاف عملية دون تكرار النتائج', () {
    const count = 10000;
    final start = DateTime(2026, 1, 1);
    final left = List.generate(
      count,
      (index) => TransactionRecord(
        id: 'L$index',
        date: start.add(Duration(days: index % 30)),
        amount: 1000 + index.toDouble(),
        documentNumber: 'DOC-$index',
      ),
    );
    final right = List.generate(
      count,
      (index) => TransactionRecord(
        id: 'R$index',
        date: start.add(Duration(days: index % 30)),
        amount: 1000 + index.toDouble(),
        documentNumber: 'DOC$index',
      ),
    );

    final watch = Stopwatch()..start();
    final result = const ReconciliationEngine().reconcile(left: left, right: right);
    watch.stop();

    expect(result.matchedCount, count);
    expect(result.unmatchedCount, 0);
    expect(result.pairs.map((pair) => pair.right!.id).toSet().length, count);
    expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
  });
}
