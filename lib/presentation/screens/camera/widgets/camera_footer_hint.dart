import 'package:flutter/material.dart';

class CameraFooterHint extends StatelessWidget {
  final bool isQa;

  const CameraFooterHint({super.key, required this.isQa});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          isQa
              ? 'نقرتين: اسأل سؤال  •  مطول: القائمة'
              : 'مطول: القائمة  •  نقرتين: وصف  •  سحب: تبديل',
          style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11),
        ),
      ),
    );
  }
}
