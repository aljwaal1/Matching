import '../models/bank_reconciliation.dart';
import '../models/transaction_record.dart';

class BankReconciliationService {
  const BankReconciliationService();

  BankReconciliationStatement build({
    String accountName = '',
    required DateTime period,
    required double bookBalance,
    required double bankBalance,
    required ReconciliationResult matchingResult,
    List<BankAdjustmentItem> previousPending = const [],
  }) {
    final currentItems = <BankAdjustmentItem>[];

    for (final pair in matchingResult.pairs) {
      if (pair.status == MatchStatus.matched) continue;
      currentItems.add(_fromBookTransaction(pair.left));
    }

    for (final transaction in matchingResult.unmatchedRight) {
      currentItems.add(_fromBankTransaction(transaction));
    }

    final currentKeys = currentItems
        .map((item) => item.deduplicationKey)
        .toSet();
    final items = <BankAdjustmentItem>[];
    final seen = <String>{};

    for (final previous in previousPending) {
      if (previous.cleared) continue;
      final key = previous.deduplicationKey;
      if (currentKeys.contains(key)) {
        // ظهر البند في كشف الشهر الحالي؛ لذلك لا يعاد ترحيله.
        continue;
      }
      if (seen.add(key)) {
        items.add(
          previous.copyWith(
            fromPreviousPeriod: true,
            status: BankItemStatus.pending,
          ),
        );
      }
    }

    for (final current in currentItems) {
      if (seen.add(current.deduplicationKey)) items.add(current);
    }

    return BankReconciliationStatement(
      accountName: accountName.trim(),
      period: DateTime(period.year, period.month),
      bookBalance: bookBalance,
      bankBalance: bankBalance,
      items: List.unmodifiable(items),
    );
  }

  List<BankAdjustmentItem> addManualItem(
    List<BankAdjustmentItem> existing,
    BankAdjustmentItem item,
  ) {
    final key = item.deduplicationKey;
    if (existing.any((value) => value.deduplicationKey == key)) {
      throw const FormatException('هذا البند موجود مسبقًا في التسوية.');
    }
    return List.unmodifiable([...existing, item.copyWith(manual: true)]);
  }

  BankAdjustmentItem _fromBookTransaction(TransactionRecord transaction) {
    // حساب البنك في دفاتر الشركة أصل: المدين زيادة، والدائن نقصان.
    final isDeposit = transaction.side == EntrySide.debit;
    final needsReview = transaction.side == EntrySide.unknown;
    return BankAdjustmentItem(
      id: 'book-${transaction.id}',
      description: transaction.description.isEmpty
          ? 'عملية موجودة في دفاتر الشركة فقط'
          : transaction.description,
      amount: transaction.amount,
      type: needsReview
          ? BankDifferenceType.reviewRequired
          : isDeposit
              ? BankDifferenceType.depositInTransit
              : BankDifferenceType.outstandingPayment,
      adjustBankBalance: true,
      add: isDeposit,
      transaction: transaction,
    );
  }

  BankAdjustmentItem _fromBankTransaction(TransactionRecord transaction) {
    final text = transaction.description.toLowerCase();
    final isFee = text.contains('fee') ||
        text.contains('commission') ||
        text.contains('عمول') ||
        text.contains('رسوم') ||
        text.contains('مصروف');
    final isInterest = text.contains('interest') ||
        text.contains('فائد') ||
        text.contains('عائد');
    final isReturned = text.contains('returned') ||
        text.contains('bounce') ||
        text.contains('مرتجع');
    final isDirectDeposit = text.contains('direct deposit') ||
        text.contains('collection') ||
        text.contains('تحصيل') ||
        text.contains('إيداع مباشر');

    final type = transaction.side == EntrySide.unknown
        ? BankDifferenceType.reviewRequired
        : isFee
            ? BankDifferenceType.bankFee
            : isInterest
                ? BankDifferenceType.bankInterest
                : isReturned
                    ? BankDifferenceType.returnedCheque
                    : isDirectDeposit
                        ? BankDifferenceType.directDeposit
                        : BankDifferenceType.unrecordedBankTransaction;

    final add = switch (type) {
      BankDifferenceType.bankFee || BankDifferenceType.returnedCheque => false,
      BankDifferenceType.bankInterest || BankDifferenceType.directDeposit => true,
      // في كشف البنك: الدائن يزيد حساب العميل، والمدين ينقصه.
      BankDifferenceType.unrecordedBankTransaction =>
        transaction.side == EntrySide.credit,
      _ => true,
    };

    return BankAdjustmentItem(
      id: 'bank-${transaction.id}',
      description: transaction.description.isEmpty
          ? 'عملية موجودة في كشف البنك فقط'
          : transaction.description,
      amount: transaction.amount,
      type: type,
      adjustBankBalance: false,
      add: add,
      transaction: transaction,
    );
  }
}