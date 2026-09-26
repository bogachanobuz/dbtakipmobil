import 'package:flutter/material.dart';

import '../theme/db_theme.dart';

class LipButton extends StatefulWidget {
  const LipButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = DbColors.red,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  State<LipButton> createState() => _LipButtonState();
}

class _LipButtonState extends State<LipButton> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton(
        onPressed: widget.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: widget.color,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          widget.label,
          style: DbText.style(
            size: 16,
            weight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
