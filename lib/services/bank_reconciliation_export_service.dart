import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/bank_reconciliation.dart';
import 'arabic_pdf_support.dart';
import 'bank_reconciliation_excel_builder.dart';
import 'bank_reconciliation_pdf_builder.dart';
import 'file_save_service.dart';

class BankReconciliationExportService {
  const BankReconciliationExportService({
    this.fileSaver = const FileSaveService(),
    this.pdfBuilder = const BankReconciliationPdfBuilder(),
    this.excelBuilder = const BankReconciliationExcelBuilder(),
  });

  final FileSaveService fileSaver;
  final BankReconciliationPdfBuilder pdfBuilder;
  final BankReconciliationExcelBuilder excelBuilder;

  Future<SavedReport?> exportPdf({
    required String companyName,
    required String bankName,
    required BankReconciliationStatement statement,
  }) async {
    final period = DateFormat('yyyy-MM', 'en_US').format(statement.period);
    final baseName = _safe('تسوية_${bankName}_$period');
    final bytes = await _buildPdfWithoutBlockingUi(
      companyName: companyName,
      bankName: bankName,
      statement: statement,
    );
    return fileSaver.saveBytes(
      bytes: bytes,
      fileName: baseName,
      extension: 'pdf',
      dialogTitle: 'حفظ التسوية البنكية بصيغة PDF',
    );
  }

  Future<Uint8List> _buildPdfWithoutBlockingUi({
    required String companyName,
    required String bankName,
    required BankReconciliationStatement statement,
  }) async {
    if (kIsWeb || pdfBuilder.runtimeType != BankReconciliationPdfBuilder) {
      return pdfBuilder.build(
        companyName: companyName,
        bankName: bankName,
        statement: statement,
      );
    }

    // rootBundle must stay on the root isolate. Only raw bytes and plain JSON
    // are passed to the worker, avoiding BackgroundIsolateBinaryMessenger null
    // failures seen after restoring an archived reconciliation.
    final fontData = await loadArabicPdfFontData();
    final regularFont = TransferableTypedData.fromList([fontData.regular]);
    final boldFont = TransferableTypedData.fromList([fontData.bold]);
    final statementJson = statement.toJson();

    return Isolate.run<Uint8List>(() async {
      final isolatedFonts = ArabicPdfFontData(
        regular: regularFont.materialize().asUint8List(),
        bold: boldFont.materialize().asUint8List(),
      );
      return const BankReconciliationPdfBuilder().build(
        companyName: companyName,
        bankName: bankName,
        statement: BankReconciliationStatement.fromJson(
          Map<String, dynamic>.from(statementJson),
        ),
        fontData: isolatedFonts,
      );
    });
  }

  Future<SavedReport?> exportExcel({
    required String companyName,
    required String bankName,
    required BankReconciliationStatement statement,
    String? suggestedName,
  }) async {
    final encoded = excelBuilder.build(
      companyName: companyName,
      bankName: bankName,
      statement: statement,
    );
    final period = DateFormat('yyyy-MM', 'en_US').format(statement.period);
    return fileSaver.saveBytes(
      bytes: Uint8List.fromList(encoded),
      fileName: suggestedName ?? _safe('تسوية_${bankName}_$period'),
      extension: 'xlsx',
      dialogTitle: 'حفظ التسوية البنكية بصيغة Excel',
    );
  }

  String _safe(String value) =>
      value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
