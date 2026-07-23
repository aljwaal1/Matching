import 'package:flutter_test/flutter_test.dart';
import 'package:matching/models/bank_reconciliation.dart';
import 'package:matching/models/transaction_record.dart';
import 'package:matching/services/bank_reconciliation_pdf_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'creates comprehensive PDF for 216 matching rows without one huge table',
    () async {
      final pairs = List<MatchPair>.generate(216, (index) {
        final amount = 1000 + index.toDouble();
        final date = DateTime(2026, 7, (index % 28) + 1);
        final status = switch (index % 3) {
          0 => MatchStatus.matched,
          1 => MatchStatus.pending,
          _ => MatchStatus.unmatched,
        };
        return MatchPair(
          left: TransactionRecord(
            id: 'book-$index',
            date: date,
            amount: amount,
            documentNumber: 'BOOK-$index',
            description: 'عملية دفترية رقم $index لاختبار التقرير الشامل',
            side: EntrySide.debit,
            balance: 500000 - index.toDouble(),
          ),
          right: TransactionRecord(
            id: 'bank-$index',
            date: date,
            amount: amount,
            documentNumber: 'BANK-$index',
            description: 'عملية بنكية رقم $index لاختبار التقرير الشامل',
            side: EntrySide.credit,
            balance: 400000 - index.toDouble(),
          ),
          status: status,
          reason: status == MatchStatus.matched
              ? 'المبلغ والتاريخ متطابقان'
              : 'يحتاج إلى مراجعة رقابية',
          score: status == MatchStatus.matched ? 100 : 75,
        );
      });

      final statement = BankReconciliationStatement(
        accountName: 'الحساب البنكي',
        period: DateTime(2026, 7),
        bookBalance: 48088325.92,
        bankBalance: 40277467.62,
        items: const [],
        bookSourceName: 'دفاتر الشركة',
        bankSourceName: 'كشف البنك',
        matchingResult: ReconciliationResult(
          pairs: pairs,
          unmatchedRight: const [],
        ),
      );

      final stopwatch = Stopwatch()..start();
      final bytes = await const BankReconciliationPdfBuilder().build(
        companyName: 'دفاتر الشركة',
        bankName: 'الحساب البنكي',
        statement: statement,
      );
      stopwatch.stop();

      expect(bytes.length, greaterThan(10000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 30)));
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
