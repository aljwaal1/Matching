import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinished,
    this.allowSkip = true,
  });

  final Future<void> Function() onFinished;
  final bool allowSkip;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _finishing = false;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      icon: Icons.account_balance_outlined,
      title: 'مرحبًا بك في Matching',
      text: 'تطبيق يساعدك على تنظيم التسوية البنكية ومراجعة الفروقات بين دفاتر الشركة وكشف البنك بطريقة واضحة.',
    ),
    _OnboardingPage(
      icon: Icons.folder_copy_outlined,
      title: 'ماذا تحتاج؟',
      text: 'تحتاج ملفين فقط: دفاتر الشركة وكشف البنك. اختر الملف الصحيح في مكانه المخصص ثم تابع.',
    ),
    _OnboardingPage(
      icon: Icons.table_chart_outlined,
      title: 'جهّز ملفاتك',
      text: 'يدعم التطبيق XLSX وCSV وPDF النصي. يفضّل أن تتضمن البيانات التاريخ ورقم المستند أو الشيك والوصف والمبالغ بوضوح.',
    ),
    _OnboardingPage(
      icon: Icons.science_outlined,
      title: 'جرّب مثالًا جاهزًا',
      text: 'لا تملك ملفات جاهزة؟ استخدم المثال التجريبي داخل التطبيق أو نزّل الملفين التجريبيين وتعرّف على خطوات الاستخدام.',
    ),
    _OnboardingPage(
      icon: Icons.task_alt_outlined,
      title: 'راجع النتيجة واحتفظ بها',
      text: 'بعد تحميل الملفين، يعرض التطبيق نتيجة التسوية ويساعدك على مراجعة البنود وحفظ النتائج وتصدير التقارير.',
    ),
  ];

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await widget.onFinished();
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: 8, end: 12),
                child: widget.allowSkip && !isLast
                    ? TextButton(
                        onPressed: _finishing ? null : _finish,
                        child: const Text('تخطي'),
                      )
                    : const SizedBox(height: 48),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 118,
                          height: 118,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAE5FF),
                            borderRadius: BorderRadius.circular(34),
                          ),
                          child: Icon(page.icon, size: 60, color: const Color(0xFF6D4CFF)),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          page.text,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7, color: const Color(0xFF504B60)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? const Color(0xFF6D4CFF) : const Color(0xFFD7D0F3),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
              child: FilledButton(
                onPressed: _finishing
                    ? null
                    : isLast
                        ? _finish
                        : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                            ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(isLast ? 'ابدأ الآن' : 'التالي'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;
}
