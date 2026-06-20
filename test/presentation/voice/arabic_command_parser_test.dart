import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/voice/arabic_command_parser.dart';

void main() {
  const parser = ArabicCommandParser();

  test('normalizes Arabic variants, tashkeel, and punctuation', () {
    expect(ArabicCommandParser.normalizeArabic('إقْرَأ، النَّص!'), 'اقرا النص');
  });

  test('finds a mode alias inside a natural Egyptian Arabic sentence', () {
    final result = parser.parseMode(
      'ممكن يا واريني افتحلي وضع وصف المكان لو سمحت',
    );

    expect(result?.mode, AppMode.home);
    expect(result?.matchedAlias, 'وصف المكان');
  });

  test('matches the real app modes through common aliases', () {
    expect(parser.parseMode('ساعدني أمشي شوية')?.mode, AppMode.navigation);
    expect(
      parser.parseMode('افتح البحث عن الأشياء')?.mode,
      AppMode.stuffFinder,
    );
    expect(parser.parseMode('عايز اقرأ النص')?.mode, AppMode.read);
    expect(parser.parseMode('افتح الإعدادات')?.mode, AppMode.settings);
    expect(parser.parseMode('اعرف الفلوس اللي في ايدي')?.mode, AppMode.scan);
  });

  test('matches Stuff Finder item aliases inside extra words', () {
    expect(
      parser.parseStuffFinderItem('دورلي على المحفظة')?.item.detectorLabel,
      'wallet',
    );
    expect(
      parser.parseStuffFinderItem('فين التليفون بتاعي')?.item.detectorLabel,
      'cell phone',
    );
    expect(
      parser.parseStuffFinderItem('عايز ازازة مايه')?.item.detectorLabel,
      'bottle',
    );
    expect(
      parser.parseStuffFinderItem('شوف المفاتيح')?.item.detectorLabel,
      'keys',
    );
  });

  test('returns null for unsupported items', () {
    expect(parser.parseStuffFinderItem('دورلي على السماعة'), isNull);
  });
}
