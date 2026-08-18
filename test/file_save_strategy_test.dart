import 'package:flutter_test/flutter_test.dart';
import 'package:matching/services/file_save_service.dart';

void main() {
  test('uses native Android writer for report formats that need reliable saving', () {
    expect(usesNativeAndroidWriterForExtension('pdf'), isTrue);
    expect(usesNativeAndroidWriterForExtension('PDF'), isTrue);
    expect(usesNativeAndroidWriterForExtension('xlsx'), isTrue);
    expect(usesNativeAndroidWriterForExtension('xls'), isTrue);
    expect(usesNativeAndroidWriterForExtension('csv'), isTrue);
  });
}
