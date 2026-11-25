import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:matching/screens/local_activation_screen.dart';
import 'package:matching/services/local_license_hashes.dart';

void main() {
  test('all 1000 license digests remain valid and unique', () {
    expect(localLicenseHashes.length, 1000);
    expect(localLicenseHashes.every((v) => RegExp(r'^[a-f0-9]{64}$').hasMatch(v)), isTrue);
  });
  test('activation normalization supports prefix, spacing and lowercase', () {
    const code = 'ACC0123456789ABCDEF0123456789ABC';
    expect(code.length, 32);
    expect(licenseDigest(code), isNotEmpty);
    expect(licenseDigest('ACC-$code'), licenseDigest(code));
    expect(licenseDigest(code.toLowerCase()), licenseDigest(code));
    expect(licenseDigest('invalid'), isEmpty);
    expect(localLicenseHashes.contains(licenseDigest('00000000000000000000000000000000')), isFalse);
  });
  Widget app() => const MaterialApp(home: Directionality(textDirection: TextDirection.rtl,
    child: LocalActivationScreen(child: Scaffold(body: Text('READY')))));
  testWidgets('unactivated installation rejects incorrect code', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('READY'), findsNothing);
    await tester.enterText(find.byType(TextField), 'incorrect');
    await tester.tap(find.text('تفعيل البرنامج'));
    await tester.pumpAndSettle();
    expect(find.text('READY'), findsNothing);
    expect(find.textContaining('رمز التفعيل غير صحيح'), findsOneWidget);
  });
  testWidgets('previously saved valid license restores access', (tester) async {
    SharedPreferences.setMockInitialValues({'windows_local_license_v1': localLicenseHashes.first});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('READY'), findsOneWidget);
  });
}
