# حزمة نشر matching على Google Play

هذه الحزمة مرتبة بحسب الحقول التي ستظهر في Play Console.

## الملفات الجاهزة للرفع

- `Matching.aab`: حزمة Android App Bundle الموقعة بنفس مفتاح التطبيق.
- `assets/app-icon-512.png`: أيقونة المتجر 512×512.
- `assets/feature-graphic-1024x500.png`: صورة العرض 1024×500.
- `screenshots/`: خمس صور هاتف عمودية 1080×1920 مأخوذة من واجهات Flutter الفعلية.
- `listing/ar-SA/`: الاسم والوصف العربي.
- `listing/en-US/`: الاسم والوصف الإنجليزي.
- `release-notes/`: ملاحظات الإصدار بالعربية والإنجليزية.
- `privacy-policy.md`: سياسة الخصوصية المنشورة.
- `play-console-answers-ar.md`: الإجابات المقترحة لكل نماذج Play Console.
- `reviewer-notes-ar.md`: تعليمات مختصرة لفريق مراجعة Google.
- `asset-alt-text-ar.md`: النص البديل للصور.

## بيانات التطبيق

- اسم التطبيق: `matching`
- اسم الحزمة: `com.explapp.accountmatching`
- الإصدار: `1.2.0 (5)`
- البريد: `fastunlocked2017@gmail.com`
- الفئة المقترحة: الأعمال `Business`
- الإعلانات: نعم، Banner واحد من AdMob في الصفحة الرئيسية فقط.

## ترتيب الرفع

1. أنشئ التطبيق كـ App مجاني بلغة افتراضية عربية.
2. انسخ نصوص `listing/ar-SA` وأضف الإنجليزية من `listing/en-US`.
3. ارفع الأيقونة وFeature Graphic وصور الهاتف بالترتيب الرقمي.
4. أكمل App content من ملف `play-console-answers-ar.md`.
5. أضف رابط سياسة الخصوصية المذكور في ملف الإجابات.
6. أنشئ إصدار اختبار مغلق وارفع `Matching.aab`.
7. إذا كان حساب المطور شخصياً جديداً، حافظ على 12 مختبراً منضمين لمدة 14 يوماً متصلة قبل طلب Production.

لا ترفع APK إلى Google Play؛ الملف المطلوب للإصدار هو AAB.
