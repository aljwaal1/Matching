import '../models/transaction_record.dart';

class ReconciliationSettings {
  const ReconciliationSettings({
    this.allowedDateDifferenceDays = 3,
    this.amountTolerance = 0.001,
  });

  final int allowedDateDifferenceDays;
  final double amountTolerance;
}

class ReconciliationEngine {
  const ReconciliationEngine();

  ReconciliationResult reconcile({
    required List<TransactionRecord> left,
    required List<TransactionRecord> right,
    ReconciliationSettings settings = const ReconciliationSettings(),
  }) {
    final availableRight = List<TransactionRecord>.from(right);
    final pairs = <MatchPair>[];

    for (final leftItem in left) {
      final candidates = availableRight
          .where((rightItem) =>
              (leftItem.amount - rightItem.amount).abs() <=
              settings.amountTolerance)
          .map((rightItem) => _score(leftItem, rightItem, settings))
          .where((candidate) => candidate.score > 0)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      if (candidates.isEmpty) {
        pairs.add(MatchPair(
          left: leftItem,
          right: null,
          status: MatchStatus.unmatched,
          reason: 'لم يتم العثور على عملية مقابلة',
          score: 0,
        ));
        continue;
      }

      final best = candidates.first;
      availableRight.remove(best.right);
      pairs.add(best);
    }

    return ReconciliationResult(
      pairs: pairs,
      unmatchedRight: List.unmodifiable(availableRight),
    );
  }

  MatchPair _score(
    TransactionRecord left,
    TransactionRecord right,
    ReconciliationSettings settings,
  ) {
    final dateDifference = left.date.difference(right.date).inDays.abs();
    if (dateDifference > settings.allowedDateDifferenceDays) {
      return MatchPair(
        left: left,
        right: right,
        status: MatchStatus.unmatched,
        reason: 'فرق التاريخ أكبر من المسموح',
        score: 0,
      );
    }

    final hasDocumentNumbers = left.normalizedDocumentNumber.isNotEmpty &&
        right.normalizedDocumentNumber.isNotEmpty;
    final documentsMatch = hasDocumentNumbers &&
        left.normalizedDocumentNumber == right.normalizedDocumentNumber;

    if (documentsMatch) {
      return MatchPair(
        left: left,
        right: right,
        status: MatchStatus.matched,
        reason: 'تطابق رقم المستند والمبلغ',
        score: 100 - dateDifference.toDouble(),
      );
    }

    final descriptionSimilarity =
        _descriptionSimilarity(left.description, right.description);
    final score = 80 - (dateDifference * 5) + (descriptionSimilarity * 15);

    return MatchPair(
      left: left,
      right: right,
      status: dateDifference <= 1 || descriptionSimilarity >= 0.5
          ? MatchStatus.matched
          : MatchStatus.probable,
      reason: dateDifference == 0
          ? 'تطابق المبلغ والتاريخ'
          : 'تطابق المبلغ مع فرق تاريخ $dateDifference يوم',
      score: score,
    );
  }

  double _descriptionSimilarity(String first, String second) {
    final a = _tokens(first);
    final b = _tokens(second);
    if (a.isEmpty || b.isEmpty) return 0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    return union == 0 ? 0 : intersection / union;
  }

  Set<String> _tokens(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\u0600-\u06FF]+'), ' ')
      .split(' ')
      .where((token) => token.length > 1)
      .toSet();
}
