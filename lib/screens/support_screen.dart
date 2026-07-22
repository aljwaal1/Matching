import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/operation_feedback.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const _channel = MethodChannel('matching/support');
  static const _supportEmail = 'fastunlocked2017@gmail.com';
  static const _categories = <String>[
    'مشكلة في تحميل كشف',
    'مشكلة في الحفظ أو التصدير',
    'مشكلة في نتائج المطابقة',
    'اقتراح لتطوير التطبيق',
    'ملاحظة أخرى',
  ];

  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _category = _categories.first;
  bool _sending = false;
  String _statusMessage = 'جاري تجهيز رسالة الدعم...';

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openEmail() async {
    final message = _messageController.text.trim();
    if (message.length < 10) {
      await showOperationError(
        context,
        title: 'الرسالة غير مكتملة',
        error: const FormatException(
          'اكتب وصفًا واضحًا للمشكلة لا يقل عن 10 أحرف.',
        ),
        message: 'كلما كانت التفاصيل أوضح كان من الأسهل فهم المشكلة.',
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _sending = true;
      _statusMessage = 'جاري فتح تطبيق البريد وإضافة تفاصيل رسالتك...';
    });

    final enteredSubject = _subjectController.text.trim();
    final subject = enteredSubject.isEmpty
        ? '$_category - تطبيق مطابقة الحسابات'
        : enteredSubject;
    final body = '''مرحبًا،

التصنيف: $_category
العنوان: $subject

تفاصيل الرسالة:
$message

يرجى توضيح خطوات الحل عند الرد.
''';

    try {
      await _channel.invokeMethod<void>('openEmail', {
        'subject': subject,
        'body': body,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم فتح تطبيق البريد. راجع الرسالة ثم اضغط إرسال.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await showOperationError(
        context,
        title: 'تعذر فتح البريد الإلكتروني',
        error: error,
        message: 'يمكنك نسخ عنوان الدعم وإرسال الرسالة يدويًا.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ عنوان البريد الإلكتروني.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الدعم والمراسلة')),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _hero(),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFEDE7FF),
                              child: Icon(
                                Icons.support_agent_rounded,
                                color: Color(0xFF5B3FD3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'أرسل ملاحظتك بالتفصيل',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          value: _category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'نوع الرسالة',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: _categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _sending
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _category = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _subjectController,
                          enabled: !_sending,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'عنوان مختصر',
                            hintText: 'مثال: تعذر حفظ تقرير PDF',
                            prefixIcon: Icon(Icons.title_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _messageController,
                          enabled: !_sending,
                          minLines: 6,
                          maxLines: 10,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            labelText: 'تفاصيل المشكلة أو الاقتراح',
                            hintText:
                                'اذكر ما الذي فعلته، وما الذي ظهر لك، ونوع الملف إن كانت المشكلة أثناء التحميل أو الحفظ.',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 112),
                              child: Icon(Icons.notes_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F3FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                color: Color(0xFF6D4CFF),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'عند وجود خطأ، أرسل نص رسالة الخطأ واذكر هل المشكلة ظهرت في Excel أو PDF أو عند رفع الكشف.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _sending ? null : _openEmail,
                          icon: const Icon(Icons.send_rounded),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('تجهيز الرسالة وفتح البريد'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'الإرسال اليدوي',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'إذا لم يوجد تطبيق بريد على الجهاز، انسخ العنوان وأرسل الرسالة من أي بريد آخر.',
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          _supportEmail,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5137CC),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _copyEmail,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('نسخ عنوان البريد'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_sending)
              OperationStatusOverlay(
                message: _statusMessage,
                details: 'سيتم فتح تطبيق البريد، ولن تُرسل الرسالة قبل موافقتك.',
              ),
          ],
        ),
      );

  Widget _hero() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6D4CFF), Color(0xFF00A9C8)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x336D4CFF),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.forum_rounded, color: Colors.white, size: 38),
            SizedBox(height: 12),
            Text(
              'نحن نهتم بملاحظاتك',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'صف المشكلة بدقة، وسيتم تجهيز رسالة منظمة تحتوي على جميع التفاصيل التي كتبتها.',
              style: TextStyle(color: Colors.white, height: 1.5),
            ),
          ],
        ),
      );
}
