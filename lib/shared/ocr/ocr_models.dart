import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:wareeny/core/localization/app_localizations.dart';

enum OcrReadingMode {
  document('Document Reader', Icons.article_outlined),
  currency('Currency Reader', Icons.payments_outlined),
  brand('Brand Detector', Icons.label_outline_rounded),
  qa('Q&A Mode', Icons.question_answer_outlined);

  const OcrReadingMode(this.label, this.icon);

  /// Hardcoded English label — use [labelFor] for localized display.
  final String label;
  final IconData icon;

  /// Returns the localized display label for this OCR sub-mode.
  String labelFor(AppLocalizations l10n) {
    return switch (this) {
      OcrReadingMode.document => l10n.ocrDocument,
      OcrReadingMode.currency => l10n.ocrCurrency,
      OcrReadingMode.brand => l10n.ocrBrand,
      OcrReadingMode.qa => l10n.ocrQa,
    };
  }
}

enum OcrLanguage { arabic, latin, mixed }

enum OcrFramingCue { none, noText, blurry, offCenter }

class OcrTextBlock {
  const OcrTextBlock({
    required this.text,
    required this.language,
    required this.confidence,
    required this.boundingBox,
    required this.isRTL,
  });

  final String text;
  final OcrLanguage language;
  final double confidence;
  final Rect boundingBox;
  final bool isRTL;
}

class OcrResult {
  const OcrResult({
    required this.blocks,
    required this.fullText,
    required this.primaryLanguage,
    required this.captureLatency,
  });

  final List<OcrTextBlock> blocks;
  final String fullText;
  final OcrLanguage primaryLanguage;
  final Duration captureLatency;

  bool get isEmpty => fullText.trim().isEmpty;
}
