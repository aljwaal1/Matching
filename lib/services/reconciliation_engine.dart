import '../models/transaction_record.dart';

class ReconciliationSettings {
  const ReconciliationSettings({this.allowedDateDifferenceDays = 3, this.amountTolerance = 0.01});
  final int allowedDateDifferenceDays;
  final double amountTolerance;
}

class ReconciliationEngine {
  const ReconciliationEngine();

  ReconciliationResult reconcile({required List<TransactionRecord> left, required List<TransactionRecord> right, required ReconciliationSettings settings}) {
    if (settings.amountTolerance <= 0) throw ArgumentError.value(settings.amountTolerance, 'amountTolerance');
    final used = <String>{};
    final pairs = <MatchPair>[];

    for (final item in left) {
      MatchPair? best;
      for (final candidate in right) {
        if (used.contains(candidate.id)) continue;
        final scored = _score(item, candidate, settings);
        if (scored.status != MatchStatus.unmatched && (best == null || scored.score > best.score)) best = scored;
      }
      if (best == null) {
        pairs.add(MatchPair(left: item, right: null, status: MatchStatus.unmatched, reason: 'لا توجد عملية مقابلة', score: 0));
      } else {
        used.add(best.right!.id);
        pairs.add(best);
      }
    }

    return ReconciliationResult(
      pairs: List.unmodifiable(pairs),
      unmatchedRight: List.unmodifiable(right.where((r) => !used.contains(r.id))),
    );
  }

  MatchPair _score(TransactionRecord left, TransactionRecord right, ReconciliationSettings s) {
    final amountMatches = (left.amount - right.amount).abs() <= s.amountTolerance;
    final ld = left.normalizedDocumentNumber;
    final rd = right.normalizedDocumentNumber;
    final bothDocs = ld.isNotEmpty && rd.isNotEmpty;
    final days = left.date.difference(right.date).inDays.abs();

    if (bothDocs) {
      if (ld != rd) return _no(left, right, 'رقم المستند مختلف');
      if (!amountMatches) return _no(left, right, 'نفس رقم المستند لكن المبلغ مختلف');
      return MatchPair(left: left, right: right, status: MatchStatus.matched, reason: 'تطابق رقم المستند والمبلغ', score: 100 - days.toDouble());
    }
    if (!amountMatches) return _no(left, right, 'المبلغ مختلف');
    if (days > s.allowedDateDifferenceDays) return _no(left, right, 'فرق التاريخ أكبر من المسموح');
    return MatchPair(left: left, right: right, status: MatchStatus.matched, reason: days == 0 ? 'تطابق المبلغ والتاريخ' : 'تطابق المبلغ مع فرق تاريخ $days يوم', score: 90 - days.toDouble());
  }

  MatchPair _no(TransactionRecord l, TransactionRecord r, String reason) => MatchPair(left: l, right: r, status: MatchStatus.unmatched, reason: reason, score: 0);
}
