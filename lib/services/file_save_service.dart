import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class SavedReport {
  const SavedReport({required this.fileName, required this.location});

  final String fileName;
  final String location;
}

class FileSaveService {
  const FileSaveService();

  Future<SavedReport?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String extension,
    String? dialogTitle,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('تعذر إنشاء التقرير: الملف الناتج فارغ.');
    }
    final safeName = _safeFileName(fileName, extension);
    final location = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle ?? 'اختر مكان حفظ الملف',
      fileName: safeName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );

    if (location == null) return null;
    return SavedReport(fileName: safeName, location: location);
  }

  String _safeFileName(String value, String extension) {
    var name = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) name = 'تقرير';
    final suffix = '.$extension';
    if (!name.toLowerCase().endsWith(suffix.toLowerCase())) {
      name += suffix;
    }
    return name;
  }
}
