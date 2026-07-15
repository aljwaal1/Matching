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
    final documentIndex = <String, List<_IndexedRecord>>{};
    for (final item in indexedRight) {
      amountIndex
          .putIfAbsent(_amountBucket(item.record.amount, settings.amountTolerance), () => [])
          .add(item);
      final document = item.record.normalizedDocumentNumber;
      if (document.isNotEmpty) {
        documentIndex.putIfAbsent(document, () => []).add(item);
      }
    }

    final usedRight = <int>{};
    final pairs = <MatchPair>[];

    for (final leftItem in left) {
      final leftDocument = leftItem.normalizedDocumentNumber;
      final sameDocumentCandidates = leftDocument.isEmpty
          ? const <_IndexedRecord>[]
          : (documentIndex[leftDocument] ?? const <_IndexedRecord>[])
              .where((candidate) => !usedRight.contains(candidate.index))
              .toList(growable: false);

      if (sameDocumentCandidates.isNotEmpty) {
        final selected = _bestDocumentCandidate(
          leftItem,
          sameDocumentCandidates,
          settings,
        );
        usedRight.add(selected.candidate.index);
        pairs.add(selected.pair);
        continue;
      }

      final bucket = _amountBucket(leftItem.amount, settings.amountTolerance);
      MatchPair? best;
      int? bestIndex;

      for (var candidateBucket = bucket - 1;
          candidateBucket <= bucket + 1;
          candidateBucket++) {
        for (final candidate in amountIndex[candidateBucket] ?? const <_IndexedRecord>[]) {
          if (usedRight.contains(candidate.index)) continue;
          final scored = _scoreByAmountAndDate(leftItem, candidate.record, settings);
          if (scored.score <= 0) continue;
          if (best == null || scored.score > best.score) {
            best = scored;
            bestIndex = candidate.index;
            if (scored.score == 90) break;
          }
        }
        if (best?.score == 90) break;
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

  _DocumentSelection _bestDocumentCandidate(
    TransactionRecord left,
    List<_IndexedRecord> candidates,
    ReconciliationSettings settings,
  ) {
    _IndexedRecord selected = candidates.first;
    var smallestDifference = (left.amount - selected.record.amount).abs();

    for (final candidate in candidates.skip(1)) {
      final difference = (left.amount - candidate.record.amount).abs();
      if (difference < smallestDifference) {
        selected = candidate;
        smallestDifference = difference;
      }
    }

    final amountMatches = smallestDifference <= settings.amountTolerance;
    return _DocumentSelection(
      candidate: selected,
      pair: MatchPair(
        left: left,
        right: selected.record,
        status: amountMatches ? MatchStatus.matched : MatchStatus.unmatched,
        reason: amountMatches
            ? 'تطابق رقم المستند والمبلغ'
            : 'نفس رقم المستند لكن المبلغ مختلف — يحتاج مراجعة',
        score: amountMatches ? 100 : 1,
      ),
    );
  }

  int _amountBucket(double amount, double tolerance) => (amount / tolerance).floor();

  MatchPair _scoreByAmountAndDate(
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
    if (bothHaveDocuments && leftDocument != rightDocument) {
      return _noMatch(left, right, 'رقم المستند مختلف');
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

class _DocumentSelection {
  const _DocumentSelection({required this.candidate, required this.pair});

  final _IndexedRecord candidate;
  final MatchPair pair;
}
