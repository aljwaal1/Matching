import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_record.dart';

class ArchivedReconciliation {
  const ArchivedReconciliation({required this.id, required this.name, required this.type, required this.createdAt, required this.firstName, required this.secondName, required this.result});
  final String id;
  final String name;
  final String type;
  final DateTime createdAt;
  final String firstName;
  final String secondName;
  final ReconciliationResult result;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'type': type, 'createdAt': createdAt.toIso8601String(),
    'firstName': firstName, 'secondName': secondName,
    'pairs': result.pairs.map((p) => {'left': _tx(p.left), 'right': p.right == null ? null : _tx(p.right!), 'status': p.status.name, 'reason': p.reason, 'score': p.score}).toList(),
    'unmatchedRight': result.unmatchedRight.map(_tx).toList(),
  };

  factory ArchivedReconciliation.fromJson(Map<String, dynamic> j) => ArchivedReconciliation(
    id: j['id'] as String,
    name: j['name'] as String,
    type: j['type'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    firstName: j['firstName'] as String,
    secondName: j['secondName'] as String,
    result: ReconciliationResult(
      pairs: (j['pairs'] as List).map((e) { final m = Map<String,dynamic>.from(e as Map); return MatchPair(left: _fromTx(Map<String,dynamic>.from(m['left'] as Map)), right: m['right'] == null ? null : _fromTx(Map<String,dynamic>.from(m['right'] as Map)), status: MatchStatus.values.firstWhere((s) => s.name == m['status']), reason: m['reason'] as String, score: (m['score'] as num).toDouble()); }).toList(),
      unmatchedRight: (j['unmatchedRight'] as List).map((e) => _fromTx(Map<String,dynamic>.from(e as Map))).toList(),
    ),
  );

  static Map<String,dynamic> _tx(TransactionRecord t) => {'id':t.id,'date':t.date.toIso8601String(),'amount':t.amount,'documentNumber':t.documentNumber,'description':t.description,'sourceRow':t.sourceRow};
  static TransactionRecord _fromTx(Map<String,dynamic> m) => TransactionRecord(id:m['id'] as String,date:DateTime.parse(m['date'] as String),amount:(m['amount'] as num).toDouble(),documentNumber:m['documentNumber'] as String?,description:m['description'] as String? ?? '',sourceRow:m['sourceRow'] as int?);
}

class ArchiveService {
  static const _key = 'matching_archive_v1';

  Future<List<ArchivedReconciliation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final items = raw.map((s) => ArchivedReconciliation.fromJson(Map<String,dynamic>.from(jsonDecode(s) as Map))).toList();
    items.sort((a,b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> save(ArchivedReconciliation item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await load();
    items.removeWhere((e) => e.id == item.id);
    items.add(item);
    await prefs.setStringList(_key, items.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await load();
    items.removeWhere((e) => e.id == id);
    await prefs.setStringList(_key, items.map((e) => jsonEncode(e.toJson())).toList());
  }
}
