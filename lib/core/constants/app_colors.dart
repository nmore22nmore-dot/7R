import 'package:flutter/material.dart';

abstract final class NColors {
  static const background = Color(0xFF050607);
  static const surface = Color(0xFF121212);
  static const surfaceElevated = Color(0xFF1B1B1D);
  static const divider = Color(0xFF2A2A2D);
  static const white = Color(0xFFFFFFFF);
  static const muted = Color(0xFF9B9BA1);
  static const cyan = Color(0xFF00F2FE);
  static const primary = cyan;
  static const card = surfaceElevated;
  static const pink = Color(0xFFFF0050);
  static const red = Color(0xFFFF1F3D);

  static const brandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cyan, Color(0xFF8B9AA0), pink],
  );

  static const actionGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [cyan, pink],
  );
}
