import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MatchingApp());
}

class MatchingApp extends StatelessWidget {
  const MatchingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مطابقة الحسابات',
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B5B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F8F7),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مطابقة الحسابات'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'الأرشيف',
            onPressed: () => _showSoon(context, 'الأرشيف'),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _WelcomeCard(),
            const SizedBox(height: 22),
            _MatchingTypeCard(
              icon: Icons.people_alt_outlined,
              title: 'مطابقة العملاء والموردين',
              subtitle: 'قارن كشف العميل مع كشف المورد مهما اختلف ترتيب الأعمدة.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReconciliationSetupScreen(
                    title: 'مطابقة العملاء والموردين',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _MatchingTypeCard(
              icon: Icons.account_balance_outlined,
              title: 'مطابقة كشف البنك',
              subtitle: 'قارن كشف البنك مع السجل المحاسبي مع السماح بفارق التاريخ.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReconciliationSetupScreen(
                    title: 'مطابقة كشف البنك',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _PrivacyNotice(),
          ],
        ),
      ),
    );
  }

  static void _showSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('سيتم تفعيل $feature ضمن مراحل التطوير القادمة.')),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rule_folder_outlined, size: 38, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'مطابقة أسرع ونتائج أوضح',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'استورد ملفين، راجع الأعمدة، ثم ابدأ المطابقة الذكية.',
            style: TextStyle(color: Colors.white, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _MatchingTypeCard extends StatelessWidget {
  const _MatchingTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: .25)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class ReconciliationSetupScreen extends StatefulWidget {
  const ReconciliationSetupScreen({super.key, required this.title});

  final String title;

  @override
  State<ReconciliationSetupScreen> createState() => _ReconciliationSetupScreenState();
}

class _ReconciliationSetupScreenState extends State<ReconciliationSetupScreen> {
  int allowedDays = 3;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _FileSlot(number: 1, label: 'كشف الطرف الأول'),
            const SizedBox(height: 12),
            const _FileSlot(number: 2, label: 'كشف الطرف الثاني'),
            const SizedBox(height: 22),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('فارق التاريخ المسموح', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('حتى $allowedDays أيام'),
                    Slider(
                      value: allowedDays.toDouble(),
                      min: 0,
                      max: 7,
                      divisions: 7,
                      label: '$allowedDays',
                      onChanged: (value) => setState(() => allowedDays = value.round()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('اختر الملفين أولاً لبدء المطابقة.')),
              ),
              icon: const Icon(Icons.compare_arrows_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('بدء المطابقة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileSlot extends StatelessWidget {
  const _FileSlot({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(child: Text('$number')),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Excel أو CSV أو PDF'),
        trailing: const Icon(Icons.upload_file_outlined),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('سيتم ربط اختيار الملفات في الخطوة التالية.')),
        ),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 20),
        SizedBox(width: 8),
        Expanded(child: Text('تتم معالجة كشوفات الحساب داخل جهازك ولا تُرفع إلى الإنترنت.')),
      ],
    );
  }
}
