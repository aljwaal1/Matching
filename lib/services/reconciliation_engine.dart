import '../models/transaction_record.dart';

class ReconciliationSettings {
  const ReconciliationSettings({
    this.allowedDateDifferenceDays = 3,
    this.amountTolerance = 0.01,
    this.requireOppositeEntrySides = true,
  });

  final int allowedDateDifferenceDays;
  final double amountTolerance;
  final bool requireOppositeEntrySides;
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

    final used = <String>{};
    final pairs = <MatchPair>[];

    for (final item in left) {
      MatchPair? best;
      for (final candidate in right) {
        if (used.contains(candidate.id)) continue;
        final scored = _score(item, candidate, settings);
        if (scored.status != MatchStatus.unmatched &&
            (best == null || scored.score > best.score)) {
          best = scored;
        }
      }

      if (best == null) {
        pairs.add(MatchPair(
          left: item,
          right: null,
          status: MatchStatus.unmatched,
          reason: 'لا توجد عملية مقابلة',
          score: 0,
        ));
      } else {
        used.add(best.right!.id);
        pairs.add(best);
      }
    }

    return ReconciliationResult(
      pairs: List.unmodifiable(pairs),
      unmatchedRight: List.unmodifiable(right.where((record) => !used.contains(record.id))),
    );
  }

  MatchPair _score(
    TransactionRecord left,
    TransactionRecord right,
    ReconciliationSettings settings,
  ) {
    // عند رفع الملف نفسه مرتين تكون معرفات الصفوف متطابقة، ولا يجوز اعتبارها مطابقة محاسبية.
    if (left.id == right.id) {
      return _no(left, right, 'تم رفع العملية نفسها في الطرفين');
    }

    if (settings.requireOppositeEntrySides &&
        left.side != EntrySide.unknown &&
        right.side != EntrySide.unknown &&
        left.side == right.side) {
      return _no(
        left,
        right,
        'جهة الحركة متشابهة (${left.sideLabel}) ويجب أن يكون المدين مقابل الدائن',
      );
    }

    final amountMatches =
        (left.amount - right.amount).abs() <= settings.amountTolerance;
    final leftDocument = left.normalizedDocumentNumber;
    final rightDocument = right.normalizedDocumentNumber;
    final bothHaveDocuments =
        leftDocument.isNotEmpty && rightDocument.isNotEmpty;
    final dateDifference =
        left.date.difference(right.date).inDays.abs();

    if (bothHaveDocuments) {
      if (leftDocument != rightDocument) {
        return _no(left, right, 'رقم المستند مختلف');
      }
      if (!amountMatches) {
        return _no(left, right, 'نفس رقم المستند لكن المبلغ مختلف');
      }
      return MatchPair(
        left: left,
        right: right,
        status: MatchStatus.matched,
        reason: _matchedReason('تطابق رقم المستند والمبلغ', left, right),
        score: 100 - dateDifference.toDouble(),
      );
    }

    if (!amountMatches) return _no(left, right, 'المبلغ مختلف');
    if (dateDifference > settings.allowedDateDifferenceDays) {
      return _no(left, right, 'فرق التاريخ أكبر من المسموح');
    }

    final baseReason = dateDifference == 0
        ? 'تطابق المبلغ والتاريخ'
        : 'تطابق المبلغ مع فرق تاريخ $dateDifference يوم';
    return MatchPair(
      left: left,
      right: right,
      status: MatchStatus.matched,
      reason: _matchedReason(baseReason, left, right),
      score: 90 - dateDifference.toDouble(),
    );
  }

  String _matchedReason(
    String base,
    TransactionRecord left,
    TransactionRecord right,
  ) {
    if (left.side == EntrySide.unknown || right.side == EntrySide.unknown) {
      return base;
    }
    return '$base — ${left.sideLabel} مقابل ${right.sideLabel}';
  }

  MatchPair _no(
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
