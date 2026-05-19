import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

class ColorService {
  static final ColorService _instance = ColorService._internal();
  factory ColorService() => _instance;
  ColorService._internal();

  /// Detect the dominant color from the center of an image.
  /// Returns an Arabic color name.
  Future<String> detectColor(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      return detectColorBytes(bytes);
    } catch (e) {
      print('❌ Color detection error: $e');
      return 'خطأ في التعرف على اللون';
    }
  }

  Future<String> detectColorBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        image.dispose();
        codec.dispose();
        return 'غير معروف';
      }

      // Average a 5x5 grid around center for more stable results
      int totalR = 0, totalG = 0, totalB = 0;
      int count = 0;
      for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
          final px = (centerX + dx).clamp(0, image.width - 1);
          final py = (centerY + dy).clamp(0, image.height - 1);
          final offset = (py * image.width + px) * 4;
          if (offset + 2 < byteData.lengthInBytes) {
            totalR += byteData.getUint8(offset);
            totalG += byteData.getUint8(offset + 1);
            totalB += byteData.getUint8(offset + 2);
            count++;
          }
        }
      }

      image.dispose();
      codec.dispose();

      if (count == 0) return 'غير معروف';

      return _getColorName(totalR ~/ count, totalG ~/ count, totalB ~/ count);
    } catch (e) {
      print('❌ Color detection error: $e');
      return 'خطأ في التعرف على اللون';
    }
  }

  String _getColorName(int r, int g, int b) {
    final hsl = _rgbToHsl(r, g, b);
    final double h = hsl[0];
    final double s = hsl[1];
    final double l = hsl[2];

    if (l < 0.15) return 'أسود';
    if (l > 0.85) return 'أبيض';
    if (s < 0.15) return 'رمادي';

    if (h < 15 || h >= 345) return 'أحمر';
    if (h < 45) return 'برتقالي';
    if (h < 75) return 'أصفر';
    if (h < 165) return 'أخضر';
    if (h < 255) return 'أزرق';
    if (h < 315) return 'بنفسجي';
    if (h < 345) return 'وردي';

    return 'لون غير معروف';
  }

  List<double> _rgbToHsl(int r, int g, int b) {
    final double rf = r / 255.0;
    final double gf = g / 255.0;
    final double bf = b / 255.0;

    final double max = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
    final double min = [rf, gf, bf].reduce((a, b) => a < b ? a : b);
    final double delta = max - min;

    double h = 0;
    if (delta != 0) {
      if (max == rf) {
        h = ((gf - bf) / delta) % 6;
      } else if (max == gf) {
        h = (bf - rf) / delta + 2;
      } else {
        h = (rf - gf) / delta + 4;
      }
      h *= 60;
    }

    final double l = (max + min) / 2;
    final double s = delta == 0 ? 0 : delta / (1 - (2 * l - 1).abs());

    return [h < 0 ? h + 360 : h, s, l];
  }
}
