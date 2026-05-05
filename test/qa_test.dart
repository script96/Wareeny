import 'package:flutter_test/flutter_test.dart';
import 'package:warene/models/ocr_result.dart';
import 'package:warene/models/qa_types.dart';
import 'package:warene/ocr_service.dart';
import 'package:warene/services/object_finder_types.dart';

void main() {
  // ══════════════════════════════════════════════════════════════════
  //  OCRResult — text cleaning and quality assessment
  // ══════════════════════════════════════════════════════════════════

  group('OCRResult.cleanForQa', () {
    test('preserves single newlines (paragraph breaks)', () {
      final result = OCRResult.cleanForQa('Hello\nWorld');
      expect(result, 'Hello\nWorld');
    });

    test('collapses 3+ newlines to fewer newlines', () {
      final result = OCRResult.cleanForQa('Hello\n\n\n\nWorld');
      // After collapsing to \n\n then filtering empty lines, we get single \n
      expect(result, 'Hello\nWorld');
    });

    test('collapses multiple spaces within a line', () {
      final result = OCRResult.cleanForQa('Hello   World   Test');
      expect(result, 'Hello World Test');
    });

    test('trims leading and trailing whitespace', () {
      final result = OCRResult.cleanForQa('  Hello World  ');
      expect(result, 'Hello World');
    });

    test('removes empty lines', () {
      final result = OCRResult.cleanForQa('Hello\n   \n\nWorld');
      // Empty/whitespace-only lines are filtered out
      expect(result, 'Hello\nWorld');
    });

    test('handles carriage returns', () {
      final result = OCRResult.cleanForQa('Hello\r\nWorld\r\n');
      expect(result, 'Hello\nWorld');
    });

    test('does NOT truncate long text', () {
      final longText = 'A' * 5000;
      final result = OCRResult.cleanForQa(longText);
      expect(result.length, 5000);
    });

    test('handles empty string', () {
      expect(OCRResult.cleanForQa(''), '');
    });
  });

  group('OCRResult.cleanForTts', () {
    test('collapses all whitespace to single spaces', () {
      final result = OCRResult.cleanForTts('Hello\n\nWorld\t\tTest');
      expect(result, 'Hello World Test');
    });

    test('truncates text longer than 200 chars', () {
      final longText = List.generate(50, (i) => 'word$i').join(' ');
      final result = OCRResult.cleanForTts(longText);
      expect(result.length, lessThanOrEqualTo(210)); // 200 + "..."
      expect(result, endsWith('...'));
    });

    test('does not truncate text shorter than 200 chars', () {
      final result = OCRResult.cleanForTts('Short text here');
      expect(result, 'Short text here');
      expect(result, isNot(endsWith('...')));
    });

    test('handles empty string', () {
      expect(OCRResult.cleanForTts(''), '');
    });
  });

  group('OCRResult.assessQuality', () {
    test('empty string → OCRQuality.empty', () {
      expect(OCRResult.assessQuality(''), OCRQuality.empty);
    });

    test('very short text → OCRQuality.tooShort', () {
      expect(OCRResult.assessQuality('Hello'), OCRQuality.tooShort);
    });

    test('19 chars → OCRQuality.tooShort', () {
      expect(OCRResult.assessQuality('A' * 19), OCRQuality.tooShort);
    });

    test('20 chars → OCRQuality.valid', () {
      expect(OCRResult.assessQuality('A' * 20), OCRQuality.valid);
    });

    test('long text → OCRQuality.valid', () {
      expect(OCRResult.assessQuality('A' * 1000), OCRQuality.valid);
    });
  });

  group('OCRResult.fromRawText', () {
    test('rawText is not truncated for QA', () {
      final longText = 'This is a test. ' * 100; // ~1600 chars
      final result = OCRResult.fromRawText(longText, OCRLanguage.english);
      // rawText should be cleaned but NOT truncated
      expect(result.rawText.length, greaterThan(200));
      expect(result.quality, OCRQuality.valid);
    });

    test('spokenPreview is truncated for TTS', () {
      final longText = 'This is a test. ' * 100;
      final result = OCRResult.fromRawText(longText, OCRLanguage.english);
      expect(result.spokenPreview.length, lessThanOrEqualTo(210));
    });

    test('empty input produces empty quality', () {
      final result = OCRResult.fromRawText('', OCRLanguage.arabic);
      expect(result.quality, OCRQuality.empty);
      expect(result.isEmpty, true);
      expect(result.charCount, 0);
    });

    test('preserves language', () {
      final result = OCRResult.fromRawText('some text here enough chars', OCRLanguage.arabic);
      expect(result.language, OCRLanguage.arabic);
    });
  });

  // ══════════════════════════════════════════════════════════════════
  //  QA Types
  // ══════════════════════════════════════════════════════════════════

  group('QaTurn', () {
    test('stores question and answer', () {
      const turn = QaTurn(question: 'ما هو؟', answer: 'هذا نص.');
      expect(turn.question, 'ما هو؟');
      expect(turn.answer, 'هذا نص.');
    });
  });

  group('DocumentQaResult', () {
    test('success result has isError false', () {
      const result = DocumentQaResult(answer: 'الإجابة هنا');
      expect(result.isError, false);
      expect(result.answer, 'الإجابة هنا');
    });

    test('error factory sets isError true', () {
      const result = DocumentQaResult.error('حصل خطأ');
      expect(result.isError, true);
      expect(result.answer, 'حصل خطأ');
    });
  });

  // ══════════════════════════════════════════════════════════════════
  //  QA History Management
  // ══════════════════════════════════════════════════════════════════

  group('QA history trimming', () {
    test('history list trims to max 5 turns by default', () {
      final history = <QaTurn>[];
      for (int i = 0; i < 7; i++) {
        history.add(QaTurn(question: 'Q$i', answer: 'A$i'));
      }

      final trimmed = trimQaHistory(history);

      expect(trimmed.length, 5);
      expect(trimmed.first.question, 'Q2'); // oldest kept
      expect(trimmed.last.question, 'Q6');  // newest
    });

    test('history under max is not trimmed', () {
      final history = <QaTurn>[
        const QaTurn(question: 'Q1', answer: 'A1'),
        const QaTurn(question: 'Q2', answer: 'A2'),
      ];

      final trimmed = trimQaHistory(history);

      expect(trimmed.length, 2);
    });

    test('trims to custom max length', () {
      final history = <QaTurn>[
        const QaTurn(question: 'Q1', answer: 'A1'),
        const QaTurn(question: 'Q2', answer: 'A2'),
        const QaTurn(question: 'Q3', answer: 'A3'),
      ];

      final trimmed = trimQaHistory(history, maxTurns: 2);

      expect(trimmed.length, 2);
      expect(trimmed.first.question, 'Q2');
    });
  });

  // ══════════════════════════════════════════════════════════════════
  //  WareneMode — documentQa exists
  // ══════════════════════════════════════════════════════════════════

  group('WareneMode documentQa', () {
    test('documentQa is a valid mode', () {
      expect(WareneMode.values, contains(WareneMode.documentQa));
    });

    test('documentQa is distinct from all other modes', () {
      final others = WareneMode.values
          .where((m) => m != WareneMode.documentQa)
          .toSet();
      expect(others, isNot(contains(WareneMode.documentQa)));
    });
  });
}
