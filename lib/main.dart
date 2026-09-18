import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

const _defaultSupabaseUrl = 'https://bpmopmwfatbwlcgvnbzw.supabase.co';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultSupabaseUrl,
  );
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (key.isEmpty) {
    runApp(const NApp(configError: true));
    return;
  }

  try {
    await Supabase.initialize(
      url: url,
      publishableKey: key,
    );
    runApp(const NApp());
  } catch (_) {
    runApp(const NApp(configError: true));
  }
}
