import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matching/main.dart';
import 'package:matching/models/transaction_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final arabicFont = FontLoader('NotoNaskhArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf'));
    await arabicFont.load();

    final latinFont = File(
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    );
    if (latinFont.existsSync()) {
      final bytes = await latinFont.readAsBytes();
      final roboto = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await roboto.load();
    }

    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final bytes = await File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await icons.load();
    }
  });

  Future<void> capture(
    WidgetTester tester,
    Widget screen,
    String fileName,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MatchingApp(home: screen));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../google-play/screenshots/$fileName'),
    );
  }

  testWidgets('home', (tester) async {
    await capture(
      tester,
      const HomeScreen(enableAds: false),
      '01-home.png',
    );
  });

  testWidgets('party reconciliation setup', (tester) async {
    await capture(
      tester,
      const SetupScreen(mode: ReconciliationMode.parties),
      '02-party-matching.png',
    );
  });

  testWidgets('bank reconciliation setup', (tester) async {
    await capture(
      tester,
      const SetupScreen(mode: ReconciliationMode.bank),
      '03-bank-reconciliation.png',
    );
  });

  testWidgets('results and exports', (tester) async {
    final first = TransactionRecord(
      id: 'left-1',
      date: DateTime(2026, 7, 15),
      amount: 1250,
      documentNumber: 'INV-1042',
      description: 'فاتورة مبيعات',
      side: EntrySide.debit,
      balance: 8400,
    );
    final second = TransactionRecord(
      id: 'right-1',
      date: DateTime(2026, 7, 15),
      amount: 1250,
      documentNumber: 'INV-1042',
      description: 'فاتورة مشتريات',
      side: EntrySide.credit,
      balance: 7150,
    );
    final pendingLeft = TransactionRecord(
      id: 'left-2',
      date: DateTime(2026, 7, 18),
      amount: 675.50,
      documentNumber: 'DOC-220',
      description: 'دفعة عميل',
      side: EntrySide.debit,
      balance: 9075.50,
    );
    final pendingRight = TransactionRecord(
      id: 'right-2',
      date: DateTime(2026, 7, 19),
      amount: 675.50,
      documentNumber: 'DOC-221',
      description: 'دفعة مورد',
      side: EntrySide.credit,
      balance: 6474.50,
    );
    final result = ReconciliationResult(
      pairs: [
        MatchPair(
          left: first,
          right: second,
          status: MatchStatus.matched,
          reason: 'تطابق رقم المستند والمبلغ — مدين مقابل دائن',
          score: 100,
        ),
        MatchPair(
          left: pendingLeft,
          right: pendingRight,
          status: MatchStatus.pending,
          reason: 'اختلاف رقم المستند — معلقة للمراجعة',
          score: 80,
        ),
      ],
      unmatchedRight: const [],
    );
    await capture(
      tester,
      ResultsScreen(
        mode: ReconciliationMode.parties,
        firstName: 'كشف العملاء.xlsx',
        secondName: 'كشف الموردين.xlsx',
        result: result,
        firstDetectedBalance: 9075.50,
        secondDetectedBalance: 6474.50,
      ),
      '04-results-and-exports.png',
    );
  });

  testWidgets('archive', (tester) async {
    await capture(
      tester,
      const ArchiveHomeScreen(),
      '05-archive.png',
    );
  });
}
