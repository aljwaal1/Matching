import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bank_reconciliation.dart';

class BankReconciliationArchiveService {
  static const _key = 'bank_reconciliation_archive_v1';

  Future<List<BankReconciliationStatement>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_key) ?? const <String>[];
    final statements = <BankReconciliationStatement>[];

    for (final value in raw) {
      try {
        statements.add(
          BankReconciliationStatement.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          ),
        );
      } catch (_) {
        // نتجاوز السجل التالف ولا نوقف الأرشيف كاملًا.
      }
    }

    statements.sort((a, b) => b.period.compareTo(a.period));
    return statements;
  }

  Future<void> save(BankReconciliationStatement statement) async {
    final normalizedAccount = _normalizeAccount(statement.accountName);
    if (normalizedAccount.isEmpty) {
      throw const FormatException('أدخل اسم البنك أو الحساب قبل الحفظ.');
    }

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_key) ?? const <String>[];
    final updated = raw.where((value) {
      try {
        final existing = BankReconciliationStatement.fromJson(
          Map<String, dynamic>.from(jsonDecode(value) as Map),
        );
        return _normalizeAccount(existing.accountName) != normalizedAccount ||
            existing.period.year != statement.period.year ||
            existing.period.month != statement.period.month;
      } catch (_) {
        return true;
      }
    }).toList()
      ..add(
        jsonEncode(
          statement
              .copyWith(
                accountName: statement.accountName.trim(),
                period: DateTime(statement.period.year, statement.period.month),
              )
              .toJson(),
        ),
      );
    final saved = await preferences.setStringList(_key, updated);
    if (!saved) throw StateError('تعذر حفظ التسوية في الأرشيف.');
  }

  Future<BankReconciliationStatement?> latestPrevious({
    required String accountName,
    required DateTime beforePeriod,
  }) async {
    final normalizedAccount = _normalizeAccount(accountName);
    if (normalizedAccount.isEmpty) return null;

    final candidates = (await loadAll())
        .where(
          (item) =>
              _normalizeAccount(item.accountName) == normalizedAccount &&
              item.period.isBefore(
                DateTime(beforePeriod.year, beforePeriod.month),
              ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.period.compareTo(a.period));

    return candidates.isEmpty ? null : candidates.first;
  }

  Future<List<BankAdjustmentItem>> pendingFromPrevious({
    required String accountName,
    required DateTime beforePeriod,
    Iterable<BankAdjustmentItem> currentItems = const [],
  }) async {
    final previous = await latestPrevious(
      accountName: accountName,
      beforePeriod: beforePeriod,
    );
    if (previous == null) return const [];

    final currentKeys = currentItems
        .map((item) => item.deduplicationKey)
        .toSet();
    final seen = <String>{};
    final result = <BankAdjustmentItem>[];

    for (final item in previous.items) {
      if (item.cleared || !item.shouldCarryForward) continue;
      final key = item.deduplicationKey;
      if (currentKeys.contains(key) || !seen.add(key)) continue;
      result.add(
        item.copyWith(
          fromPreviousPeriod: true,
          status: BankItemStatus.pending,
        ),
      );
    }

    return List.unmodifiable(result);
  }

  Future<void> delete({
    required String accountName,
    required DateTime period,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final normalizedAccount = _normalizeAccount(accountName);
    final raw = preferences.getStringList(_key) ?? const <String>[];
    final updated = raw.where((value) {
      try {
        final item = BankReconciliationStatement.fromJson(
          Map<String, dynamic>.from(jsonDecode(value) as Map),
        );
        return _normalizeAccount(item.accountName) != normalizedAccount ||
            item.period.year != period.year ||
            item.period.month != period.month;
      } catch (_) {
        return true;
      }
    }).toList(growable: false);
    final saved = await preferences.setStringList(_key, updated);
    if (!saved) throw StateError('تعذر حذف التسوية من الأرشيف.');
  }

  String _normalizeAccount(String value) => value
      .trim()
      .toLowerCase()
      .replaceFirst(
        RegExp(r'\.(xlsx|xls|csv|tsv|txt|pdf)$', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ');
}
