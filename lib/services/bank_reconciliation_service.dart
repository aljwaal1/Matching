import '../models/bank_reconciliation.dart';
import '../models/transaction_record.dart';

class BankReconciliationService {
  const BankReconciliationService();

  BankReconciliationStatement build({
    required DateTime period,
    required double bookBalance,
    required double bankBalance,
    required ReconciliationResult matchingResult,
    List<BankAdjustmentItem> previousPending = const [],
  }) {
    final items = <BankAdjustmentItem>[
      ...previousPending.map(
        (item) => BankAdjustmentItem(
          id: item.id,
          description: item.description,
          amount: item.amount,
          type: item.type,
          adjustBankBalance: item.adjustBankBalance,
          add: item.add,
          transaction: item.transaction,
          fromPreviousPeriod: true,
          cleared: item.cleared,
        ),
      ),
    ];

    for (final pair in matchingResult.pairs) {
      if (pair.status == MatchStatus.matched) continue;
      items.add(_fromBookTransaction(pair.left));
    }

    for (final transaction in matchingResult.unmatchedRight) {
      items.add(_fromBankTransaction(transaction));
    }

    return BankReconciliationStatement(
      period: DateTime(period.year, period.month),
      bookBalance: bookBalance,
      bankBalance: bankBalance,
      items: List.unmodifiable(items),
    );
  }

  BankAdjustmentItem _fromBookTransaction(TransactionRecord transaction) {
    final isDeposit = transaction.side == EntrySide.debit;
    return BankAdjustmentItem(
      id: 'book-${transaction.id}',
      description: transaction.description.isEmpty
          ? 'عملية موجودة في دفاتر الشركة فقط'
          : transaction.description,
      amount: transaction.amount,
      type: isDeposit
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

    final type = isFee
        ? BankDifferenceType.bankFee
        : isInterest
            ? BankDifferenceType.bankInterest
            : BankDifferenceType.unrecordedBankTransaction;

    final add = switch (type) {
      BankDifferenceType.bankFee => false,
      BankDifferenceType.bankInterest => true,
      _ => transaction.side == EntrySide.debit,
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
