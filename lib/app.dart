import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/auth_page.dart';

class NApp extends StatelessWidget {
  const NApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'N',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07080D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C8FF),
          brightness: Brightness.dark,
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const NWelcomePage(),
    );
  }
}

class NWelcomePage extends StatelessWidget {
  const NWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 115,
                  height: 115,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00C8FF),
                        Color(0xFFFF287A),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'N',
                      style: TextStyle(
                        fontSize: 74,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'N',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'شبكتك الاجتماعية الجديدة',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'فيديوهات • منشورات • قصص • رسائل • بث مباشر',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 38),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AuthPage(),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'ابدأ الآن',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
