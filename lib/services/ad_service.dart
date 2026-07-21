import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static final instance = AdService._();

  Future<bool>? _initialization;

  Future<bool> initialize() => _initialization ??= _initialize();

  Future<bool> _initialize() async {
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
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  void showPrivacyOptions(void Function(FormError?) onDismissed) {
    ConsentForm.showPrivacyOptionsForm(onDismissed);
  }
}
