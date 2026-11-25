import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_license_hashes.dart';

String licenseDigest(String input) {
  final normalized = input.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  final code = normalized.startsWith('ACC') ? normalized.substring(3) : normalized;
  if (!RegExp(r'^[0-9A-F]{32}$').hasMatch(code)) return '';
  return sha256.convert(utf8.encode(code)).toString();
}

class LocalActivationScreen extends StatefulWidget {
  const LocalActivationScreen({super.key, required this.child});
  final Widget child;
  @override
  State<LocalActivationScreen> createState() => _LocalActivationScreenState();
}

class _LocalActivationScreenState extends State<LocalActivationScreen> {
  static const _key = 'windows_local_license_v1';
  final _controller = TextEditingController();
  bool _loading = true;
  bool _active = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _restore();
  }
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() {
        _active = localLicenseHashes.contains(prefs.getString(_key));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر قراءة الترخيص المحلي'; });
    }
  }
  Future<void> _activate() async {
    final digest = licenseDigest(_controller.text);
    if (!localLicenseHashes.contains(digest)) {
      setState(() => _error = 'رمز التفعيل غير صحيح. تحقق من الرمز وحاول مجدداً.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(_key, digest);
      if (mounted) setState(() {
        _active = saved; _loading = false;
        if (!saved) _error = 'تعذر حفظ الترخيص';
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر حفظ الترخيص'; });
    }
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (_active) return widget.child;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 510),
          child: Card(child: Padding(padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_user_outlined, size: 54, color: Color(0xFF087F75)),
              const SizedBox(height: 12),
              const Text('المطابقة البنكية الاحترافية', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
              const Text('أدخل رمز التفعيل مرة واحدة. لا يلزم اتصال بالإنترنت.'),
              const SizedBox(height: 18),
              TextField(controller: _controller, enabled: !_loading, textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: 'رمز التفعيل', errorText: _error),
                onSubmitted: (_) { if (!_loading) _activate(); }),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loading ? null : _activate,
                child: Text(_loading ? 'جاري التحقق...' : 'تفعيل البرنامج')),
              const SizedBox(height: 20),
              const Text('تصميم وإعداد وبرمجة المحاسب المحترف'),
              const Text('acc.explapp.com'),
            ])))))),
    );
  }
}
