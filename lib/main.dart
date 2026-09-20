import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

const _defaultSupabaseUrl = 'https://bpmopmwfatbwlcgvnbzw.supabase.co';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  } catch (_) {
    // Firebase is optional at startup; Supabase can still initialize.
  }

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
