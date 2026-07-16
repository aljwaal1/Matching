import 'transaction_record.dart';

enum BankDifferenceType {
  depositInTransit,
  outstandingPayment,
  bankFee,
  bankInterest,
  unrecordedBankTransaction,
  reviewRequired,
}

extension BankDifferenceTypeLabel on BankDifferenceType {
  String get label => switch (this) {
        BankDifferenceType.depositInTransit => 'إيداع بالطريق',
        BankDifferenceType.outstandingPayment => 'شيك أو دفعة معلقة',
        BankDifferenceType.bankFee => 'عمولة أو مصروف بنكي',
        BankDifferenceType.bankInterest => 'فائدة بنكية',
        BankDifferenceType.unrecordedBankTransaction => 'حركة بنكية غير مسجلة',
        BankDifferenceType.reviewRequired => 'فرق يحتاج مراجعة',
      };
}

class BankAdjustmentItem {
  const BankAdjustmentItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.adjustBankBalance,
    required this.add,
    this.transaction,
    this.fromPreviousPeriod = false,
    this.cleared = false,
  });

  final String id;
  final String description;
  final double amount;
  final BankDifferenceType type;
  final bool adjustBankBalance;
  final bool add;
  final TransactionRecord? transaction;
  final bool fromPreviousPeriod;
  final bool cleared;

  BankAdjustmentItem copyWith({
    BankDifferenceType? type,
    bool? adjustBankBalance,
    bool? add,
    bool? cleared,
  }) =>
      BankAdjustmentItem(
        id: id,
        description: description,
        amount: amount,
        type: type ?? this.type,
        adjustBankBalance: adjustBankBalance ?? this.adjustBankBalance,
        add: add ?? this.add,
        transaction: transaction,
        fromPreviousPeriod: fromPreviousPeriod,
        cleared: cleared ?? this.cleared,
      );
}

class BankReconciliationStatement {
  const BankReconciliationStatement({
    required this.period,
    required this.bookBalance,
    required this.bankBalance,
    required this.items,
  });

  final DateTime period;
  final double bookBalance;
  final double bankBalance;
  final List<BankAdjustmentItem> items;

  double get adjustedBankBalance => items
      .where((item) => item.adjustBankBalance && !item.cleared)
      .fold(bankBalance, (sum, item) => sum + (item.add ? item.amount : -item.amount));

  double get adjustedBookBalance => items
      .where((item) => !item.adjustBankBalance && !item.cleared)
      .fold(bookBalance, (sum, item) => sum + (item.add ? item.amount : -item.amount));

  double get difference => adjustedBankBalance - adjustedBookBalance;

  bool get isBalanced => difference.abs() <= 0.01;

  List<BankAdjustmentItem> get carryForwardItems =>
      items.where((item) => !item.cleared).toList(growable: false);
}
