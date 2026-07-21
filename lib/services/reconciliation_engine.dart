import '../models/transaction_record.dart';

class ReconciliationSettings {
  const ReconciliationSettings({
    this.allowedDateDifferenceDays = 3,
    this.amountTolerance = 0.01,
    this.mode = ReconciliationMode.parties,
    this.documentMismatchRule = DocumentMismatchRule.unmatched,
  });

  final int allowedDateDifferenceDays;
  final double amountTolerance;
  final ReconciliationMode mode;
  final DocumentMismatchRule documentMismatchRule;

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
          .putIfAbsent(
            _bucket(item.record.amount, settings.amountTolerance),
            () => [],
          )
          .add(item);
    }

    final used = <int>{};
    final pairs = <MatchPair>[];
    for (final item in left) {
      final decision = _selectBest(
        item,
        documentIndex,
        amountIndex,
        used,
        settings,
      );
      if (decision.index != null &&
          decision.pair.status != MatchStatus.unmatched) {
        used.add(decision.index!);
      }
      pairs.add(decision.pair);
    }

    return ReconciliationResult(
      pairs: List.unmodifiable(pairs),
      unmatchedRight: List.unmodifiable(
        indexed
            .where((item) => !used.contains(item.index))
            .map((item) => item.record),
      ),
    );
  }

  _Decision _selectBest(
    TransactionRecord left,
    Map<String, List<_IndexedRecord>> documentIndex,
    Map<int, List<_IndexedRecord>> amountIndex,
    Set<int> used,
    ReconciliationSettings settings,
  ) {
    final candidates = <_IndexedRecord>[];
    final seen = <int>{};
    final document = left.normalizedDocumentNumber;

    if (document.isNotEmpty) {
      for (final item
          in documentIndex[document] ?? const <_IndexedRecord>[]) {
        if (!used.contains(item.index) && seen.add(item.index)) {
          candidates.add(item);
        }
      }
    }

    // عند غياب رقم المستند في أحد الطرفين، أو عدم وجود الرقم نفسه،
    // نبحث في المبلغ والتاريخ مع إبقاء اختلاف أرقام المستندات سبباً للرفض.
    if (candidates.isEmpty) {
      final bucket = _bucket(left.amount, settings.amountTolerance);
      for (var current = bucket - 1; current <= bucket + 1; current++) {
        for (final item
            in amountIndex[current] ?? const <_IndexedRecord>[]) {
          if (!used.contains(item.index) && seen.add(item.index)) {
            candidates.add(item);
          }
        }
      }
    }

    MatchPair? bestMatch;
    int? bestIndex;
    MatchPair? bestRejection;
    for (final candidate in candidates) {
      final scored = _score(left, candidate.record, settings);
      if (scored.status != MatchStatus.unmatched) {
        if (bestMatch == null || scored.score > bestMatch.score) {
          bestMatch = scored;
          bestIndex = candidate.index;
        }
      } else if (bestRejection == null ||
          scored.score > bestRejection.score) {
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
      if (left.side == EntrySide.unknown ||
          right.side == EntrySide.unknown) {
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
    final bothHaveDocuments =
        leftDocument.isNotEmpty && rightDocument.isNotEmpty;
    final dateDifference = left.date.difference(right.date).inDays.abs();
    if (dateDifference > settings.allowedDateDifferenceDays) {
      return _no(left, right, 'فرق التاريخ أكبر من المسموح', 5);
    }

    if (settings.mode == ReconciliationMode.parties &&
        bothHaveDocuments &&
        leftDocument != rightDocument) {
      return switch (settings.documentMismatchRule) {
        DocumentMismatchRule.unmatched =>
          _no(left, right, 'اختلاف رقم المستند', 6),
        DocumentMismatchRule.pending => MatchPair(
            left: left,
            right: right,
            status: MatchStatus.pending,
            reason: 'اختلاف رقم المستند — معلقة للمراجعة',
            score: 80,
          ),
        DocumentMismatchRule.matchedWithNote => MatchPair(
            left: left,
            right: right,
            status: MatchStatus.matched,
            reason: 'مطابقة مع ملاحظة: اختلاف رقم المستند',
            score: 80,
          ),
      };
    }

    final reason = bothHaveDocuments
        ? 'تطابق رقم المستند والمبلغ'
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

  int _bucket(double amount, double tolerance) =>
      (amount / tolerance).floor();

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
