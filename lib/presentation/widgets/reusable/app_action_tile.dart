import 'package:flutter/material.dart';

class AppActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String semanticsLabel;
  final VoidCallback onTap;

  const AppActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withAlpha(230),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
