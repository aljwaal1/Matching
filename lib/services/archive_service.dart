import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_record.dart';

class ArchivedReconciliation {
  const ArchivedReconciliation({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.firstName,
    required this.secondName,
    required this.result,
    this.firstBalance,
    this.secondBalance,
    this.firstBalanceRowNumber,
    this.secondBalanceRowNumber,
  });

  final String id;
  final String name;
  final String type;
  final DateTime createdAt;
  final String firstName;
  final String secondName;
  final ReconciliationResult result;
  final double? firstBalance;
  final double? secondBalance;
  final int? firstBalanceRowNumber;
  final int? secondBalanceRowNumber;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'firstName': firstName,
        'secondName': secondName,
        'firstBalance': firstBalance,
        'secondBalance': secondBalance,
        'firstBalanceRowNumber': firstBalanceRowNumber,
        'secondBalanceRowNumber': secondBalanceRowNumber,
        'pairs': result.pairs
            .map((pair) => {
                  'left': _tx(pair.left),
                  'right': pair.right == null ? null : _tx(pair.right!),
                  'status': pair.status.name,
                  'reason': pair.reason,
                  'score': pair.score,
                })
            .toList(),
        'unmatchedRight': result.unmatchedRight.map(_tx).toList(),
      };

  factory ArchivedReconciliation.fromJson(Map<String, dynamic> json) =>
      ArchivedReconciliation(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        firstName: json['firstName'] as String,
        secondName: json['secondName'] as String,
        firstBalance: (json['firstBalance'] as num?)?.toDouble(),
        secondBalance: (json['secondBalance'] as num?)?.toDouble(),
        firstBalanceRowNumber: json['firstBalanceRowNumber'] as int?,
        secondBalanceRowNumber: json['secondBalanceRowNumber'] as int?,
        result: ReconciliationResult(
          pairs: (json['pairs'] as List).map((value) {
            final map = Map<String, dynamic>.from(value as Map);
            return MatchPair(
              left: _fromTx(Map<String, dynamic>.from(map['left'] as Map)),
              right: map['right'] == null
                  ? null
                  : _fromTx(Map<String, dynamic>.from(map['right'] as Map)),
              status: MatchStatus.values.byName(map['status'] as String),
              reason: map['reason'] as String,
              score: (map['score'] as num).toDouble(),
            );
          }).toList(),
          unmatchedRight: (json['unmatchedRight'] as List)
              .map((value) => _fromTx(Map<String, dynamic>.from(value as Map)))
              .toList(),
        ),
      );

  static Map<String, dynamic> _tx(TransactionRecord item) => {
        'id': item.id,
        'date': item.date.toIso8601String(),
        'amount': item.amount,
        'documentNumber': item.documentNumber,
        'description': item.description,
        'sourceRow': item.sourceRow,
        'side': item.side.name,
        'balance': item.balance,
      };

  static TransactionRecord _fromTx(Map<String, dynamic> map) => TransactionRecord(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        amount: (map['amount'] as num).toDouble(),
        documentNumber: map['documentNumber'] as String?,
        description: map['description'] as String? ?? '',
        sourceRow: map['sourceRow'] as int?,
        side: EntrySide.values.byName(map['side'] as String? ?? 'unknown'),
        balance: (map['balance'] as num?)?.toDouble(),
      );
}

class ArchiveService {
  static const _key = 'matching_archive_v2';

  Future<List<ArchivedReconciliation>> load({String? type}) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_key) ?? const [];
    final items = <ArchivedReconciliation>[];
    for (final value in raw) {
      try {
        final item = ArchivedReconciliation.fromJson(
          Map<String, dynamic>.from(jsonDecode(value) as Map),
        );
        if (type == null || item.type == type) items.add(item);
      } catch (_) {
        // لا نسمح لسجل قديم أو تالف بإيقاف الأرشيف كله.
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> save(ArchivedReconciliation item) async {
    final preferences = await SharedPreferences.getInstance();
    final items = await load();
    items.removeWhere((existing) => existing.id == item.id);
    items.add(item);
    await preferences.setStringList(
      _key,
      items.map((value) => jsonEncode(value.toJson())).toList(),
    );
  }

  Future<void> delete(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final items = await load();
    items.removeWhere((item) => item.id == id);
    await preferences.setStringList(
      _key,
      items.map((value) => jsonEncode(value.toJson())).toList(),
    );
  }
}
