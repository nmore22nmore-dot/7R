import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

final sb = Supabase.instance.client;

const bg = Color(0xFF07080D);
const panel = Color(0xFF11131B);
const cyan = Color(0xFF00C8FF);
const pink = Color(0xFFFF287A);
const authRedirectUrl = 'n://auth-callback';

Future<void> _registerPushToken() async {
  final user = sb.auth.currentUser;
  if (user == null) return;
  try {
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return;
    await sb.from('push_tokens').upsert({
      'user_id': user.id,
      'token': token,
      'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,token');
    messaging.onTokenRefresh.listen((next) async {
      if (next.isEmpty) return;
      try {
        await sb.from('push_tokens').upsert({
          'user_id': user.id,
          'token': next,
          'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,token');
      } catch (_) {}
    });
  } catch (_) {}
}

String _mimeForExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'mp4': return 'video/mp4';
    case 'mov': return 'video/quicktime';
    case 'm4v': return 'video/x-m4v';
    case 'webm': return 'video/webm';
    case 'avi': return 'video/x-msvideo';
    case 'mkv': return 'video/x-matroska';
    case 'jpg': case 'jpeg': return 'image/jpeg';
    case 'png': return 'image/png';
    case 'gif': return 'image/gif';
    case 'webp': return 'image/webp';
    case 'heic': return 'image/heic';
    case 'heif': return 'image/heif';
    case 'pdf': return 'application/pdf';
    case 'zip': return 'application/zip';
    case 'txt': return 'text/plain';
    case 'json': return 'application/json';
    case 'doc': return 'application/msword';
    case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls': return 'application/vnd.ms-excel';
    case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt': return 'application/vnd.ms-powerpoint';
    case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    default: return 'application/octet-stream';
  }
}


String _storageMessage(Object error) {
  if (error is StorageException) return error.message;
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

String _storagePath(String value, String bucket) {
  if (value.startsWith('http')) {
    final marker = '/storage/v1/object/public/$bucket/';
    final i = value.indexOf(marker);
    if (i >= 0) return Uri.decodeComponent(value.substring(i + marker.length));
    final signedMarker = '/storage/v1/object/sign/$bucket/';
    final j = value.indexOf(signedMarker);
    if (j >= 0) return Uri.decodeComponent(value.substring(j + signedMarker.length).split('?').first);
  }
  return value;
}


class OfflineStore {
  static Future<Directory> _dir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/n_offline');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
  static Future<File> _indexFile() async { final dir = await _dir(); return File('${dir.path}/index.json'); }
  static Future<List<Map<String,dynamic>>> list() async {
    try { final f=await _indexFile(); if(!await f.exists()) return []; final raw=jsonDecode(await f.readAsString()); if(raw is! List)return []; return raw.map((e)=>Map<String,dynamic>.from(e as Map)).where((e)=>File(e['path'].toString()).existsSync()).toList(); } catch(_){return [];}
  }
  static Future<void> _write(List<Map<String,dynamic>> items) async { final f=await _indexFile(); await f.writeAsString(jsonEncode(items)); }
  static Future<Map<String,dynamic>> download({required String id,required String url,required String type,String caption='',String username='N'}) async {
    final dir=await _dir(); final ext=type=='video'?'mp4':'jpg'; final file=File('${dir.path}/$id.$ext');
    if(!await file.exists()) { final client=HttpClient(); try { final request=await client.getUrl(Uri.parse(url)); final response=await request.close(); if(response.statusCode<200||response.statusCode>=300)throw Exception('HTTP ${response.statusCode}'); final sink=file.openWrite(); await response.pipe(sink); await sink.close(); } finally { client.close(force:true); } }
    final item={'id':id,'path':file.path,'type':type,'caption':caption,'username':username,'saved_at':DateTime.now().toIso8601String()}; final items=await list(); items.removeWhere((e)=>e['id'].toString()==id); items.insert(0,item); await _write(items); return item;
  }
  static Future<void> remove(String id) async { final items=await list(); for(final e in items.where((e)=>e['id'].toString()==id)){try{await File(e['path'].toString()).delete();}catch(_){}} items.removeWhere((e)=>e['id'].toString()==id); await _write(items); }
}
Future<void> _downloadPost(BuildContext context, Map<String,dynamic> post) async {
  final id=post['id']?.toString(), url=post['media_url']?.toString()??'', type=post['media_type']?.toString()??'video'; if(id==null||id.isEmpty||url.isEmpty)return;
  try { await OfflineStore.download(id:id,url:url,type:type,caption:post['caption']?.toString()??'',username:post['profile']?['username']?.toString()??'N'); if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تنزيل المحتوى للمشاهدة دون اتصال.'))); } catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تنزيل المحتوى: $e')));}
}

Future<String?> _signedPostUrl(String value) async {
  if (value.isEmpty) return null;
  try {
    return await sb.storage.from('post-media').createSignedUrl(_storagePath(value, 'post-media'), 3600);
  } catch (_) {
    return null;
  }
}

Future<List<Map<String, dynamic>>> loadPostsWithProfiles({required bool following}) async {
  final user = sb.auth.currentUser;
  var query = sb.from('posts').select('*');
  if (following) {
    if (user == null) return [];
    final follows = await sb.from('follows').select('following_id').eq('follower_id', user.id);
    final ids = List<Map<String, dynamic>>.from(follows).map((r) => r['following_id'].toString()).toList();
    if (ids.isEmpty) return [];
    query = query.inFilter('user_id', ids);
  }
  // Do not filter visibility here. Supabase RLS (can_read_post) is the single
  // source of truth for public/private/followers/+21/block rules.
  final raw = await query.order('created_at', ascending: false).limit(50);
  final rows = List<Map<String, dynamic>>.from(raw);
  if (rows.isEmpty) return rows;
  final ids = rows.map((r) => r['user_id'].toString()).toSet().toList();
  final profiles = await sb.from('profiles').select('id,username,avatar_url,bio,is_verified').inFilter('id', ids);
  final byId = <String, Map<String, dynamic>>{for (final p in List<Map<String, dynamic>>.from(profiles)) p['id'].toString(): p};
  return Future.wait(rows.map((row) async {
    final copy = Map<String, dynamic>.from(row);
    copy['profile'] = byId[row['user_id'].toString()];
    final rawUrl = (copy['media_url'] ?? '').toString();
    final path = _storagePath(rawUrl, 'post-media');
    if (path.isNotEmpty) {
      try { copy['media_url'] = await sb.storage.from('post-media').createSignedUrl(path, 3600); } catch (_) { copy['media_url'] = rawUrl; }
    }
    return copy;
  }));
}

class NApp extends StatelessWidget {
  final bool configError;

  const NApp({
    super.key,
    this.configError = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: cyan,
      brightness: Brightness.dark,
    ).copyWith(
      primary: cyan,
      secondary: pink,
      surface: panel,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'N',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: scheme,
        useMaterial3: true,
        fontFamily: 'sans',
        dividerColor: const Color(0xFF202833),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF10131A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF252B36)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF252B36)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: cyan, width: 1.4),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          centerTitle: true,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF0B0D13),
          indicatorColor: Color(0xFF17202A),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: configError ? const ConfigPage() : const AuthGate(),
    );
  }
}

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'إعداد Supabase غير مكتمل.\n'
            'أضف SUPABASE_PUBLISHABLE_KEY في إعدادات البناء. رابط N مضمّن افتراضيًا، ويمكن تغييره عبر SUPABASE_URL.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool passwordRecovery = false;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = sb.auth.onAuthStateChange.listen(
      (data) {
        if (!mounted) return;
        setState(() {
          passwordRecovery = data.event == AuthChangeEvent.passwordRecovery;
        });
        if (data.session != null) {
          _registerPushToken();
        }
      },
      onError: (_) {},
    );
    if (sb.auth.currentSession != null) {
      _registerPushToken();
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (passwordRecovery) return const UpdatePasswordPage();
    return sb.auth.currentSession == null ? const AuthPage() : const Shell();
  }
}

class UpdatePasswordPage extends StatefulWidget {
  const UpdatePasswordPage({super.key});

  @override
  State<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends State<UpdatePasswordPage> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  bool obscure = true;
  String? message;

  Future<void> updatePassword() async {
    final p = password.text;
    if (p.length < 6 || p != confirm.text) {
      setState(() => message = 'تأكد من أن كلمة المرور 6 أحرف على الأقل ومتطابقة.');
      return;
    }
    setState(() { busy = true; message = null; });
    try {
      await sb.auth.updateUser(UserAttributes(password: p));
      if (mounted) {
        setState(() => message = 'تم تغيير كلمة المرور بنجاح.');
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) setState(() => message = 'تعذر تغيير كلمة المرور: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تعيين كلمة مرور جديدة')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const Icon(Icons.lock_reset, size: 72, color: cyan),
                  const SizedBox(height: 18),
                  const Text('أدخل كلمة المرور الجديدة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 22),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirm,
                    obscureText: obscure,
                    decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور', prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 14),
                    Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: cyan)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: FilledButton(
                      onPressed: busy ? null : updatePassword,
                      child: Text(busy ? 'جارٍ الحفظ...' : 'حفظ كلمة المرور'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final username = TextEditingController();
  DateTime? birthDate;

  bool signup = false;
  bool busy = false;
  bool obscure = true;
  String? error;

  String _authMessage(Object e) {
    final raw = e.toString().replaceFirst('AuthException: ', '');
    final lower = raw.toLowerCase();

    if (lower.contains('invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (lower.contains('email not confirmed')) {
      return 'البريد الإلكتروني غير مؤكد. افتح رسالة التأكيد ثم حاول تسجيل الدخول.';
    }
    if (lower.contains('user already registered')) {
      return 'هذا البريد مسجل مسبقًا. جرّب تسجيل الدخول.';
    }
    if (lower.contains('password')) {
      return 'كلمة المرور غير صالحة أو قصيرة.';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وإعدادات Supabase.';
    }
    return raw.isEmpty ? 'حدث خطأ غير معروف.' : raw;
  }

  Future<void> submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final e = email.text.trim();
    final p = pass.text;

    if (e.isEmpty || !e.contains('@')) {
      setState(() => error = 'أدخل بريدًا إلكترونيًا صحيحًا.');
      return;
    }
    if (p.length < 6) {
      setState(() => error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      if (signup) {
        final u = username.text.trim();

        if (u.length < 4) {
          throw Exception('اسم المستخدم يجب أن يكون 4 أحرف أو أكثر.');
        }
        if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(u)) {
          throw Exception('اسم المستخدم يقبل الحروف الإنجليزية والأرقام والشرطة السفلية فقط.');
        }
        if (birthDate == null) {
          throw Exception('اختر تاريخ الميلاد.');
        }
        final today = DateTime.now();
        var age = today.year - birthDate!.year;
        if (today.month < birthDate!.month || (today.month == birthDate!.month && today.day < birthDate!.day)) age--;
        if (age < 13) throw Exception('يجب أن يكون عمرك 13 سنة أو أكثر.');

        final r = await sb.auth.signUp(
          email: e,
          password: p,
          data: {'username': u, 'birth_date': birthDate!.toIso8601String().substring(0,10)},
          emailRedirectTo: authRedirectUrl,
        );

        if (r.user == null) {
          throw Exception('تعذر إنشاء الحساب.');
        }

        if (r.session == null && mounted) {
          setState(() {
            error = 'تم إنشاء الحساب. تحقق من بريدك الإلكتروني ثم سجّل الدخول.';
            signup = false;
          });
        }
      } else {
        await sb.auth.signInWithPassword(
          email: e,
          password: p,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = _authMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> resetPassword() async {
    final e = email.text.trim();
    if (e.isEmpty || !e.contains('@')) {
      setState(() => error = 'أدخل بريدك الإلكتروني أولًا لاستعادة كلمة المرور.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await sb.auth.resetPasswordForEmail(e, redirectTo: authRedirectUrl);
      if (mounted) {
        setState(() => error = 'تم إرسال رابط استعادة كلمة المرور إلى بريدك.');
      }
    } catch (e) {
      if (mounted) setState(() => error = _authMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFF06131A),
                      Color(0xFF07080D),
                      Color(0xFF14070E),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -120,
              right: -80,
              child: _glow(cyan, 260),
            ),
            Positioned(
              bottom: -150,
              left: -90,
              child: _glow(pink, 300),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/branding/n_icon.png',
                          width: 112,
                          height: 112,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'N',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          signup ? 'أنشئ حسابك في N' : 'مرحبًا بك في N',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'منصة اجتماعية عربية للفيديو القصير',
                          style: TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xCC0D1017),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: const Color(0xFF26303A),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 35,
                                spreadRadius: 1,
                                color: Color(0x55000000),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              if (signup) ...[
                                TextField(
                                  controller: username,
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(
                                    labelText: 'اسم المستخدم',
                                    prefixIcon: Icon(Icons.alternate_email),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.cake_outlined),
                                  title: Text(birthDate == null ? 'تاريخ الميلاد' : '${birthDate!.year}/${birthDate!.month.toString().padLeft(2,'0')}/${birthDate!.day.toString().padLeft(2,'0')}'),
                                  subtitle: const Text('يُستخدم لتطبيق حد العمر 13+ و+21.'),
                                  trailing: const Icon(Icons.calendar_month_outlined),
                                  onTap: busy ? null : () async {
                                    final picked = await showDatePicker(context: context, initialDate: DateTime(DateTime.now().year - 18), firstDate: DateTime(1900), lastDate: DateTime.now(), helpText: 'اختر تاريخ الميلاد');
                                    if (picked != null) setState(() => birthDate = picked);
                                  },
                                ),
                              ],
                              TextField(
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                decoration: const InputDecoration(
                                  labelText: 'البريد الإلكتروني',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: pass,
                                obscureText: obscure,
                                decoration: InputDecoration(
                                  labelText: 'كلمة المرور',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => obscure = !obscure),
                                    icon: Icon(
                                      obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              if (!signup)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: busy ? null : resetPassword,
                                    child: const Text('نسيت كلمة المرور؟'),
                                  ),
                                ),
                              if (error != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: error!.contains('تم')
                                        ? const Color(0x2210D8FF)
                                        : const Color(0x33FF287A),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: error!.contains('تم')
                                          ? cyan
                                          : Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [cyan, pink],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                    ),
                                    onPressed: busy ? null : submit,
                                    child: Text(
                                      busy
                                          ? 'جارٍ المعالجة...'
                                          : signup
                                              ? 'إنشاء الحساب'
                                              : 'تسجيل الدخول',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                          signup = !signup;
                                          error = null;
                                        }),
                                child: Text(
                                  signup
                                      ? 'لدي حساب بالفعل'
                                      : 'إنشاء حساب جديد',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _glow(Color color, double size) {
  return IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .18),
            blurRadius: 120,
            spreadRadius: 25,
          ),
        ],
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  final pages = const [HomePage(), FollowingPage(), PublishPage(), MessagesPage(), ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1017),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: const Color(0xFF1E2730)),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: Row(
              children: [
                _navItem(0, Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
                _navItem(1, Icons.people_outline_rounded, Icons.people_rounded, 'المتابعة'),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _openCreateMenu,
                      child: Container(
                        width: 54, height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          gradient: const LinearGradient(colors: [Color(0xFF25F4EE), Colors.white, Color(0xFFFF0050)]),
                          boxShadow: const [BoxShadow(color: Color(0x5525F4EE), blurRadius: 12)],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add, color: Colors.black, size: 27),
                        ),
                      ),
                    ),
                  ),
                ),
                _navItem(3, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'الرسائل'),
                _navItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'الملف الشخصي'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData normal, IconData active, String label) {
    final selected = index == i;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() => index = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? active : normal, color: selected ? cyan : Colors.white70, size: 22),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: selected ? cyan : Colors.white70, fontSize: 8.5, fontWeight: selected ? FontWeight.w900 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _openCreateMenu() {
    showModalBottomSheet<void>(
      context: context, backgroundColor: const Color(0xFF181818), showDragHandle: true,
      builder: (context) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          _createAction(Icons.video_call_outlined, 'فيديو', () { Navigator.pop(context); setState(() => index = 2); }),
          _createAction(Icons.image_outlined, 'صورة', () { Navigator.pop(context); setState(() => index = 2); }),
          _createAction(Icons.sensors, 'بث مباشر', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const LivePage())); }),
          _createAction(Icons.auto_awesome, 'N AI', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AiPage())); }),
        ]),
      )),
    );
  }

  Widget _createAction(IconData icon, String title, VoidCallback onTap) => SizedBox(
    width: 82, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10), child: Column(children: [
        CircleAvatar(radius: 25, backgroundColor: const Color(0xFF282828), child: Icon(icon, color: Colors.white)),
        const SizedBox(height: 7), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ])),
    ),
  );

}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ctrl = TextEditingController();
  List<Map<String, dynamic>> users = [];
  bool loading = false;
  Timer? debounce;

  Future<void> search() async {
    final q = ctrl.text.trim();
    if (q.isEmpty) { setState(() => users = []); return; }
    setState(() => loading = true);
    try {
      final data = await sb.from('profiles').select('id,username,avatar_url,bio').ilike('username', '%$q%').limit(30);
      if (mounted) setState(() => users = List<Map<String,dynamic>>.from(data));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر البحث: $e')));
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override void dispose() { debounce?.cancel(); ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('البحث')),
    body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      TextField(controller: ctrl, autofocus: true, textDirection: TextDirection.ltr,
        onChanged: (_) { debounce?.cancel(); debounce = Timer(const Duration(milliseconds:350), search); },
        decoration: InputDecoration(hintText:'ابحث عن اسم المستخدم', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: () { ctrl.clear(); search(); }, icon: const Icon(Icons.clear)))),
      const SizedBox(height: 12),
      if (loading) const LinearProgressIndicator(),
      Expanded(child: ListView.builder(itemCount: users.length, itemBuilder: (_,i) {
        final u=users[i];
        return ListTile(leading: CircleAvatar(backgroundImage: (u['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage(u['avatar_url']) : null, child: (u['avatar_url'] ?? '').toString().isEmpty ? const Icon(Icons.person) : null), title: Text('@${u['username'] ?? ''}'), subtitle: Text(u['bio'] ?? ''), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(userId: u['id'].toString(), username: u['username'].toString()))));
      }))
    ])),
  );
}

class UserProfilePage extends StatefulWidget {
  final String userId; final String username;
  const UserProfilePage({super.key, required this.userId, required this.username});
  @override State<UserProfilePage> createState() => _UserProfilePageState();
}
class _UserProfilePageState extends State<UserProfilePage> {
  List<Map<String,dynamic>> posts=[]; bool following=false; bool busy=false;
  @override void initState(){super.initState(); load();}
  Future<void> load() async {
    try {
      final data=await sb.from('posts').select().eq('user_id',widget.userId).order('created_at',ascending:false);
      final me=sb.auth.currentUser;
      if (me != null && me.id != widget.userId) {
        try {
          await sb.from('profile_views').upsert({'profile_id': widget.userId, 'viewer_id': me.id}, onConflict: 'profile_id,viewer_id');
        } catch (_) {}
      }
      final f=me==null?null:await sb.from('follows').select('following_id').eq('follower_id',me.id).eq('following_id',widget.userId).maybeSingle();
      if (mounted) {
        setState(() {
          posts = List<Map<String, dynamic>>.from(data);
          following = f != null;
        });
      }
    } catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحميل الملف: $e'))); }
  }
  Future<void> toggleFollow() async {
    final me=sb.auth.currentUser; if(me==null || me.id==widget.userId)return; setState(()=>busy=true);
    try {
      if (following) {
        await sb.from('follows').delete().eq('follower_id', me.id).eq('following_id', widget.userId);
      } else {
        await sb.from('follows').insert({'follower_id': me.id, 'following_id': widget.userId});
      }
      if (mounted) {
        setState(() {
          following = !following;
        });
      }
    }
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحديث المتابعة: $e')));} finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> blockUser() async {
    final me=sb.auth.currentUser; if(me==null || me.id==widget.userId)return;
    try {
      await sb.from('blocked_users').upsert({'blocker_id':me.id,'blocked_id':widget.userId}, onConflict:'blocker_id,blocked_id');
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم حظر الحساب.')));Navigator.pop(context);}
    } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حظر الحساب: $e')));}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('@${widget.username}'),actions:[IconButton(onPressed:blockUser,icon:const Icon(Icons.block_outlined))]),body:Column(children:[
    const SizedBox(height:18), CircleAvatar(radius:44,child:Text(widget.username.isEmpty?'N':widget.username[0].toUpperCase(),style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold))), const SizedBox(height:10),
    FilledButton(onPressed:busy?null:toggleFollow,child:Text(following?'إلغاء المتابعة':'متابعة')), const SizedBox(height:12),
    Expanded(child:GridView.builder(padding:const EdgeInsets.all(8),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:4,mainAxisSpacing:4),itemCount:posts.length,itemBuilder:(_,i)=>FutureBuilder<String?>(
      future: _signedPostUrl(posts[i]['media_url'].toString()),
      builder: (_, snap) => snap.hasData ? Image.network(snap.data!, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.broken_image)) : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    )))
  ]));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeedPage(
      following: false,
    );
  }
}

class FollowingPage extends StatelessWidget {
  const FollowingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeedPage(
      following: true,
    );
  }
}


class StoryStrip extends StatefulWidget {
  const StoryStrip({super.key});
  @override State<StoryStrip> createState() => _StoryStripState();
}

class _StoryStripState extends State<StoryStrip> {
  List<Map<String, dynamic>> stories = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final r = await sb.from('stories').select('id,user_id,media_url,expires_at').gt('expires_at', DateTime.now().toUtc().toIso8601String()).order('created_at', ascending: false).limit(30);
      final rows = List<Map<String, dynamic>>.from(r);
      final ids = rows.map((x) => x['user_id'].toString()).toSet().toList();
      if (ids.isNotEmpty) {
        final p = await sb.from('profiles').select('id,username,avatar_url').inFilter('id', ids);
        final byId = <String, Map<String, dynamic>>{for (final x in List<Map<String, dynamic>>.from(p)) x['id'].toString(): x};
        for (final x in rows) {
          x['_profile'] = byId[x['user_id'].toString()];
        }
      }
      if (mounted) setState(() { stories = rows; loading = false; });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  Future<void> addStory() async {
    final source = await showModalBottomSheet<String>(context: context, builder: (c) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('صورة'), onTap: () => Navigator.pop(c, 'image')),
      ListTile(leading: const Icon(Icons.video_library_outlined), title: const Text('فيديو'), onTap: () => Navigator.pop(c, 'video')),
    ])));
    if (source == null) return;
    final picked = source == 'image'
        ? await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88)
        : await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final u = sb.auth.currentUser;
    if (u == null) return;
    try {
      final ext = picked.name.split('.').last.toLowerCase();
      final path = '${u.id}/${DateTime.now().microsecondsSinceEpoch}.$ext';
      await sb.storage.from('story-media').upload(path, File(picked.path), fileOptions: FileOptions(contentType: _mimeForExtension(ext), upsert: false));
      await sb.from('stories').insert({'user_id': u.id, 'media_url': path, 'media_type': source, 'expires_at': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String()});
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر نشر القصة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: stories.length + 1,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        if (i == 0) return GestureDetector(onTap: addStory, child: _storyBubble(null, 'قصتي', true));
        final x = stories[i - 1];
        return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewerPage(stories: stories, initialIndex: i - 1))), child: _storyBubble(x, (x['_profile']?['username'] ?? 'N').toString(), false));
      },
    );
  }

  Widget _storyBubble(Map<String, dynamic>? x, String label, bool add) {
    final avatar = (x?['_profile']?['avatar_url'] ?? '').toString();
    return SizedBox(width: 66, child: Column(children: [
      Container(width: 58, height: 58, padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [cyan, pink])), child: CircleAvatar(backgroundColor: panel, backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar.isEmpty ? Icon(add ? Icons.add : Icons.person, color: Colors.white) : null)),
      const SizedBox(height: 4), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
    ]));
  }
}

class StoryViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;
  const StoryViewerPage({super.key, required this.stories, required this.initialIndex});
  @override State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  late int index = widget.initialIndex;
  String? url;
  VideoPlayerController? video;

  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    final raw = (widget.stories[index]['media_url'] ?? '').toString();
    try {
      final signed = await sb.storage.from('story-media').createSignedUrl(_storagePath(raw, 'story-media'), 3600);
      if (!mounted) return;
      if ((widget.stories[index]['media_type'] ?? 'image') == 'video') {
        final vc = VideoPlayerController.networkUrl(Uri.parse(signed));
        await vc.initialize();
        await vc.setLooping(true);
        await vc.play();
        if (!mounted) { await vc.dispose(); return; }
        setState(() { video?.dispose(); video = vc; url = signed; });
      } else {
        setState(() => url = signed);
      }
    } catch (_) {}
  }
  void next() {
    if (index < widget.stories.length - 1) {
      setState(() { index++; url = null; });
      load();
    } else {
      Navigator.pop(context);
    }
  }
  void prev() {
    if (index > 0) {
      setState(() { index--; url = null; });
      load();
    }
  }

  @override void dispose() { video?.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: Colors.black, body: GestureDetector(onTapUp: (d) => d.localPosition.dx < MediaQuery.of(context).size.width / 2 ? prev() : next(), child: Stack(fit: StackFit.expand, children: [
    if (video?.value.isInitialized == true) FittedBox(fit: BoxFit.contain, child: SizedBox(width: video!.value.size.width, height: video!.value.size.height, child: VideoPlayer(video!)))
    else if (url != null) Image.network(url!, fit: BoxFit.contain) else const Center(child: CircularProgressIndicator()),
    SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Align(alignment: Alignment.topCenter, child: LinearProgressIndicator(value: (index + 1) / widget.stories.length, minHeight: 3)))),
    SafeArea(child: Align(alignment: Alignment.topRight, child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white, size: 30)))),
  ])));
}

class FeedPage extends StatefulWidget {
  final bool following;
  const FeedPage({super.key, required this.following});
  @override State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<Map<String, dynamic>> posts = [];
  bool loading = true;
  int activeIndex = 0;
  late bool followingTab;

  @override void initState() { super.initState(); followingTab = widget.following; load(); }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try { final data = await loadPostsWithProfiles(following: followingTab); if (mounted) setState(() => posts = data); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل المحتوى: $e'))); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      loading ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : posts.isEmpty
        ? RefreshIndicator(onRefresh: load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 300), Center(child: Text('لا توجد فيديوهات بعد', style: TextStyle(color: Colors.white70))) ]))
        : RefreshIndicator(onRefresh: load, child: PageView.builder(scrollDirection: Axis.vertical, itemCount: posts.length,
            onPageChanged: (i) => setState(() => activeIndex = i), itemBuilder: (_, i) => VideoCard(post: posts[i], active: i == activeIndex))),
      SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(10, 5, 10, 0), child: Row(children: [
        _roundTopButton(Icons.search, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage()))),
        const Spacer(),
        GestureDetector(onTap: () => setState(() { followingTab = false; load(); }), child: _FeedTab(active: !followingTab, title: 'لك')),
        const SizedBox(width: 22),
        GestureDetector(onTap: () => setState(() { followingTab = true; load(); }), child: _FeedTab(active: followingTab, title: 'أتابع')),
        const Spacer(),
        _roundTopButton(Icons.chat_bubble_outline_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesPage()))),
      ]))),
      const Positioned(left: 0, right: 0, top: 82, height: 86, child: StoryStrip()),
    ])));
  }
}

Widget _roundTopButton(IconData icon, VoidCallback onTap) => Material(
  color: const Color(0xAA10141C),
  shape: const CircleBorder(),
  child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(9), child: Icon(icon, color: Colors.white, size: 19))),
);

class _FeedTab extends StatelessWidget {
  final bool active;
  final String title;

  const _FeedTab({
    required this.active,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: active ? FontWeight.w900 : FontWeight.w500,
            color: active ? Colors.white : Colors.white70,
          ),
        ),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 30 : 0,
          height: 2.5,
          decoration: BoxDecoration(
            color: pink,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class VideoCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool active;
  const VideoCard({super.key, required this.post, this.active = true});
  @override State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  VideoPlayerController? c;
  bool liked = false, saved = false, following = false;
  int likes = 0;
  String get url => (widget.post['media_url'] ?? '').toString();
  String get username => (widget.post['profile']?['username'] ?? 'N').toString();
  String get avatar => (widget.post['profile']?['avatar_url'] ?? '').toString();

  @override void initState() { super.initState();
    final raw = widget.post['likes_count']; likes = raw is int ? raw : int.tryParse('$raw') ?? 0;
    if (url.isNotEmpty && (widget.post['media_type'] ?? 'video') == 'video') {
      c = VideoPlayerController.networkUrl(Uri.parse(url))..initialize().then((_) { if (mounted) { setState(() {}); c!.setLooping(true); if (widget.active) c!.play(); }});
    }
    _loadReactionState();
  }
  Future<void> _loadReactionState() async {
    final user = sb.auth.currentUser; if (user == null) return;
    try { final r = await Future.wait([
      sb.from('post_likes').select('post_id').eq('post_id', widget.post['id']).eq('user_id', user.id).maybeSingle(),
      sb.from('saved_posts').select('post_id').eq('post_id', widget.post['id']).eq('user_id', user.id).maybeSingle(),
      sb.from('follows').select('following_id').eq('follower_id', user.id).eq('following_id', widget.post['user_id']).maybeSingle(),
    ]); if (mounted) setState(() { liked = r[0] != null; saved = r[1] != null; following = r[2] != null; }); } catch (_) {}
  }
  @override void didUpdateWidget(covariant VideoCard oldWidget) { super.didUpdateWidget(oldWidget); if (c?.value.isInitialized != true) return; if (widget.active && !oldWidget.active) c!.play(); if (!widget.active && oldWidget.active) c!.pause(); }
  @override void dispose() { c?.dispose(); super.dispose(); }

  Future<void> like() async { final u = sb.auth.currentUser; if (u == null) return; try {
    if (liked) { await sb.from('post_likes').delete().eq('post_id', widget.post['id']).eq('user_id', u.id); likes = likes > 0 ? likes - 1 : 0; }
    else { await sb.from('post_likes').insert({'post_id': widget.post['id'], 'user_id': u.id}); likes++; }
    if (mounted) setState(() => liked = !liked);
  } catch (_) {} }
  Future<void> save() async {
    final u = sb.auth.currentUser;
    if (u == null) return;
    try {
      if (saved) {
        await sb.from('saved_posts').delete().eq('post_id', widget.post['id']).eq('user_id', u.id);
      } else {
        await sb.from('saved_posts').insert({'post_id': widget.post['id'], 'user_id': u.id});
      }
      if (mounted) setState(() => saved = !saved);
    } catch (_) {}
  }

  Future<void> toggleFollow() async {
    final u = sb.auth.currentUser;
    final target = widget.post['user_id']?.toString();
    if (u == null || target == null || u.id == target) return;
    try {
      if (following) {
        await sb.from('follows').delete().eq('follower_id', u.id).eq('following_id', target);
      } else {
        await sb.from('follows').insert({'follower_id': u.id, 'following_id': target});
      }
      if (mounted) setState(() => following = !following);
    } catch (_) {}
  }

  Widget _action(IconData icon, String text, VoidCallback onTap, {bool active=false}) => Padding(padding: const EdgeInsets.only(bottom: 15), child: Column(children: [
    InkWell(onTap:onTap, child: Icon(icon, color: active ? const Color(0xFFFF2D55) : Colors.white, size: 32)),
    const SizedBox(height: 2), Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, shadows:[Shadow(blurRadius:3,color:Colors.black)])),
  ]));

  @override Widget build(BuildContext context) => GestureDetector(onDoubleTap: like, child: Stack(fit: StackFit.expand, children: [
    if ((widget.post['media_type'] ?? 'video') == 'image' && url.isNotEmpty) Image.network(url, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Center(child:Icon(Icons.broken_image_outlined,size:60)))
    else if (c?.value.isInitialized == true) FittedBox(fit:BoxFit.cover, child:SizedBox(width:c!.value.size.width,height:c!.value.size.height,child:VideoPlayer(c!)))
    else const Center(child:CircularProgressIndicator(strokeWidth:2)),
    const Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter,end: Alignment.bottomCenter,colors:[Colors.transparent,Colors.transparent,Color(0xCC000000)],stops:[0,.55,1]))))),
    Positioned(top: MediaQuery.of(context).padding.top + 46, right: 10, child: Column(children: [
      CircleAvatar(radius:28, backgroundColor:const Color(0xFF333333), backgroundImage:avatar.isNotEmpty?NetworkImage(avatar):null, child:avatar.isEmpty?const Icon(Icons.person,color:Colors.white):null),
      GestureDetector(onTap:toggleFollow, child: Container(width:22,height:22,decoration:BoxDecoration(color:following?Colors.white:const Color(0xFFFF0050),shape:BoxShape.circle,border:Border.all(color:Colors.black,width:2)),child:Icon(following?Icons.check:Icons.add,size:14,color:following?Colors.black:Colors.white))),
    ])),
    Positioned(right: 10, bottom: 92, child: Column(children: [
      _action(liked?Icons.favorite:Icons.favorite_border, '$likes', like, active:liked),
      _action(Icons.comment_outlined, 'تعليق', () => showComments(context, widget.post['id'])),
      _action(saved?Icons.bookmark:Icons.bookmark_border, 'حفظ', save, active:saved),
      _action(Icons.download_outlined, 'تنزيل', () => _downloadPost(context, widget.post)),
      _action(Icons.share_outlined, 'مشاركة', () => showShare(context, postId: widget.post['id']?.toString())),
    ])),
    Positioned(left:14,right:82,bottom:24,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('@$username',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
      if((widget.post['caption']??'').toString().trim().isNotEmpty) ...[const SizedBox(height:7),Text((widget.post['caption']??'').toString(),maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:14))],
      const SizedBox(height:7),
      Row(children:[const Icon(Icons.music_note,size:15),const SizedBox(width:4),Flexible(child:Text('الصوت الأصلي لـ @$username',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)))])
    ])),
  ]));
}

Future<void> showShare(BuildContext context, {String? postId}) async {
  final id = postId ?? '';
  final link = id.isEmpty ? 'N — منصة الفيديو الاجتماعي' : 'https://n.app/p/$id';
  try {
    await Share.share(link, subject: 'مشاركة من N');
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح نافذة المشاركة.')),
      );
    }
  }
}

Future<List<Map<String, dynamic>>> _loadComments(dynamic postId) async {
  final raw = await sb.from('comments').select('id,post_id,user_id,body,created_at').eq('post_id', postId).order('created_at', ascending: false);
  final rows = List<Map<String, dynamic>>.from(raw);
  final ids = rows.map((r) => r['user_id'].toString()).toSet().toList();
  if (ids.isEmpty) return rows;
  final profiles = await sb.from('profiles').select('id,username,avatar_url').inFilter('id', ids);
  final byId = <String, Map<String, dynamic>>{for (final p in List<Map<String, dynamic>>.from(profiles)) p['id'].toString(): p};
  return rows.map((r) { final x=Map<String,dynamic>.from(r); x['profile']=byId[r['user_id'].toString()]; return x; }).toList();
}

Future<void> showComments(
  BuildContext context,
  dynamic postId,
) async {
  final ctrl = TextEditingController();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, set) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'التعليقات',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 280,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadComments(postId),
                    builder: (_, s) {
                      if (s.hasData) {
                        return ListView(
                          children: s.data!.map((e) {
                            return ListTile(
                              title: Text(
                                '@${e['profile']?['username'] ?? ''}',
                              ),
                              subtitle: Text(
                                e['body'] ?? '',
                              ),
                            );
                          }).toList(),
                        );
                      }

                      if (s.hasError) {
                        return const Center(
                          child: Text('تعذر تحميل التعليقات'),
                        );
                      }

                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(
                          hintText: 'اكتب تعليقًا...',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final body = ctrl.text.trim();

                        if (body.isEmpty) {
                          return;
                        }

                        final user = sb.auth.currentUser;

                        if (user == null) {
                          return;
                        }

                        await sb.from('comments').insert({
                          'post_id': postId,
                          'user_id': user.id,
                          'body': body,
                        });

                        ctrl.clear();

                        set(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );

  ctrl.dispose();
}

class LivePage extends StatefulWidget {
  const LivePage({super.key});
  @override State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  List<Map<String, dynamic>> rooms = [];
  bool loading = true;

  @override
  void initState() { super.initState(); loadRooms(); }

  Future<void> loadRooms() async {
    try {
      final data = await sb.from('live_rooms').select('id,host_id,title,stream_url,viewer_count,created_at').eq('status','live').order('created_at', ascending: false);
      final list = List<Map<String,dynamic>>.from(data);
      final ids = list.map((e) => e['host_id'].toString()).toSet().toList();
      final profiles = ids.isEmpty ? <dynamic>[] : await sb.from('profiles').select('id,username,avatar_url').inFilter('id', ids);
      final byId = {for (final p in List<Map<String,dynamic>>.from(profiles)) p['id'].toString(): p};
      for (final r in list) {
        r['_profile'] = byId[r['host_id'].toString()];
      }
      if (mounted) setState(() { rooms = list; loading = false; });
    } catch (e) {
      if (mounted) { setState(() => loading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل البثوث: $e'))); }
    }
  }

  Future<void> createRoom() async {
    final u = sb.auth.currentUser;
    if (u == null) return;
    final title = TextEditingController(text: 'بث مباشر N');
    final url = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('بدء بث مباشر'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان البث')),
        TextField(controller: url, decoration: const InputDecoration(labelText: 'رابط البث (من مزود البث)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx,false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx,true), child: const Text('بدء'))],
    ));
    if (result != true) return;
    try {
      await sb.from('live_rooms').insert({'host_id':u.id,'title':title.text.trim().isEmpty?'بث مباشر N':title.text.trim(),'stream_url':url.text.trim().isEmpty?null:url.text.trim(),'status':'live'});
      await loadRooms();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء البث: $e'))); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('البث المباشر', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: loadRooms, icon: const Icon(Icons.refresh_rounded))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: createRoom, backgroundColor: pink, icon: const Icon(Icons.sensors), label: const Text('ابدأ بثًا')),
      body: loading ? const Center(child: CircularProgressIndicator()) : rooms.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.sensors_off_rounded,size:64,color:Colors.white38),SizedBox(height:12),Text('لا توجد بثوث مباشرة الآن'),SizedBox(height:6),Text('يمكنك بدء بث وربطه بمزود البث الخارجي.',style:TextStyle(color:Colors.white54))])) : ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100), itemCount: rooms.length, itemBuilder: (_,i) {
          final r=rooms[i]; final p=r['_profile'] as Map<String,dynamic>?; final name=(p?['username']??'مستخدم').toString(); final avatar=(p?['avatar_url']??'').toString();
          return Card(color: panel, child: ListTile(
            leading: CircleAvatar(backgroundImage: avatar.isNotEmpty?NetworkImage(avatar):null, child: avatar.isEmpty?const Icon(Icons.person):null),
            title: Text(r['title']?.toString()??'بث مباشر N',style:const TextStyle(fontWeight:FontWeight.w800)),
            subtitle: Text('@$name • ${r['viewer_count']??0} مشاهد'),
            trailing: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveRoomPage(roomId:r['id'].toString(), hostId:r['host_id'].toString(), username:name, viewers:'${r['viewer_count']??0}', streamUrl:r['stream_url']?.toString()))), child: const Text('مشاهدة')),
          ));
        }),
    );
  }
}

class PublishPage extends StatefulWidget {
  const PublishPage({super.key});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final caption = TextEditingController();

  XFile? file;
  bool imageMode = false;
  bool busy = false;
  String visibility = 'public';
  bool adultOnly = false;
  String? selectedMime;

  Future<void> pick(ImageSource src) async {
    final x = imageMode ? await ImagePicker().pickImage(source: src, imageQuality: 90) : await ImagePicker().pickVideo(source: src);

    if (x != null && mounted) {
      setState(() { file = x; selectedMime = _mimeForExtension((x.name.split('.').last).toLowerCase()); });
    }
  }

  Future<void> pickAnyFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, type: FileType.media, withData: false);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single;
      if (f.path == null) return;
      const max = 200 * 1024 * 1024;
      if (f.size > max) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحد الأقصى للفيديو أو الصورة 200 ميجابايت.'))); return; }
      final ext = (f.extension ?? '').toLowerCase();
      final mime = _mimeForExtension(ext);
      final isImage = mime.startsWith('image/');
      final isVideo = mime.startsWith('video/');
      if (!isImage && !isVideo) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر صورة أو فيديو مدعومًا.'))); return; }
      if (mounted) setState(() { file = XFile(f.path!, name: f.name); imageMode = isImage; selectedMime = mime; });
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر اختيار الوسائط: $e'))); }
  }

  Future<void> publish() async {
    if (file == null) {
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      final user = sb.auth.currentUser;

      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولًا.');
      }

      final uid = user.id;
      final ext = file!.path.split('.').last;

      final path =
          '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await sb.storage.from('post-media').upload(
            path,
            File(file!.path),
            fileOptions: FileOptions(contentType: _mimeForExtension(ext), upsert: false),
          );

      final mediaPath = path;

      await sb.from('posts').insert({
        'user_id': uid,
        'media_url': mediaPath,
        'media_type': imageMode ? 'image' : 'video',
        'caption': caption.text.trim(),
        'visibility': visibility,
        'adult_only': adultOnly,
      });

      if (mounted) {
        caption.clear();

        setState(() { file = null; selectedMime = null; });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نشر الفيديو'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل النشر: ${_storageMessage(e)}'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('نشر فيديو', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            height: 245,
            decoration: BoxDecoration(
              color: const Color(0xFF0F131B),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF25313B)),
            ),
            child: file == null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.video_library_outlined, size: 52, color: cyan),
                  const SizedBox(height: 12),
                  const Text('أضف فيديو أو صورة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('اختر من الكاميرا أو المعرض أو الملفات', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(onPressed: busy ? null : pickAnyFile, icon: const Icon(Icons.folder_open_outlined), label: const Text('اختيار ملف')),
                ])
              : Center(child: Padding(padding: const EdgeInsets.all(18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle_rounded, color: cyan, size: 48),
                  const SizedBox(height: 10),
                  Text(file!.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(selectedMime ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ]))),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => pick(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: Text(imageMode ? 'صورة' : 'فيديو'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('المعرض'))),
          ]),
          const SizedBox(height: 14),
          TextField(controller: caption, maxLines: 4, decoration: const InputDecoration(hintText: 'اكتب وصفًا للفيديو...', prefixIcon: Icon(Icons.edit_outlined))),
          const SizedBox(height: 14),
          const Text('من يمكنه مشاهدة المنشور؟', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'public', label: Text('الجميع'), icon: Icon(Icons.public, size: 17)),
              ButtonSegment(value: 'followers', label: Text('المتابعون'), icon: Icon(Icons.people_outline, size: 17)),
              ButtonSegment(value: 'private', label: Text('أنا فقط'), icon: Icon(Icons.lock_outline, size: 17)),
            ], selected: {visibility}, onSelectionChanged: (v) => setState(() => visibility = v.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: adultOnly,
            onChanged: busy ? null : (v) => setState(() => adultOnly = v),
            title: const Text('محتوى +21', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('سيظهر فقط للحسابات التي عمر صاحبها 21 سنة أو أكثر.'),
            secondary: const Icon(Icons.eighteen_up_rating_outlined),
          ),
          const SizedBox(height: 22),
          SizedBox(height: 52, child: FilledButton(
            onPressed: busy || file == null ? null : publish,
            style: FilledButton.styleFrom(backgroundColor: pink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            child: Text(busy ? 'جاري النشر...' : 'نشر', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          )),
        ],
      ),
    );
  }
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final user = sb.auth.currentUser;

      if (user == null) {
        return;
      }

      final x = await sb
          .from('conversations')
          .select()
          .or(
            'user_a.eq.${user.id},user_b.eq.${user.id}',
          )
          .order(
            'updated_at',
            ascending: false,
          );

      final rawRows = List<Map<String, dynamic>>.from(x);
      final ids = <String>{};
      for (final row in rawRows) {
        final other = row['user_a'].toString() == user.id ? row['user_b'].toString() : row['user_a'].toString();
        ids.add(other);
      }
      final profiles = ids.isEmpty ? <dynamic>[] : await sb.from('profiles').select('id,username,avatar_url').inFilter('id', ids.toList());
      final byId = <String, Map<String,dynamic>>{for (final p in List<Map<String,dynamic>>.from(profiles)) p['id'].toString(): p};
      for (final row in rawRows) {
        final other = row['user_a'].toString() == user.id ? row['user_b'].toString() : row['user_a'].toString();
        final profile = byId[other];
        row['_other_username'] = profile?['username'] ?? 'مستخدم';
        row['_other_avatar'] = profile?['avatar_url'];
        try { final unread=await sb.from('messages').select('id').eq('conversation_id',row['id']).neq('sender_id',user.id).isFilter('read_at',null); row['_unread']=List.from(unread).length; } catch (_) { row['_unread']=0; }
      }
      if (mounted) setState(() => rows = rawRows);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('الرسائل', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))]),
      body: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(14, 4, 14, 8), child: TextField(decoration: InputDecoration(hintText: 'ابحث في الرسائل...', prefixIcon: Icon(Icons.search), isDense: true))),
        if (rows.isEmpty) const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.chat_bubble_outline_rounded, size: 54, color: Colors.white38), SizedBox(height: 12), Text('لا توجد محادثات بعد', style: TextStyle(color: Colors.white70))])))
        else Expanded(child: ListView.separated(padding: const EdgeInsets.fromLTRB(10, 4, 10, 110), itemCount: rows.length, separatorBuilder: (_,__) => const Divider(height: 1, indent: 74), itemBuilder: (_, i) {
          final e = rows[i];
          return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), leading: CircleAvatar(radius: 25, backgroundColor: const Color(0xFF1B252D), backgroundImage: (e['_other_avatar'] ?? '').toString().isNotEmpty ? NetworkImage(e['_other_avatar'].toString()) : null, child: (e['_other_avatar'] ?? '').toString().isEmpty ? const Icon(Icons.person_outline_rounded) : null), title: Row(children: [Expanded(child: Text(e['_other_username'] ?? e['title'] ?? 'محادثة', style: const TextStyle(fontWeight: FontWeight.w800))), if ((e['_unread'] ?? 0) > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: pink, borderRadius: BorderRadius.circular(12)), child: Text('${e['_unread']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))) ]), subtitle: Text(e['last_message'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)), trailing: const Icon(Icons.chevron_left_rounded, color: Colors.white38), onTap: () => ChatPage.open(context, e['id']));
        }))
      ]),
    );
  }
}

class ChatPage extends StatefulWidget {
  final dynamic id;

  const ChatPage({
    super.key,
    required this.id,
  });

  static void open(
    BuildContext context,
    dynamic id,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          id: id,
        ),
      ),
    );
  }

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ctrl = TextEditingController();
  List<Map<String, dynamic>> msgs = [];
  PlatformFile? attachment;
  bool sending = false;
  Timer? _messageRefreshTimer;
  RealtimeChannel? _channel;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _recordingVoice = false;
  String? _playingVoice;

  @override
  void initState() {
    super.initState();
    load();
    _messageRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !sending) load(silent: true);
    });
    _channel = sb.channel('chat-${widget.id}')
      .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'messages', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.id.toString()), callback: (_) => load(silent: true))
      .subscribe();
  }

  Future<void> load({bool silent = false}) async {
    try {
      final x = await sb
          .from('messages')
          .select()
          .eq('conversation_id', widget.id)
          .order('created_at');
      final next = List<Map<String, dynamic>>.from(x);
      final me=sb.auth.currentUser?.id;
      if(me!=null){try{await sb.rpc('mark_conversation_read',params:{'p_conversation':widget.id.toString()});}catch(_){}}
      if (mounted) setState(() => msgs = next);
    } catch (e) {
      if (mounted && !silent) _showError('تعذر تحميل الرسائل: $e');
    }
  }

  Future<void> pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      const maxBytes = 50 * 1024 * 1024;
      if (picked.size > maxBytes) {
        _showError('حجم الملف يتجاوز الحد المسموح وهو 50 ميجابايت.');
        return;
      }
      if ((picked.path == null || picked.path!.isEmpty) && picked.bytes == null) {
        _showError('تعذر الوصول إلى الملف المحدد. اختر الملف من مدير الملفات مرة أخرى.');
        return;
      }
      if (mounted) setState(() => attachment = picked);
    } catch (e) {
      if (mounted) _showError('تعذر اختيار الملف: $e');
    }
  }

  Future<void> toggleVoiceRecording() async {
    if (sending) return;
    if (_recordingVoice) {
      try {
        final path = await _recorder.stop();
        if (mounted) setState(() => _recordingVoice = false);
        if (path == null || path.isEmpty) return;
        final user = sb.auth.currentUser;
        if (user == null) return;
        final conversation = widget.id.toString();
        final stamp = DateTime.now().microsecondsSinceEpoch;
        final storagePath = '${user.id}/$conversation/$stamp.m4a';
        if (mounted) setState(() => sending = true);
        await sb.storage.from('message-media').upload(
          storagePath,
          File(path),
          fileOptions: const FileOptions(contentType: 'audio/mp4', upsert: false),
        );
        await sb.from('messages').insert({
          'conversation_id': widget.id,
          'sender_id': user.id,
          'body': '',
          'media_url': storagePath,
          'media_type': 'voice',
          'media_name': 'رسالة صوتية',
          'media_size': await File(path).length(),
        });
        try { await File(path).delete(); } catch (_) {}
        await load();
      } catch (e) {
        if (mounted) _showError('تعذر إرسال الرسالة الصوتية: $e');
      } finally {
        if (mounted) setState(() => sending = false);
      }
      return;
    }
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        _showError('اسمح للتطبيق باستخدام الميكروفون لإرسال رسالة صوتية.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/n_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100), path: path);
      if (mounted) setState(() => _recordingVoice = true);
    } catch (e) {
      _showError('تعذر بدء التسجيل الصوتي: $e');
    }
  }

  Future<void> send() async {
    final body = ctrl.text.trim();
    if (body.isEmpty && attachment == null) return;
    final user = sb.auth.currentUser;
    if (user == null) return;

    setState(() => sending = true);
    String? uploadedPath;
    try {
      String? mediaUrl;
      String? mediaType;
      String? mediaName;
      int? mediaSize;
      if (attachment != null) {
        final attachmentPath = attachment!.path ?? '';
        final ext = (attachment!.extension ?? attachment!.name.split('.').last).toLowerCase().split('?').first;
        final mime = _mimeForExtension(ext);
        if (mime.startsWith('image/') || {'jpg','jpeg','png','gif','webp','heic','heif'}.contains(ext)) {
          mediaType = 'image';
        } else if (mime.startsWith('video/') || {'mp4','mov','m4v','webm','avi','mkv'}.contains(ext)) {
          mediaType = 'video';
        } else {
          mediaType = 'file';
        }
        final safeExt = ext.isEmpty ? 'bin' : ext.replaceAll(RegExp(r'[^a-z0-9]'), '');
        final stamp = DateTime.now().microsecondsSinceEpoch;
        final path = '${user.id}/${widget.id}/$stamp.$safeExt';
        uploadedPath = path;
        final options = FileOptions(
          contentType: mime.isNotEmpty ? mime : _mimeForExtension(safeExt),
          upsert: false,
        );
        if (attachment!.bytes != null) {
          await sb.storage.from('message-media').uploadBinary(
            path,
            attachment!.bytes!,
            fileOptions: options,
          );
        } else if (attachmentPath.isNotEmpty) {
          await sb.storage.from('message-media').upload(
            path,
            File(attachmentPath),
            fileOptions: options,
          );
        } else {
          throw Exception('تعذر قراءة الملف المحدد.');
        }
        mediaUrl = path;
        mediaName = attachment!.name;
        mediaSize = attachment!.size;
      }

      await sb.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': user.id,
        'body': body,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'media_name': mediaName,
        'media_size': mediaSize,
      });
      ctrl.clear();
      if (mounted) setState(() => attachment = null);
      await load();
    } catch (e) {
      if (uploadedPath != null) {
        try {
          await sb.storage.from('message-media').remove([uploadedPath]);
        } catch (_) {}
      }
      if (mounted) _showError('فشل إرسال الرسالة: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _messageRefreshTimer?.cancel();
    if (_channel != null) sb.removeChannel(_channel!);
    _audioPlayer.dispose();
    _recorder.dispose();
    ctrl.dispose();
    super.dispose();
  }

  Future<String?> _signedMessageUrl(String value) async {
    try { return await sb.storage.from('message-media').createSignedUrl(_storagePath(value, 'message-media'), 3600); } catch (_) { return null; }
  }

  Widget _messageMedia(Map<String, dynamic> m) {
    final url = (m['media_url'] ?? '').toString();
    if (url.isEmpty) return const SizedBox.shrink();
    final type = (m['media_type'] ?? 'file').toString();
    final name = (m['media_name'] ?? 'ملف مرفق').toString();
    if (type == 'voice') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: FutureBuilder<String?>(
          future: _signedMessageUrl(url),
          builder: (_, snap) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF1A2029), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: snap.hasData ? () async {
                  try {
                    if (_playingVoice == url) {
                      await _audioPlayer.stop();
                      if (mounted) setState(() => _playingVoice = null);
                    } else {
                      await _audioPlayer.stop();
                      await _audioPlayer.play(UrlSource(snap.data!));
                      if (mounted) setState(() => _playingVoice = url);
                      _audioPlayer.onPlayerComplete.first.then((_) { if (mounted && _playingVoice == url) setState(() => _playingVoice = null); });
                    }
                  } catch (_) { _showError('تعذر تشغيل الرسالة الصوتية.'); }
                } : null,
                icon: Icon(_playingVoice == url ? Icons.stop_circle : Icons.play_circle_fill, color: cyan, size: 30),
              ),
              const Text('رسالة صوتية'),
            ]),
          ),
        ),
      );
    }
    if (type == 'image') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: FutureBuilder<String?>(
          future: _signedMessageUrl(url),
          builder: (_, snap) => snap.hasData
              ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(snap.data!, width: 220, height: 220, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Text('تعذر عرض الصورة')))
              : const SizedBox(width: 220, height: 80, child: Center(child: CircularProgressIndicator())),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: FutureBuilder<String?>(
        future: _signedMessageUrl(url),
        builder: (_, snap) => InkWell(
          onTap: !snap.hasData ? null : () async {
            final uri = Uri.tryParse(snap.data!);
            if (uri != null && !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              _showError('تعذر فتح المرفق.');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF1A2029), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(type == 'video' ? Icons.videocam_outlined : Icons.insert_drive_file_outlined),
              const SizedBox(width: 8),
              Flexible(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new, size: 17),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = sb.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('محادثة N')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              children: msgs.map<Widget>((m) {
                final isMine = m['sender_id'] == currentUserId;
                return Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _messageMedia(m),
                        if ((m['body'] ?? '').toString().isNotEmpty) Text(m['body'].toString()),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (attachment != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.attach_file),
                const SizedBox(width: 8),
                Expanded(child: Text(attachment!.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                IconButton(onPressed: sending ? null : () => setState(() => attachment = null), icon: const Icon(Icons.close)),
              ]),
            ),
          SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(onPressed: sending ? null : pickAttachment, icon: const Icon(Icons.attach_file)),
                Expanded(child: TextField(controller: ctrl, enabled: !sending && !_recordingVoice, decoration: InputDecoration(hintText: _recordingVoice ? 'جارٍ التسجيل... اضغط الميكروفون للإرسال' : 'اكتب رسالة...', border: InputBorder.none))),
                IconButton(onPressed: sending ? null : toggleVoiceRecording, icon: Icon(_recordingVoice ? Icons.stop_circle : Icons.mic_rounded, color: _recordingVoice ? pink : null)),
                IconButton(onPressed: sending || _recordingVoice ? null : send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? p;
  List<Map<String, dynamic>> myPosts = [];
  List<Map<String, dynamic>> likedPosts = [];
  bool loading = true;
  int tab = 0;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final user = sb.auth.currentUser;
    if (user == null) return;
    try {
      final results = await Future.wait([
        sb.from('profiles').select().eq('id', user.id).maybeSingle(),
        sb.from('posts').select().eq('user_id', user.id).order('created_at', ascending: false),
        sb.from('follows').select('follower_id').eq('following_id', user.id),
        sb.from('follows').select('following_id').eq('follower_id', user.id),
        sb.from('post_likes').select('post_id').eq('user_id', user.id),
      ]);
      final likedIds = List<Map<String,dynamic>>.from(results[4] as List).map((r)=>r['post_id']).toList();
      List<Map<String,dynamic>> liked = [];
      if (likedIds.isNotEmpty) {
        final lp = await sb.from('posts').select().inFilter('id', likedIds).order('created_at', ascending:false);
        liked = List<Map<String,dynamic>>.from(lp);
      }
      if (!mounted) return;
      final profile = Map<String, dynamic>.from((results[0] as Map?) ?? {});
      profile['followers_count'] = (results[2] as List).length;
      profile['following_count'] = (results[3] as List).length;
      profile['likes_count'] = (results[4] as List).length;
      setState(() { p = profile; myPosts = List<Map<String, dynamic>>.from(results[1] as List); likedPosts = liked; loading = false; });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _editProfile() async {
    final username = TextEditingController(text: p?['username'] ?? '');
    final bio = TextEditingController(text: p?['bio'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الملف الشخصي'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: username, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
          const SizedBox(height: 12),
          TextField(controller: bio, maxLines: 3, decoration: const InputDecoration(labelText: 'النبذة')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await sb.from('profiles').update({'username': username.text.trim(), 'bio': bio.text.trim()}).eq('id', sb.auth.currentUser!.id);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الملف الشخصي')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الملف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final username = (p?['username'] ?? 'N').toString();
    final bio = (p?['bio'] ?? '').toString();
    final avatar = (p?['avatar_url'] ?? '').toString();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('@$username', style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())), icon: const Icon(Icons.menu)),
        actions: [
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())), icon: const Icon(Icons.search)),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())), icon: const Icon(Icons.more_horiz)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(children: [
          const SizedBox(height: 12),
          Center(child: CircleAvatar(radius: 47, backgroundColor: const Color(0xFF17323A), backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar.isEmpty ? const Icon(Icons.person, size: 52, color: Colors.white70) : null)),
          const SizedBox(height: 10),
          Center(child: Text('@$username', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
          if (bio.isNotEmpty) ...[const SizedBox(height: 5), Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text(bio, textAlign: TextAlign.center)))],
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _stat('المتابَعون', _countFollowing()),
            _stat('المتابِعون', _countFollowers()),
            _stat('الإعجابات', _countLikes()),
          ]),
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _editProfile, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('تعديل الملف'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () async { final text = 'تابعني على N: @$username'; try { await Share.share(text, subject: 'ملف @$username'); } catch (_) {} }, icon: const Icon(Icons.share_outlined, size: 18), label: const Text('مشاركة'))),
          ])),
          const SizedBox(height: 18),
          SizedBox(height: 48, child: Row(children: [
            _profileTab(0, Icons.grid_view_rounded, 'منشوراتي'),
            _profileTab(1, Icons.lock_outline, 'خاص'),
            _profileTab(2, Icons.favorite_border, 'الإعجابات'),
          ])),
          const Divider(height: 1),
          if (tab == 0) _postGrid(myPosts) else if (tab == 1) _postGrid(myPosts.where((x)=>(x['visibility'] ?? 'public') != 'public').toList()) else _postGrid(likedPosts),
          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  String _countFollowers() => (p?['followers_count'] ?? 0).toString();
  String _countFollowing() => (p?['following_count'] ?? 0).toString();
  String _countLikes() => (p?['likes_count'] ?? 0).toString();

  Widget _stat(String label, String value) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Column(children: [Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))]));
  Widget _profileTab(int i, IconData icon, String label) => Expanded(child: InkWell(onTap: () => setState(() => tab = i), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 21, color: tab == i ? Colors.white : Colors.white54), const SizedBox(height: 3), Text(label, style: TextStyle(fontSize: 10, color: tab == i ? Colors.white : Colors.white54))])));
  Widget _postGrid(List<Map<String, dynamic>> posts) => posts.isEmpty ? const SizedBox(height: 260, child: Center(child: Text('لا توجد فيديوهات بعد'))) : GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.all(2), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2, childAspectRatio: .66), itemCount: posts.length, itemBuilder: (_, i) => FutureBuilder<String?>(future: _signedPostUrl((posts[i]['media_url'] ?? '').toString()), builder: (_, snap) => snap.hasData ? Stack(fit: StackFit.expand, children: [Image.network(snap.data!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)), const Positioned(bottom: 4, right: 4, child: Row(children: [Icon(Icons.play_arrow, size: 14), SizedBox(width: 2), Text('N', style: TextStyle(fontSize: 9))]))]) : const ColoredBox(color: Color(0xFF16181F))));
}


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والخصوصية'), leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back))),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 30), children: [
        _section('الحساب'),
        _item(context, Icons.person_outline, 'الحساب', 'إدارة معلومات حساب N', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()))),
        _item(context, Icons.security_outlined, 'الأمان', 'كلمة المرور وأمان الحساب', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityPage()))),
        _item(context, Icons.qr_code_2, 'رمز QR الخاص بي', 'شارك ملفك بسرعة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrPage()))),
        _section('المحتوى والنشاط'),
        _item(context, Icons.history, 'مركز النشاط', 'سجل تفاعلاتك ونشاطك', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityPage()))),
        _item(context, Icons.visibility_outlined, 'زيارات الملف الشخصي', 'من شاهد ملفك', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitorsPage()))),
        _item(context, Icons.block_outlined, 'الحسابات المحظورة', 'إدارة الحسابات المحظورة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedPage()))),
        _section('الأدوات'),
        _item(context, Icons.download_outlined, 'فيديوهات بدون اتصال', 'مشاهدة المحتوى المحفوظ محليًا', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflinePage()))),
        _item(context, Icons.auto_awesome, 'N Studio', 'أدوات إنشاء وإدارة المحتوى', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudioPage()))),
        _item(context, Icons.account_balance_wallet_outlined, 'الرصيد والهدايا', 'إدارة العملات والهدايا', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage()))),
        _item(context, Icons.notifications_none, 'الإشعارات', 'إعدادات التنبيهات', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()))),
        _section('الخصوصية'),
        _item(context, Icons.lock_outline, 'الخصوصية', 'الحساب الخاص والتحكم بالمحتوى', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPage()))),
        _section('N'),
        _item(context, Icons.info_outline, 'حول N', 'الإصدار 5.4.0', () => showAboutDialog(context: context, applicationName: 'N', applicationVersion: '5.4.0', applicationLegalese: 'N Social Platform')), 
        ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent)), onTap: () async { await sb.auth.signOut(); if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst); }),
      ]),
    );
  }

  Widget _section(String title) => Padding(padding: const EdgeInsets.fromLTRB(8, 20, 8, 7), child: Text(title, style: const TextStyle(color: cyan, fontSize: 12, fontWeight: FontWeight.w900)));
  Widget _item(BuildContext context, IconData icon, String title, String sub, VoidCallback tap) => Container(margin: const EdgeInsets.only(bottom: 6), decoration: BoxDecoration(color: const Color(0xFF0F131A), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1E2730))), child: ListTile(onTap: tap, leading: Icon(icon, size: 22), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(sub, style: const TextStyle(fontSize: 10.5, color: Colors.white54)), trailing: const Icon(Icons.chevron_left_rounded, color: Colors.white38)));
}

class LiveRoomPage extends StatefulWidget{final String roomId,hostId,username,viewers;final String? streamUrl;const LiveRoomPage({super.key,required this.roomId,required this.hostId,required this.username,required this.viewers,this.streamUrl});@override State<LiveRoomPage> createState()=>_LiveRoomPageState();}
class _LiveRoomPageState extends State<LiveRoomPage>{final ctrl=TextEditingController();List<Map<String,dynamic>> comments=[];VideoPlayerController? _video;RealtimeChannel? _channel;Timer? _refresh;int viewers=0;bool ending=false;@override void initState(){super.initState();viewers=int.tryParse(widget.viewers)??0;_enter();_initStream();}
Future<void> _enter()async{try{final r=await sb.rpc('enter_live_room',params:{'p_room':widget.roomId});if(mounted)setState(()=>viewers=(r as num?)?.toInt()??viewers+1);}catch(_){if(mounted)setState(()=>viewers++);}await _loadComments();_channel=sb.channel('live-comments-${widget.roomId}').onPostgresChanges(event:PostgresChangeEvent.insert,schema:'public',table:'live_comments',filter:PostgresChangeFilter(type:PostgresChangeFilterType.eq,column:'room_id',value:widget.roomId),callback:(_)=>_loadComments(silent:true)).subscribe();_refresh=Timer.periodic(const Duration(seconds:5),(_)=>_loadRoomCount());}
Future<void> _loadRoomCount()async{try{final r=await sb.from('live_rooms').select('viewer_count').eq('id',widget.roomId).maybeSingle();if(mounted&&r!=null)setState(()=>viewers=(r['viewer_count'] as num?)?.toInt()??viewers);}catch(_){}}
Future<void> _loadComments({bool silent = false}) async {
    try {
      final r = await sb
          .from('live_comments')
          .select('id,user_id,body,created_at')
          .eq('room_id', widget.roomId)
          .order('created_at', ascending: false)
          .limit(30);
      final rows = List<Map<String, dynamic>>.from(r);
      final ids = rows.map((e) => e['user_id'].toString()).toSet().toList();
      if (ids.isNotEmpty) {
        final p = await sb.from('profiles').select('id,username').inFilter('id', ids);
        final by = <String, Map<String, dynamic>>{
          for (final x in List<Map<String, dynamic>>.from(p)) x['id'].toString(): x,
        };
        for (final x in rows) {
          x['_username'] = by[x['user_id'].toString()]?['username'] ?? 'مستخدم';
        }
      }
      if (mounted) {
        setState(() => comments = rows.reversed.toList());
      }
    } catch (_) {}
  }
Future<void> _initStream() async {
    final raw = widget.streamUrl;
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(raw));
      await c.initialize();
      await c.play();
      if (mounted) {
        setState(() => _video = c);
      } else {
        c.dispose();
      }
    } catch (_) {}
  }
Future<void> _sendComment()async{final t=ctrl.text.trim();if(t.isEmpty)return;final u=sb.auth.currentUser;if(u==null)return;try{await sb.from('live_comments').insert({'room_id':widget.roomId,'user_id':u.id,'body':t});ctrl.clear();await _loadComments(silent:true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر إرسال التعليق: $e')));}}
Future<void> _endLive()async{if(ending)return;setState(()=>ending=true);try{await sb.from('live_rooms').update({'status':'ended','ended_at':DateTime.now().toUtc().toIso8601String(),'viewer_count':0}).eq('id',widget.roomId).eq('host_id',sb.auth.currentUser?.id??'');if(mounted)Navigator.pop(context);}catch(e){if(mounted){setState(()=>ending=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر إنهاء البث: $e')));}}}
@override void dispose(){_refresh?.cancel();if(_channel!=null)sb.removeChannel(_channel!);_video?.dispose();ctrl.dispose();sb.rpc('leave_live_room',params:{'p_room':widget.roomId});super.dispose();}
@override Widget build(BuildContext context){final mine=sb.auth.currentUser?.id==widget.hostId;return Scaffold(backgroundColor:Colors.black,appBar:AppBar(title:Text('@${widget.username} • مباشر'),actions:[if(mine)IconButton(onPressed:ending?null:_endLive,icon:const Icon(Icons.stop_circle_outlined,color:pink))]),body:Stack(children:[const Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFF122530),Colors.black])))),if(_video?.value.isInitialized==true)Positioned.fill(child:FittedBox(fit:BoxFit.cover,child:SizedBox(width:_video!.value.size.width,height:_video!.value.size.height,child:VideoPlayer(_video!))))else const Center(child:Icon(Icons.sensors_rounded,size:92,color:cyan)),Positioned(top:18,right:14,child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:pink,borderRadius:BorderRadius.circular(18)),child:Text('$viewers مشاهد'))),Positioned(left:14,right:14,bottom:82,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:comments.take(6).map((e)=>Padding(padding:const EdgeInsets.only(bottom:5),child:Text('@${e['_username']??'مستخدم'}: ${e['body']}',style:const TextStyle(fontWeight:FontWeight.w700,shadows:[Shadow(blurRadius:4,color:Colors.black)])))).toList())),Positioned(left:10,right:10,bottom:10,child:Row(children:[Expanded(child:TextField(controller:ctrl,onSubmitted:(_)=>_sendComment(),decoration:const InputDecoration(hintText:'اكتب تعليقًا...',filled:true,fillColor:Color(0xAA151922)))),const SizedBox(width:6),IconButton(onPressed:_sendComment,icon:const Icon(Icons.send,color:cyan))]))]));}
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final u = sb.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('الحساب')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('البريد الإلكتروني'),
            subtitle: Text(u?.email ?? 'غير متوفر'),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('حالة تسجيل الدخول'),
            subtitle: Text(u == null ? 'غير مسجل' : 'مسجل الدخول'),
          ),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const Text('تغيير كلمة المرور'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SecurityPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final p = TextEditingController();
  final c = TextEditingController();
  bool busy = false;
  bool obscure = true;

  @override
  void dispose() {
    p.dispose();
    c.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (p.text.length < 6 || p.text != c.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمتا المرور غير متطابقتين أو أقصر من 6 أحرف.')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await sb.auth.updateUser(UserAttributes(password: p.text));
      if (mounted) {
        p.clear();
        c.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تغيير كلمة المرور.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تغيير كلمة المرور: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأمان')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('حماية الحساب'),
            subtitle: Text('غيّر كلمة المرور بشكل دوري ولا تشاركها مع أي شخص.'),
          ),
          TextField(
            controller: p,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              suffixIcon: IconButton(
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            obscureText: obscure,
            decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'جاري الحفظ...' : 'حفظ كلمة المرور'),
          ),
        ],
      ),
    );
  }
}

class SimpleNPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const SimpleNPage({super.key, required this.title, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF101923),
                  border: Border.all(color: const Color(0xFF23323D)),
                ),
                child: Icon(icon, size: 44, color: cyan),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QrPage extends StatelessWidget {
  const QrPage({super.key});

  @override
  Widget build(BuildContext c) {
    final u = sb.auth.currentUser;
    final data = 'n://profile/${u?.id ?? 'guest'}';
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('رمز QR', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 250,
              height: 250,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 210,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
              ),
            ),
            const SizedBox(height: 18),
            Text(data, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await Share.share(data, subject: 'ملفي على N');
                } catch (_) {}
              },
              icon: const Icon(Icons.share),
              label: const Text('مشاركة الرمز'),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool loading = true;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final u = sb.auth.currentUser;
      if (u == null) return;
      final r = await sb
          .from('notifications')
          .select('id,type,created_at,read,actor_id,post_id')
          .eq('user_id', u.id)
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) setState(() => items = List<Map<String, dynamic>>.from(r));
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('مركز النشاط')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('لا يوجد نشاط بعد'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return ListTile(
                      leading: Icon(_notificationIcon(e['type']), color: e['read'] == true ? Colors.white54 : cyan),
                      title: Text(_notificationText(e['type'])),
                      subtitle: Text((e['created_at'] ?? '').toString()),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsPage()),
                      ),
                    );
                  },
                ),
    );
  }
}

IconData _notificationIcon(dynamic t) => t == 'like'
    ? Icons.favorite
    : t == 'comment'
        ? Icons.chat_bubble_outline
        : t == 'follow'
            ? Icons.person_add_alt_1
            : Icons.card_giftcard;

String _notificationText(dynamic t) => t == 'like'
    ? 'إعجاب بمحتواك'
    : t == 'comment'
        ? 'تعليق على منشورك'
        : t == 'follow'
            ? 'بدأ متابعتك'
            : 'أرسل لك هدية';

class VisitorsPage extends StatefulWidget {
  const VisitorsPage({super.key});

  @override
  State<VisitorsPage> createState() => _VisitorsPageState();
}

class _VisitorsPageState extends State<VisitorsPage> {
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final u = sb.auth.currentUser;
      if (u == null) return;
      final r = await sb
          .from('profile_views')
          .select('viewer_id,created_at')
          .eq('profile_id', u.id)
          .order('created_at', ascending: false)
          .limit(100);
      final next = List<Map<String, dynamic>>.from(r);
      final ids = next.map((x) => x['viewer_id'].toString()).toSet().toList();
      if (ids.isNotEmpty) {
        final profiles = await sb.from('profiles').select('id,username,avatar_url,is_verified').inFilter('id', ids);
        final byId = <String, Map<String, dynamic>>{for (final p in List<Map<String, dynamic>>.from(profiles)) p['id'].toString(): p};
        for (final row in next) {
          row['_profile'] = byId[row['viewer_id'].toString()];
        }
      }
      if (mounted) setState(() => rows = next);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('زيارات الملف الشخصي')),
      body: rows.isEmpty
          ? const Center(child: Text('لا توجد زيارات مسجلة بعد'))
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: ((rows[i]['_profile']?['avatar_url'] ?? '').toString().isNotEmpty)
                      ? NetworkImage(rows[i]['_profile']['avatar_url'].toString())
                      : null,
                  child: ((rows[i]['_profile']?['avatar_url'] ?? '').toString().isEmpty) ? const Icon(Icons.person) : null,
                ),
                title: Text('@${rows[i]['_profile']?['username'] ?? 'مستخدم'}'),
                subtitle: Text((rows[i]['created_at'] ?? '').toString()),
              ),
            ),
    );
  }
}

class BlockedPage extends StatefulWidget {
  const BlockedPage({super.key});

  @override
  State<BlockedPage> createState() => _BlockedPageState();
}

class _BlockedPageState extends State<BlockedPage> {
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final u = sb.auth.currentUser;
      if (u == null) return;
      final r = await sb
          .from('blocked_users')
          .select('blocked_id,created_at')
          .eq('blocker_id', u.id)
          .order('created_at', ascending: false);
      final next = List<Map<String, dynamic>>.from(r);
      final ids = next.map((x) => x['blocked_id'].toString()).toList();
      if (ids.isNotEmpty) {
        final profiles = await sb.from('profiles').select('id,username,avatar_url').inFilter('id', ids);
        final byId = <String, Map<String, dynamic>>{for (final p in List<Map<String, dynamic>>.from(profiles)) p['id'].toString(): p};
        for (final row in next) {
          row['_profile'] = byId[row['blocked_id'].toString()];
        }
      }
      if (mounted) setState(() => rows = next);
    } catch (_) {}
  }

  Future<void> remove(String id) async {
    try {
      await sb.from('blocked_users').delete().eq('blocker_id', sb.auth.currentUser!.id).eq('blocked_id', id);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إلغاء الحظر: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('الحسابات المحظورة')),
      body: rows.isEmpty
          ? const Center(child: Text('لا توجد حسابات محظورة'))
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: ((rows[i]['_profile']?['avatar_url'] ?? '').toString().isNotEmpty)
                      ? NetworkImage(rows[i]['_profile']['avatar_url'].toString())
                      : null,
                  child: ((rows[i]['_profile']?['avatar_url'] ?? '').toString().isEmpty) ? const Icon(Icons.block) : null,
                ),
                title: Text('@${rows[i]['_profile']?['username'] ?? rows[i]['blocked_id']}'),
                trailing: TextButton(
                  onPressed: () => remove(rows[i]['blocked_id'].toString()),
                  child: const Text('إلغاء الحظر'),
                ),
              ),
            ),
    );
  }
}

class OfflinePage extends StatefulWidget {
  const OfflinePage({super.key});

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final x = await OfflineStore.list();
      if (mounted) {
        setState(() {
          items = x;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> remove(String id) async {
    await OfflineStore.remove(id);
    await load();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المشاهدة دون اتصال'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_done_rounded, size: 70, color: cyan),
                      SizedBox(height: 14),
                      Text('لا توجد فيديوهات محفوظة بعد'),
                      SizedBox(height: 6),
                      Text(
                        'اضغط «تنزيل» من أي منشور لحفظه هنا.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    final video = e['type'] == 'video';
                    final avatarPath = e['path']?.toString() ?? '';
                    return Card(
                      color: panel,
                      child: ListTile(
                        leading: SizedBox(
                          width: 62,
                          height: 62,
                          child: video
                              ? const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFF18202A),
                                  ),
                                  child: Icon(
                                    Icons.play_circle_fill,
                                    size: 34,
                                    color: cyan,
                                  ),
                                )
                              : Image.file(
                                  File(avatarPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image),
                                ),
                        ),
                        title: Text(
                          '@${e['username'] ?? 'N'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          (e['caption'] ?? '').toString().isEmpty
                              ? 'محتوى محفوظ محليًا'
                              : e['caption'].toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          onPressed: () => remove(e['id'].toString()),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                        onTap: () => Navigator.push(
                          c,
                          MaterialPageRoute(
                            builder: (_) => OfflineViewerPage(item: e),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class OfflineViewerPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const OfflineViewerPage({super.key, required this.item});

  @override
  State<OfflineViewerPage> createState() => _OfflineViewerPageState();
}

class _OfflineViewerPageState extends State<OfflineViewerPage> {
  VideoPlayerController? controller;

  @override
  void initState() {
    super.initState();
    if (widget.item['type'] == 'video') {
      controller = VideoPlayerController.file(
        File(widget.item['path'].toString()),
      )
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            controller!.setLooping(true);
            controller!.play();
          }
        });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('@${widget.item['username'] ?? 'N'}'),
      ),
      body: Center(
        child: widget.item['type'] == 'video'
            ? (controller?.value.isInitialized == true
                ? AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: VideoPlayer(controller!),
                  )
                : const CircularProgressIndicator())
            : Image.file(
                File(widget.item['path'].toString()),
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}

class StudioPage extends StatelessWidget {
  const StudioPage({super.key});

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('N Studio')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          ListTile(
            leading: const Icon(Icons.video_library, color: cyan),
            title: const Text('إنشاء منشور'),
            subtitle: const Text('اختيار فيديو أو صورة ونشرها'),
            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const PublishPage())),
          ),
          ListTile(
            leading: const Icon(Icons.sensors, color: pink),
            title: const Text('بدء بث مباشر'),
            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const LivePage())),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: cyan),
            title: const Text('N AI'),
            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AiPage())),
          ),
        ],
      ),
    );
  }
}

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  int balance = 0;
  int selected = 0;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  List<ProductDetails> products = [];
  bool storeAvailable = false;
  bool storeLoading = true;
  static const _coinProductIds = <String>{'n_coins_100','n_coins_550','n_coins_1200','n_coins_2600','n_coins_7000'};
  final gifts = const [
    ['وردة', 10, Icons.local_florist],
    ['قلب', 50, Icons.favorite],
    ['أسد', 500, Icons.pets],
    ['سيارة', 1000, Icons.directions_car],
    ['يخت', 5000, Icons.directions_boat],
    ['قصر', 10000, Icons.castle],
    ['طائر النور', 20000, Icons.flutter_dash],
    ['نجمة', 50000, Icons.auto_awesome],
    ['ختمة', 100000, Icons.star_border],
  ];

  @override
  void initState() { super.initState(); load(); _purchaseSub=_iap.purchaseStream.listen(_handlePurchases,onError:(_)=>{}); _loadStore(); }
  Future<void> _loadStore() async { try { final available=await _iap.isAvailable(); if(!available){if(mounted)setState((){storeAvailable=false;storeLoading=false;});return;} final response=await _iap.queryProductDetails(_coinProductIds); if(mounted)setState((){storeAvailable=true;products=response.productDetails;storeLoading=false;}); } catch(_){if(mounted)setState((){storeAvailable=false;storeLoading=false;});} }
  Future<void> _buy(ProductDetails product) async { try { await _iap.buyConsumable(purchaseParam:PurchaseParam(productDetails:product),autoConsume:true); } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر بدء الشراء: $e')));} }
  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async { for(final purchase in purchases){ if(purchase.status==PurchaseStatus.purchased||purchase.status==PurchaseStatus.restored){ try { final result=await sb.functions.invoke('verify-purchase',body:{'productId':purchase.productID,'purchaseToken':purchase.verificationData.serverVerificationData}); final data=result.data is Map?Map<String,dynamic>.from(result.data as Map):<String,dynamic>{}; if(data['ok']==true){await load();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تمت إضافة ${data['coins']??''} عملة إلى رصيدك.')));} } catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر التحقق من عملية الشراء: $e')));} } else if(purchase.status==PurchaseStatus.error&&mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('فشلت عملية الشراء: ${purchase.error?.message??'خطأ غير معروف'}')));} if(purchase.pendingCompletePurchase){try{await _iap.completePurchase(purchase);}catch(_){}} } }
  @override void dispose(){_purchaseSub?.cancel();super.dispose();}

  Future<void> load() async {
    try {
      final u = sb.auth.currentUser;
      if (u == null) return;
      final r = await sb.from('user_coins').select('balance').eq('user_id', u.id).maybeSingle();
      if (mounted) setState(() => balance = (r?['balance'] ?? 0) as int);
    } catch (_) {}
  }

  Future<void> sendGift() async {
    final u = sb.auth.currentUser;
    if (u == null) return;
    final g = gifts[selected];
    final other = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final x = TextEditingController();
        return AlertDialog(
          title: const Text('إرسال هدية'),
          content: TextField(controller: x, decoration: const InputDecoration(labelText: 'اسم المستخدم أو UUID')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, x.text.trim()), child: const Text('إرسال')),
          ],
        );
      },
    );
    if (other == null || other.isEmpty) return;
    try {
      var receiver=other; final byUsername=await sb.from('profiles').select('id').ilike('username',other).maybeSingle(); if(byUsername!=null)receiver=byUsername['id'].toString();
      await sb.rpc('send_gift', params: {'p_receiver': receiver, 'p_name': g[0], 'p_cost': g[1]});
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال ${g[0]} بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الهدية: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('المتجر والهدايا', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [Padding(padding: const EdgeInsets.only(left: 12), child: Center(child: Text('🪙 $balance', style: const TextStyle(fontWeight: FontWeight.w900))))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() => selected = selected),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF171D25)),
                  child: const Text('الهدايا'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showModalBottomSheet(
                    context: c,
                    builder: (_) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'شراء العملات',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (storeLoading)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              )
                            else if (!storeAvailable || products.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'متجر Google Play غير متاح أو لم تتم إضافة منتجات العملات بعد.',
                                ),
                              )
                            else
                              ...products.map(
                                (p) => Card(
                                  color: panel,
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.monetization_on,
                                      color: cyan,
                                    ),
                                    title: Text(p.title),
                                    subtitle: Text(p.description),
                                    trailing: FilledButton(
                                      onPressed: () => _buy(p),
                                      child: Text(p.price),
                                    ),
                                  ),
                                ),
                              ),
                            TextButton(
                              onPressed: () => _iap.restorePurchases(),
                              child: const Text('استعادة عمليات الشراء'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('شراء العملات'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: gifts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: .86,
            ),
            itemBuilder: (_, i) {
              final g = gifts[i];
              final on = i == selected;
              return InkWell(
                onTap: () => setState(() => selected = i),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E131A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: on ? pink : const Color(0xFF202B35), width: on ? 1.6 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(g[2] as IconData, size: 42, color: i % 2 == 0 ? pink : cyan),
                      const SizedBox(height: 7),
                      Text(g[0] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('🪙 ${g[1]}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: sendGift,
              style: FilledButton.styleFrom(backgroundColor: pink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text('إرسال هدية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final u = sb.auth.currentUser;
      if (u == null) return;
      final r = await sb
          .from('notifications')
          .select('id,type,created_at,read,actor_id,post_id')
          .eq('user_id', u.id)
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) setState(() => rows = List<Map<String, dynamic>>.from(r));
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> markAll() async {
    try {
      final u = sb.auth.currentUser;
      if (u == null) return;
      await sb.from('notifications').update({'read': true}).eq('user_id', u.id).eq('read', false);
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الإشعارات: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('الإشعارات', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: markAll, icon: const Icon(Icons.done_all_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const Center(child: Text('لا توجد إشعارات بعد'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 30),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = rows[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: Icon(_notificationIcon(e['type']), color: e['read'] == true ? Colors.white54 : cyan),
                      title: Text(
                        _notificationText(e['type']),
                        style: TextStyle(fontWeight: e['read'] == true ? FontWeight.w500 : FontWeight.w900),
                      ),
                      subtitle: Text((e['created_at'] ?? '').toString()),
                      onTap: () async {
                        if (e['read'] != true) {
                          await sb.from('notifications').update({'read': true}).eq('id', e['id']);
                          await load();
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool private = false;
  bool notifications = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = sb.auth.currentUser;
    if (u == null) return;
    try {
      final r = await sb
          .from('profiles')
          .select('is_private,notifications_enabled')
          .eq('id', u.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        private = r?['is_private'] == true;
        notifications = r?['notifications_enabled'] != false;
      });
    } catch (_) {}
  }

  Future<void> _set(String field, bool value) async {
    setState(() {
      if (field == 'is_private') {
        private = value;
      } else {
        notifications = value;
      }
    });
    try {
      final u = sb.auth.currentUser;
      if (u == null) return;
      await sb.from('profiles').update({field: value}).eq('id', u.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (field == 'is_private') {
          private = !value;
        } else {
          notifications = !value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('الخصوصية')),
        body: ListView(
          children: [
            SwitchListTile(
              value: private,
              onChanged: (v) => _set('is_private', v),
              title: const Text('حساب خاص'),
              subtitle: const Text('تحكم بمن يمكنه مشاهدة محتواك'),
              secondary: const Icon(Icons.lock_outline),
            ),
            SwitchListTile(
              value: notifications,
              onChanged: (v) => _set('notifications_enabled', v),
              title: const Text('الإشعارات'),
              secondary: const Icon(Icons.notifications_none),
            ),
          ],
        ),
      );
}

class AiPage extends StatefulWidget {
  const AiPage({super.key});
  @override State<AiPage> createState() => _AiPageState();
}
class _AiPageState extends State<AiPage> {
  final ctrl = TextEditingController();
  final messages = <Map<String,String>>[];
  bool busy = false;
  Future<void> send() async {
    final text = ctrl.text.trim(); if (text.isEmpty || busy) return;
    setState(() { messages.add({'role':'user','text':text}); ctrl.clear(); busy=true; });
    try {
      final result = await sb.functions.invoke('ai-chat', body: {'message': text});
      final data = result.data;
      final reply = data is Map ? (data['reply'] ?? '').toString() : '';
      if (reply.isEmpty) throw Exception('لم تصل استجابة من N AI.');
      if (!mounted) return;
      setState(() { busy=false; messages.add({'role':'ai','text':reply}); });
    } catch (e) {
      if (!mounted) return;
      setState(() { busy=false; messages.add({'role':'ai','text':'تعذر الاتصال بـ N AI الآن: $e'}); });
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('N AI')),
    body: Column(children: [
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: messages.length, itemBuilder: (_,i) => Align(alignment: messages[i]['role']=='user'?Alignment.centerRight:Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom:10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: panel,borderRadius: BorderRadius.circular(16)), child: Text(messages[i]['text']!))))),
      SafeArea(child: Row(children: [Expanded(child: TextField(controller: ctrl, minLines:1, maxLines:4, decoration: const InputDecoration(hintText:'اكتب لـ N AI'))), IconButton(onPressed: busy?null:send, icon: const Icon(Icons.send))]))
    ]),
  );
}
