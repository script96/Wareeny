import 'package:flutter_test/flutter_test.dart';
import 'package:warene/services/object_finder_types.dart';

void main() {
  // ── WareneMode ──

  group('WareneMode', () {
    test('has 7 values', () {
      expect(WareneMode.values.length, 7);
    });

    test('contains all expected modes', () {
      final expected = {
        WareneMode.generalObjects,
        WareneMode.currency,
        WareneMode.objectFinderFast,
        WareneMode.objectFinderSmart,
        WareneMode.color,
        WareneMode.documentQa,
        WareneMode.indoorNavigation,
      };
      expect(WareneMode.values.toSet(), expected);
    });
  });

  // ── ObjectFinderStatus ──

  group('ObjectFinderStatus', () {
    test('has 4 values (no cancelled, found renamed to tracking)', () {
      expect(ObjectFinderStatus.values.length, 4);
    });

    test('contains inactive, searching, tracking, error', () {
      final expected = {
        ObjectFinderStatus.inactive,
        ObjectFinderStatus.searching,
        ObjectFinderStatus.tracking,
        ObjectFinderStatus.error,
      };
      expect(ObjectFinderStatus.values.toSet(), expected);
    });
  });

  // ── ObjectFinderRegistry ──

  group('ObjectFinderRegistry', () {
    test('fastTargets contains 10 COCO presets', () {
      expect(ObjectFinderRegistry.fastTargets.length, 10);
    });

    test('smartTargets contains 7 non-COCO presets', () {
      expect(ObjectFinderRegistry.smartTargets.length, 7);
    });

    test('fast target keys match expected COCO labels', () {
      final expected = {
        'apple',
        'banana',
        'bottle',
        'cup',
        'chair',
        'book',
        'cell phone',
        'laptop',
        'backpack',
        'person',
      };
      expect(ObjectFinderRegistry.fastTargets.keys.toSet(), expected);
    });

    test('smart target keys match expected presets', () {
      final expected = {
        'keys',
        'wallet',
        'glasses',
        'charger',
        'medicine',
        'id card',
        'remote control',
      };
      expect(ObjectFinderRegistry.smartTargets.keys.toSet(), expected);
    });
  });

  // ── ObjectFinderRegistry.resolve ──

  group('ObjectFinderRegistry.resolve', () {
    test('apple resolves to Fast mode with Arabic name', () {
      final target = ObjectFinderRegistry.resolve('apple');
      expect(target.mode, ObjectFinderMode.fastYolo);
      expect(target.arabicName, 'تفاحة');
      expect(target.label, 'apple');
    });

    test('keys resolves to Smart mode with Arabic name', () {
      final target = ObjectFinderRegistry.resolve('keys');
      expect(target.mode, ObjectFinderMode.smartVision);
      expect(target.arabicName, 'مفاتيح');
      expect(target.label, 'keys');
    });

    test('COCO label not in fastTargets still resolves to Fast (e.g. car)', () {
      final target = ObjectFinderRegistry.resolve('car');
      expect(target.mode, ObjectFinderMode.fastYolo);
      expect(target.label, 'car');
    });

    test('unknown label resolves to Smart mode', () {
      final target = ObjectFinderRegistry.resolve('unicorn');
      expect(target.mode, ObjectFinderMode.smartVision);
      expect(target.label, 'unicorn');
    });

    test('resolve is case-insensitive and trims whitespace', () {
      final target = ObjectFinderRegistry.resolve('  APPLE  ');
      expect(target.mode, ObjectFinderMode.fastYolo);
      expect(target.label, 'apple');
    });
  });

  // ── ObjectFinderRegistry.fromCustomText ──

  group('ObjectFinderRegistry.fromCustomText', () {
    test('always returns Smart mode', () {
      final target = ObjectFinderRegistry.fromCustomText('ساعة');
      expect(target.mode, ObjectFinderMode.smartVision);
      expect(target.label, 'ساعة');
      expect(target.arabicName, 'ساعة');
    });

    test('trims whitespace', () {
      final target = ObjectFinderRegistry.fromCustomText('  محفظة  ');
      expect(target.label, 'محفظة');
    });

    test('even COCO labels use Smart when entered as custom text', () {
      final target = ObjectFinderRegistry.fromCustomText('apple');
      expect(target.mode, ObjectFinderMode.smartVision);
    });
  });

  // ── SmartFindResult ──

  group('SmartFindResult', () {
    test('fromJson parses valid found response', () {
      final result = SmartFindResult.fromJson({
        'found': true,
        'direction': 'right',
        'distance': 'close',
        'arabic_response': 'المفاتيح على اليمين، قريبة',
      });
      expect(result.found, true);
      expect(result.direction, 'right');
      expect(result.distance, 'close');
      expect(result.spokenText, 'المفاتيح على اليمين، قريبة');
      expect(result.isError, false);
    });

    test('fromJson parses not-found response', () {
      final result = SmartFindResult.fromJson({
        'found': false,
        'direction': 'unknown',
        'distance': 'unknown',
        'arabic_response': '',
      });
      expect(result.found, false);
    });

    test('fromJson handles missing fields gracefully', () {
      final result = SmartFindResult.fromJson({'found': true});
      expect(result.found, true);
      expect(result.direction, 'unknown');
      expect(result.distance, 'unknown');
      expect(result.spokenText, '');
    });

    test('fromJson with missing found field defaults to false', () {
      final result = SmartFindResult.fromJson({'direction': 'left'});
      expect(result.found, false);
    });

    test('fromJson with non-bool found defaults to false', () {
      final result = SmartFindResult.fromJson({
        'found': 'yes',
        'direction': 'center',
      });
      expect(result.found, false);
    });

    test('error factory sets isError and message', () {
      const result = SmartFindResult.error('البحث الذكي يحتاج إنترنت');
      expect(result.found, false);
      expect(result.isError, true);
      expect(result.spokenText, 'البحث الذكي يحتاج إنترنت');
    });
  });

  // ── ObjectFinderState ──

  group('ObjectFinderState', () {
    test('inactive factory has all null fields', () {
      const state = ObjectFinderState.inactive();
      expect(state.status, ObjectFinderStatus.inactive);
      expect(state.mode, isNull);
      expect(state.targetLabel, isNull);
      expect(state.targetArabicName, isNull);
      expect(state.foundDetection, isNull);
      expect(state.statusText, '');
    });
  });
}
