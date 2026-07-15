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
  });

  final String id;
  final String name;
  final String type;
  final DateTime createdAt;
  final String firstName;
  final String secondName;
  final ReconciliationResult result;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'firstName': firstName,
        'secondName': secondName,
        'result': _resultToJson(result),
      };

  factory ArchivedReconciliation.fromJson(Map<String, dynamic> json) =>
      ArchivedReconciliation(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        firstName: json['firstName'] as String,
        secondName: json['secondName'] as String,
        result: _resultFromJson(json['result'] as Map<String, dynamic>),
      );

  static Map<String, dynamic> _recordToJson(TransactionRecord item) => {
        'id': item.id,
        'date': item.date.toIso8601String(),
        'amount': item.amount,
        'documentNumber': item.documentNumber,
        'description': item.description,
        'sourceRow': item.sourceRow,
      };

  static TransactionRecord _recordFromJson(Map<String, dynamic> json) =>
      TransactionRecord(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num).toDouble(),
        documentNumber: json['documentNumber'] as String?,
        description: json['description'] as String? ?? '',
        sourceRow: json['sourceRow'] as int?,
      );

  static Map<String, dynamic> _resultToJson(ReconciliationResult result) => {
        'pairs': result.pairs
            .map((pair) => {
                  'left': _recordToJson(pair.left),
                  'right': pair.right == null ? null : _recordToJson(pair.right!),
                  'status': pair.status.name,
                  'reason': pair.reason,
                  'score': pair.score,
                })
            .toList(),
        'unmatchedRight': result.unmatchedRight.map(_recordToJson).toList(),
      };

  static ReconciliationResult _resultFromJson(Map<String, dynamic> json) =>
      ReconciliationResult(
        pairs: (json['pairs'] as List)
            .map((value) {
              final item = value as Map<String, dynamic>;
              return MatchPair(
                left: _recordFromJson(item['left'] as Map<String, dynamic>),
                right: item['right'] == null
                    ? null
                    : _recordFromJson(item['right'] as Map<String, dynamic>),
                status: MatchStatus.values.byName(item['status'] as String),
                reason: item['reason'] as String,
                score: (item['score'] as num).toDouble(),
              );
            })
            .toList(),
        unmatchedRight: (json['unmatchedRight'] as List)
            .map((value) => _recordFromJson(value as Map<String, dynamic>))
            .toList(),
      );
}

class ArchiveService {
  static const _storageKey = 'matching_archives_v1';

  Future<List<ArchivedReconciliation>> load({String? type}) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_storageKey) ?? const [];
    final all = raw
        .map((value) => ArchivedReconciliation.fromJson(
              jsonDecode(value) as Map<String, dynamic>,
            ))
        .where((item) => type == null || item.type == type)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  Future<void> save(ArchivedReconciliation item) async {
    final preferences = await SharedPreferences.getInstance();
    final all = await load();
    all.removeWhere((existing) => existing.id == item.id);
    all.add(item);
    await preferences.setStringList(
      _storageKey,
      all.map((value) => jsonEncode(value.toJson())).toList(),
    );
  }

  Future<void> delete(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final all = await load();
    all.removeWhere((item) => item.id == id);
    await preferences.setStringList(
      _storageKey,
      all.map((value) => jsonEncode(value.toJson())).toList(),
    );
  }
}
