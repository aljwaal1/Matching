import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matching/main.dart';

void main() {
  testWidgets('Matching launches with Arabic RTL and desktop-safe home', (tester) async {
    await tester.pumpWidget(const MatchingApp(home: Scaffold(body: Text('مطابقة الحسابات'))));
    expect(find.text('مطابقة الحسابات'), findsOneWidget);
    final context = tester.element(find.text('مطابقة الحسابات'));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });
}
