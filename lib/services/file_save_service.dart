import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedReport {
  const SavedReport({required this.fileName, required this.location});

  final String fileName;
  final String location;
}

class FileSaveService {
  const FileSaveService();

  static const _channel = MethodChannel('matching/files');

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
    final preferences = await SharedPreferences.getInstance();
    final locationKey = _locationKey(safeName);
    final previousLocation = preferences.getString(locationKey);
    if (previousLocation != null) {
      try {
        await _writeAndVerify(previousLocation, bytes);
        return SavedReport(fileName: safeName, location: previousLocation);
      } catch (_) {
        await preferences.remove(locationKey);
      }
    }

    // عند تمرير bytes يقوم file_picker بإنشاء الملف وكتابته على الهاتف.
    // لا نعيد فتح الملف وكتابته مرة ثانية؛ لأن ذلك قد يصفر الملف عند بعض
    // مزودي المستندات، كما أنه يحجب واجهة أندرويد عند التقارير الكبيرة.
    final location = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle ?? 'اختر مكان حفظ الملف',
      fileName: safeName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );

    if (location == null) return null;
    await _verifyExisting(location, bytes.length);
    final remembered = await preferences.setString(locationKey, location);
    if (!remembered) {
      throw StateError('تم إنشاء الملف، لكن تعذر حفظ موقعه للتحديث اللاحق.');
    }
    return SavedReport(fileName: safeName, location: location);
  }

  Future<void> _writeAndVerify(String location, Uint8List bytes) async {
    int size;
    if (!kIsWeb && Platform.isAndroid) {
      size = await _channel.invokeMethod<int>('writeAndVerify', {
            'location': location,
            'bytes': bytes,
          }) ??
          -1;
    } else if (!kIsWeb) {
      final file = File(location);
      await file.writeAsBytes(bytes, mode: FileMode.write, flush: true);
      size = await file.length();
    } else {
      return;
    }
    _ensureExpectedSize(size, bytes.length);
  }

  Future<void> _verifyExisting(String location, int expectedSize) async {
    if (kIsWeb) return;

    final int size;
    if (Platform.isAndroid) {
      size = await _channel.invokeMethod<int>('verifySize', {
            'location': location,
          }) ??
          -1;
    } else {
      size = await File(location).length();
    }
    _ensureExpectedSize(size, expectedSize);
  }

  void _ensureExpectedSize(int size, int expectedSize) {
    if (size != expectedSize || size <= 0) {
      throw StateError(
        'فشل التحقق من الملف بعد الحفظ: الحجم المتوقع $expectedSize والحجم الفعلي $size.',
      );
    }
  }

  String _locationKey(String fileName) =>
      'saved_report_${base64Url.encode(utf8.encode(fileName))}';

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
