import 'package:flutter/material.dart';

/// A circular send button.
class SendButton extends StatelessWidget {
  const SendButton({super.key, required this.onTap});

  /// Callback when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFF3C3C3C),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_forward, color: Colors.white, size: 22),
      ),
    );
  }
}
