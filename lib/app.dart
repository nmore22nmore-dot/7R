import 'package:flutter/material.dart';
import 'pages/auth_page.dart';
import 'pages/home_page.dart';

class NApp extends StatelessWidget {
  final bool configured;
  const NApp({super.key, required this.configured});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'N',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF07080D),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00C8FF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: configured ? const AuthGate() : const ConfigPage(),
  );
}

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Padding(
      padding: EdgeInsets.all(28),
      child: Text(
        'N\n\nأضف SUPABASE_URL و SUPABASE_PUBLISHABLE_KEY في بيئة البناء.',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: 18),
      ),
    )),
  );
}
