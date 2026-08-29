import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    runApp(const _ConfigurationErrorApp());
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );

    runApp(const NApp());
  } catch (e) {
    runApp(
      _ConfigurationErrorApp(
        message: 'تعذر تشغيل اتصال Supabase.\n\n$e',
      ),
    );
  }
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'N',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07080D),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF07080D),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message ??
                  'لم يتم إعداد اتصال Supabase.\n\n'
                  'تحقق من SUPABASE_URL و '
                  'SUPABASE_PUBLISHABLE_KEY.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
