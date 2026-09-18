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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: sb.auth.onAuthStateChange,
      builder: (_, snap) {
        return sb.auth.currentSession == null
            ? const AuthPage()
            : const Shell();
      },
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
      await sb.auth.resetPasswordForEmail(e);
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
    LivePage(),
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
                      onTap: () => setState(() => index = 2),
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
                _navItem(3, Icons.sensors_outlined, Icons.sensors, 'البث المباشر'),
                _navItem(4, Icons.person_outline, Icons.person, 'الملف الشخصي'),
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

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await sb
          .from('posts')
          .select('*, profiles(username,avatar_url)')
          .eq('visibility', 'public')
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          posts = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        loading = false;
      });
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
                  ? const Center(
                      child: Text(
                        'لا توجد فيديوهات بعد.\nابدأ بالنشر من زر +',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : PageView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: posts.length,
                      itemBuilder: (_, i) => VideoCard(post: posts[i]),
                    ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
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

  const VideoCard({
    super.key,
    required this.post,
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

    if (url.isNotEmpty) {
      c = VideoPlayerController.networkUrl(
        Uri.parse(url),
      )..initialize().then((_) {
          if (mounted) {
            setState(() {});
            c!.setLooping(true);
            c!.play();
          }
        });
    }
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
    return Stack(
      fit: StackFit.expand,
      children: [
        if (c?.value.isInitialized == true)
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
                '@${widget.post['profiles']?['username'] ?? 'N'}',
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
                    future: sb
                        .from('comments')
                        .select('*, profiles(username)')
                        .eq('post_id', postId)
                        .order(
                          'created_at',
                          ascending: false,
                        )
                        .then(
                          (x) => List<Map<String, dynamic>>.from(x),
                        ),
                    builder: (_, s) {
                      if (s.hasData) {
                        return ListView(
                          children: s.data!.map((e) {
                            return ListTile(
                              title: Text(
                                '@${e['profiles']?['username'] ?? ''}',
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
  bool busy = false;

  Future<void> pick(ImageSource src) async {
    final x = await ImagePicker().pickVideo(
      source: src,
    );

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

      final url = sb.storage
          .from('post-media')
          .getPublicUrl(path);

      await sb.from('posts').insert({
        'user_id': uid,
        'media_url': url,
        'media_type': 'video',
        'caption': caption.text.trim(),
        'visibility': 'public',
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      pick(ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('تصوير'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      pick(ImageSource.gallery);
                    },
                    icon: const Icon(Icons.video_library),
                    label: const Text('رفع فيديو'),
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
              decoration: const InputDecoration(
                labelText: 'الوصف',
              ),
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

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final x = await sb
          .from('messages')
          .select()
          .eq(
            'conversation_id',
            widget.id,
          )
          .order('created_at');

      if (mounted) {
        setState(() {
          msgs = List<Map<String, dynamic>>.from(x);
        });
      }
    } catch (_) {}
  }

  Future<void> send() async {
    final body = ctrl.text.trim();

    if (body.isEmpty) {
      return;
    }

    final user = sb.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      await sb.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': user.id,
        'body': body,
      });

      ctrl.clear();
      await load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = sb.auth.currentUser?.id;

    final messageWidgets = msgs.map<Widget>((m) {
      final isMine = m['sender_id'] == currentUserId;

      return Align(
        alignment:
            isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            m['body'] ?? '',
          ),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('محادثة N'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: messageWidgets,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    hintText: 'اكتب رسالة...',
                  ),
                ),
              ),
              IconButton(
                onPressed: send,
                icon: const Icon(Icons.send),
              ),
            ],
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

      if (mounted) {
        setState(() {
          p = x;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            onPressed: () {
              sb.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 25),
            const CircleAvatar(
              radius: 48,
              child: Icon(
                Icons.person,
                size: 50,
              ),
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
            const SizedBox(height: 20),
            const Text(
              'منشوراتي',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
