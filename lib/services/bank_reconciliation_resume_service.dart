import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bank_reconciliation.dart';

class BankReconciliationResumeData {
  const BankReconciliationResumeData({
    required this.firstName,
    required this.secondName,
    required this.statement,
  });

  final String firstName;
  final String secondName;
  final BankReconciliationStatement statement;
}

class BankReconciliationResumeService {
  const BankReconciliationResumeService();

  static const _key = 'bank_reconciliation_export_resume_v1';

  Future<void> save({
    required String firstName,
    required String secondName,
    required BankReconciliationStatement statement,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _key,
      jsonEncode({
        'firstName': firstName,
        'secondName': secondName,
        'statement': statement.toJson(),
      }),
    );
    if (!saved) {
      throw StateError('تعذر حفظ حالة شاشة التسوية مؤقتًا.');
    }
  }

  Future<BankReconciliationResumeData?> take() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return null;
    await preferences.remove(_key);

    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return BankReconciliationResumeData(
        firstName: json['firstName'] as String? ?? 'دفاتر الشركة',
        secondName: json['secondName'] as String? ?? 'كشف البنك',
        statement: BankReconciliationStatement.fromJson(
          Map<String, dynamic>.from(json['statement'] as Map),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
