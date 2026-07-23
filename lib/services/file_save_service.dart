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
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final preferences = await SharedPreferences.getInstance();
    final locationKey = _locationKey(safeName);

    // على Android لا نعيد استخدام URI قديم تلقائيًا. بعض مديري الملفات
    // يحتفظون بالإذن شكليًا ثم يفرغون الملف عند محاولة الكتابة اللاحقة.
    // فتح نافذة الحفظ كل مرة يمنع تحويل ملف سابق إلى صفر بايت.
    if (!isAndroid) {
      final previousLocation = preferences.getString(locationKey);
      if (previousLocation != null) {
        try {
          await _writeAndVerify(previousLocation, bytes);
          return SavedReport(fileName: safeName, location: previousLocation);
        } catch (_) {
          await preferences.remove(locationKey);
        }
      }
    }

    final SavedReport? saved;
    if (isAndroid) {
      saved = await _createAndWriteOnAndroid(
        bytes: bytes,
        fileName: safeName,
        extension: extension,
      );
    } else {
      final location = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle ?? 'اختر مكان حفظ الملف',
        fileName: safeName,
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: bytes,
      );
      if (location == null) return null;
      await _verifyExistingWithRetries(location, bytes.length);
      saved = SavedReport(fileName: safeName, location: location);
    }

    if (saved == null) return null;
    if (!isAndroid) {
      final remembered = await preferences.setString(locationKey, saved.location);
      if (!remembered) {
        throw StateError('تم إنشاء الملف، لكن تعذر حفظ موقعه للتحديث اللاحق.');
      }
    }
    return saved;
  }

  Future<SavedReport?> _createAndWriteOnAndroid({
    required Uint8List bytes,
    required String fileName,
    required String extension,
  }) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'createAndWrite',
      {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': _mimeType(extension),
      },
    );
    if (response == null) return null;

    final location = response['location'] as String?;
    if (location == null || location.trim().isEmpty) {
      throw StateError('لم يرجع مدير الملفات موقعًا صالحًا للحفظ.');
    }

    // لا نكتفي بالحجم الذي تعيده عملية الكتابة؛ نعيد فتح الملف وقراءته
    // عدة مرات. هذا يمنع إعلان النجاح بينما الملف الفعلي ما زال صفر بايت.
    await _verifyExistingWithRetries(location, bytes.length);
    return SavedReport(fileName: fileName, location: location);
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

  Future<void> _verifyExistingWithRetries(
    String location,
    int expectedSize,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 12; attempt++) {
      try {
        await _verifyExisting(location, expectedSize);
        return;
      } catch (error) {
        lastError = error;
        if (attempt < 11) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    }
    throw StateError(
      'فشل التحقق من الملف بعد الحفظ. لم يثبت أن حجمه يساوي '
      '$expectedSize بايت. التفاصيل: $lastError',
    );
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

  String _mimeType(String extension) => switch (extension.toLowerCase()) {
        'pdf' => 'application/pdf',
        'xlsx' =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'xls' => 'application/vnd.ms-excel',
        'csv' => 'text/csv',
        _ => 'application/octet-stream',
      };

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
