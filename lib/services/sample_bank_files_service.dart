import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'file_import_service.dart';
import 'file_save_service.dart';

class BankSampleFiles {
  const BankSampleFiles({required this.books, required this.bank});

  final ImportedStatement books;
  final ImportedStatement bank;
}

class SampleBankFilesService {
  const SampleBankFilesService();

  static const booksAsset = 'assets/samples/company_books_sample.csv';
  static const bankAsset = 'assets/samples/bank_statement_sample.csv';

  Future<BankSampleFiles> loadExample() async {
    final importer = FileImportService();
    final booksBytes = await _loadAsset(booksAsset);
    final bankBytes = await _loadAsset(bankAsset);
    return BankSampleFiles(
      books: importer.importBytes(fileName: 'دفاتر_الشركة_مثال.csv', bytes: booksBytes),
      bank: importer.importBytes(fileName: 'كشف_البنك_مثال.csv', bytes: bankBytes),
    );
  }

  Future<List<SavedReport?>> downloadExamples() async {
    const saver = FileSaveService();
    final booksBytes = await _loadAsset(booksAsset);
    final bankBytes = await _loadAsset(bankAsset);
    final books = await saver.saveBytes(
      bytes: booksBytes,
      fileName: 'دفاتر_الشركة_مثال',
      extension: 'csv',
      dialogTitle: 'حفظ ملف دفاتر الشركة التجريبي',
    );
    final bank = await saver.saveBytes(
      bytes: bankBytes,
      fileName: 'كشف_البنك_مثال',
      extension: 'csv',
      dialogTitle: 'حفظ ملف كشف البنك التجريبي',
    );
    return [books, bank];
  }

  Future<Uint8List> _loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
