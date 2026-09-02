import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'n_data.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'core/widgets/n_bottom_nav.dart';
import 'core/widgets/n_logo.dart';
import 'pages/inbox_page.dart';
import 'pages/security_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    runApp(const NConfigurationErrorApp());
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  } catch (_) {
    runApp(const NConfigurationErrorApp());
    return;
  }

  runApp(const NApp());
}

class NConfigurationErrorApp extends StatelessWidget {
  const NConfigurationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'إعدادات Supabase غير موجودة.\n'
                'أعد بناء التطبيق من Codemagic.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NApp extends StatelessWidget {
  const NApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'N',
      debugShowCheckedModeBanner: false,
      theme: NTheme.dark(),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: LoginPage(),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool register = true;
  bool hidden = true;
  bool submitting = false;

  final name = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  DateTime? birthDate;

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  int ageFromBirth(DateTime date) {
    final now = DateTime.now();

    var age = now.year - date.year;

    final birthday = DateTime(
      now.year,
      date.month,
      date.day,
    );

    if (birthday.isAfter(now)) {
      age--;
    }

    return age;
  }

  Future<void> chooseBirthDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'اختر تاريخ الميلاد',
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        birthDate = result;
      });
    }
  }

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  void _setLocalUser({
    required String newName,
    required String newUsername,
    required String newEmail,
    required int newAge,
  }) {
    data.setAuthenticatedUser(
      newName: newName,
      newUsername: newUsername,
      newEmail: newEmail,
      newAge: newAge,
    );
  }

  Future<void> submit() async {
    if (submitting) return;

    final cleanUsername = username.text
        .trim()
        .replaceFirst('@', '')
        .replaceAll(' ', '')
        .toLowerCase();

    final cleanEmail = email.text.trim();
    final cleanName = name.text.trim();
    final cleanPassword = password.text;

    if (register && cleanName.isEmpty) {
      message('اكتب اسمك');
      return;
    }

    if (cleanUsername.length < 4) {
      message('اسم المستخدم يجب أن يحتوي على 4 أحرف على الأقل');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(cleanUsername)) {
      message('استخدم الأحرف الإنجليزية والأرقام و _ و . فقط');
      return;
    }

    if (!cleanEmail.contains('@')) {
      message('أدخل بريدًا إلكترونيًا صحيحًا');
      return;
    }

    if (cleanPassword.length < 6) {
      message('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    if (register && birthDate == null) {
      message('اختر تاريخ الميلاد');
      return;
    }

    final age = register
        ? ageFromBirth(birthDate!)
        : data.age;

    if (register && age < 13) {
      message('يجب أن يكون العمر 13 سنة أو أكثر');
      return;
    }

    setState(() {
      submitting = true;
    });

    try {
      final client = Supabase.instance.client;

      if (register) {
        final response = await client.auth.signUp(
          email: cleanEmail,
          password: cleanPassword,
          data: {
            'name': cleanName,
            'username': cleanUsername,
            'age': age,
          },
        );

        final user = response.user;

        if (user == null) {
          message('تعذر إنشاء الحساب');
          return;
        }

        if (response.session == null) {
          message(
            'تم إنشاء الحساب.\n'
            'تحقق من بريدك الإلكتروني ثم سجّل الدخول.',
          );

          if (mounted) {
            setState(() {
              register = false;
            });
          }

          return;
        }

        _setLocalUser(
          newName: cleanName,
          newUsername: cleanUsername,
          newEmail: cleanEmail,
          newAge: age,
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const NHome(),
          ),
        );

        return;
      }

      final response = await client.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      final user = response.user;

      if (user == null) {
        message('تعذر تسجيل الدخول');
        return;
      }

      final metadata = user.userMetadata ?? <String, dynamic>{};

      final storedName =
          (metadata['name'] as String?)?.trim();

      final storedUsername =
          (metadata['username'] as String?)?.trim();

      final storedAge =
          metadata['age'] is num
              ? (metadata['age'] as num).toInt()
              : data.age;

      _setLocalUser(
        newName: storedName?.isNotEmpty == true
            ? storedName!
            : data.name,
        newUsername: storedUsername?.isNotEmpty == true
            ? storedUsername!
            : cleanUsername,
        newEmail: user.email ?? cleanEmail,
        newAge: storedAge,
      );

      if (!data.loggedIn) {
        message('تعذر تحميل الحساب');
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const NHome(),
        ),
      );
    } on AuthException catch (e) {
      message(e.message);
    } on PostgrestException catch (e) {
      message('خطأ في قاعدة البيانات: ${e.message}');
    } catch (_) {
      message('حدث خطأ أثناء العملية');
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 35),
                  const CircleAvatar(
                    radius: 42,
                    child: Text(
                      'N',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'N',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    register
                        ? 'أنشئ حسابك في N'
                        : 'مرحباً بعودتك إلى N',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (register) ...[
                    TextField(
                      controller: name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'الاسم',
                        prefixIcon: Icon(
                          Icons.person_outline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: username,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      hintText: 'username',
                      prefixIcon: Icon(
                        Icons.alternate_email,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: hidden,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            hidden = !hidden;
                          });
                        },
                        icon: Icon(
                          hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (register) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: chooseBirthDate,
                      icon: const Icon(
                        Icons.cake_outlined,
                      ),
                      label: Text(
                        birthDate == null
                            ? 'اختيار تاريخ الميلاد'
                            : 'تاريخ الميلاد: '
                                '${birthDate!.day}/'
                                '${birthDate!.month}/'
                                '${birthDate!.year}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: submitting ? null : submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      child: submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'متابعة',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () {
                            setState(() {
                              register = !register;
                            });
                          },
                    child: Text(
                      register
                          ? 'لديك حساب بالفعل؟ تسجيل الدخول'
                          : 'ليس لديك حساب؟ إنشاء حساب',
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

class NHome extends StatefulWidget {
  const NHome({super.key});

  @override
  State<NHome> createState() => _NHomeState();
}

class _NHomeState extends State<NHome> {
  int index = 0;

  late final List<Widget> pages = [
    const NVideoFeedPage(),
    const ExplorePage(),
    const CreatePage(),
    const LivePage(),
    const ProfilePage(),
  ];

  void _onNavigationChanged(int value) {
    if (value == 2) {
      setState(() => index = value);
      return;
    }
    setState(() => index = value);
  }

  

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (_, __) {
        return Scaffold(
          backgroundColor: NColors.background,
          body: IndexedStack(index: index, children: pages),
          bottomNavigationBar: NBottomNav(
            index: index,
            onChanged: _onNavigationChanged,
          ),
        );
      },
    );
  }
}

class NVideoFeedPage extends StatefulWidget {
  const NVideoFeedPage({super.key});

  @override
  State<NVideoFeedPage> createState() => _NVideoFeedPageState();
}

class _NVideoFeedPageState extends State<NVideoFeedPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _followingOnly = false;

  @override
  void initState() {
    super.initState();
    unawaited(data.loadPosts());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (context, _) {
        final visible = data.visiblePosts();
        final posts = _followingOnly
            ? visible.where((post) =>
                post.username == data.username ||
                data.following.contains(post.username),
              ).toList()
            : visible;

        if (posts.isEmpty) {
          return const Scaffold(
            backgroundColor: NColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_currentIndex >= posts.length) {
          _currentIndex = posts.length - 1;
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: posts.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final distance = (index - _currentIndex).abs();
                  return ShortVideoCard(
                    key: ValueKey(posts[index].id),
                    post: posts[index],
                    active: index == _currentIndex,
                    preload: distance <= 1,
                  );
                },
              ),
              _NHomeHeader(
                following: _followingOnly,
                onChanged: (value) {
                  if (_followingOnly == value) return;
                  setState(() {
                    _followingOnly = value;
                    _currentIndex = 0;
                  });
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(0);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NHomeHeader extends StatelessWidget {
  const _NHomeHeader({required this.following, required this.onChanged});

  final bool following;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 6,
      left: 12,
      right: 12,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NSearchPage()),
            ),
            tooltip: 'بحث',
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 28),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => onChanged(true),
            child: _NTopTab(label: 'متابعة', active: following),
          ),
          const SizedBox(width: 28),
          GestureDetector(
            onTap: () => onChanged(false),
            child: _NTopTab(label: 'لك', active: !following),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _NTopTab extends StatelessWidget {
  const _NTopTab({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontSize: 16,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 32 : 0,
          height: 2.5,
          decoration: BoxDecoration(
            color: NColors.pink,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}

class ShortVideoCard extends StatefulWidget {
  const ShortVideoCard({
    super.key,
    required this.post,
    required this.active,
    this.preload = false,
  });

  final NPost post;
  final bool active;
  final bool preload;

  @override
  State<ShortVideoCard> createState() => _ShortVideoCardState();
}

class _ShortVideoCardState extends State<ShortVideoCard> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _muted = false;
  bool _preparing = false;

  @override
  void initState() {
    super.initState();
    if (widget.preload) unawaited(_prepare());
  }

  @override
  void didUpdateWidget(covariant ShortVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.videoUrl != widget.post.videoUrl) {
      _disposeController();
      if (widget.preload) unawaited(_prepare());
      return;
    }
    if (!oldWidget.preload && widget.preload) {
      unawaited(_prepare());
    } else if (oldWidget.preload && !widget.preload) {
      _disposeController();
    }
    _syncPlayback();
  }

  Future<void> _prepare() async {
    if (_preparing || _controller != null || !widget.preload) return;
    _preparing = true;
    final url = widget.post.videoUrl?.trim();
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _loading = false);
      _preparing = false;
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await controller.initialize();
      await controller.setLooping(true);
      controller.setVolume(_muted ? 0 : 1);
      _controller = controller;
      unawaited(data.registerView(widget.post));
      if (mounted) {
        setState(() => _loading = false);
        _syncPlayback();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      _preparing = false;
    }
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.active) {
      unawaited(controller.play());
    } else {
      unawaited(controller.pause());
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  Future<void> _comment() async {
    final controller = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF111318),
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 1000,
                    decoration: const InputDecoration(hintText: 'اكتب تعليقك...'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () async {
                    final ok = await data.addComment(widget.post, controller.text);
                    if (!sheetContext.mounted) return;
                    if (ok) Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _share() async {
    final url = widget.post.videoUrl?.trim();
    final text = url == null || url.isEmpty ? 'شاهد هذا المنشور على N' : 'شاهد هذا الفيديو على N\n$url';
    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized == true;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          onDoubleTap: () => unawaited(data.like(widget.post)),
          child: Container(
            color: Colors.black,
            child: initialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  )
                : widget.post.imageUrl?.trim().isNotEmpty == true
                    ? Image.network(widget.post.imageUrl!, fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.play_circle_outline, size: 86, color: Colors.white38)),
          ),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator()),
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, Color(0xD9000000)],
                  stops: [0, .55, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 132,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VideoAction(
                icon: widget.post.liked ? Icons.favorite : Icons.favorite_border,
                value: widget.post.likes,
                active: widget.post.liked,
                onTap: () => unawaited(data.like(widget.post)),
              ),
              _VideoAction(
                icon: Icons.mode_comment_outlined,
                value: widget.post.comments,
                onTap: _comment,
              ),
              _VideoAction(
                icon: widget.post.saved ? Icons.bookmark : Icons.bookmark_border,
                value: null,
                active: widget.post.saved,
                onTap: () => unawaited(data.save(widget.post)),
              ),
              _VideoAction(
                icon: Icons.share_outlined,
                value: null,
                onTap: _share,
              ),
              const SizedBox(height: 6),
              IconButton(
                onPressed: _toggleMute,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 46, height: 46),
                icon: Icon(
                  _muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 29,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 78,
          bottom: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 22, child: Icon(Icons.person)),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      '@${widget.post.username}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (!widget.post.verified && widget.post.username != data.username)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton.tonal(
                        onPressed: () => unawaited(data.follow(widget.post.username)),
                        child: Text(data.following.contains(widget.post.username) ? 'متابَع' : 'متابعة'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (widget.post.text.trim().isNotEmpty)
                Text(widget.post.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.45)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.music_note, size: 15),
                  const SizedBox(width: 5),
                  Expanded(child: Text('الصوت الأصلي • N', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 14,
          child: const Text('N', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _VideoAction extends StatelessWidget {
  const _VideoAction({required this.icon, required this.value, required this.onTap, this.active = false});
  final IconData icon;
  final int? value;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 46, height: 46),
          icon: Icon(
            icon,
            size: 31,
            color: active ? NColors.pink : Colors.white,
          ),
        ),
        if (value != null)
          Text(
            '$value',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        const SizedBox(height: 9),
      ],
    );
  }
}

class NSearchPage extends StatefulWidget {
  const NSearchPage({super.key});

  @override
  State<NSearchPage> createState() => _NSearchPageState();
}

class _NSearchPageState extends State<NSearchPage> {
  final controller = TextEditingController();
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> results = [];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = controller.text.trim().replaceFirst('@', '');
    if (query.isEmpty) {
      setState(() {
        results = [];
        error = null;
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final rows = await data.supabase
          .from('public_profiles')
          .select('id, name, username, avatar_url, verified')
          .or('username.ilike.%$query%,name.ilike.%$query%')
          .limit(30);

      if (!mounted) return;
      setState(() {
        results = rows.map((row) => Map<String, dynamic>.from(row)).toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذر تنفيذ البحث';
        results = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.background,
      appBar: AppBar(
        backgroundColor: NColors.background,
        title: const Text('بحث', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'ابحث عن اسم أو @username',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
          ),
          if (loading)
            const LinearProgressIndicator(minHeight: 2),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!, style: const TextStyle(color: NColors.muted)),
            ),
          Expanded(
            child: results.isEmpty && !loading
                ? const Center(
                    child: Text(
                      'اكتب اسمًا للبحث عن المستخدمين',
                      style: TextStyle(color: NColors.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: NColors.divider,
                    ),
                    itemBuilder: (context, index) {
                      final row = results[index];
                      final name = (row['name'] ?? 'مستخدم N').toString();
                      final username = (row['username'] ?? '').toString();
                      final avatar = (row['avatar_url'] ?? '').toString();
                      final verified = row['verified'] == true;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: NColors.surface,
                          backgroundImage: avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar.isEmpty
                              ? const Icon(Icons.person_rounded)
                              : null,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (verified) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified, size: 16, color: NColors.cyan),
                            ],
                          ],
                        ),
                        subtitle: Text('@$username'),
                        onTap: username.isEmpty
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserProfilePage(
                                      name: name,
                                      username: username,
                                    ),
                                  ),
                                ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final TextEditingController _search = TextEditingController();
  bool _searching = false;
  List<Map<String, dynamic>> _profiles = [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadExplore());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadExplore([String query = '']) async {
    try {
      dynamic request = data.supabase
          .from('public_profiles')
          .select('id, name, username, avatar_url, verified')
          .limit(30);

      if (query.trim().isNotEmpty) {
        final q = query.trim().replaceAll(',', '');
        request = request.or('username.ilike.%$q%,name.ilike.%$q%');
      }

      final rows = await request;
      if (!mounted) return;
      setState(() {
        _profiles = List<Map<String, dynamic>>.from(rows);
      });
    } catch (_) {
      // Keep the local feed available if profiles are unavailable.
    }
  }

  void _onSearchChanged(String value) {
    final active = value.trim().isNotEmpty;
    if (active != _searching) {
      setState(() => _searching = active);
    }
    unawaited(_loadExplore(value));
  }

  void _openProfile(Map<String, dynamic> profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          name: (profile['name'] ?? 'مستخدم N').toString(),
          username: (profile['username'] ?? '').toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.background,
      appBar: AppBar(
        title: const Text('استكشاف', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: false,
      ),
      body: AnimatedBuilder(
        animation: data,
        builder: (context, _) {
          final posts = data.visiblePosts();
          final tags = <String>{};
          for (final post in posts) {
            for (final word in post.text.split(RegExp(r'\s+'))) {
              if (word.startsWith('#') && word.length > 1) tags.add(word);
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              await data.loadPosts();
              await _loadExplore(_search.text);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
              children: [
                TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مستخدم أو فيديو أو وسم',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searching
                        ? IconButton(
                            onPressed: () {
                              _search.clear();
                              _onSearchChanged('');
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 22),
                if (_searching) ...[
                  const Text('الحسابات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (_profiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('لا توجد نتائج')),
                    )
                  else
                    ..._profiles.map(
                      (profile) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => _openProfile(profile),
                          leading: CircleAvatar(
                            backgroundImage: (profile['avatar_url'] as String?)?.isNotEmpty == true
                                ? NetworkImage(profile['avatar_url'] as String)
                                : null,
                            child: (profile['avatar_url'] as String?)?.isNotEmpty == true
                                ? null
                                : const Icon(Icons.person_outline),
                          ),
                          title: Row(
                            children: [
                              Flexible(child: Text((profile['name'] ?? 'مستخدم N').toString())),
                              if (profile['verified'] == true) ...[
                                const SizedBox(width: 5),
                                const Icon(Icons.verified_rounded, size: 17, color: NColors.cyan),
                              ],
                            ],
                          ),
                          subtitle: Text('@${profile['username'] ?? ''}'),
                          trailing: FilledButton(
                            onPressed: () => data.follow((profile['username'] ?? '').toString()),
                            child: Text(
                              data.following.contains((profile['username'] ?? '').toString())
                                  ? 'متابَع'
                                  : 'متابعة',
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const Text('فيديوهات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                ] else ...[
                  const Text('الترند الآن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  if (tags.isNotEmpty)
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: tags.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ActionChip(
                          label: Text(tags.elementAt(i)),
                          onPressed: () {
                            _search.text = tags.elementAt(i);
                            _onSearchChanged(_search.text);
                          },
                        ),
                      ),
                    ),
                  if (tags.isEmpty)
                    const Text('اكتشف أحدث الفيديوهات والحسابات على N', style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 20),
                  const Text('أحدث الفيديوهات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                ],
                if (posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: Text('لا توجد فيديوهات حتى الآن')),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: posts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: .68,
                    ),
                    itemBuilder: (_, index) {
                      final post = posts[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoExploreViewer(posts: posts, initialIndex: index),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (post.imageUrl?.isNotEmpty == true)
                                Image.network(post.imageUrl!, fit: BoxFit.cover)
                              else
                                Container(
                                  color: NColors.surface,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.play_circle_outline_rounded, size: 42),
                                ),
                              Positioned(
                                left: 7,
                                bottom: 7,
                                child: Row(
                                  children: [
                                    const Icon(Icons.favorite_rounded, size: 14),
                                    const SizedBox(width: 3),
                                    Text('${post.likes}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class VideoExploreViewer extends StatefulWidget {
  const VideoExploreViewer({super.key, required this.posts, required this.initialIndex});
  final List<NPost> posts;
  final int initialIndex;

  @override
  State<VideoExploreViewer> createState() => _VideoExploreViewerState();
}

class _VideoExploreViewerState extends State<VideoExploreViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('استكشاف')),
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => ShortVideoCard(post: widget.posts[i], active: i == _index, preload: (i - _index).abs() <= 1),
      ),
    );
  }
}

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final ImagePicker _picker = ImagePicker();
  final caption = TextEditingController();
  XFile? selectedVideo;
  XFile? selectedCover;
  bool adult = false;
  bool publishing = false;
  String visibility = 'عام';

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  Future<void> _pickVideo({required bool camera}) async {
    final file = await _picker.pickVideo(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (!mounted || file == null) return;
    setState(() {
      selectedVideo = file;
      selectedCover = null;
    });
  }

  Future<void> _pickCover() async {
    if (selectedVideo == null) return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1440,
    );
    if (!mounted || file == null) return;
    setState(() => selectedCover = file);
  }

  Future<void> publish() async {
    if (publishing) return;
    if (selectedVideo == null) {
      _message('اختر فيديو أولاً');
      return;
    }
    if (adult && !data.adultAllowed) {
      _message('محتوى +21 غير متاح لهذا الحساب');
      return;
    }

    final text = caption.text.trim();
    if (text.length > 2200) {
      _message('الوصف طويل جدًا');
      return;
    }

    setState(() => publishing = true);
    try {
      final videoUrl = await data.uploadVideo(File(selectedVideo!.path));
      if (!mounted) return;
      if (videoUrl == null) {
        _message(data.errorMessage ?? 'تعذر رفع الفيديو');
        return;
      }

      String? coverUrl;
      if (selectedCover != null) {
        coverUrl = await data.uploadImage(File(selectedCover!.path));
        if (!mounted) return;
        if (coverUrl == null) {
          _message(data.errorMessage ?? 'تعذر رفع الغلاف');
          return;
        }
      }

      final ok = await data.createPost(
        text,
        adult: adult,
        visibility: visibility,
        video: true,
        videoUrl: videoUrl,
        imageUrl: coverUrl,
      );
      if (!mounted) return;
      if (!ok) {
        _message(data.errorMessage ?? 'تعذر نشر الفيديو');
        return;
      }

      caption.clear();
      setState(() {
        selectedVideo = null;
        selectedCover = null;
        adult = false;
        visibility = 'عام';
      });
      _message('تم نشر الفيديو بنجاح');
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.background,
      appBar: AppBar(
        title: const Text('إنشاء فيديو'),
        actions: [
          TextButton(
            onPressed: publishing ? null : publish,
            child: Text(
              'نشر',
              style: TextStyle(
                color: publishing ? Colors.white38 : NColors.cyan,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: _CreateAction(
                  icon: Icons.video_library_outlined,
                  label: 'من المعرض',
                  onTap: publishing ? null : () => _pickVideo(camera: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CreateAction(
                  icon: Icons.camera_alt_outlined,
                  label: 'تصوير',
                  outlined: true,
                  onTap: publishing ? null : () => _pickVideo(camera: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: selectedVideo == null
                ? _EmptyVideoPicker(key: const ValueKey('empty'))
                : _SelectedVideo(
                    key: const ValueKey('selected'),
                    file: File(selectedVideo!.path),
                    onRemove: publishing
                        ? null
                        : () => setState(() {
                              selectedVideo = null;
                              selectedCover = null;
                            }),
                  ),
          ),
          if (selectedVideo != null) ...[
            const SizedBox(height: 12),
            _CoverPicker(
              cover: selectedCover,
              onTap: publishing ? null : _pickCover,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: caption,
            maxLength: 2200,
            maxLines: 5,
            enabled: !publishing,
            decoration: const InputDecoration(
              hintText: 'اكتب وصف الفيديو والوسوم...',
              prefixIcon: Icon(Icons.edit_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: visibility,
            decoration: const InputDecoration(
              labelText: 'من يمكنه مشاهدة الفيديو؟',
              prefixIcon: Icon(Icons.visibility_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'عام', child: Text('الجميع')),
              DropdownMenuItem(value: 'المتابعون', child: Text('المتابعون')),
              DropdownMenuItem(value: 'خاص', child: Text('أنا فقط')),
            ],
            onChanged: publishing
                ? null
                : (value) => setState(() => visibility = value ?? 'عام'),
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: adult,
            onChanged: publishing ? null : (value) => setState(() => adult = value),
            title: const Text('محتوى +21'),
            subtitle: const Text('يتم تطبيق قيود العمر من الخادم أيضًا'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: publishing ? null : publish,
              icon: publishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_outlined),
              label: Text(publishing ? 'جارٍ الرفع والنشر...' : 'نشر الفيديو على N'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateAction extends StatelessWidget {
  const _CreateAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
            )
          : FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class _EmptyVideoPicker extends StatelessWidget {
  const _EmptyVideoPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: NColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_call_outlined, size: 58, color: Colors.white54),
            SizedBox(height: 14),
            Text('اختر فيديو لبدء النشر'),
            SizedBox(height: 6),
            Text(
              'حتى 5 دقائق • عمودي 9:16 يفضل',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedVideo extends StatelessWidget {
  const _SelectedVideo({super.key, required this.file, required this.onRemove});

  final File file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 390,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayerPreview(file: file),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton.filled(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ),
          const Positioned(
            bottom: 12,
            left: 12,
            child: _PreviewBadge(),
          ),
        ],
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text('معاينة', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({required this.cover, required this.onTap});

  final XFile? cover;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 82,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: NColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: cover == null
                  ? Container(
                      width: 66,
                      height: 66,
                      color: Colors.white.withValues(alpha: .06),
                      child: const Icon(Icons.image_outlined, color: Colors.white54),
                    )
                  : Image.file(
                      File(cover!.path),
                      width: 66,
                      height: 66,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('غلاف الفيديو', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text(
                    'اختر صورة مميزة تظهر في الملف الشخصي والاستكشاف',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerPreview extends StatefulWidget {
  const VideoPlayerPreview({super.key, required this.file});
  final File file;

  @override
  State<VideoPlayerPreview> createState() => _VideoPlayerPreviewState();
}

class _VideoPlayerPreviewState extends State<VideoPlayerPreview> {
  VideoPlayerController? controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final value = VideoPlayerController.file(widget.file);
    await value.initialize();
    await value.setLooping(true);
    await value.play();
    if (!mounted) {
      await value.dispose();
      return;
    }
    setState(() => controller = value);
  }

  @override
  void dispose() {
    final value = controller;
    if (value != null) unawaited(value.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = controller;
    if (value == null || !value.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: value.value.size.width,
        height: value.value.size.height,
        child: VideoPlayer(value),
      ),
    );
  }
}

class LivePage extends StatelessWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final live = data.posts.where((p) => p.videoUrl != null).take(8).toList();
    return Scaffold(
      backgroundColor: NColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: const [
            NLogo(size: 34),
            SizedBox(width: 10),
            Text('البث المباشر'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'ابدأ بثًا',
            onPressed: () => _showComingSoon(context, 'إنشاء غرفة بث مباشرة'),
            icon: const Icon(Icons.videocam_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => data.loadPosts(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF161A25), Color(0xFF0D1018)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NColors.pink.withValues(alpha: .16),
                      border: Border.all(color: NColors.pink),
                    ),
                    child: const Icon(Icons.live_tv, color: NColors.pink),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('اكتشف البث المباشر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        SizedBox(height: 5),
                        Text('تابع المبدعين وتفاعل معهم لحظة بلحظة', style: TextStyle(color: NColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('مباشر الآن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (live.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
                decoration: BoxDecoration(
                  color: NColors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.podcasts_outlined, size: 52, color: NColors.muted),
                    SizedBox(height: 12),
                    Text('لا توجد بثوث مباشرة الآن'),
                    SizedBox(height: 6),
                    Text('كن أول من يبدأ بثًا على N', style: TextStyle(color: NColors.muted)),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: live.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .72,
                ),
                itemBuilder: (_, i) {
                  final post = live[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: NColors.surface),
                        if (post.imageUrl != null)
                          Image.network(post.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC000000)]),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(color: NColors.pink, borderRadius: BorderRadius.circular(10)),
                            child: const Text('LIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Text('غرفة N المباشرة', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _LiveAction(title: 'الهدايا', icon: Icons.card_giftcard_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NWalletPage())))),
                const SizedBox(width: 10),
                Expanded(child: _LiveAction(title: 'العملات', icon: Icons.monetization_on_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NWalletPage())))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _showComingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name قيد الربط بالخادم')));
  }
}

class _LiveAction extends StatelessWidget {
  const _LiveAction({required this.title, required this.icon, required this.onTap});
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: NColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
      child: Row(children: [Icon(icon, color: NColors.cyan), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w800))]),
    ),
  );
}


class NWalletPage extends StatefulWidget {
  const NWalletPage({super.key});

  @override
  State<NWalletPage> createState() => _NWalletPageState();
}

class _NWalletPageState extends State<NWalletPage> {
  bool busy = false;
  final recipient = TextEditingController();

  @override
  void dispose() {
    recipient.dispose();
    super.dispose();
  }

  Future<void> _sendGift(String giftId, int price, String name, String icon) async {
    if (recipient.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسم المستخدم أولاً')));
      return;
    }
    setState(() => busy = true);
    final ok = await data.sendGift(recipientUsername: recipient.text, giftId: giftId);
    if (!mounted) return;
    setState(() => busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'تم إرسال $icon $name — الرصيد ${data.coins}' : (data.errorMessage ?? 'تعذر إرسال الهدية'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (_, __) => Scaffold(
        backgroundColor: NColors.background,
        appBar: AppBar(title: const Text('المحفظة والمتجر')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF161A25), Color(0xFF10131B)]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: NColors.cyan.withValues(alpha: .25)),
              ),
              child: Column(children: [
                const Text('رصيد N', style: TextStyle(color: NColors.muted)),
                const SizedBox(height: 8),
                Text('${data.coins}', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('عملة', style: TextStyle(color: NColors.cyan, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 24),
            const Text('المتجر', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'شراء العملات سيُفعّل عبر بوابة دفع موثوقة قبل الإصدار التجاري. لا يتم إنشاء عملات مجانية من تطبيق المستخدم.',
              style: TextStyle(color: NColors.muted),
            ),
            const SizedBox(height: 14),
            for (final pack in const [(100, '100 عملة'), (500, '500 عملة'), (1200, '1200 عملة'), (3000, '3000 عملة')])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WalletTile(
                  icon: Icons.monetization_on_outlined,
                  title: pack.$2,
                  trailing: 'قريباً',
                  onTap: null,
                ),
              ),
            const SizedBox(height: 20),
            const Text('إرسال هدية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            TextField(
              controller: recipient,
              decoration: InputDecoration(
                hintText: '@اسم_المستخدم',
                prefixIcon: const Icon(Icons.person_outline),
                filled: true,
                fillColor: NColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _GiftChip(id: 'rose', name: 'وردة', icon: '🌹', price: 5),
                _GiftChip(id: 'heart', name: 'قلب', icon: '❤️', price: 20),
                _GiftChip(id: 'star', name: 'نجمة', icon: '⭐', price: 50),
                _GiftChip(id: 'diamond', name: 'ألماسة', icon: '💎', price: 100),
                _GiftChip(id: 'crown', name: 'تاج N', icon: '👑', price: 500),
              ],
            ),
            const SizedBox(height: 20),
            if (busy) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({required this.icon, required this.title, required this.trailing, required this.onTap});
  final IconData icon;
  final String title;
  final String trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: NColors.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(icon, color: NColors.cyan),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
          Text(trailing, style: const TextStyle(color: NColors.pink, fontWeight: FontWeight.w900)),
        ]),
      ),
    ),
  );
}

class _GiftChip extends StatelessWidget {
  const _GiftChip({required this.id, required this.name, required this.icon, required this.price});
  final String id;
  final String name;
  final String icon;
  final int price;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () {
      final state = context.findAncestorStateOfType<_NWalletPageState>();
      state?._sendGift(id, price, name, icon);
    },
    borderRadius: BorderRadius.circular(18),
    child: Container(
      width: 112,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: NColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
      child: Column(children: [Text(icon, style: const TextStyle(fontSize: 30)), const SizedBox(height: 5), Text(name, style: const TextStyle(fontWeight: FontWeight.w800)), Text('$price N', style: const TextStyle(color: NColors.cyan, fontWeight: FontWeight.w700))]),
    ),
  );
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الرسائل',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: data,
        builder: (_, __) {
          final conversations = data.messages.entries.toList();

          if (conversations.isEmpty) {
            return const Center(
              child: Text('لا توجد محادثات'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: conversations.map(
              (entry) {
                final last = entry.value.isEmpty
                    ? null
                    : entry.value.last;

                final displayName =
                    _displayName(entry.key);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(displayName),
                    subtitle: Text(
                      last?.text ?? 'لا توجد رسائل',
                    ),
                    trailing: const Icon(
                      Icons.chevron_left,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            name: displayName,
                            username: entry.key,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ).toList(),
          );
        },
      ),
    );
  }

  String _displayName(String username) {
    return '@$username';
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.name,
    required this.username,
  });

  final String name;
  final String username;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = controller.text.trim();

    if (text.isEmpty) return;

    try {
      await data.sendMessage(
        widget.username,
        text,
      );

      controller.clear();

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إرسال الرسالة'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              child: Icon(Icons.person),
            ),
            const SizedBox(width: 10),
            Text(widget.name),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: data,
              builder: (_, __) {
                final current =
                    data.messages[widget.username] ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: current.length,
                  itemBuilder: (_, i) {
                    final currentMessage = current[i];

                    final mine =
                        currentMessage.sender == data.username;

                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(
                          bottom: 8,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(0xFF006D91)
                              : const Color(0xFF1B1E27),
                          borderRadius:
                              BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(currentMessage.text),
                            const SizedBox(height: 3),
                            Text(
                              currentMessage.time,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textInputAction:
                          TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: send,
                    icon: const Icon(Icons.send),
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int tab = 0;
  int followers = 0;
  bool loadingFollowers = true;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    final count = await data.followerCount(data.username);
    if (!mounted) return;
    setState(() { followers = count; loadingFollowers = false; });
  }

  Future<void> _openEditProfile(BuildContext context) async {
    final name = TextEditingController(text: data.name);
    final username = TextEditingController(text: data.username);
    final bio = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NColors.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          MediaQuery.of(sheetContext).viewInsets.bottom + 18,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تعديل الملف الشخصي',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم'),
                validator: (v) =>
                    v!.trim().isEmpty ? 'اكتب الاسم' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: username,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  prefixText: '@',
                ),
                validator: (v) =>
                    v!.trim().isEmpty ? 'اكتب اسم المستخدم' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: bio,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'النبذة'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await data.updateProfile(
                      name: name.text.trim(),
                      username: username.text.trim(),
                      bio: bio.text.trim(),
                    );
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                  } catch (_) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text('تعذر حفظ الملف الشخصي'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('حفظ التغييرات'),
              ),
            ],
          ),
        ),
      ),
    );

    name.dispose();
    username.dispose();
    bio.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (_, __) {
        final myPosts = data.postsOf(data.username);
        final likedPosts = data.posts.where((post) => post.liked).toList();
        final visiblePosts = tab == 1 ? likedPosts : tab == 2 ? <NPost>[] : myPosts;

        return Scaffold(
          backgroundColor: NColors.background,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: NColors.background.withValues(alpha: .96),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('@${data.username}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (data.badges.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: NColors.cyan, size: 17),
                    ],
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'الإشعارات',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NInboxPage(initialTab: 1),
                      ),
                    ),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                  IconButton(
                    tooltip: 'مساعد N الذكي',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NAssistantPage())),
                    icon: const Icon(Icons.auto_awesome_rounded),
                  ),
                  IconButton(
                    tooltip: 'الأمان والخصوصية',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NSecurityPage(data: data),
                      ),
                    ),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  IconButton(
                    tooltip: 'تسجيل الخروج',
                    onPressed: () async {
                      await data.logout();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (_) => false,
                      );
                    },
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: NColors.actionGradient,
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: NColors.surface,
                              backgroundImage: data.avatarUrl?.isNotEmpty == true
                                  ? NetworkImage(data.avatarUrl!)
                                  : null,
                              child: data.avatarUrl?.isNotEmpty == true
                                  ? null
                                  : const Icon(Icons.person_rounded, size: 48, color: NColors.muted),
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: NColors.pink,
                              shape: BoxShape.circle,
                              border: Border.all(color: NColors.background, width: 3),
                            ),
                            child: const Icon(Icons.add, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(data.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                          if (data.badges.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: NColors.cyan, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('@${data.username}', style: const TextStyle(color: NColors.muted)),
                      if (data.email.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(data.email, style: const TextStyle(color: NColors.muted, fontSize: 12)),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ProfileStat(value: '${myPosts.length}', label: 'فيديو'),
                          _ProfileStat(value: loadingFollowers ? '—' : '$followers', label: 'المتابعون'),
                          _ProfileStat(value: '${data.following.length}', label: 'يتابع'),
                          _ProfileStat(value: '${data.coins}', label: 'N'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openEditProfile(context),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('تعديل الملف الشخصي'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: NColors.white,
                                side: const BorderSide(color: NColors.divider),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () => Share.share('تابع @${data.username} على N'),
                            style: IconButton.styleFrom(
                              backgroundColor: NColors.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.share_outlined),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _ProfileTabsDelegate(activeIndex: tab, onChanged: (value) {
                  setState(() => tab = value);
                }),
              ),
              if (visiblePosts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      tab == 1 ? 'لا توجد فيديوهات أعجبت بها' : tab == 2 ? 'الفيديوهات الخاصة ستظهر هنا' : 'لم تنشر أي فيديو بعد',
                      style: const TextStyle(color: NColors.muted),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(3),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ProfileVideoTile(post: visiblePosts[index]),
                      childCount: visiblePosts.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                      childAspectRatio: .72,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

}

class _ProfileTabsDelegate extends SliverPersistentHeaderDelegate {
  _ProfileTabsDelegate({required this.activeIndex, required this.onChanged});

  final int activeIndex;
  final ValueChanged<int> onChanged;
  @override
  double get minExtent => 50;

  @override
  double get maxExtent => 50;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    const tabs = [
      (Icons.grid_on_rounded, 'الفيديوهات'),
      (Icons.favorite_border_rounded, 'الإعجابات'),
      (Icons.lock_outline_rounded, 'خاص'),
    ];
    return Container(
      color: NColors.background,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: _ProfileTab(icon: tabs[i].$1, active: activeIndex == i, label: tabs[i].$2),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.icon, required this.label, this.active = false});

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: active ? NColors.pink : NColors.divider, width: active ? 2 : 1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: active ? NColors.white : NColors.muted),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: active ? NColors.white : NColors.muted)),
        ],
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});

  final NPost post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.background,
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ShortVideoCard(
                post: post,
                active: true,
                preload: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileVideoTile extends StatelessWidget {
  const _ProfileVideoTile({required this.post});

  final NPost post;

  @override
  Widget build(BuildContext context) {
    final image = post.imageUrl ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostCard(post: post))),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image.isNotEmpty)
            Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: NColors.surface, child: Icon(Icons.image_not_supported_outlined)))
          else
            const ColoredBox(color: NColors.surface, child: Center(child: Icon(Icons.play_circle_outline_rounded, size: 38, color: NColors.muted))),
          if (post.video)
            const Positioned(top: 7, left: 7, child: Icon(Icons.play_arrow_rounded, size: 18)),
          Positioned(
            bottom: 6,
            right: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 14),
                const SizedBox(width: 2),
                Text('${post.likes}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: NColors.muted, fontSize: 12)),
      ],
    );
  }
}

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({
    super.key,
    required this.name,
    required this.username,
  });

  final String name;
  final String username;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (_, __) {
        final userPosts = data.postsOf(username);
        final isFollowing =
            data.following.contains(username);

        return Scaffold(
          appBar: AppBar(
            title: Text('@$username'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 10),
              const Center(
                child: CircleAvatar(
                  radius: 48,
                  child: Icon(
                    Icons.person,
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '@$username',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  data.follow(username);
                },
                child: Text(
                  isFollowing
                      ? 'إلغاء المتابعة'
                      : 'متابعة',
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'المنشورات',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (userPosts.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'لا توجد منشورات',
                    ),
                  ),
                )
              else
                ...userPosts.map(
                  (post) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: PostCard(
                      post: post,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.favorite),
            ),
            title: Text('إعجاب جديد'),
            subtitle: Text(
              'أعجب شخص بمنشورك',
            ),
          ),
          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.person_add),
            ),
            title: Text('متابع جديد'),
            subtitle: Text(
              'بدأ شخص بمتابعتك',
            ),
          ),
          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.comment),
            ),
            title: Text('تعليق جديد'),
            subtitle: Text(
              'تمت إضافة تعليق على منشورك',
            ),
          ),
        ],
      ),
    );
  }
}


class NAssistantPage extends StatefulWidget {
  const NAssistantPage({super.key});
  @override State<NAssistantPage> createState() => _NAssistantPageState();
}

class _NAssistantPageState extends State<NAssistantPage> {
  final input = TextEditingController();
  final messages = <Map<String,String>>[];
  bool busy = false;
  @override void dispose() { input.dispose(); super.dispose(); }
  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    setState(() { messages.add({'role':'user','text':text}); input.clear(); busy=true; });
    try {
      final result = await Supabase.instance.client.functions.invoke('n-ai-assistant', body: {'message': text});
      final data = Map<String,dynamic>.from(result.data as Map);
      setState(() => messages.add({'role':'assistant','text':(data['answer'] ?? 'تعذر الحصول على رد').toString()}));
    } catch (_) {
      setState(() => messages.add({'role':'assistant','text':'مساعد N غير مفعّل على الخادم بعد.'}));
    } finally { if (mounted) setState(() => busy=false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: NColors.background,
    appBar: AppBar(title: const Text('مساعد N الذكي')),
    body: Column(children:[
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: messages.length, itemBuilder: (_,i){ final m=messages[i]; return Align(alignment:m['role']=='user'?Alignment.centerRight:Alignment.centerLeft, child: Container(margin:const EdgeInsets.only(bottom:10), padding:const EdgeInsets.all(14), constraints:const BoxConstraints(maxWidth:340), decoration:BoxDecoration(color:m['role']=='user'?NColors.pink:NColors.surface, borderRadius:BorderRadius.circular(16)), child:Text(m['text']??''))); })),
      SafeArea(child: Padding(padding:const EdgeInsets.all(12), child: Row(children:[Expanded(child:TextField(controller:input,onSubmitted:(_)=>send(),decoration:const InputDecoration(hintText:'اكتب رسالتك إلى مساعد N'))), const SizedBox(width:8), IconButton(onPressed:busy?null:send, icon:const Icon(Icons.send_rounded))]))),
    ]),
  );
}
