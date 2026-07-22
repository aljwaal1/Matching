from pathlib import Path


def replace_between(text: str, start: str, end: str, replacement: str, label: str) -> str:
    start_index = text.find(start)
    if start_index < 0:
        raise SystemExit(f'Missing start marker for {label}: {start!r}')
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise SystemExit(f'Missing end marker for {label}: {end!r}')
    return text[:start_index] + replacement + text[end_index:]


main_path = Path('lib/main.dart')
text = main_path.read_text(encoding='utf-8')

privacy_import = "import 'screens/privacy_policy_screen.dart';\n"
new_imports = (
    privacy_import
    + "import 'screens/support_screen.dart';\n"
    + "import 'widgets/operation_feedback.dart';\n"
)
if "import 'screens/support_screen.dart';" not in text:
    if privacy_import not in text:
        raise SystemExit('Privacy screen import was not found')
    text = text.replace(privacy_import, new_imports, 1)

support_start = 'class SupportScreen extends StatelessWidget {'
setup_marker = 'class SetupScreen extends StatefulWidget {'
if support_start in text:
    text = replace_between(text, support_start, setup_marker, '', 'old support screen')

busy_field = "  bool _busy = false;\n"
busy_replacement = (
    busy_field
    + "  String _busyMessage = 'جاري تنفيذ العملية...';\n"
)
current_busy_messages = text.count("String _busyMessage = 'جاري تنفيذ العملية...';")
if current_busy_messages == 0:
    if text.count(busy_field) != 2:
        raise SystemExit(f'Expected two busy fields in main.dart, found {text.count(busy_field)}')
    text = text.replace(busy_field, busy_replacement)
elif current_busy_messages != 2:
    raise SystemExit(f'Unexpected busy message field count: {current_busy_messages}')

pick_replacement = '''  Future<void> _pick(bool first) async {
    setState(() {
      _busy = true;
      _busyMessage = 'جاري فتح مدير الملفات...';
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv', 'tsv', 'txt', 'pdf'],
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      if (mounted) {
        setState(() => _busyMessage = 'جاري قراءة ملف ${file.name}...');
      }
      Uint8List? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException(
          'تعذر الوصول إلى بيانات الملف من الجهاز. جرّب اختيار الملف من مجلد آخر.',
        );
      }

      if (mounted) {
        setState(() => _busyMessage = 'جاري تحليل الأعمدة والبيانات...');
      }
      final prepared = _importer.prepareBytes(
        fileName: file.name,
        bytes: bytes,
      );
      bytes = null;

      if (mounted) {
        setState(() => _busyMessage = 'بانتظار تأكيد أعمدة الكشف...');
      }
      var mapping = await _askMapping(
        prepared,
        initial: prepared.suggestedMapping,
        statementLabel: first ? firstStatementLabel : secondStatementLabel,
      );
      if (mapping == null) return;

      final usesDirectAmount = mapping.amount != null &&
          mapping.debit == null &&
          mapping.credit == null;
      if (widget.mode == ReconciliationMode.parties && usesDirectAmount) {
        final selectedSide =
            await _askDirectAmountRule(file.name, prepared, mapping);
        if (selectedSide == null) return;
        mapping = ColumnMapping(
          date: mapping.date,
          document: mapping.document,
          amount: mapping.amount,
          debit: mapping.debit,
          credit: mapping.credit,
          balance: mapping.balance,
          description: mapping.description,
          directAmountRule: selectedSide,
        );
      }

      if (mounted) {
        setState(() => _busyMessage = 'جاري استيراد العمليات إلى التطبيق...');
      }
      final imported = _importer.buildStatement(prepared, mapping);

      if (!mounted) return;
      setState(() => first ? _first = imported : _second = imported);
      _message(
        'تم استيراد ${imported.records.length} عملية من ${file.name}'
        '${imported.detectedBalance == null ? '' : '، واكتشاف الرصيد ${NumberFormat('#,##0.00', 'en_US').format(imported.detectedBalance)} من الصف ${imported.balanceRowNumber}'}'
        '${imported.skippedRows.isEmpty ? '' : '، وتجاهل ${imported.skippedRows.length} صف'}',
      );
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        await showOperationError(
          context,
          title: 'تعذر قراءة الكشف',
          error: error,
          message: 'تحقق من صيغة الملف ومن وجود بيانات قابلة للقراءة.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        await showOperationError(
          context,
          title: 'حدث خطأ أثناء تحميل الكشف',
          error: error,
          message: 'لم يتم حذف الكشف الذي سبق تحميله، ويمكنك المحاولة مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
text = replace_between(
    text,
    '  Future<void> _pick(bool first) async {',
    '  Future<DirectAmountRule?> _askDirectAmountRule(',
    pick_replacement,
    'SetupScreen._pick',
)

match_replacement = '''  Future<void> _match() async {
    if (_first == null || _second == null) {
      _message('اختر الملفين أولاً.');
      return;
    }

    final rule = await _askMatchingRules();
    if (rule == null) return;
    _documentMismatchRule = rule;

    setState(() {
      _busy = true;
      _busyMessage = 'جاري مطابقة العمليات وإعداد النتائج...';
    });
    await Future<void>.delayed(Duration.zero);
    try {
      final left = _first!.records;
      final right = _second!.records;
      final settings = ReconciliationSettings(
        allowedDateDifferenceDays: _days,
        mode: widget.mode,
        documentMismatchRule: _documentMismatchRule,
      );
      final result = const ReconciliationEngine().reconcile(
        left: left,
        right: right,
        settings: settings,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: widget.mode == ReconciliationMode.bank
                ? BankReconciliationScreen(
                    firstName: _first!.fileName,
                    secondName: _second!.fileName,
                    result: result,
                    documentMismatchRule: _documentMismatchRule,
                    initialBookBalance: _first!.detectedBalance,
                    initialBankBalance: _second!.detectedBalance,
                    bookBalanceRowNumber: _first!.balanceRowNumber,
                    bankBalanceRowNumber: _second!.balanceRowNumber,
                  )
                : ResultsScreen(
                    mode: widget.mode,
                    firstName: _first!.fileName,
                    secondName: _second!.fileName,
                    result: result,
                    firstDetectedBalance: _first!.detectedBalance,
                    secondDetectedBalance: _second!.detectedBalance,
                    firstBalanceRowNumber: _first!.balanceRowNumber,
                    secondBalanceRowNumber: _second!.balanceRowNumber,
                  ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        await showOperationError(
          context,
          title: 'تعذر إكمال المطابقة',
          error: error,
          message: 'راجع الملفين ثم أعد المحاولة. لم يتم حذف الملفات المحمّلة.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
text = replace_between(
    text,
    '  Future<void> _match() async {',
    '  Future<DocumentMismatchRule?> _askMatchingRules()',
    match_replacement,
    'SetupScreen._match',
)

result_save_replacement = '''  Future<void> _save() async {
    final name = await _askName();
    if (name == null) return;

    setState(() {
      _busy = true;
      _busyMessage = 'جاري حفظ النتيجة في الأرشيف...';
    });
    try {
      final id = _savedId ?? '${DateTime.now().microsecondsSinceEpoch}';
      await _archive.save(
        ArchivedReconciliation(
          id: id,
          name: name,
          type: widget.mode.name,
          createdAt: DateTime.now(),
          firstName: widget.firstName,
          secondName: widget.secondName,
          result: widget.result,
          firstBalance: widget.firstDetectedBalance,
          secondBalance: widget.secondDetectedBalance,
          firstBalanceRowNumber: widget.firstBalanceRowNumber,
          secondBalanceRowNumber: widget.secondBalanceRowNumber,
        ),
      );
      if (!mounted) return;
      setState(() {
        _savedId = id;
        _savedName = name;
      });
      _message('تم حفظ النتيجة في الأرشيف بنجاح.');
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        await showOperationError(
          context,
          title: 'تعذر حفظ النتيجة',
          error: error,
          message: 'احتفظ بالصفحة مفتوحة ثم أعد المحاولة.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
text = replace_between(
    text,
    '  Future<void> _save() async {',
    '  Future<void> _doExport(bool pdf) async {',
    result_save_replacement,
    'ResultsScreen._save',
)

result_export_replacement = '''  Future<void> _doExport(bool pdf) async {
    final name = _savedName ?? await _askName();
    if (name == null) return;

    setState(() {
      _busy = true;
      _busyMessage = pdf
          ? 'جاري إنشاء تقرير PDF وفتح نافذة الحفظ...'
          : 'جاري إنشاء تقرير Excel وفتح نافذة الحفظ...';
    });
    try {
      final saved = pdf
          ? await _export.exportPdf(
              name: name,
              firstName: widget.firstName,
              secondName: widget.secondName,
              result: widget.result,
            )
          : await _export.exportExcel(
              name: name,
              firstName: widget.firstName,
              secondName: widget.secondName,
              result: widget.result,
            );
      if (!mounted) return;
      if (saved == null) {
        _message('تم إلغاء حفظ التقرير.');
      } else {
        _message('تم حفظ ${pdf ? 'PDF' : 'Excel'} باسم ${saved.fileName}.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        await showOperationError(
          context,
          title: 'تعذر إنشاء أو حفظ التقرير',
          error: error,
          message: 'تأكد من توفر مساحة تخزين ومن صلاحية مجلد الحفظ.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
text = replace_between(
    text,
    '  Future<void> _doExport(bool pdf) async {',
    '  void _message(String text) {',
    result_export_replacement,
    'ResultsScreen._doExport',
)

old_overlay = '''          if (_busy)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),'''
new_overlay = '''          if (_busy)
            OperationStatusOverlay(
              message: _busyMessage,
              details: 'قد تستغرق العملية بعض الوقت حسب حجم الملف وعدد العمليات.',
            ),'''
if old_overlay in text:
    if text.count(old_overlay) != 2:
        raise SystemExit(f'Expected two main overlays, found {text.count(old_overlay)}')
    text = text.replace(old_overlay, new_overlay)
elif text.count('OperationStatusOverlay(') < 2:
    raise SystemExit('Main operation overlays were not found')

main_path.write_text(text, encoding='utf-8')


bank_path = Path('lib/screens/bank_reconciliation_screen.dart')
bank = bank_path.read_text(encoding='utf-8')
service_import = "import '../services/bank_reconciliation_service.dart';\n"
if "import '../widgets/operation_feedback.dart';" not in bank:
    if service_import not in bank:
        raise SystemExit('Bank service import was not found')
    bank = bank.replace(
        service_import,
        service_import + "import '../widgets/operation_feedback.dart';\n",
        1,
    )

bank_busy_field = "  bool _busy = false;\n"
if "String _busyMessage = 'جاري تنفيذ العملية...';" not in bank:
    if bank.count(bank_busy_field) != 1:
        raise SystemExit('Bank busy field was not found uniquely')
    bank = bank.replace(
        bank_busy_field,
        bank_busy_field + "  String _busyMessage = 'جاري تنفيذ العملية...';\n",
        1,
    )

old_bank_overlay = '''          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x44000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),'''
new_bank_overlay = '''          if (_busy)
            OperationStatusOverlay(
              message: _busyMessage,
              details: 'قد يستغرق إعداد التقرير وقتًا حسب عدد العمليات.',
            ),'''
if old_bank_overlay in bank:
    bank = bank.replace(old_bank_overlay, new_bank_overlay, 1)
elif 'OperationStatusOverlay(' not in bank:
    raise SystemExit('Bank operation overlay was not found')

calculate_replacement = '''  Future<void> _calculate() async {
    final book = double.tryParse(_bookController.text.replaceAll(',', ''));
    final bankBalance =
        double.tryParse(_bankController.text.replaceAll(',', ''));
    final account = _accountController.text.trim();
    if (account.isEmpty || book == null || bankBalance == null) {
      _message('أدخل اسم الحساب والرصيدين بصورة صحيحة.');
      return;
    }

    setState(() {
      _busy = true;
      _busyMessage = _usePreviousReconciliation
          ? 'جاري تحميل البنود السابقة وإعداد التسوية...'
          : 'جاري إعداد تقرير التسوية البنكية...';
    });
    await Future<void>.delayed(Duration.zero);
    try {
      if (widget.initialStatement != null &&
          widget.initialStatement!.matchingResult == null) {
        setState(() {
          _statement = widget.initialStatement!.copyWith(
            accountName: account,
            period: _period,
            bookBalance: book,
            bankBalance: bankBalance,
          );
        });
        return;
      }
      final previousPending = _usePreviousReconciliation
          ? await _archive.pendingFromPrevious(
              accountName: account,
              beforePeriod: _period,
            )
          : const <BankAdjustmentItem>[];
      if (!mounted) return;
      setState(() {
        _statement = _service.build(
          accountName: account,
          period: _period,
          bookBalance: book,
          bankBalance: bankBalance,
          matchingResult: widget.result,
          bookSourceName: widget.firstName,
          bankSourceName: widget.secondName,
          documentMismatchRule: widget.documentMismatchRule,
          previousPending: previousPending,
        );
      });
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        await showOperationError(
          context,
          title: 'تعذر إعداد التسوية البنكية',
          error: error,
          message: 'راجع الأرصدة واسم الحساب ثم أعد المحاولة.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
bank = replace_between(
    bank,
    '  Future<void> _calculate() async {',
    '  Future<void> _save(BankReconciliationStatement statement) async {',
    calculate_replacement,
    'BankReconciliationScreen._calculate',
)

bank_save_replacement = '''  Future<void> _save(BankReconciliationStatement statement) async {
    setState(() {
      _busy = true;
      _busyMessage = 'جاري حفظ التسوية في الأرشيف...';
    });
    try {
      final updated = statement.copyWith(
        accountName: _accountController.text.trim(),
        period: _period,
      );
      await _archive.save(updated);
      if (!mounted) return;
      setState(() => _statement = updated);
      _message('تم الحفظ في أرشيف التسويات البنكية.');
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        await showOperationError(
          context,
          title: 'تعذر حفظ التسوية',
          error: error,
          message: 'لم يتم حذف التقرير الحالي، ويمكنك إعادة المحاولة.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
bank = replace_between(
    bank,
    '  Future<void> _save(BankReconciliationStatement statement) async {',
    '  Future<void> _loadPreviousPending() async {',
    bank_save_replacement,
    'BankReconciliationScreen._save',
)

load_previous_replacement = '''  Future<void> _loadPreviousPending() async {
    final statement = _statement;
    if (statement == null) return;
    setState(() {
      _busy = true;
      _busyMessage = 'جاري استدعاء البنود المعلقة من التسويات السابقة...';
    });
    try {
      final pending = await _archive.pendingFromPrevious(
        accountName: _accountController.text,
        beforePeriod: _period,
        currentItems: statement.items,
      );
      if (!mounted) return;
      if (pending.isEmpty) {
        _message('لا توجد بنود قابلة للترحيل من تسوية سابقة.');
      } else {
        setState(() {
          _statement = statement.copyWith(items: [...statement.items, ...pending]);
        });
        _message('تم استدعاء ${pending.length} بند معلق دون تكرار.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        await showOperationError(
          context,
          title: 'تعذر استدعاء التسوية السابقة',
          error: error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
bank = replace_between(
    bank,
    '  Future<void> _loadPreviousPending() async {',
    '  Future<void> _openArchive() async {',
    load_previous_replacement,
    'BankReconciliationScreen._loadPreviousPending',
)

bank_export_replacement = '''  Future<void> _export(
    BankReconciliationStatement statement, {
    required bool pdf,
  }) async {
    setState(() {
      _busy = true;
      _busyMessage = pdf
          ? 'جاري إنشاء تقرير PDF الشامل وفتح نافذة الحفظ...'
          : 'جاري إنشاء تقرير Excel الشامل وفتح نافذة الحفظ...';
    });
    try {
      final companyName = statement.bookSourceName.isEmpty
          ? widget.firstName
          : statement.bookSourceName;
      final bankName = statement.accountName.isEmpty
          ? (statement.bankSourceName.isEmpty
              ? widget.secondName
              : statement.bankSourceName)
          : statement.accountName;
      final saved = pdf
          ? await _exporter.exportPdf(
              companyName: companyName,
              bankName: bankName,
              statement: statement,
            )
          : await _exporter.exportExcel(
              companyName: companyName,
              bankName: bankName,
              statement: statement,
            );
      if (!mounted) return;
      if (saved == null) {
        _message('تم إلغاء حفظ التقرير.');
      } else {
        _message('تم حفظ ${pdf ? 'PDF' : 'Excel'}: ${saved.fileName}');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        await showOperationError(
          context,
          title: 'تعذر إنشاء أو حفظ تقرير التسوية',
          error: error,
          message: 'تأكد من توفر مساحة تخزين ومن صلاحية مجلد الحفظ.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
bank = replace_between(
    bank,
    '  Future<void> _export(',
    '  void _message(String text) {',
    bank_export_replacement,
    'BankReconciliationScreen._export',
)

bank_path.write_text(bank, encoding='utf-8')
print('Feedback UI patch applied successfully')
