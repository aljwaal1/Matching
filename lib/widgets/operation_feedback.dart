import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OperationStatusOverlay extends StatelessWidget {
  const OperationStatusOverlay({
    super.key,
    required this.message,
    this.details = 'يرجى الانتظار وعدم إغلاق التطبيق.',
  });

  final String message;
  final String details;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: AbsorbPointer(
          child: ColoredBox(
            color: const Color(0x66000000),
            child: SafeArea(
              child: Center(
                child: Container(
                  width: 330,
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 46,
                        height: 46,
                        child: CircularProgressIndicator(strokeWidth: 4),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        details,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

String operationErrorDetails(Object error) {
  if (error is PlatformException) {
    final message = error.message?.trim();
    return message == null || message.isEmpty
        ? 'حدث خطأ في النظام (${error.code}).'
        : message;
  }
  if (error is FormatException) {
    final message = error.message.toString().trim();
    return message.isEmpty ? 'صيغة الملف أو البيانات غير صالحة.' : message;
  }
  if (error is StateError) {
    final text = error.toString().replaceFirst('Bad state: ', '').trim();
    return text.isEmpty ? 'تعذر إكمال العملية.' : text;
  }
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  return text.isEmpty ? 'حدث خطأ غير متوقع.' : text;
}

Future<void> showOperationError(
  BuildContext context, {
  required String title,
  required Object error,
  String? message,
}) async {
  final details = operationErrorDetails(error);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.error_outline_rounded,
        color: Color(0xFFC62828),
        size: 42,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message != null && message.trim().isNotEmpty) ...[
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4F4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFC9C9)),
              ),
              child: SelectableText(details),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: details));
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('تم نسخ تفاصيل الخطأ.')),
              );
            }
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('نسخ التفاصيل'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('حسنًا'),
        ),
      ],
    ),
  );
}
