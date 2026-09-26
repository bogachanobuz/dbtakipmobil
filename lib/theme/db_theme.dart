import 'package:flutter/material.dart';

abstract final class DbColors {
  static const navy = Color(0xFF1E4D8C);
  static const navyDeep = Color(0xFF14386A);
  static const ink = Color(0xFF142033);
  static const muted = Color(0xFF6B7385);
  static const red = Color(0xFFE10600);
  static const redDeep = Color(0xFFB10500);
  static const mist = Color(0xFFF3F6FB);
  static const line = Color(0xFFE6EAF2);
  static const skin = Color(0xFFF3C19A);
  static const skinDeep = Color(0xFFE3A97A);
}

abstract final class DbText {
  static TextStyle style({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color color = DbColors.ink,
    double height = 1.2,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: 'Nunito',
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', _axis(weight))],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static double _axis(FontWeight weight) {
    return switch (weight) {
      FontWeight.w400 => 400,
      FontWeight.w500 => 500,
      FontWeight.w600 => 600,
      FontWeight.w800 => 800,
      FontWeight.w900 => 900,
      _ => 700,
    };
  }
}
