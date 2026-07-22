import 'package:flutter_test/flutter_test.dart';
import 'package:matching/models/bank_reconciliation.dart';
import 'package:matching/models/transaction_record.dart';
import 'package:matching/services/bank_reconciliation_archive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BankReconciliationArchiveService archive;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    archive = BankReconciliationArchiveService();
  });

  BankAdjustmentItem item(
    String id, {
    BankItemStatus status = BankItemStatus.pending,
    double amount = 10,
    String description = 'بند',
  }) =>
      BankAdjustmentItem(
        id: id,
        description: description,
        amount: amount,
        type: BankDifferenceType.reviewRequired,
        adjustBankBalance: true,
        add: true,
        status: status,
      );

  test('يحفظ تسوية واحدة لكل حساب وشهر ويستبدل النسخة السابقة', () async {
    await archive.save(
      BankReconciliationStatement(
        accountName: 'البنك العربي',
        period: DateTime(2026, 6),
        bankBalance: 100,
        bookBalance: 90,
        items: [item('a')],
      ),
    );
    await archive.save(
      BankReconciliationStatement(
        accountName: ' البنك العربي ',
        period: DateTime(2026, 6, 25),
        bankBalance: 120,
        bookBalance: 120,
        items: [item('b')],
      ),
    );

    final all = await archive.loadAll();
    expect(all, hasLength(1));
    expect(all.single.bankBalance, 120);
    expect(all.single.period, DateTime(2026, 6));
  });

  test('يعيد آخر تسوية سابقة لنفس الحساب فقط', () async {
    await archive.save(
      BankReconciliationStatement(
        accountName: 'حساب 1',
        period: DateTime(2026, 4),
        bankBalance: 1,
        bookBalance: 1,
        items: const [],
      ),
    );
    await archive.save(
      BankReconciliationStatement(
        accountName: 'حساب 1',
        period: DateTime(2026, 5),
        bankBalance: 2,
        bookBalance: 2,
        items: const [],
      ),
    );
    await archive.save(
      BankReconciliationStatement(
        accountName: 'حساب 2',
        period: DateTime(2026, 6),
        bankBalance: 3,
        bookBalance: 3,
        items: const [],
      ),
    );

    final previous = await archive.latestPrevious(
      accountName: 'حساب 1',
      beforePeriod: DateTime(2026, 7),
    );

    expect(previous, isNotNull);
    expect(previous!.period, DateTime(2026, 5));
  });

  test('يرحل فقط البنود المحددة للترحيل وغير الموجودة في الشهر الحالي', () async {
    final carry = item(
      'carry',
      status: BankItemStatus.carryForward,
      amount: 50,
      description: 'شيك معلق',
    );
    final cleared = item(
      'cleared',
      status: BankItemStatus.cleared,
      amount: 20,
      description: 'تمت تسويته',
    );

    await archive.save(
      BankReconciliationStatement(
        accountName: 'البنك',
        period: DateTime(2026, 6),
        bankBalance: 0,
        bookBalance: 0,
        items: [carry, cleared],
      ),
    );

    final pending = await archive.pendingFromPrevious(
      accountName: 'البنك',
      beforePeriod: DateTime(2026, 7),
    );
    expect(pending, hasLength(1));
    expect(pending.single.id, 'carry');
    expect(pending.single.fromPreviousPeriod, isTrue);
    expect(pending.single.status, BankItemStatus.pending);

    final duplicateBlocked = await archive.pendingFromPrevious(
      accountName: 'البنك',
      beforePeriod: DateTime(2026, 7),
      currentItems: [carry],
    );
    expect(duplicateBlocked, isEmpty);
  });

  test('يحذف التسوية المحددة فقط', () async {
    await archive.save(
      BankReconciliationStatement(
        accountName: 'البنك',
        period: DateTime(2026, 5),
        bankBalance: 0,
        bookBalance: 0,
        items: const [],
      ),
    );
    await archive.save(
      BankReconciliationStatement(
        accountName: 'البنك',
        period: DateTime(2026, 6),
        bankBalance: 0,
        bookBalance: 0,
        items: const [],
      ),
    );

    await archive.delete(
      accountName: 'البنك',
      period: DateTime(2026, 5),
    );

    final all = await archive.loadAll();
    expect(all, hasLength(1));
    expect(all.single.period, DateTime(2026, 6));
  });

  test('يحفظ قاعدة المرجع ونتيجة التحليل لإعادة التصدير', () async {
    final matchingResult = ReconciliationResult(
      pairs: [
        MatchPair(
          left: TransactionRecord(
            id: 'book',
            date: DateTime(2026, 7, 1),
            amount: 10,
          ),
          right: TransactionRecord(
            id: 'bank',
            date: DateTime(2026, 7, 1),
            amount: 10,
          ),
          status: MatchStatus.pending,
          reason: 'اختلاف رقم المستند',
          score: 80,
        ),
      ],
      unmatchedRight: const [],
    );
    await archive.save(
      BankReconciliationStatement(
        accountName: 'البنك',
        period: DateTime(2026, 7),
        bankBalance: 10,
        bookBalance: 10,
        items: const [],
        bookSourceName: 'دفاتر.xlsx',
        bankSourceName: 'بنك.xlsx',
        documentMismatchRule: DocumentMismatchRule.pending,
        matchingResult: matchingResult,
      ),
    );

    final restored = (await archive.loadAll()).single;
    expect(restored.bookSourceName, 'دفاتر.xlsx');
    expect(restored.bankSourceName, 'بنك.xlsx');
    expect(restored.documentMismatchRule, DocumentMismatchRule.pending);
    expect(restored.matchingResult?.pendingCount, 1);
    expect(restored.matchingResult?.pairs.single.right?.id, 'bank');
  });
}
