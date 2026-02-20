// Warene — Gemini Vision scene description service
//
// Sends a camera snapshot to Gemini Vision API and returns
// a natural Arabic description optimized for blind users.

import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Description verbosity level.
enum DescriptionStyle {
  brief,    // 1 sentence — walking/scanning
  normal,   // 2–3 sentences — default daily use
  detailed, // 4–5 sentences — exploring a new place
}

class GeminiService {
  GenerativeModel? _model;
  bool _isReady = false;

  bool get isReady => _isReady;

  // API key — keep this private, do not commit to public repos
  static const String _apiKey = 'AIzaSyA9UFye6Y4mF0oRJSyFRavpSdk4ezM5nvk';

  // Fallback models to try if the primary one fails with 404
  final List<String> _modelsToTry = [
    'gemini-1.5-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-flash-8b',
    'gemini-2.0-flash-exp',
  ];
  int _currentModelIndex = 0;

  /// Initialize the Gemini Vision model.
  Future<void> init() async {
    _currentModelIndex = 0;
    await _initModel();
  }

  Future<void> _initModel() async {
    if (_currentModelIndex >= _modelsToTry.length) {
      print('❌ Gemini: All models failed.');
      return;
    }

    final modelName = _modelsToTry[_currentModelIndex];
    try {
      _model = GenerativeModel(
        model: modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          maxOutputTokens: 200,
          temperature: 0.3,
        ),
      );
      _isReady = true;
      print('✅ Gemini Vision ready with model: $modelName');
    } catch (e) {
      print('❌ Gemini init error for $modelName: $e');
      _isReady = false;
    }
  }

  /// Try the next model in the list if current one gives 404.
  Future<bool> tryNextModel() async {
    _currentModelIndex++;
    if (_currentModelIndex < _modelsToTry.length) {
      await _initModel();
      return true;
    }
    return false;
  }

  /// Build the system prompt with style-specific length instructions.
  String _buildPrompt(DescriptionStyle style) {
    String lengthRule;
    switch (style) {
      case DescriptionStyle.brief:
        lengthRule = 'جملة واحدة فقط — أقصى ٨ كلمات.';
        break;
      case DescriptionStyle.normal:
        lengthRule = 'جملتين أو ٣ جمل كحد أقصى.';
        break;
      case DescriptionStyle.detailed:
        lengthRule = '٤ أو ٥ جمل كحد أقصى.';
        break;
    }

    return '''
أنت مساعد بصري لشخص كفيف في مصر.
المستخدم لا يرى — كل كلمة تقولها هي عينه.

مهمتك:
وصف ما في الصورة بالعربي الفصيح البسيط. $lengthRule

القواعد:
١. ابدأ دائماً بأهم شيء قدام المستخدم مباشرة
٢. اذكر الاتجاهات: يمين، يسار، قدام، وراء
٣. اذكر المسافة: قريب، بعيد، على بعد خطوات
٤. نبّه على أي خطر فوراً: سلالم، سيارات متحركة، حفر، أبواب زجاجية، عقبات في الطريق
٥. لا تقل "أرى" أو "في الصورة" — تكلم كأنك واقف جنب المستخدم
٦. لا تخمن حاجة مش واضحة — اذكر بس اللي أنت متأكد منه
٧. لا تصف ألوان إلا لو مهمة للسلامة (إشارة مرور مثلاً)
٨. لا تذكر أي شخص بالاسم أو تحدد العمر أو الجنس إلا لو ضروري
٩. لا تستخدم كلمات صعبة أو تقنية
١٠. لا تذكر أي حاجة مش موجودة فعلاً — الوصف الغلط ممكن يعرّض المستخدم للخطر
١١. لو الصورة مظلمة أو مش واضحة، قول "الصورة مش واضحة، حاول توجه الكاميرا تاني"
١٢. لو فيه إشارة مرور، اذكر لونها — ده استثناء مهم لقاعدة الألوان

تنسيق الإجابة:
[الوصف الرئيسي]. [الاتجاهات]. [تحذير لو فيه خطر].
''';
  }

  /// Describe a scene from JPEG bytes.
  ///
  /// Returns the Arabic description text, or an error message
  /// if something goes wrong. Never returns null — always returns
  /// a speakable Arabic string.
  Future<String> describeScene(
    Uint8List imageBytes, {
    DescriptionStyle style = DescriptionStyle.normal,
  }) async {
    if (!_isReady || _model == null) {
      return 'خدمة الوصف مش جاهزة. تأكد من مفتاح الـ API.';
    }

    try {
      final prompt = _buildPrompt(style);
      final content = Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ]);

      final response = await _model!
          .generateContent([content])
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception('timeout');
      });

      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        return 'مقدرتش أوصف المشهد. حاول تاني.';
      }

      return text.trim();
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      print('❌ Gemini error details: $e');

      // If model not found (404), try next model fallback
      if (msg.contains('notfound') || msg.contains('404')) {
        print('🔄 Model not found, trying fallback...');
        final switched = await tryNextModel();
        if (switched) {
          return describeScene(imageBytes, style: style);
        }
      }

      if (msg.contains('timeout')) {
        return 'الوصف أخذ وقت طويل. حاول تاني.';
      } else if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection')) {
        return 'مفيش اتصال بالإنترنت. حاول تاني.';
      } else if (msg.contains('quota') ||
          msg.contains('rate') ||
          msg.contains('resource') ||
          msg.contains('429')) {
        return 'الخدمة مشغولة دلوقتي (Rate Limit). استنى دقيقة وحاول تاني.';
      } else {
        return 'خطأ من جوجل: ${e.toString().replaceAll('Exception:', '').trim()}';
      }
    } catch (e) {
      print('❌ Gemini unexpected error: $e');
      return 'حصل خطأ غير متوقع. حاول تاني.';
    }
  }

  void dispose() {
    _model = null;
    _isReady = false;
  }
}
