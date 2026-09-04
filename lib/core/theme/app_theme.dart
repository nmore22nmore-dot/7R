import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'app_text_styles.dart';

abstract final class NTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: NColors.cyan,
      brightness: Brightness.dark,
    ).copyWith(
      primary: NColors.cyan,
      secondary: NColors.pink,
      surface: NColors.surface,
      onSurface: NColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: NColors.background,
      fontFamily: 'Cairo',
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: NColors.background,
        foregroundColor: NColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: NTextStyles.title,
      ),
      cardTheme: const CardThemeData(
        color: NColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(NSizes.radiusMedium)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: NColors.divider,
        thickness: 0.7,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NColors.surface,
        hintStyle: NTextStyles.caption.copyWith(fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NSizes.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NSizes.radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NSizes.radiusMedium),
          borderSide: const BorderSide(color: NColors.cyan, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NColors.background,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 70,
        labelTextStyle: const WidgetStatePropertyAll(NTextStyles.nav),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(size: 25, color: NColors.white),
        ),
      ),
    );
  }
}
