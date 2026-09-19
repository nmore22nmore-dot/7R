import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

final sb = Supabase.instance.client;

const bg = Color(0xFF07080D);
const panel = Color(0xFF11131B);
const cyan = Color(0xFF00C8FF);
const pink = Color(0xFFFF287A);
const authRedirectUrl = 'n://auth-callback';


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
  var query = sb.from('posts').select('*').eq('visibility', 'public');
  if (following) {
    if (user == null) return [];
    final follows = await sb.from('follows').select('following_id').eq('follower_id', user.id);
    final ids = List<Map<String, dynamic>>.from(follows).map((r) => r['following_id'].toString()).toList();
    if (ids.isEmpty) return [];
    query = query.inFilter('user_id', ids);
  }
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
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0B0D13),
          indicatorColor: const Color(0xFF17202A),
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
      },
      onError: (_) {},
    );
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

        final r = await sb.auth.signUp(
          email: e,
          password: p,
          data: {'username': u},
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
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
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

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  final pages = const [
    HomePage(),
    FollowingPage(),
    PublishPage(),
    MessagesPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: index,
          children: pages,
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xF20C0F16),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF202833)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _navItem(0, Icons.home_outlined, Icons.home, 'الرئيسية'),
                _navItem(1, Icons.people_outline, Icons.people, 'الأصدقاء'),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _openCreateMenu,
                      child: Container(
                        width: 54,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [cyan, Colors.white, pink],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x5500C8FF),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                _navItem(3, Icons.mail_outline, Icons.mail, 'الرسائل'),
                _navItem(4, Icons.person_outline, Icons.person, 'الملف الشخصي'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCreateMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _createAction(Icons.video_call, 'فيديو', () {
                Navigator.pop(context);
                setState(() => index = 2);
              }),
              _createAction(Icons.image_outlined, 'صورة', () {
                Navigator.pop(context);
                setState(() => index = 2);
              }),
              _createAction(Icons.sensors, 'بث مباشر', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LivePage()));
              }),
              _createAction(Icons.auto_awesome, 'N AI', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AiPage()));
              }),
              _createAction(Icons.history_toggle_off, 'قصة', () {
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('إضافة القصص قيد الربط مع التخزين.')));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createAction(IconData icon, String title, VoidCallback onTap) {
    return SizedBox(
      width: 92,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            CircleAvatar(radius: 28, backgroundColor: const Color(0xFF202833), child: Icon(icon, color: cyan)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
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
            Icon(
              selected ? active : normal,
              color: selected ? cyan : Colors.white70,
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? cyan : Colors.white70,
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      final data=await sb.from('posts').select().eq('user_id',widget.userId).eq('visibility','public').order('created_at',ascending:false);
      final me=sb.auth.currentUser;
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
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('@${widget.username}')),body:Column(children:[
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

class FeedPage extends StatefulWidget {
  final bool following;

  const FeedPage({
    super.key,
    required this.following,
  });

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<Map<String, dynamic>> posts = [];
  bool loading = true;
  int activeIndex = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      final data = await loadPostsWithProfiles(following: widget.following);
      if (mounted) setState(() => posts = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل المحتوى: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          loading
              ? const Center(child: CircularProgressIndicator())
              : posts.isEmpty
                  ? RefreshIndicator(
                      onRefresh: load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 300),
                          Center(
                            child: Text(
                              'لا توجد فيديوهات بعد.\nاسحب للتحديث أو ابدأ بالنشر من زر +',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: load,
                      child: PageView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: posts.length,
                        onPageChanged: (i) => setState(() => activeIndex = i),
                        itemBuilder: (_, i) => VideoCard(post: posts[i], active: i == activeIndex),
                      ),
                    ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x6610131B),
                    ),
                    icon: const Icon(Icons.search),
                  ),
                  const Spacer(),
                  _FeedTab(
                    active: !widget.following,
                    title: 'لك',
                  ),
                  const SizedBox(width: 22),
                  _FeedTab(
                    active: widget.following,
                    title: 'متابعة',
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MessagesPage()),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x6610131B),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

  const VideoCard({
    super.key,
    required this.post,
    this.active = true,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  VideoPlayerController? c;
  bool liked = false;
  bool saved = false;
  int likes = 0;

  String get url {
    return (widget.post['media_url'] ?? '').toString();
  }

  @override
  void initState() {
    super.initState();

    final rawLikes = widget.post['likes_count'];
    likes = rawLikes is int ? rawLikes : 0;

    if (url.isNotEmpty && (widget.post['media_type'] ?? 'video') == 'video') {
      c = VideoPlayerController.networkUrl(Uri.parse(url))..initialize().then((_) {
        if (mounted) {
          setState(() {});
          c!.setLooping(true);
          if (widget.active) c!.play();
        }
      });
    }
    _loadReactionState();
  }

  Future<void> _loadReactionState() async {
    final user = sb.auth.currentUser;
    if (user == null) return;
    try {
      final results = await Future.wait([
        sb.from('post_likes').select('post_id').eq('post_id', widget.post['id']).eq('user_id', user.id).maybeSingle(),
        sb.from('saved_posts').select('post_id').eq('post_id', widget.post['id']).eq('user_id', user.id).maybeSingle(),
      ]);
      if (mounted) {
        setState(() {
          liked = results[0] != null;
          saved = results[1] != null;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (c?.value.isInitialized != true) return;
    if (widget.active && !oldWidget.active) c!.play();
    if (!widget.active && oldWidget.active) c!.pause();
  }

  @override
  void dispose() {
    c?.dispose();
    super.dispose();
  }

  Future<void> like() async {
    final user = sb.auth.currentUser;

    if (user == null) {
      return;
    }

    final uid = user.id;

    try {
      if (liked) {
        await sb
            .from('post_likes')
            .delete()
            .eq('post_id', widget.post['id'])
            .eq('user_id', uid);

        likes--;
      } else {
        await sb.from('post_likes').insert({
          'post_id': widget.post['id'],
          'user_id': uid,
        });

        likes++;
      }

      if (mounted) {
        setState(() {
          liked = !liked;
        });
      }
    } catch (_) {}
  }

  Future<void> save() async {
    final user = sb.auth.currentUser;

    if (user == null) {
      return;
    }

    final uid = user.id;

    try {
      if (saved) {
        await sb
            .from('saved_posts')
            .delete()
            .eq('post_id', widget.post['id'])
            .eq('user_id', uid);
      } else {
        await sb.from('saved_posts').insert({
          'post_id': widget.post['id'],
          'user_id': uid,
        });
      }

      if (mounted) {
        setState(() {
          saved = !saved;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: like,
      child: Stack(
        fit: StackFit.expand,
      children: [
        if ((widget.post['media_type'] ?? 'video') == 'image' && url.isNotEmpty)
          Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 60)))
        else if (c?.value.isInitialized == true)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: c!.value.size.width,
              height: c!.value.size.height,
              child: VideoPlayer(c!),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(),
          ),
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              IconButton(
                onPressed: like,
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? pink : Colors.white,
                  size: 34,
                ),
              ),
              Text('$likes'),
              IconButton(
                onPressed: () {
                  showComments(
                    context,
                    widget.post['id'],
                  );
                },
                icon: const Icon(
                  Icons.comment,
                  size: 32,
                ),
              ),
              IconButton(
                onPressed: save,
                icon: Icon(
                  saved ? Icons.bookmark : Icons.bookmark_border,
                  size: 32,
                ),
              ),
              IconButton(
                onPressed: () {
                  showShare(context);
                },
                icon: const Icon(
                  Icons.share,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 18,
          left: 88,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.post['profile']?['username'] ?? 'N'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.post['caption'] ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              const Text('N original sound'),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

void showShare(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (_) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'شارك رابط المنشور من خلال مشاركة النظام.',
          ),
        ),
      );
    },
  );
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

class LivePage extends StatelessWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          'البث المباشر',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF162733), Color(0xFF180B14)],
              ),
              border: Border.all(color: const Color(0xFF273541)),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.sensors,
                    color: cyan,
                    size: 54,
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: pink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  right: 16,
                  bottom: 16,
                  child: Text(
                    'ابدأ بثك المباشر',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'بثوث مباشرة الآن',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            4,
            (i) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF202833)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0xFF202833),
                    child: Icon(Icons.person),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '@N_user_${i + 1}\\nبث مباشر الآن',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.visibility_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text('${(i + 1) * 1.2}K'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _storageMessage(Object e) {
  final raw = e.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('row-level security') || lower.contains('not authorized') || lower.contains('permission')) {
    return 'الرفع مرفوض من Supabase Storage. تحقق من bucket وسياسات Storage.';
  }
  if (lower.contains('bucket') && lower.contains('not found')) {
    return 'مجلد post-media غير موجود في Supabase.';
  }
  if (lower.contains('network')) {
    return 'تعذر الاتصال بالخادم.';
  }
  return raw.replaceFirst('Exception: ', '');
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

  Future<void> pick(ImageSource src) async {
    final x = imageMode ? await ImagePicker().pickImage(source: src, imageQuality: 90) : await ImagePicker().pickVideo(source: src);

    if (x != null && mounted) {
      setState(() {
        file = x;
      });
    }
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
          );

      final mediaPath = path;

      await sb.from('posts').insert({
        'user_id': uid,
        'media_url': mediaPath,
        'media_type': imageMode ? 'image' : 'video',
        'caption': caption.text.trim(),
        'visibility': visibility,
      });

      if (mounted) {
        caption.clear();

        setState(() {
          file = null;
        });

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
      appBar: AppBar(
        title: const Text('نشر فيديو'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SegmentedButton<bool>(segments: const [ButtonSegment(value:false,label:Text('فيديو'),icon:Icon(Icons.videocam)), ButtonSegment(value:true,label:Text('صورة'),icon:Icon(Icons.image))], selected:{imageMode}, onSelectionChanged:(v)=>setState(()=>imageMode=v.first)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      pick(ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: Text(imageMode ? 'التقاط صورة' : 'تصوير فيديو'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      pick(ImageSource.gallery);
                    },
                    icon: const Icon(Icons.video_library),
                    label: Text(imageMode ? 'اختيار صورة' : 'رفع فيديو'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (file != null)
              Text(
                'تم اختيار: ${file!.name}',
              ),
            TextField(
              controller: caption,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: Text('من يمكنه مشاهدة المنشور؟', style: Theme.of(context).textTheme.titleSmall)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'public', label: Text('الجميع'), icon: Icon(Icons.public, size: 18)),
                ButtonSegment(value: 'followers', label: Text('المتابعون'), icon: Icon(Icons.people_outline, size: 18)),
                ButtonSegment(value: 'private', label: Text('أنا فقط'), icon: Icon(Icons.lock_outline, size: 18)),
              ],
              selected: {visibility},
              onSelectionChanged: (v) => setState(() => visibility = v.first),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : publish,
                child: Text(
                  busy ? 'جاري النشر...' : 'نشر',
                ),
              ),
            ),
          ],
        ),
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

      if (mounted) {
        setState(() {
          rows = List<Map<String, dynamic>>.from(x);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرسائل'),
      ),
      body: rows.isEmpty
          ? const Center(
              child: Text('لا توجد محادثات بعد'),
            )
          : ListView(
              children: rows.map((e) {
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(
                    e['title'] ?? 'محادثة',
                  ),
                  subtitle: Text(
                    e['last_message'] ?? '',
                  ),
                  onTap: () {
                    ChatPage.open(
                      context,
                      e['id'],
                    );
                  },
                );
              }).toList(),
            ),
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
  XFile? attachment;
  bool sending = false;
  Timer? _messageRefreshTimer;
  RealtimeChannel? _channel;

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
      if (mounted && next.length != msgs.length) {
        setState(() => msgs = next);
      }
    } catch (e) {
      if (mounted && !silent) _showError('تعذر تحميل الرسائل: $e');
    }
  }

  Future<void> pickAttachment() async {
    try {
      final x = await ImagePicker().pickMedia();
      if (x != null && mounted) setState(() => attachment = x);
    } catch (e) {
      if (mounted) _showError('تعذر اختيار الملف: $e');
    }
  }

  Future<void> send() async {
    final body = ctrl.text.trim();
    if (body.isEmpty && attachment == null) return;
    final user = sb.auth.currentUser;
    if (user == null) return;

    setState(() => sending = true);
    try {
      String? mediaUrl;
      String? mediaType;
      if (attachment != null) {
        final ext = attachment!.path.split('.').last.toLowerCase().split('?').first;
        final isVideo = {'mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'}.contains(ext);
        mediaType = isVideo ? 'video' : 'image';
        final safeExt = ext.isEmpty ? (isVideo ? 'mp4' : 'jpg') : ext;
        final path = '${user.id}/${widget.id}/${DateTime.now().millisecondsSinceEpoch}.$safeExt';
        await sb.storage.from('message-media').upload(path, File(attachment!.path));
        mediaUrl = path;
      }

      await sb.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': user.id,
        'body': body,
        'media_url': mediaUrl,
        'media_type': mediaType,
      });
      ctrl.clear();
      if (mounted) setState(() => attachment = null);
      await load();
    } catch (e) {
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
    ctrl.dispose();
    super.dispose();
  }

  Future<String?> _signedMessageUrl(String value) async {
    try { return await sb.storage.from('message-media').createSignedUrl(_storagePath(value, 'message-media'), 3600); } catch (_) { return null; }
  }

  Widget _messageMedia(Map<String, dynamic> m) {
    final url = (m['media_url'] ?? '').toString();
    if (url.isEmpty) return const SizedBox.shrink();
    final type = (m['media_type'] ?? '').toString();
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
      child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.videocam_outlined), SizedBox(width: 6), Text('فيديو مرفق')]),
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
                Expanded(child: TextField(controller: ctrl, enabled: !sending, decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: InputBorder.none))),
                IconButton(onPressed: sending ? null : send, icon: const Icon(Icons.send)),
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

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? p;
  List<Map<String,dynamic>> myPosts = [];

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
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final posts = await sb.from('posts').select().eq('user_id', user.id).order('created_at', ascending: false);
      if (mounted) {
        setState(() { p = x; myPosts = List<Map<String,dynamic>>.from(posts); });
      }
    } catch (_) {}
  }

  Future<void> _editProfile(BuildContext context) async {
    final username = TextEditingController(text: p?['username'] ?? '');
    final bio = TextEditingController(text: p?['bio'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل الملف الشخصي'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: username, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
          const SizedBox(height: 12),
          TextField(controller: bio, maxLines: 3, decoration: const InputDecoration(labelText: 'النبذة')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await sb.from('profiles').update({'username': username.text.trim(), 'bio': bio.text.trim()}).eq('id', sb.auth.currentUser!.id);
      await load();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الملف الشخصي.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الملف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 25),
            CircleAvatar(
              radius: 48,
              backgroundImage: (p?['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage(p!['avatar_url']) : null,
              child: (p?['avatar_url'] ?? '').toString().isEmpty ? const Icon(Icons.person, size: 50) : null,
            ),
            const SizedBox(height: 12),
            Text(
              '@${p?['username'] ?? ''}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              p?['bio'] ?? '',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _editProfile(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('تعديل الملف الشخصي'),
            ),
            const SizedBox(height: 20),
            Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: Text('منشوراتي (${myPosts.length})', style: const TextStyle(fontSize:20,fontWeight:FontWeight.bold)))),
            const SizedBox(height: 10),
            Expanded(child: GridView.builder(padding: const EdgeInsets.symmetric(horizontal:8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:4,mainAxisSpacing:4), itemCount:myPosts.length, itemBuilder:(_,i)=>FutureBuilder<String?>(
      future: _signedPostUrl(myPosts[i]['media_url'].toString()),
      builder: (_, snap) => snap.hasData ? Image.network(snap.data!, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.broken_image)) : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    ))),
          ],
        ),
      ),
    );
  }
}


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  bool private = false, notifications = true, loading = true;

  @override void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    final user = sb.auth.currentUser; if (user == null) return;
    try {
      final row = await sb.from('profiles').select('is_private,notifications_enabled').eq('id', user.id).maybeSingle();
      if (mounted) setState(() { private = row?['is_private'] == true; notifications = row?['notifications_enabled'] != false; loading = false; });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  Future<void> _setSetting(String field, bool value) async {
    final user = sb.auth.currentUser; if (user == null) return;
    final oldPrivate=private, oldNotifications=notifications;
    setState(() { if(field=='is_private') private=value; if(field=='notifications_enabled') notifications=value; });
    try { await sb.from('profiles').update({field:value}).eq('id', user.id); }
    catch(e) { if(!mounted)return; setState(() { private=oldPrivate; notifications=oldNotifications; }); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حفظ الإعداد: $e'))); }
  }

  @override Widget build(BuildContext context) => Scaffold(appBar:AppBar(title:const Text('الإعدادات والخصوصية')),body: loading ? const Center(child:CircularProgressIndicator()) : ListView(children:[
    SwitchListTile(value:private,onChanged:(v)=>_setSetting('is_private',v),title:const Text('حساب خاص'),subtitle:const Text('التحكم في ظهور محتواك للآخرين'),secondary:const Icon(Icons.lock_outline)),
    SwitchListTile(value:notifications,onChanged:(v)=>_setSetting('notifications_enabled',v),title:const Text('الإشعارات'),secondary:const Icon(Icons.notifications_none)),
    ListTile(leading:const Icon(Icons.security_outlined),title:const Text('الأمان والحساب'),onTap:()=>showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('الأمان والحساب'),content:const Text('يمكنك استخدام استعادة كلمة المرور من شاشة الدخول.'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إغلاق'))]))),
    ListTile(leading:const Icon(Icons.language),title:const Text('اللغة'),subtitle:const Text('العربية')), const Divider(),
    ListTile(leading:const Icon(Icons.logout),title:const Text('تسجيل الخروج'),onTap:() async { await sb.auth.signOut(); if(context.mounted) Navigator.pop(context); }),
  ]));
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
    // The UI is ready; the actual model call must be routed through a protected backend/Edge Function.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() { busy=false; messages.add({'role':'ai','text':'N AI يحتاج ربط خدمة الذكاء الاصطناعي الآمنة من الخادم قبل أن أرسل طلبات حقيقية.'}); });
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('N AI')),
    body: Column(children: [
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: messages.length, itemBuilder: (_,i) => Align(alignment: messages[i]['role']=='user'?Alignment.centerRight:Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom:10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: panel,borderRadius: BorderRadius.circular(16)), child: Text(messages[i]['text']!))))),
      SafeArea(child: Row(children: [Expanded(child: TextField(controller: ctrl, minLines:1, maxLines:4, decoration: const InputDecoration(hintText:'اكتب لـ N AI'))), IconButton(onPressed: busy?null:send, icon: const Icon(Icons.send))]))
    ]),
  );
}
