import 'package:flutter_test/flutter_test.dart';
import 'package:matching/models/bank_reconciliation.dart';
import 'package:matching/models/transaction_record.dart';
import 'package:matching/services/bank_reconciliation_service.dart';

void main() {
  const service = BankReconciliationService();

  TransactionRecord transaction(
    String id,
    double amount, {
    EntrySide side = EntrySide.debit,
    String description = '',
  }) =>
      TransactionRecord(
        id: id,
        date: DateTime(2026, 7, 1),
        amount: amount,
        side: side,
        description: description,
      );

  test('calculates the two adjusted balances and final difference', () {
    final statement = BankReconciliationStatement(
      accountName: 'البنك العربي',
      period: DateTime(2026, 7),
      bankBalance: 1000,
      bookBalance: 930,
      items: const [
        BankAdjustmentItem(
          id: 'deposit',
          description: 'إيداع بالطريق',
          amount: 100,
          type: BankDifferenceType.depositInTransit,
          adjustBankBalance: true,
          add: true,
        ),
        BankAdjustmentItem(
          id: 'cheque',
          description: 'شيك معلق',
          amount: 50,
          type: BankDifferenceType.outstandingPayment,
          adjustBankBalance: true,
          add: false,
        ),
        BankAdjustmentItem(
          id: 'interest',
          description: 'فائدة',
          amount: 120,
          type: BankDifferenceType.bankInterest,
          adjustBankBalance: false,
          add: true,
        ),
      ],
    );

    expect(statement.adjustedBankBalance, 1050);
    expect(statement.adjustedBookBalance, 1050);
    expect(statement.difference, 0);
    expect(statement.isBalanced, isTrue);
  });

  test('cleared items do not affect adjusted balances', () {
    final statement = BankReconciliationStatement(
      period: DateTime(2026, 7),
      bankBalance: 100,
      bookBalance: 100,
      items: const [
        BankAdjustmentItem(
          id: 'cleared',
          description: 'تمت تسويته',
          amount: 25,
          type: BankDifferenceType.bankFee,
          adjustBankBalance: false,
          add: false,
          status: BankItemStatus.cleared,
        ),
      ],
    );

    expect(statement.adjustedBookBalance, 100);
    expect(statement.isBalanced, isTrue);
  });

  test('review-required items do not affect totals or falsely balance', () {
    final statement = BankReconciliationStatement(
      period: DateTime(2026, 7),
      bankBalance: 100,
      bookBalance: 100,
      items: const [
        BankAdjustmentItem(
          id: 'unknown',
          description: 'حركة غير معروفة',
          amount: 25,
          type: BankDifferenceType.reviewRequired,
          adjustBankBalance: false,
          add: true,
        ),
      ],
    );

    expect(statement.adjustedBankBalance, 100);
    expect(statement.adjustedBookBalance, 100);
    expect(statement.hasReviewItems, isTrue);
    expect(statement.isBalanced, isFalse);
  });

  test('bank statement debit decreases books and credit increases books', () {
    final result = ReconciliationResult(
      pairs: const [],
      unmatchedRight: [
        transaction('debit', 40, side: EntrySide.debit),
        transaction('credit', 70, side: EntrySide.credit),
      ],
    );

    final statement = service.build(
      period: DateTime(2026, 7),
      bookBalance: 100,
      bankBalance: 130,
      matchingResult: result,
    );

    final debitItem = statement.items.firstWhere(
      (item) => item.transaction?.id == 'debit',
    );
    final creditItem = statement.items.firstWhere(
      (item) => item.transaction?.id == 'credit',
    );

    expect(debitItem.adjustBankBalance, isFalse);
    expect(debitItem.add, isFalse);
    expect(creditItem.adjustBankBalance, isFalse);
    expect(creditItem.add, isTrue);
    expect(statement.adjustedBookBalance, 130);
    expect(statement.isBalanced, isTrue);
  });

  test('unknown transaction direction requires review', () {
    final statement = service.build(
      period: DateTime(2026, 7),
      bookBalance: 100,
      bankBalance: 100,
      matchingResult: ReconciliationResult(
        pairs: const [],
        unmatchedRight: [
          transaction('unknown', 20, side: EntrySide.unknown),
        ],
      ),
    );

    expect(statement.items.single.type, BankDifferenceType.reviewRequired);
    expect(statement.adjustedBookBalance, 100);
    expect(statement.isBalanced, isFalse);
  });

  test('pending document mismatch stays out of adjusted balances', () {
    final left = transaction('book-review', 20, side: EntrySide.debit);
    final right = transaction('bank-review', 20, side: EntrySide.credit);
    final matchingResult = ReconciliationResult(
      pairs: [
        MatchPair(
          left: left,
          right: right,
          status: MatchStatus.pending,
          reason: 'اختلاف رقم المستند — معلقة للمراجعة',
          score: 80,
        ),
      ],
      unmatchedRight: const [],
    );

    final statement = service.build(
      period: DateTime(2026, 7),
      bookBalance: 100,
      bankBalance: 100,
      matchingResult: matchingResult,
      documentMismatchRule: DocumentMismatchRule.pending,
    );

    expect(statement.items, hasLength(1));
    expect(statement.items.single.type, BankDifferenceType.reviewRequired);
    expect(statement.adjustedBookBalance, 100);
    expect(statement.adjustedBankBalance, 100);
    expect(statement.isBalanced, isFalse);
    expect(statement.matchingResult, same(matchingResult));
  });

  test('changing standard classification updates accounting treatment', () {
    const original = BankAdjustmentItem(
      id: 'item',
      description: 'بند',
      amount: 10,
      type: BankDifferenceType.reviewRequired,
      adjustBankBalance: false,
      add: true,
    );

    final deposit = original.copyWith(type: BankDifferenceType.depositInTransit);
    final cheque = original.copyWith(type: BankDifferenceType.outstandingPayment);
    final fee = original.copyWith(type: BankDifferenceType.bankFee);
    final interest = original.copyWith(type: BankDifferenceType.bankInterest);

    expect(deposit.adjustBankBalance, isTrue);
    expect(deposit.add, isTrue);
    expect(cheque.adjustBankBalance, isTrue);
    expect(cheque.add, isFalse);
    expect(fee.adjustBankBalance, isFalse);
    expect(fee.add, isFalse);
    expect(interest.adjustBankBalance, isFalse);
    expect(interest.add, isTrue);
  });

  test('does not carry a previous item that appears in current month', () {
    final current = transaction(
      'same',
      50,
      side: EntrySide.debit,
      description: 'رسوم بنكية',
    );
    final previous = BankAdjustmentItem(
      id: 'old',
      description: 'رسوم بنكية',
      amount: 50,
      type: BankDifferenceType.bankFee,
      adjustBankBalance: false,
      add: false,
      transaction: current,
      status: BankItemStatus.carryForward,
    );

    final statement = service.build(
      accountName: 'البنك',
      period: DateTime(2026, 7),
      bookBalance: 0,
      bankBalance: 0,
      matchingResult: ReconciliationResult(
        pairs: const [],
        unmatchedRight: [current],
      ),
      previousPending: [previous],
    );

    expect(statement.items, hasLength(1));
    expect(statement.items.single.fromPreviousPeriod, isFalse);
  });

  test('carries unique uncleared previous items only once', () {
    const previous = BankAdjustmentItem(
      id: 'old',
      description: 'شيك معلق رقم 10',
      amount: 75,
      type: BankDifferenceType.outstandingPayment,
      adjustBankBalance: true,
      add: false,
      status: BankItemStatus.carryForward,
    );

    final statement = service.build(
      period: DateTime(2026, 7),
      bookBalance: 0,
      bankBalance: 0,
      matchingResult: const ReconciliationResult(
        pairs: [],
        unmatchedRight: [],
      ),
      previousPending: const [previous, previous],
    );

    expect(statement.items, hasLength(1));
    expect(statement.items.single.fromPreviousPeriod, isTrue);
    expect(statement.items.single.status, BankItemStatus.pending);
  });

  test('prevents adding the same manual item twice', () {
    const item = BankAdjustmentItem(
      id: 'manual-1',
      description: 'عمولة شهرية',
      amount: 10,
      type: BankDifferenceType.bankFee,
      adjustBankBalance: false,
      add: false,
      manual: true,
    );

    expect(
      () => service.addManualItem(const [item], item),
      throwsA(isA<FormatException>()),
    );
  });

  test('classifies fees interest returned cheques and direct deposits', () {
    final result = ReconciliationResult(
      pairs: const [],
      unmatchedRight: [
        transaction('fee', 5, side: EntrySide.debit, description: 'رسوم بنكية'),
        transaction(
          'interest',
          7,
          side: EntrySide.credit,
          description: 'فائدة دائنة',
        ),
        transaction(
          'returned',
          9,
          side: EntrySide.debit,
          description: 'شيك مرتجع',
        ),
        transaction(
          'direct',
          11,
          side: EntrySide.credit,
          description: 'تحصيل مباشر',
        ),
      ],
    );

    final statement = service.build(
      period: DateTime(2026, 7),
      bookBalance: 0,
      bankBalance: 0,
      matchingResult: result,
    );

    expect(
      statement.items.map((item) => item.type),
      containsAll([
        BankDifferenceType.bankFee,
        BankDifferenceType.bankInterest,
        BankDifferenceType.returnedCheque,
        BankDifferenceType.directDeposit,
      ]),
    );
  });
}
