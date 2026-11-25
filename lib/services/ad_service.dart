import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static final instance = AdService._();

  Future<bool>? _initialization;

  Future<bool> initialize() => _initialization ??= _initialize();

  bool get _supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> _initialize() async {
    if (!_supported) return false;
    final consentUpdated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((_) {
          if (!consentUpdated.isCompleted) consentUpdated.complete();
        });
      },
      (_) {
        if (!consentUpdated.isCompleted) consentUpdated.complete();
      },
    );
    await consentUpdated.future;
    if (!await ConsentInformation.instance.canRequestAds()) return false;
    await MobileAds.instance.initialize();
    return true;
  }

  Future<bool> get privacyOptionsRequired async =>
      _supported && await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  void showPrivacyOptions(void Function(FormError?) onDismissed) {
    if (!_supported) { onDismissed(null); return; }
    ConsentForm.showPrivacyOptionsForm(onDismissed);
  }
}
