import 'package:flutter_test/flutter_test.dart';
import 'package:matching/models/transaction_record.dart';
import 'package:matching/services/archive_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('يحفظ الأرشيف جهة الحركة ويستعيدها', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ArchiveService();
    final left = TransactionRecord(
      id: 'L1',
      date: DateTime(2026, 1, 1),
      amount: 100,
      side: EntrySide.debit,
    );
    final right = TransactionRecord(
      id: 'R1',
      date: DateTime(2026, 1, 1),
      amount: 100,
      side: EntrySide.credit,
    );
    await service.save(
      ArchivedReconciliation(
        id: '1',
        name: 'اختبار',
        type: ReconciliationMode.parties.name,
        createdAt: DateTime(2026, 1, 2),
        firstName: 'الأول',
        secondName: 'الثاني',
        result: ReconciliationResult(
          pairs: [
            MatchPair(
              left: left,
              right: right,
              status: MatchStatus.matched,
              reason: 'اختبار',
              score: 100,
            ),
          ],
          unmatchedRight: const [],
        ),
      ),
    );
    final loaded = await service.load(type: ReconciliationMode.parties.name);
    expect(loaded, hasLength(1));
    expect(loaded.single.result.pairs.single.left.side, EntrySide.debit);
    expect(loaded.single.result.pairs.single.right!.side, EntrySide.credit);
  });

  test('يرحل أرشيف v1 دون حذف النسخة القديمة', () async {
    final legacy = ArchivedReconciliation(
      id: 'legacy',
      name: 'قديم',
      type: ReconciliationMode.parties.name,
      createdAt: DateTime(2026, 1, 1),
      firstName: 'الأول',
      secondName: 'الثاني',
      result: const ReconciliationResult(pairs: [], unmatchedRight: []),
    );
    final encoded = jsonEncode(legacy.toJson());
    SharedPreferences.setMockInitialValues({
      'matching_archive_v1': [encoded],
    });

    final loaded = await ArchiveService().load();
    final preferences = await SharedPreferences.getInstance();

    expect(loaded.single.id, 'legacy');
    expect(preferences.getStringList('matching_archive_v2'), [encoded]);
    expect(preferences.getStringList('matching_archive_v1'), [encoded]);
  });

  test('لا يحذف السجل التالف عند حفظ سجل جديد', () async {
    SharedPreferences.setMockInitialValues({
      'matching_archive_v2': ['not-json'],
    });
    await ArchiveService().save(
      ArchivedReconciliation(
        id: 'new',
        name: 'جديد',
        type: ReconciliationMode.parties.name,
        createdAt: DateTime(2026, 1, 2),
        firstName: 'الأول',
        secondName: 'الثاني',
        result: const ReconciliationResult(pairs: [], unmatchedRight: []),
      ),
    );

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('matching_archive_v2'),
      contains('not-json'),
    );
  });
}
import 'dart:convert';
