import '../models/transaction_record.dart';

class ReconciliationSettings {
  const ReconciliationSettings({
    this.allowedDateDifferenceDays = 3,
    this.amountTolerance = 0.01,
    this.mode = ReconciliationMode.parties,
  });

  final int allowedDateDifferenceDays;
  final double amountTolerance;
  final ReconciliationMode mode;

  bool get requireOppositeEntrySides => mode == ReconciliationMode.parties;
}

class ReconciliationEngine {
  const ReconciliationEngine();

  ReconciliationResult reconcile({
    required List<TransactionRecord> left,
    required List<TransactionRecord> right,
    required ReconciliationSettings settings,
  }) {
    if (settings.amountTolerance <= 0) {
      throw ArgumentError.value(settings.amountTolerance, 'amountTolerance');
    }
    if (settings.allowedDateDifferenceDays < 0) {
      throw ArgumentError.value(
        settings.allowedDateDifferenceDays,
        'allowedDateDifferenceDays',
      );
    }

    final indexed = List.generate(
      right.length,
      (index) => _IndexedRecord(index, right[index]),
      growable: false,
    );
    final documentIndex = <String, List<_IndexedRecord>>{};
    final amountIndex = <int, List<_IndexedRecord>>{};
    for (final item in indexed) {
      final document = item.record.normalizedDocumentNumber;
      if (document.isNotEmpty) {
        documentIndex.putIfAbsent(document, () => []).add(item);
      }
      amountIndex
          .putIfAbsent(_bucket(item.record.amount, settings.amountTolerance), () => [])
          .add(item);
    }

    final used = <int>{};
    final pairs = <MatchPair>[];
    for (final item in left) {
      final decision = _selectBest(
        item,
        indexed,
        documentIndex,
        amountIndex,
        used,
        settings,
      );
      if (decision.index != null && decision.pair.status == MatchStatus.matched) {
        used.add(decision.index!);
      }
      pairs.add(decision.pair);
    }

    return ReconciliationResult(
      pairs: List.unmodifiable(pairs),
      unmatchedRight: List.unmodifiable(
        indexed.where((item) => !used.contains(item.index)).map((item) => item.record),
      ),
    );
  }

  _Decision _selectBest(
    TransactionRecord left,
    List<_IndexedRecord> allRight,
    Map<String, List<_IndexedRecord>> documentIndex,
    Map<int, List<_IndexedRecord>> amountIndex,
    Set<int> used,
    ReconciliationSettings settings,
  ) {
    final document = left.normalizedDocumentNumber;
    final candidates = <_IndexedRecord>[];

    if (document.isNotEmpty) {
      candidates.addAll(
        (documentIndex[document] ?? const <_IndexedRecord>[])
            .where((item) => !used.contains(item.index)),
      );
    } else {
      final bucket = _bucket(left.amount, settings.amountTolerance);
      for (var current = bucket - 1; current <= bucket + 1; current++) {
        candidates.addAll(
          (amountIndex[current] ?? const <_IndexedRecord>[])
              .where((item) => !used.contains(item.index)),
        );
      }
    }

    MatchPair? bestMatch;
    int? bestIndex;
    MatchPair? bestRejection;
    for (final candidate in candidates) {
      final scored = _score(left, candidate.record, settings);
      if (scored.status == MatchStatus.matched) {
        if (bestMatch == null || scored.score > bestMatch.score) {
          bestMatch = scored;
          bestIndex = candidate.index;
        }
      } else if (bestRejection == null || scored.score > bestRejection.score) {
        bestRejection = scored;
      }
    }

    if (bestMatch != null) return _Decision(bestMatch, bestIndex);
    if (bestRejection != null) return _Decision(bestRejection, null);

    return _Decision(
      MatchPair(
        left: left,
        right: null,
        status: MatchStatus.unmatched,
        reason: 'لا توجد عملية مقابلة ضمن شروط المطابقة',
        score: 0,
      ),
      null,
    );
  }

  MatchPair _score(
    TransactionRecord left,
    TransactionRecord right,
    ReconciliationSettings settings,
  ) {
    if (left.id == right.id) {
      return _no(left, right, 'الملفان يحتويان العملية نفسها', 8);
    }

    if (settings.requireOppositeEntrySides) {
      if (left.side == EntrySide.unknown || right.side == EntrySide.unknown) {
        return _no(
          left,
          right,
          'تعذر إثبات أن المدين يقابل الدائن لأن جهة الحركة غير محددة',
          7,
        );
      }
      if (left.side == right.side) {
        return _no(
          left,
          right,
          'جهة الحركة متشابهة (${left.sideLabel}) ويجب أن يكون المدين مقابل الدائن',
          9,
        );
      }
    }

    final amountDifference = (left.amount - right.amount).abs();
    if (amountDifference > settings.amountTolerance) {
      return _no(left, right, 'المبلغ مختلف', 4);
    }

    final leftDocument = left.normalizedDocumentNumber;
    final rightDocument = right.normalizedDocumentNumber;
    final bothHaveDocuments = leftDocument.isNotEmpty && rightDocument.isNotEmpty;
    if (bothHaveDocuments && leftDocument != rightDocument) {
      return _no(left, right, 'رقم المستند مختلف', 6);
    }

    final dateDifference = left.date.difference(right.date).inDays.abs();
    if (!bothHaveDocuments &&
        dateDifference > settings.allowedDateDifferenceDays) {
      return _no(left, right, 'فرق التاريخ أكبر من المسموح', 5);
    }

    final reason = bothHaveDocuments
        ? 'تطابق رقم المستند والمبلغ${dateDifference == 0 ? '' : ' — فرق التاريخ $dateDifference يوم'}'
        : dateDifference == 0
            ? 'تطابق المبلغ والتاريخ'
            : 'تطابق المبلغ مع فرق تاريخ $dateDifference يوم';
    final sideText = settings.requireOppositeEntrySides
        ? ' — ${left.sideLabel} مقابل ${right.sideLabel}'
        : '';
    return MatchPair(
      left: left,
      right: right,
      status: MatchStatus.matched,
      reason: '$reason$sideText',
      score: (bothHaveDocuments ? 100 : 90) - dateDifference.toDouble(),
    );
  }

  int _bucket(double amount, double tolerance) => (amount / tolerance).floor();

  MatchPair _no(
    TransactionRecord left,
    TransactionRecord right,
    String reason,
    double score,
  ) =>
      MatchPair(
        left: left,
        right: right,
        status: MatchStatus.unmatched,
        reason: reason,
        score: score,
      );
}

class _IndexedRecord {
  const _IndexedRecord(this.index, this.record);
  final int index;
  final TransactionRecord record;
}

class _Decision {
  const _Decision(this.pair, this.index);
  final MatchPair pair;
  final int? index;
}
