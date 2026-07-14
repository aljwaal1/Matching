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
      pairs: List.unmodifiable(pairs),
      unmatchedRight: List.unmodifiable(availableRight),
    );
  }

  MatchPair _score(
    TransactionRecord left,
    TransactionRecord right,
    ReconciliationSettings settings,
  ) {
    final amountMatches =
        (left.amount - right.amount).abs() <= settings.amountTolerance;
    if (!amountMatches) return _noMatch(left, right, 'المبلغ مختلف');

    final leftDocument = left.normalizedDocumentNumber;
    final rightDocument = right.normalizedDocumentNumber;
    final bothHaveDocuments = leftDocument.isNotEmpty && rightDocument.isNotEmpty;

    if (bothHaveDocuments) {
      if (leftDocument != rightDocument) {
        return _noMatch(left, right, 'رقم المستند مختلف');
      }
      return MatchPair(
        left: left,
        right: right,
        status: MatchStatus.matched,
        reason: 'تطابق رقم المستند والمبلغ',
        score: 100,
      );
    }

    final dateDifference = left.date.difference(right.date).inDays.abs();
    if (dateDifference > settings.allowedDateDifferenceDays) {
      return _noMatch(left, right, 'فرق التاريخ أكبر من المسموح');
    }

    return MatchPair(
      left: left,
      right: right,
      status: MatchStatus.matched,
      reason: dateDifference == 0
          ? 'تطابق المبلغ والتاريخ'
          : 'تطابق المبلغ مع فرق تاريخ $dateDifference يوم',
      score: 90 - dateDifference.toDouble(),
    );
  }

  MatchPair _noMatch(
    TransactionRecord left,
    TransactionRecord right,
    String reason,
  ) =>
      MatchPair(
        left: left,
        right: right,
        status: MatchStatus.unmatched,
        reason: reason,
        score: 0,
      );
}
