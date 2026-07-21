enum MatchStatus { matched, pending, unmatched }

enum DocumentMismatchRule { unmatched, pending, matchedWithNote }

enum EntrySide { debit, credit, unknown }

enum ReconciliationMode { parties, bank }

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.date,
    required this.amount,
    this.documentNumber,
    this.description = '',
    this.sourceRow,
    this.side = EntrySide.unknown,
    this.balance,
  });

  final String id;
  final DateTime date;
  final double amount;
  final String? documentNumber;
  final String description;
  final int? sourceRow;
  final EntrySide side;
  final double? balance;

  String get normalizedDocumentNumber => (documentNumber ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]'), '');

  String get sideLabel => switch (side) {
        EntrySide.debit => 'مدين',
        EntrySide.credit => 'دائن',
        EntrySide.unknown => 'غير محدد',
      };
}

class MatchPair {
  const MatchPair({
    required this.left,
    required this.right,
    required this.status,
    required this.reason,
    required this.score,
  });

  final TransactionRecord left;
  final TransactionRecord? right;
  final MatchStatus status;
  final String reason;
  final double score;
}

class ReconciliationResult {
  const ReconciliationResult({
    required this.pairs,
    required this.unmatchedRight,
  });

  final List<MatchPair> pairs;
  final List<TransactionRecord> unmatchedRight;

  int get matchedCount =>
      pairs.where((pair) => pair.status == MatchStatus.matched).length;
  int get pendingCount =>
      pairs.where((pair) => pair.status == MatchStatus.pending).length;
  int get unmatchedCount =>
      pairs.where((pair) => pair.status == MatchStatus.unmatched).length +
      unmatchedRight.length;
}
