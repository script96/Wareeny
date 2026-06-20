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
  String get modeScan => isArabic ? 'المسح' : 'Scan';
  String get modeRead => isArabic ? 'القراءة' : 'Read';
  String get modeSettings => isArabic ? 'الإعدادات' : 'Settings';

  // ── Navigation sub-modes ─────────────────────────────────────────────────

  String get navIndoor => isArabic ? 'داخلي' : 'Indoor';
  String get navOutdoor => isArabic ? 'خارجي' : 'Outdoor';

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

  // ── Scan + Read status / actions ─────────────────────────────────────────

  /// Pill shown while the Read mode VLM works before the first token arrives.
  String get readingStatus => isArabic ? 'جارٍ القراءة…' : 'Reading…';

  /// Pill shown while the Scan mode VLM works before the first token arrives.
  String get scanningStatus => isArabic ? 'جارٍ التعرف…' : 'Identifying…';

  /// Screen-reader action to re-speak the last scan result.
  String get repeatResult => isArabic ? 'إعادة النتيجة' : 'Repeat result';

  String get readUnavailable => isArabic
      ? 'القراءة غير متاحة. ثبّت النموذج على الجهاز أو اتصل بالإنترنت ثم حاول مرة أخرى.'
      : 'Reading is unavailable. Install the on-device model or connect to the internet, then try again.';

  String get scanUnavailable => isArabic
      ? 'المسح غير متاح. ثبّت النموذج على الجهاز أو اتصل بالإنترنت ثم حاول مرة أخرى.'
      : 'Scan is unavailable. Install the on-device model or connect to the internet, then try again.';

  // ── Settings screen ───────────────────────────────────────────────────────

  String get settingsTitle => isArabic ? 'الإعدادات' : 'Settings';
  String get settingsLanguage => isArabic ? 'اللغة' : 'Language';
  String get settingsLanguageEn => isArabic ? 'الإنجليزية' : 'English';
  String get settingsLanguageAr => isArabic ? 'العربية' : 'Arabic (العربية)';
  String get settingsSpeechRate => isArabic ? 'سرعة الكلام' : 'Speech Rate';
  String get settingsSpeechRateSlow => isArabic ? 'بطيء' : 'Slow';
  String get settingsSpeechRateFast => isArabic ? 'سريع' : 'Fast';
  String get settingsHaptics => isArabic ? 'الاهتزاز' : 'Haptic Feedback';
  String get settingsServer => isArabic ? 'الخادم' : 'Server';
  String get settingsServerAddress =>
      isArabic ? 'عنوان الخادم' : 'Server Address';
  String get settingsServerHint => isArabic
      ? 'أدخل IP الخادم أو رابط النفق. إذا أدخلت IP فقط سيستخدم التطبيق المنفذ 8000.'
      : 'Enter the server IP or tunnel URL. If you enter only an IP, the app uses port 8000.';
  String get settingsServerPlaceholder =>
      isArabic ? 'مثال: 192.168.1.38' : 'Example: 192.168.1.38';
  String get settingsServerSave => isArabic ? 'حفظ' : 'Save';
  String get settingsServerSaved =>
      isArabic ? 'تم حفظ عنوان الخادم' : 'Server address saved';
  String get settingsServerDefault => isArabic
      ? 'تم الرجوع إلى خادم التطبيق الافتراضي'
      : 'Reverted to the default app server';
  String get settingsHapticsHint => isArabic
      ? 'تفعيل أو إيقاف الاهتزاز عند التنبيهات'
      : 'Enable or disable vibration on alerts';

  String get settingsLanguageHint =>
      isArabic ? 'اختر لغة التطبيق' : 'Choose app language';

  String get settingsBack => isArabic ? 'رجوع' : 'Back';

  String get settingsExitHint => isArabic
      ? 'مرّر بإصبعين للخروج من الإعدادات'
      : 'Swipe with two fingers to exit settings';
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
