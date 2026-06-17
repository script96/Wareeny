import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/stuff_finder/stuff_finder_items.dart';

class ParsedModeCommand {
  const ParsedModeCommand({
    required this.mode,
    required this.normalizedText,
    required this.matchedAlias,
  });

  final AppMode mode;
  final String normalizedText;
  final String matchedAlias;
}

class ParsedStuffFinderItem {
  const ParsedStuffFinderItem({
    required this.item,
    required this.normalizedText,
    required this.matchedAlias,
  });

  final StuffFinderItem item;
  final String normalizedText;
  final String matchedAlias;
}

class ArabicCommandParser {
  const ArabicCommandParser();

  static const _modeAliases = <AppMode, List<String>>{
    AppMode.home: [
      'الوضع العادي',
      'وصف المكان',
      'اوصف المكان',
      'وصف المشهد',
      'كشف الأشياء',
      'كشف الاشياء',
      'الوضع الرئيسي',
      'الرئيسية',
      'الكشف',
    ],
    AppMode.navigation: [
      'ساعدني أمشي',
      'ساعدني امشي',
      'وضع التنقل',
      'النافيجيشن',
      'التنقل',
      'المشي',
    ],
    AppMode.stuffFinder: [
      'البحث عن شيء',
      'البحث عن الأشياء',
      'البحث عن الاشياء',
      'دور على حاجة',
      'دورلي على حاجة',
      'الفايندر',
      'الحاجات',
      'البحث',
    ],
    AppMode.scan: [
      'المسح',
      'وضع المسح',
      'اعرف اللي في ايدي',
      'اللي في ايدي',
      'اعرف الفلوس',
      'اعرف اللون',
      'كشف اللون',
      'في اليد',
      'الفلوس',
      'العملة',
      'الألوان',
      'الالوان',
    ],
    AppMode.read: [
      'اقرأ النص',
      'اقرا النص',
      'قراءة النص',
      'قارئ المستندات',
      'وضع القراءة',
      'القراءة',
      'اقرأ',
      'اقرا',
    ],
    AppMode.settings: [
      'افتح الإعدادات',
      'افتح الاعدادات',
      'وضع الإعدادات',
      'وضع الاعدادات',
      'الإعدادات',
      'الاعدادات',
    ],
  };

  ParsedModeCommand? parseMode(String rawText) {
    final normalized = normalizeArabic(rawText);
    if (normalized.isEmpty) return null;

    for (final candidate in _sortedModeAliases) {
      if (_containsPhrase(normalized, candidate.alias)) {
        return ParsedModeCommand(
          mode: candidate.mode,
          normalizedText: normalized,
          matchedAlias: candidate.alias,
        );
      }
    }
    return null;
  }

  ParsedStuffFinderItem? parseStuffFinderItem(String rawText) {
    final normalized = normalizeArabic(rawText);
    if (normalized.isEmpty) return null;

    final aliases = <_ItemAlias>[
      for (final item in stuffFinderItems)
        for (final alias in item.aliases)
          _ItemAlias(item, normalizeArabic(alias)),
    ]..sort((a, b) => b.alias.length.compareTo(a.alias.length));

    for (final candidate in aliases) {
      if (_containsPhrase(normalized, candidate.alias)) {
        return ParsedStuffFinderItem(
          item: candidate.item,
          normalizedText: normalized,
          matchedAlias: candidate.alias,
        );
      }
    }
    return null;
  }

  static String normalizeArabic(String input) {
    return input
        .toLowerCase()
        .replaceAll(
          RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]'),
          '',
        )
        .replaceAll('ـ', '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'[،؛؟]'), ' ')
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _containsPhrase(String text, String phrase) {
    return ' $text '.contains(' $phrase ');
  }

  static final List<_ModeAlias> _sortedModeAliases = [
    for (final entry in _modeAliases.entries)
      for (final alias in entry.value)
        _ModeAlias(entry.key, normalizeArabic(alias)),
  ]..sort((a, b) => b.alias.length.compareTo(a.alias.length));
}

class _ModeAlias {
  const _ModeAlias(this.mode, this.alias);

  final AppMode mode;
  final String alias;
}

class _ItemAlias {
  const _ItemAlias(this.item, this.alias);

  final StuffFinderItem item;
  final String alias;
}
