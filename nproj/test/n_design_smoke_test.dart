import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:n/core/constants/app_colors.dart';
import 'package:n/core/theme/app_theme.dart';
import 'package:n/core/widgets/n_logo.dart';

void main() {
  testWidgets('N design system smoke test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NTheme.dark(),
        home: const Scaffold(
          body: Center(child: NLogo(size: 48)),
        ),
      ),
    );

    expect(find.byType(NLogo), findsOneWidget);
    expect(NColors.background, isA<Color>());
  });
}
