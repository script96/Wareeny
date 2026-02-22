// Warene — Gemini Vision scene description service
//
// Sends a camera snapshot to Gemini Vision API and returns
// a natural Arabic description optimized for blind users.

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Description verbosity level.
enum DescriptionStyle {
  brief,    // 1 sentence — walking/scanning
  normal,   // 2–3 sentences — default daily use
  detailed, // 4–5 sentences — exploring a new place
}

class GeminiService {
  bool _isReady = false;

  bool get isReady => _isReady;

  // API key — keep this private, do not commit to public repos
  static const String _apiKey = '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';

  /// Initialize the Gemini Vision model.
  Future<void> init() async {
    _isReady = true; // Groq needs no SDK initialization
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

    try {
      final base64Image = base64Encode(imageBytes);
      final prompt = _buildPrompt(style);

      final response = await http.post(
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
                {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}},
                {'type': 'text', 'text': prompt}
              ]
            }
          ],
          'max_tokens': 300,
        }),
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception('timeout');
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices'][0]['message']['content'] as String?;
        if (text == null || text.trim().isEmpty) return 'مقدرتش أوصف المشهد. حاول تاني.';
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
      if (msg.contains('socket') || msg.contains('network') || msg.contains('connection')) return 'مفيش اتصال بالإنترنت.';
      return 'حصل خطأ غير متوقع. حاول تاني.';
    }
  }

  void dispose() {
    _isReady = false;
  }
}
