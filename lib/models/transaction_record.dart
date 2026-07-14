enum MatchStatus { matched, probable, unmatched }

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.date,
    required this.amount,
    this.documentNumber,
    this.description = '',
    this.sourceRow,
  });

  final String id;
  final DateTime date;
  final double amount;
  final String? documentNumber;
  final String description;
  final int? sourceRow;

  String get normalizedDocumentNumber =>
      (documentNumber ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
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
  int get probableCount =>
      pairs.where((pair) => pair.status == MatchStatus.probable).length;
  int get unmatchedCount =>
      pairs.where((pair) => pair.status == MatchStatus.unmatched).length +
      unmatchedRight.length;
}
