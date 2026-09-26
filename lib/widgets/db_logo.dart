import 'package:flutter/material.dart';

import '../theme/db_theme.dart';

class DbLogo extends StatelessWidget {
  const DbLogo({super.key, this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand/db_mark.png',
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        SizedBox(width: height * 0.28),
        Text(
          'dbtakip',
          style: DbText.style(
            size: height * 0.62,
            weight: FontWeight.w900,
            color: const Color(0xFF1A2845),
            height: 1,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }
}
