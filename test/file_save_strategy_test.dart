import 'package:flutter_test/flutter_test.dart';
import 'package:matching/services/file_save_service.dart';

void main() {
  test('keeps Excel on file_picker and PDF on native Android writer', () {
    expect(usesNativeAndroidWriterForExtension('pdf'), isTrue);
    expect(usesNativeAndroidWriterForExtension('PDF'), isTrue);

    expect(usesNativeAndroidWriterForExtension('xlsx'), isFalse);
    expect(usesNativeAndroidWriterForExtension('xls'), isFalse);
    expect(usesNativeAndroidWriterForExtension('csv'), isFalse);
  });
}
