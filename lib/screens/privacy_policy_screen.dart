import 'package:flutter/material.dart';

import '../services/ad_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _policy = '''
سياسة خصوصية matching

يعالج التطبيق ملفات المطابقة والتسوية على جهازك. لا يرسل المطور محتوى الملفات أو الأرصدة أو البنود أو التقارير إلى خوادمه. تُحفظ نتائج الأرشيف محلياً على الجهاز، ويمكن حذفها من داخل التطبيق أو بإزالة بيانات التطبيق.

عند التصدير أو إرسال الملاحظات، لا تغادر البيانات جهازك إلا عندما تختار أنت مشاركتها عبر تطبيق آخر.

يعرض التطبيق إعلان Banner واحداً من Google AdMob في الصفحة الرئيسية. قد تجمع Google وتشارك عنوان IP المستخدم لتقدير الموقع التقريبي، وتفاعلات التطبيق، ومعلومات التشخيص، ومعرّفات الجهاز أو الإعلانات لأغراض عرض الإعلانات والتحليلات ومنع الاحتيال. تُشفّر هذه البيانات أثناء النقل وفقاً لممارسات Google.

لا يتطلب التطبيق إنشاء حساب، ولا يبيع المطور بيانات المستخدمين. يمكنك تعديل خيارات خصوصية الإعلانات عندما يكون هذا الخيار مطلوباً في منطقتك، كما يمكنك إعادة ضبط معرّف الإعلانات من إعدادات Android.

للاستفسارات المتعلقة بالخصوصية: fastunlocked2017@gmail.com

تاريخ السريان: 21 يوليو 2026
''';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('سياسة الخصوصية')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SelectableText(_policy, textAlign: TextAlign.start),
            FutureBuilder<bool>(
              future: AdService.instance.privacyOptionsRequired,
              builder: (context, snapshot) => snapshot.data == true
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: FilledButton.icon(
                        onPressed: () => AdService.instance.showPrivacyOptions(
                          (error) {
                            if (error != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.message)),
                              );
                            }
                          },
                        ),
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text('إعدادات خصوصية الإعلانات'),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
}
