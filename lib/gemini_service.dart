// Warene — Scene description + Document QA service (Groq / Llama)
//
// Scene description: sends camera snapshots to Groq's Llama Vision API.
// Document QA: answers questions from OCR text via Groq's text LLM.
//
// NOTE: The class is still named GeminiService for historical reasons.
// It originally targeted Google Gemini but now uses Groq.

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/object_finder_types.dart';
import 'models/qa_types.dart';
import 'ocr_service.dart';

/// Description verbosity level.
enum DescriptionStyle {
  brief, // 1 sentence — walking/scanning
  normal, // 2–3 sentences — default daily use
  detailed, // 4–5 sentences — exploring a new place
}

class GeminiService {
  static const String _dartDefineApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  bool _isReady = false;

  bool get isReady => _isReady;

  // API key loaded from .env at runtime.
  // For dev builds this uses flutter_dotenv.
  // For production, consider a backend proxy — secrets bundled
  // into a mobile APK can still be extracted.
  String get _apiKey {
    try {
      if (dotenv.isInitialized) {
        final envKey = dotenv.env['GROQ_API_KEY'] ?? '';
        if (envKey.isNotEmpty) return envKey;
      }
    } catch (_) {
      // Ignore missing/uninitialized dotenv and fall back to dart-define.
    }
    return _dartDefineApiKey;
  }

  /// Initialize the service. Validates the API key is present.
  Future<void> init() async {
    if (_apiKey.isEmpty) {
      print('❌ GROQ_API_KEY is missing from .env');
      _isReady = false;
      return;
    }
    _isReady = true;
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
    if (!_isReady) {
      return 'خدمة الوصف مش جاهزة. تأكد من مفتاح الـ API.';
    }

    if (_apiKey.isEmpty) {
      return 'مفتاح الـ API مش موجود. تحقق من ملف الإعدادات.';
    }

    try {
      final base64Image = base64Encode(imageBytes);
      final prompt = _buildPrompt(style);

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/jpeg;base64,$base64Image',
                      },
                    },
                    {'type': 'text', 'text': prompt},
                  ],
                },
              ],
              'max_tokens': 300,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices'][0]['message']['content'] as String?;
        if (text == null || text.trim().isEmpty)
          return 'مقدرتش أوصف المشهد. حاول تاني.';
        return text.trim();
      } else if (response.statusCode == 429) {
        return 'الخدمة مشغولة دلوقتي. استنى دقيقة وحاول تاني.';
      } else if (response.statusCode == 401 || response.statusCode == 400) {
        return 'خطأ في المفتاح، تحقق من الإعدادات.';
      } else {
        return 'خطأ من الخدمة: ${response.statusCode}';
      }
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout')) return 'الوصف أخذ وقت طويل. حاول تاني.';
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection'))
        return 'مفيش اتصال بالإنترنت.';
      return 'حصل خطأ غير متوقع. حاول تاني.';
    }
  }

  // ── Arabic OCR — extract text from image ──

  /// Extract all readable text from [imageBytes] using the vision model.
  /// Used for Arabic OCR — Groq handles Arabic script that ML Kit cannot.
  ///
  /// Returns:
  ///   - non-empty String: extracted text
  ///   - empty String: no text found in the image
  ///   - null: API/network error (rate limit, auth, timeout, etc.)
  Future<String?> extractTextFromImage(Uint8List imageBytes) async {
    if (!_isReady || _apiKey.isEmpty) return null;

    try {
      final base64Image = base64Encode(imageBytes);

      const prompt =
          'اقرأ كل النص الموجود في هذه الصورة وأعده كما هو بالضبط بدون أي تعليق أو إضافة. لو مفيش نص، رد بـ: لا يوجد نص.';

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/jpeg;base64,$base64Image',
                      },
                    },
                    {'type': 'text', 'text': prompt},
                  ],
                },
              ],
              'max_tokens': 500,
            }),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw Exception('timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices'][0]['message']['content'] as String?;
        if (text == null || text.trim().isEmpty) return '';
        final result = text.trim();
        if (result == 'لا يوجد نص.' || result == 'لا يوجد نص') return '';
        return result;
      }
      // 429, 401, 400, etc — treat as error so caller can distinguish.
      print('⚠️ extractTextFromImage HTTP ${response.statusCode}');
      return null;
    } on Exception catch (e) {
      print('⚠️ extractTextFromImage error: $e');
      return null;
    }
  }

  // ── Smart Finder — Object-in-scene search ──

  /// Ask the vision model whether [targetName] is visible in the image.
  ///
  /// Returns a [SmartFindResult] with direction/distance when found,
  /// or `found: false` when not found or on error.
  Future<SmartFindResult> findObjectInScene(
    Uint8List imageBytes, {
    required String targetName,
    required String targetArabicName,
  }) async {
    if (!_isReady || _apiKey.isEmpty) {
      return const SmartFindResult.error(
        'مفتاح الـ API مش موجود. تحقق من ملف الإعدادات.',
      );
    }

    try {
      final base64Image = base64Encode(imageBytes);

      final prompt =
          '''
You are helping a blind user find an object.
Target object: $targetName / $targetArabicName.
Look ONLY for this specific target in the image.
Return JSON only, no extra text:
{"found": true/false, "direction": "left|center|right|unknown", "distance": "very_close|close|far|unknown", "arabic_response": "..."}

Rules:
- If the target is clearly visible, set found to true and describe its position.
- arabic_response must be a short Arabic sentence like: "المفاتيح على اليمين، قريبة"
- If you are not sure, found MUST be false. Do not guess.
- Do not mention other objects.
''';

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/jpeg;base64,$base64Image',
                      },
                    },
                    {'type': 'text', 'text': prompt},
                  ],
                },
              ],
              'max_tokens': 150,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            (data['choices'][0]['message']['content'] as String?)?.trim() ?? '';
        print('🔍 Smart Finder raw response: $text');

        // Extract JSON from the response (it may be wrapped in markdown fences)
        String jsonStr = text;
        final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(text);
        if (jsonMatch != null) {
          jsonStr = jsonMatch.group(0)!;
        }

        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          return SmartFindResult.fromJson(json);
        } catch (e) {
          print('⚠️ Smart Finder JSON parse failed: $e');
          return const SmartFindResult(found: false);
        }
      } else if (response.statusCode == 429) {
        return const SmartFindResult.error('الخدمة مشغولة. حاول تاني.');
      } else if (response.statusCode == 401 || response.statusCode == 400) {
        return const SmartFindResult.error(
          'خطأ في المفتاح، تحقق من الإعدادات.',
        );
      } else {
        return SmartFindResult.error('خطأ من الخدمة: ${response.statusCode}');
      }
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout')) {
        return const SmartFindResult(found: false);
      }
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection')) {
        return const SmartFindResult.error('البحث الذكي يحتاج إنترنت');
      }
      return const SmartFindResult.error('حصل خطأ غير متوقع. حاول تاني.');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  DOCUMENT QA — Text-only Q&A from OCR content
  // ══════════════════════════════════════════════════════════════════

  /// Maximum document context size in characters.
  static const int _maxDocumentChars = 4000;

  /// Text-only model for QA (better reasoning than vision model).
  static const String _qaModel = 'llama-3.3-70b-versatile';

  /// Answer a question using only the provided document text.
  ///
  /// Returns a [DocumentQaResult] with the Arabic answer or an error
  /// message. Never returns null — always returns a speakable result.
  Future<DocumentQaResult> answerQuestionFromDocument({
    required String documentText,
    required String question,
    List<QaTurn> history = const [],
    OCRLanguage language = OCRLanguage.arabic,
  }) async {
    if (!_isReady) {
      return const DocumentQaResult.error(
        'خدمة الإجابة مش جاهزة. تأكد من مفتاح الـ API.',
      );
    }

    if (_apiKey.isEmpty) {
      return const DocumentQaResult.error(
        'مفتاح الـ API مش موجود. تحقق من ملف الإعدادات.',
      );
    }

    try {
      // Truncate document if too long
      String docContext = documentText;
      if (docContext.length > _maxDocumentChars) {
        docContext = docContext.substring(0, _maxDocumentChars);
        print('📄 Document truncated to $_maxDocumentChars chars for QA');
      }

      // Build messages array
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': _buildQaSystemPrompt(docContext)},
      ];

      // Add conversation history (last N turns)
      for (final turn in history) {
        messages.add({'role': 'user', 'content': turn.question});
        messages.add({'role': 'assistant', 'content': turn.answer});
      }

      // Add current question
      messages.add({'role': 'user', 'content': question});

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _qaModel,
              'messages': messages,
              'max_tokens': 300,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Defensive parsing against missing fields
        final choices = data is Map<String, dynamic> ? data['choices'] : null;
        if (choices is! List || choices.isEmpty) {
          return const DocumentQaResult.error(
            'مقدرتش أطلع إجابة. حاول تسأل بطريقة تانية.',
          );
        }

        final choice = choices.first;
        if (choice is! Map<String, dynamic>) {
          return const DocumentQaResult.error(
            'مقدرتش أطلع إجابة. حاول تسأل بطريقة تانية.',
          );
        }

        final message = choice['message'];
        if (message is! Map<String, dynamic>) {
          return const DocumentQaResult.error(
            'مقدرتش أطلع إجابة. حاول تسأل بطريقة تانية.',
          );
        }

        final text = message['content'];
        if (text is! String || text.trim().isEmpty) {
          return const DocumentQaResult.error(
            'مقدرتش ألاقي إجابة. حاول تسأل بطريقة تانية.',
          );
        }
        return DocumentQaResult(answer: text.trim());
      } else if (response.statusCode == 429) {
        return const DocumentQaResult.error(
          'الخدمة مشغولة دلوقتي. استنى دقيقة وحاول تاني.',
        );
      } else if (response.statusCode == 401 || response.statusCode == 400) {
        return const DocumentQaResult.error(
          'خطأ في المفتاح، تحقق من الإعدادات.',
        );
      } else {
        return DocumentQaResult.error('خطأ من الخدمة: ${response.statusCode}');
      }
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout')) {
        return const DocumentQaResult.error(
          'الإجابة أخدت وقت طويل. حاول تاني.',
        );
      }
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection')) {
        return const DocumentQaResult.error('مفيش اتصال بالإنترنت.');
      }
      return const DocumentQaResult.error('حصل خطأ غير متوقع. حاول تاني.');
    }
  }

  /// Build the system prompt for document QA.
  String _buildQaSystemPrompt(String documentText) {
    return '''
أنت مساعد ذكي بتجاوب على أسئلة عن نص مكتوب.
المستخدم كفيف وبيسمع الإجابة صوتياً.

النص المكتوب:
---
$documentText
---

القواعد:
١. جاوب بالعربي المصري البسيط.
٢. جاوب من النص اللي فوق بس. ماتخترعش أي معلومة مش موجودة.
٣. لو المعلومة مش موجودة في النص، قول: "المعلومة دي مش موجودة في النص."
٤. خلي الإجابة قصيرة ومباشرة — جملة أو اتنين كفاية.
٥. ماتذكرش أسماء أو أرقام أو تواريخ مش موجودة في النص.
٦. لو النص مش واضح أو فيه أخطاء إملائية، قول إن النص مش واضح في الجزء ده.
٧. ماتقولش "حسب النص" أو "النص بيقول" — جاوب مباشرة.
٨. الإجابة لازم تكون نص عادي (بدون Markdown، بدون قوائم نقطية).
''';
  }

  void dispose() {
    _isReady = false;
  }
}
