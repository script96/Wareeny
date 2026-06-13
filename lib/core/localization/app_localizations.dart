import 'package:flutter/material.dart';

/// All string resources for the Wareeny app.
/// Every user-visible string and TTS announcement must be fetched through this class.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  bool get isArabic => locale.languageCode == 'ar';

  // ── App identity ──────────────────────────────────────────────────────────

  String get appName => isArabic ? 'ويرني' : 'Wareeny';

  // ── Mode names ────────────────────────────────────────────────────────────

  String get modeHome => isArabic ? 'الرئيسية' : 'Home';
  String get modeNavigation => isArabic ? 'التنقل' : 'Navigation';
  String get modeStuffFinder => isArabic ? 'البحث عن الأشياء' : 'Stuff Finder';
  String get modeInHand => isArabic ? 'في اليد' : 'In-Hand';
  String get modeRead => isArabic ? 'القراءة' : 'Read';
  String get modeSettings => isArabic ? 'الإعدادات' : 'Settings';

  // ── Navigation sub-modes ─────────────────────────────────────────────────

  String get navIndoor => isArabic ? 'داخلي' : 'Indoor';
  String get navOutdoor => isArabic ? 'خارجي' : 'Outdoor';

  // ── OCR sub-modes ─────────────────────────────────────────────────────────

  String get ocrDocument => isArabic ? 'قارئ المستندات' : 'Document Reader';
  String get ocrCurrency => isArabic ? 'قارئ العملة' : 'Currency Reader';
  String get ocrBrand => isArabic ? 'كاشف العلامات' : 'Brand Detector';
  String get ocrQa => isArabic ? 'وضع السؤال والجواب' : 'Q&A Mode';

  // ── Semantic hints ────────────────────────────────────────────────────────

  String get swipeHint => isArabic
      ? 'مرر بإصبعين يميناً أو يساراً لتغيير الوضع.'
      : 'Swipe with two fingers left or right to switch modes.';

  String get switchTo => isArabic ? 'الانتقال إلى' : 'Switch to';

  String get subModeSwipeHint => isArabic
      ? 'مرر بإصبعين للأعلى أو الأسفل لتبديل النوع.'
      : 'Swipe with two fingers up or down to switch type.';

  String get tapToCaptureHint =>
      isArabic ? 'انقر مرتين لالتقاط الصورة.' : 'Double tap to capture.';

  String get ocrSelectorHint =>
      isArabic ? 'اختر نوع القراءة.' : 'OCR mode selector.';

  String get navTypeSelectorHint => isArabic
      ? 'نوع التنقل الحالي. انقر للتبديل.'
      : 'Navigation type. Tap to switch.';

  // ── Announcements (TTS + screen reader) ──────────────────────────────────

  String activeMode(String modeName) =>
      isArabic ? '$modeName نشط' : '$modeName active';

  String activeModeNamed(String name) => isArabic ? 'وضع $name' : '$name Mode';

  String get appReady =>
      isArabic ? 'ويرني جاهز. الوضع الرئيسي.' : 'Wareeny active. Home Mode.';

  String get appGreeting => isArabic
      ? 'مرحباً بك في ويرني. مرّر بإصبعين للتنقل بين الأوضاع.'
      : 'Welcome to Wareeny. Swipe with two fingers to navigate between modes.';

  String get scanComplete => isArabic ? 'اكتملت القراءة.' : 'Reading complete.';

  String get noTextFound => isArabic
      ? 'لم يُعثر على نص. وجّه الكاميرا نحو مستند وحاول مرة أخرى.'
      : 'No text found. Aim at a document and try again.';

  // ── Settings screen ───────────────────────────────────────────────────────

  String get settingsTitle => isArabic ? 'الإعدادات' : 'Settings';
  String get settingsLanguage => isArabic ? 'اللغة' : 'Language';
  String get settingsLanguageEn => isArabic ? 'الإنجليزية' : 'English';
  String get settingsLanguageAr => isArabic ? 'العربية' : 'Arabic (العربية)';
  String get settingsSpeechRate => isArabic ? 'سرعة الكلام' : 'Speech Rate';
  String get settingsSpeechRateSlow => isArabic ? 'بطيء' : 'Slow';
  String get settingsSpeechRateFast => isArabic ? 'سريع' : 'Fast';
  String get settingsHaptics => isArabic ? 'الاهتزاز' : 'Haptic Feedback';
  String get settingsHapticsHint => isArabic
      ? 'تفعيل أو إيقاف الاهتزاز عند التنبيهات'
      : 'Enable or disable vibration on alerts';

  String get settingsLanguageHint =>
      isArabic ? 'اختر لغة التطبيق' : 'Choose app language';

  String get settingsBack => isArabic ? 'رجوع' : 'Back';

  String get settingsExitHint => isArabic
      ? 'مرّر بإصبعين للخروج من الإعدادات'
      : 'Swipe with two fingers to exit settings';

  // ── Emergency assistance ─────────────────────────────────────────────────

  String get emergencyContactTitle =>
      isArabic ? 'جهة اتصال الطوارئ' : 'Emergency contact';
  String get emergencyContactExplanation => isArabic
      ? 'اختر شخصاً موثوقاً للاتصال به عند اكتشاف سقوط محتمل أو استخدام زر الاستغاثة.'
      : 'Choose a trusted person to call after a possible fall or when you use SOS.';
  String get chooseFromContacts =>
      isArabic ? 'اختيار من جهات الاتصال' : 'Choose from contacts';
  String get contactName => isArabic ? 'الاسم' : 'Name';
  String get contactPhone => isArabic ? 'رقم الهاتف' : 'Phone number';
  String get contactRelationship => isArabic ? 'صلة القرابة' : 'Relationship';
  String get fieldRequired =>
      isArabic ? 'هذا الحقل مطلوب' : 'This field is required';
  String get invalidPhoneNumber =>
      isArabic ? 'أدخل رقماً دولياً صحيحاً' : 'Enter a valid phone number';
  String get contactsPermissionDenied => isArabic
      ? 'تم رفض إذن جهات الاتصال. يمكنك إدخال الرقم يدوياً.'
      : 'Contacts permission was denied. You can enter the number manually.';
  String get contactHasNoPhone => isArabic
      ? 'لا تحتوي جهة الاتصال على رقم هاتف'
      : 'This contact has no phone number';
  String get testCall => isArabic ? 'اختبار الاتصال' : 'Test call';
  String get confirmEmergencyContact =>
      isArabic ? 'تأكيد جهة الاتصال' : 'Confirm emergency contact';
  String get manualSos => isArabic ? 'استغاثة يدوية' : 'Manual SOS';
  String get manualSosHint => isArabic
      ? 'يبدأ عدّاً تنازلياً قبل الاتصال بجهة الطوارئ'
      : 'Starts a countdown before calling your emergency contact';
  String get emergencyCountdown =>
      isArabic ? 'عد تنازلي للطوارئ' : 'Emergency countdown';
  String get possibleFallWarning => isArabic
      ? 'تم اكتشاف سقوط محتمل. سيتم الاتصال بجهة الطوارئ خلال عشر ثوان.'
      : 'Possible fall detected. Calling your emergency contact in ten seconds.';
  String callingContactSoon(String name) => isArabic
      ? 'سيتم الاتصال بـ $name عند انتهاء العد التنازلي'
      : 'Calling $name when the countdown finishes';
  String get cancelEmergency => isArabic ? 'إلغاء' : 'Cancel';
  String get callNow => isArabic ? 'اتصل الآن' : 'Call now';
  String get callFailed =>
      isArabic ? 'تعذر فتح الاتصال' : 'Could not start the call';
  String get callFailedHint => isArabic
      ? 'تحقق من إعدادات الهاتف وحاول مرة أخرى.'
      : 'Check the phone settings and try again.';
  String get dismiss => isArabic ? 'إغلاق' : 'Dismiss';
  String get safetyMonitoring =>
      isArabic ? 'مراقبة السلامة' : 'Safety monitoring';
  String get foregroundFallDetection => isArabic
      ? 'اكتشاف السقوط أثناء فتح التطبيق'
      : 'Foreground fall detection';
  String get foregroundFallDetectionHint => isArabic
      ? 'ميزة تجريبية. قد تحدث تنبيهات خاطئة.'
      : 'Experimental. False alerts are possible.';
  String get sessionExpired => isArabic
      ? 'انتهت جلسة الحساب. ميزات الطوارئ ما زالت تعمل.'
      : 'Account session expired. Emergency features are still available.';
  String get signInForSync =>
      isArabic ? 'تسجيل الدخول للمزامنة' : 'Sign in for cloud sync';
  String get account => isArabic ? 'الحساب' : 'Account';
  String get shareEmergencyLocation =>
      isArabic ? 'مشاركة موقع الطوارئ' : 'Share emergency location';
  String get shareEmergencyLocationHint => isArabic
      ? 'إرفاق آخر موقع متاح بسجل الحادث. لن يؤخر الاتصال.'
      : 'Attach the latest available location to the event. Calling will not wait.';
  String get removeEmergencyContact =>
      isArabic ? 'حذف جهة اتصال الطوارئ' : 'Remove emergency contact';
  String get removeEmergencyContactConfirmation => isArabic
      ? 'لن تعمل الاستغاثة أو مراقبة السقوط حتى تضيف جهة اتصال جديدة.'
      : 'SOS and fall monitoring will stop until you add another contact.';
  String get remove => isArabic ? 'حذف' : 'Remove';
  String get unableToSaveContact => isArabic
      ? 'تعذر حفظ جهة الاتصال بشكل آمن. حاول مرة أخرى.'
      : 'Could not save the contact securely. Please try again.';
}

// ── Delegate ──────────────────────────────────────────────────────────────────

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'ar';

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
