import 'transaction_record.dart';

enum BankDifferenceType {
  depositInTransit,
  outstandingPayment,
  bankFee,
  bankInterest,
  returnedCheque,
  directDeposit,
  bankError,
  bookError,
  unrecordedBankTransaction,
  otherBankAdjustment,
  otherBookAdjustment,
  reviewRequired,
}

extension BankDifferenceTypeLabel on BankDifferenceType {
  String get label => switch (this) {
        BankDifferenceType.depositInTransit => 'إيداع بالطريق',
        BankDifferenceType.outstandingPayment => 'شيك أو دفعة معلقة',
        BankDifferenceType.bankFee => 'عمولة أو مصروف بنكي',
        BankDifferenceType.bankInterest => 'فائدة بنكية',
        BankDifferenceType.returnedCheque => 'شيك مرتجع',
        BankDifferenceType.directDeposit => 'إيداع أو تحصيل مباشر',
        BankDifferenceType.bankError => 'خطأ في كشف البنك',
        BankDifferenceType.bookError => 'خطأ في دفاتر الشركة',
        BankDifferenceType.unrecordedBankTransaction => 'حركة بنكية غير مسجلة',
        BankDifferenceType.otherBankAdjustment => 'بند آخر يعدل كشف البنك',
        BankDifferenceType.otherBookAdjustment => 'بند آخر يعدل دفاتر الشركة',
        BankDifferenceType.reviewRequired => 'فرق يحتاج مراجعة',
      };
}

enum BankItemStatus { pending, cleared, carryForward }

extension BankItemStatusLabel on BankItemStatus {
  String get label => switch (this) {
        BankItemStatus.pending => 'يبقى معلقًا',
        BankItemStatus.cleared => 'تمت تسويته',
        BankItemStatus.carryForward => 'يرحّل للشهر القادم',
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
    this.status = BankItemStatus.pending,
    this.manual = false,
  });

  final String id;
  final String description;
  final double amount;
  final BankDifferenceType type;
  final bool adjustBankBalance;
  final bool add;
  final TransactionRecord? transaction;
  final bool fromPreviousPeriod;
  final BankItemStatus status;
  final bool manual;

  bool get cleared => status == BankItemStatus.cleared;
  bool get shouldCarryForward => status == BankItemStatus.carryForward;

  /// لا يدخل البند في حساب الرصيد المعدل قبل تحديد طبيعته المحاسبية.
  bool get includedInCalculation =>
      !cleared && type != BankDifferenceType.reviewRequired;

  String get deduplicationKey {
    final transactionId = transaction?.id.trim();
    if (transactionId != null && transactionId.isNotEmpty) {
      return 'tx:$transactionId';
    }
    final normalizedDescription = description
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    return '${adjustBankBalance ? 'bank' : 'book'}|'
        '${amount.abs().toStringAsFixed(2)}|$normalizedDescription';
  }

  BankAdjustmentItem copyWith({
    String? description,
    double? amount,
    BankDifferenceType? type,
    bool? adjustBankBalance,
    bool? add,
    bool? fromPreviousPeriod,
    BankItemStatus? status,
    bool? manual,
  }) {
    final resolvedType = type ?? this.type;
    final standard = type == null ? null : _standardTreatment(resolvedType);
    return BankAdjustmentItem(
      id: id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: resolvedType,
      adjustBankBalance:
          adjustBankBalance ?? standard?.adjustBankBalance ?? this.adjustBankBalance,
      add: add ?? standard?.add ?? this.add,
      transaction: transaction,
      fromPreviousPeriod: fromPreviousPeriod ?? this.fromPreviousPeriod,
      status: status ?? this.status,
      manual: manual ?? this.manual,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'type': type.name,
        'adjustBankBalance': adjustBankBalance,
        'add': add,
        'transaction': transaction == null ? null : _transactionToJson(transaction!),
        'fromPreviousPeriod': fromPreviousPeriod,
        'status': status.name,
        'manual': manual,
      };

  factory BankAdjustmentItem.fromJson(Map<String, dynamic> json) =>
      BankAdjustmentItem(
        id: json['id'] as String,
        description: json['description'] as String? ?? '',
        amount: (json['amount'] as num).toDouble().abs(),
        type: BankDifferenceType.values.byName(
          json['type'] as String? ?? BankDifferenceType.reviewRequired.name,
        ),
        adjustBankBalance: json['adjustBankBalance'] as bool? ?? true,
        add: json['add'] as bool? ?? true,
        transaction: json['transaction'] == null
            ? null
            : _transactionFromJson(
                Map<String, dynamic>.from(json['transaction'] as Map),
              ),
        fromPreviousPeriod: json['fromPreviousPeriod'] as bool? ?? false,
        status: BankItemStatus.values.byName(
          json['status'] as String? ??
              ((json['cleared'] as bool? ?? false)
                  ? BankItemStatus.cleared.name
                  : BankItemStatus.pending.name),
        ),
        manual: json['manual'] as bool? ?? false,
      );
}

class _AccountingTreatment {
  const _AccountingTreatment(this.adjustBankBalance, this.add);

  final bool adjustBankBalance;
  final bool add;
}

_AccountingTreatment? _standardTreatment(BankDifferenceType type) => switch (type) {
      BankDifferenceType.depositInTransit =>
        const _AccountingTreatment(true, true),
      BankDifferenceType.outstandingPayment =>
        const _AccountingTreatment(true, false),
      BankDifferenceType.bankFee || BankDifferenceType.returnedCheque =>
        const _AccountingTreatment(false, false),
      BankDifferenceType.bankInterest || BankDifferenceType.directDeposit =>
        const _AccountingTreatment(false, true),
      BankDifferenceType.otherBankAdjustment =>
        const _AccountingTreatment(true, true),
      BankDifferenceType.otherBookAdjustment =>
        const _AccountingTreatment(false, true),
      _ => null,
    };

class BankReconciliationStatement {
  const BankReconciliationStatement({
    this.accountName = '',
    required this.period,
    required this.bookBalance,
    required this.bankBalance,
    required this.items,
  });

  final String accountName;
  final DateTime period;
  final double bookBalance;
  final double bankBalance;
  final List<BankAdjustmentItem> items;

  double get adjustedBankBalance => items
      .where((item) => item.adjustBankBalance && item.includedInCalculation)
      .fold(bankBalance, (sum, item) => sum + (item.add ? item.amount : -item.amount));

  double get adjustedBookBalance => items
      .where((item) => !item.adjustBankBalance && item.includedInCalculation)
      .fold(bookBalance, (sum, item) => sum + (item.add ? item.amount : -item.amount));

  double get difference => adjustedBankBalance - adjustedBookBalance;

  bool get hasReviewItems =>
      items.any((item) => item.type == BankDifferenceType.reviewRequired && !item.cleared);

  bool get isBalanced => !hasReviewItems && difference.abs() <= 0.01;

  List<BankAdjustmentItem> get carryForwardItems => items
      .where((item) => item.status == BankItemStatus.carryForward)
      .toList(growable: false);

  BankReconciliationStatement copyWith({
    String? accountName,
    DateTime? period,
    double? bookBalance,
    double? bankBalance,
    List<BankAdjustmentItem>? items,
  }) =>
      BankReconciliationStatement(
        accountName: accountName ?? this.accountName,
        period: period ?? this.period,
        bookBalance: bookBalance ?? this.bookBalance,
        bankBalance: bankBalance ?? this.bankBalance,
        items: List.unmodifiable(items ?? this.items),
      );

  Map<String, dynamic> toJson() => {
        'accountName': accountName,
        'period': period.toIso8601String(),
        'bookBalance': bookBalance,
        'bankBalance': bankBalance,
        'adjustedBankBalance': adjustedBankBalance,
        'adjustedBookBalance': adjustedBookBalance,
        'difference': difference,
        'isBalanced': isBalanced,
        'items': items.map((item) => item.toJson()).toList(growable: false),
      };

  factory BankReconciliationStatement.fromJson(Map<String, dynamic> json) =>
      BankReconciliationStatement(
        accountName: json['accountName'] as String? ?? '',
        period: DateTime.parse(json['period'] as String),
        bookBalance: (json['bookBalance'] as num).toDouble(),
        bankBalance: (json['bankBalance'] as num).toDouble(),
        items: (json['items'] as List? ?? const [])
            .map(
              (item) => BankAdjustmentItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );
}

Map<String, dynamic> _transactionToJson(TransactionRecord item) => {
      'id': item.id,
      'date': item.date.toIso8601String(),
      'amount': item.amount,
      'documentNumber': item.documentNumber,
      'description': item.description,
      'sourceRow': item.sourceRow,
      'side': item.side.name,
      'balance': item.balance,
    };

TransactionRecord _transactionFromJson(Map<String, dynamic> map) =>
    TransactionRecord(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      amount: (map['amount'] as num).toDouble(),
      documentNumber: map['documentNumber'] as String?,
      description: map['description'] as String? ?? '',
      sourceRow: map['sourceRow'] as int?,
      side: EntrySide.values.byName(map['side'] as String? ?? 'unknown'),
      balance: (map['balance'] as num?)?.toDouble(),
    );
