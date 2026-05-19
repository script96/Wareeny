import 'package:flutter/material.dart';

class CameraBrandTitle extends StatelessWidget {
  const CameraBrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 48,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          'وريني',
          style: TextStyle(
            color: Colors.white.withAlpha(200),
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}
