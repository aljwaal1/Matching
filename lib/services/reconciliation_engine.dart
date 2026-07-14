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
    if (settings.amountTolerance <= 0) {
      throw ArgumentError.value(
        settings.amountTolerance,
        'amountTolerance',
        'يجب أن تكون سماحية المبلغ أكبر من صفر.',
      );
    }

    final indexedRight = List.generate(
      right.length,
      (index) => _IndexedRecord(index: index, record: right[index]),
      growable: false,
    );
    final amountIndex = <int, List<_IndexedRecord>>{};
    for (final item in indexedRight) {
      amountIndex
          .putIfAbsent(_amountBucket(item.record.amount, settings.amountTolerance), () => [])
          .add(item);
    }

    final usedRight = <int>{};
    final pairs = <MatchPair>[];

    for (final leftItem in left) {
      final bucket = _amountBucket(leftItem.amount, settings.amountTolerance);
      MatchPair? best;
      int? bestIndex;

      // A value within the tolerance can only fall in its own bucket or one
      // of the directly adjacent buckets.
      for (var candidateBucket = bucket - 1;
          candidateBucket <= bucket + 1;
          candidateBucket++) {
        for (final candidate in amountIndex[candidateBucket] ?? const <_IndexedRecord>[]) {
          if (usedRight.contains(candidate.index)) continue;
          final scored = _score(leftItem, candidate.record, settings);
          if (scored.score <= 0) continue;
          if (best == null || scored.score > best.score) {
            best = scored;
            bestIndex = candidate.index;
            if (scored.score == 100) break;
          }
        }
        if (best?.score == 100) break;
      }

      if (best == null || bestIndex == null) {
        pairs.add(MatchPair(
          left: leftItem,
          right: null,
          status: MatchStatus.unmatched,
          reason: 'لم يتم العثور على عملية مقابلة',
          score: 0,
        ));
        continue;
      }

      usedRight.add(bestIndex);
      pairs.add(best);
    }

    final unmatchedRight = indexedRight
        .where((item) => !usedRight.contains(item.index))
        .map((item) => item.record)
        .toList(growable: false);

    return ReconciliationResult(
      pairs: List.unmodifiable(pairs),
      unmatchedRight: List.unmodifiable(unmatchedRight),
    );
  }

  int _amountBucket(double amount, double tolerance) => (amount / tolerance).floor();

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

class _IndexedRecord {
  const _IndexedRecord({required this.index, required this.record});

  final int index;
  final TransactionRecord record;
}
