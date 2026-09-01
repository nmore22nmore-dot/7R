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
        final posts = data.visiblePosts();

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
                onPageChanged: (index) =>
                    setState(() => _currentIndex = index),
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
              const _NHomeHeader(),
            ],
          ),
        );
      },
    );
  }
}

class _NHomeHeader extends StatelessWidget {
  const _NHomeHeader();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Positioned(
      top: top + 6,
      left: 12,
      right: 12,
      child: Row(
        children: [
          const NLogo(size: 34),
          const SizedBox(width: 18),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 29,
            ),
            tooltip: 'بحث',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const NInboxPage(initialTab: 0),
              ),
            ),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 27,
            ),
            tooltip: 'التواصل',
          ),
          const Spacer(),
          _NTopTab(
            label: 'متابعة',
            active: false,
          ),
          const SizedBox(width: 24),
          _NTopTab(
            label: 'لك',
            active: true,
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white12,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on_outlined,
                  color: Color(0xFFFFC928),
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '${data.coins}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NTopTab extends StatelessWidget {
  const _NTopTab({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.white70,
          fontSize: 15,
          fontWeight:
              active ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
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

class _ShortVideoCardState extends State<ShortVideoCard>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  bool _muted = true;
  bool _liked = false;
  bool _saved = false;
  bool _loadingAction = false;

  int _likes = 0;
  int _comments = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _likes = widget.post.likes;
    _comments = widget.post.comments;
    _liked = data.isPostLiked(widget.post.id);
    _saved = data.isPostSaved(widget.post.id);

    if (widget.active || widget.preload) {
      _prepareVideo();
    }
  }

  @override
  void didUpdateWidget(covariant ShortVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post.id != widget.post.id) {
      _disposeController();

      _likes = widget.post.likes;
      _comments = widget.post.comments;
      _liked = data.isPostLiked(widget.post.id);
      _saved = data.isPostSaved(widget.post.id);
    }

    if (widget.active || widget.preload) {
      _prepareVideo();
    }

    if (widget.active) {
      _controller?.play();
    } else {
      _controller?.pause();
    }
  }

  Future<void> _prepareVideo() async {
    if (_controller != null ||
        _initializeFuture != null ||
        widget.post.videoUrl.trim().isEmpty) {
      return;
    }

    final url = widget.post.videoUrl.trim();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
    );

    _controller = controller;

    _initializeFuture = controller.initialize().then((_) {
      controller
        ..setLooping(true)
        ..setVolume(_muted ? 0 : 1);

      if (widget.active) {
        controller.play();
      }

      if (mounted) {
        setState(() {});
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {});
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  void _disposeController() {
    final controller = _controller;

    _controller = null;
    _initializeFuture = null;

    if (controller != null) {
      unawaited(controller.dispose());
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (_controller == null) return;

    if (state == AppLifecycleState.resumed) {
      if (widget.active) {
        _controller!.play();
      }
    } else {
      _controller!.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_loadingAction) return;

    setState(() {
      _loadingAction = true;
    });

    try {
      final liked = await data.toggleLike(widget.post.id);

      if (!mounted) return;

      setState(() {
        _liked = liked;
        _likes = liked
            ? _likes + 1
            : (_likes > 0 ? _likes - 1 : 0);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAction = false;
        });
      }
    }
  }

  Future<void> _toggleSave() async {
    if (_loadingAction) return;

    setState(() {
      _loadingAction = true;
    });

    try {
      final saved = await data.toggleSave(widget.post.id);

      if (!mounted) return;

      setState(() {
        _saved = saved;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAction = false;
        });
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller?.setVolume(_muted ? 0 : 1);
    });
  }

  Future<void> _share() async {
    final url = widget.post.videoUrl.trim();

    final text = url.isEmpty
        ? 'شاهد هذا المنشور على N'
        : 'شاهد هذا الفيديو على N\n$url';

    await Share.share(text);
  }

  Future<void> _openComments() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NColors.surface,
      builder: (_) => CommentsSheet(
        post: widget.post,
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _comments = data.commentsFor(widget.post.id).length;
      });
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfilePage(
          username: widget.post.username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _toggleLike,
      onTap: _toggleMute,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
            child: _buildVideo(controller),
          ),
          _buildGradient(),
          _buildTopControls(),
          _buildRightActions(),
          _buildBottomInfo(),
          if (_loadingAction)
            const Positioned(
              top: 110,
              right: 20,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideo(
    VideoPlayerController? controller,
  ) {
    if (controller == null) {
      return _buildCover();
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return _buildCover();
        }

        if (!controller.value.isInitialized) {
          return _buildCover();
        }

        return Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }

  Widget _buildCover() {
    final cover = widget.post.coverUrl.trim();

    if (cover.isEmpty) {
      return const Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 64,
          color: Colors.white54,
        ),
      );
    }

    return Image.network(
      cover,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 50,
            color: Colors.white54,
          ),
        );
      },
      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }

        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        );
      },
    );
  }

  Widget _buildGradient() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(.20),
              Colors.transparent,
              Colors.black.withOpacity(.72),
            ],
            stops: const [
              0,
              .42,
              1,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 12,
      right: 12,
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleMute,
            icon: Icon(
              _muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (widget.post.isAdult)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '+21',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRightActions() {
    return Positioned(
      right: 10,
      bottom: 130,
      child: Column(
        children: [
          _VideoAction(
            icon: _liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: '$_likes',
            active: _liked,
            onTap: _toggleLike,
          ),
          const SizedBox(height: 18),
          _VideoAction(
            icon: Icons.mode_comment_outlined,
            label: '$_comments',
            onTap: _openComments,
          ),
          const SizedBox(height: 18),
          _VideoAction(
            icon: _saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            label: _saved ? 'محفوظ' : 'حفظ',
            active: _saved,
            onTap: _toggleSave,
          ),
          const SizedBox(height: 18),
          _VideoAction(
            icon: Icons.share_outlined,
            label: 'مشاركة',
            onTap: _share,
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _openProfile,
            child: CircleAvatar(
              radius: 23,
              backgroundColor: Colors.white24,
              backgroundImage:
                  widget.post.avatarUrl.trim().isNotEmpty
                      ? NetworkImage(
                          widget.post.avatarUrl,
                        )
                      : null,
              child: widget.post.avatarUrl.trim().isEmpty
                  ? const Icon(
                      Icons.person,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Positioned(
      left: 16,
      right: 75,
      bottom: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _openProfile,
            child: Row(
              children: [
                Text(
                  '@${widget.post.username}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                if (widget.post.verified) ...[
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.verified_rounded,
                    size: 17,
                  ),
                ],
              ],
            ),
          ),
          if (widget.post.caption.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.post.caption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ],
          if (widget.post.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.post.tags
                  .map((e) => '#$e')
                  .join(' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoAction extends StatelessWidget {
  const _VideoAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active
                  ? Colors.pinkAccent
                  : Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.post,
  });

  final NPost post;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final controller = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = controller.text.trim();

    if (text.isEmpty || sending) return;

    setState(() {
      sending = true;
    });

    try {
      await data.addComment(
        widget.post.id,
        text,
      );

      controller.clear();

      if (mounted) {
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = data.commentsFor(
      widget.post.id,
    );

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .72,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'التعليقات (${comments.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const Divider(),
            Expanded(
              child: comments.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد تعليقات بعد',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: comments.length,
                      itemBuilder: (_, index) {
                        final comment = comments[index];

                        return ListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage:
                                comment.avatarUrl
                                        .trim()
                                        .isNotEmpty
                                    ? NetworkImage(
                                        comment.avatarUrl,
                                      )
                                    : null,
                            child: comment.avatarUrl
                                    .trim()
                                    .isEmpty
                                ? const Icon(
                                    Icons.person,
                                  )
                                : null,
                          ),
                          title: Text(
                            '@${comment.username}',
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            comment.text,
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom:
                    MediaQuery.of(context)
                        .viewInsets
                        .bottom +
                    8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction:
                          TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration:
                          const InputDecoration(
                        hintText: 'اكتب تعليقًا...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: sending ? null : send,
                    icon: sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );class _CreatePage extends StatefulWidget {
  const _CreatePage();

  @override
  State<_CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<_CreatePage> {
  final captionController = TextEditingController();
  final tagsController = TextEditingController();

  XFile? selectedVideo;
  XFile? selectedCover;

  bool isAdult = false;
  bool uploading = false;

  @override
  void dispose() {
    captionController.dispose();
    tagsController.dispose();
    super.dispose();
  }

  Future<void> pickVideo() async {
    final picker = ImagePicker();

    final file = await picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (file == null || !mounted) return;

    setState(() {
      selectedVideo = file;
    });
  }

  Future<void> pickCover() async {
    final picker = ImagePicker();

    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (file == null || !mounted) return;

    setState(() {
      selectedCover = file;
    });
  }

  Future<void> publish() async {
    if (uploading) return;

    if (selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر فيديو أولاً'),
        ),
      );
      return;
    }

    setState(() {
      uploading = true;
    });

    try {
      final caption = captionController.text.trim();

      final tags = tagsController.text
          .split(RegExp(r'[\s,]+'))
          .map((e) => e.replaceFirst('#', '').trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await data.createPost(
        videoFile: selectedVideo!,
        coverFile: selectedCover,
        caption: caption,
        tags: tags,
        isAdult: isAdult,
      );

      if (!mounted) return;

      captionController.clear();
      tagsController.clear();

      setState(() {
        selectedVideo = null;
        selectedCover = null;
        isAdult = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر الفيديو بنجاح'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر نشر الفيديو: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء منشور'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _UploadPreview(
            video: selectedVideo,
            cover: selectedCover,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : pickVideo,
                  icon: const Icon(
                    Icons.video_library_outlined,
                  ),
                  label: const Text('اختيار فيديو'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : pickCover,
                  icon: const Icon(
                    Icons.image_outlined,
                  ),
                  label: const Text('اختيار غلاف'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: captionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'الوصف',
              hintText: 'اكتب وصف الفيديو...',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: tagsController,
            decoration: const InputDecoration(
              labelText: 'الوسوم',
              hintText: '#رياضة #ترفيه',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isAdult,
            onChanged: uploading
                ? null
                : (value) {
                    setState(() {
                      isAdult = value;
                    });
                  },
            title: const Text(
              'محتوى +21',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'ضع علامة +21 إذا كان المحتوى للبالغين',
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: uploading ? null : publish,
              child: uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'نشر الفيديو',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadPreview extends StatelessWidget {
  const _UploadPreview({
    required this.video,
    required this.cover,
  });

  final XFile? video;
  final XFile? cover;

  @override
  Widget build(BuildContext context) {
    if (video == null && cover == null) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: NColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_collection_outlined,
                size: 56,
              ),
              SizedBox(height: 10),
              Text('اختر فيديو للبدء'),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: NColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: cover != null
          ? Image.file(
              File(cover!.path),
              fit: BoxFit.cover,
            )
          : const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 64,
              ),
            ),
    );
  }
}

class _ProfileVideoTile extends StatelessWidget {
  const _ProfileVideoTile({
    required this.post,
  });

  final NPost post;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: NColors.background,
              body: SafeArea(
                child: ShortVideoCard(
                  post: post,
                  active: true,
                  preload: true,
                ),
              ),
            ),
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (post.coverUrl.trim().isNotEmpty)
                Image.network(
                  post.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const ColoredBox(
                      color: Colors.black26,
                      child: Icon(
                        Icons.video_library_outlined,
                        color: Colors.white,
                        size: 34,
                      ),
                    );
                  },
                )
              else
                const ColoredBox(
                  color: Colors.black26,
                  child: Icon(
                    Icons.video_library_outlined,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              const Positioned(
                right: 7,
                bottom: 7,
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              if (post.isAdult)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '+21',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.username,
  });

  final String username;

  @override
  State<UserProfilePage> createState() =>
      _UserProfilePageState();
}

class _UserProfilePageState
    extends State<UserProfilePage> {
  bool loading = true;
  bool following = false;

  NProfile? profile;
  List<NPost> posts = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
    });

    try {
      profile = await data.publicProfile(
        widget.username,
      );

      posts = await data.postsForUser(
        widget.username,
      );

      following = data.isFollowing(
        widget.username,
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> toggleFollow() async {
    final result = await data.toggleFollow(
      widget.username,
    );

    if (!mounted) return;

    setState(() {
      following = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('المستخدم غير موجود'),
        ),
      );
    }

    final p = profile!;

    return Scaffold(
      appBar: AppBar(
        title: Text('@${p.username}'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundImage:
                    p.avatarUrl.trim().isNotEmpty
                        ? NetworkImage(p.avatarUrl)
                        : null,
                child: p.avatarUrl.trim().isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 42,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '@${p.username}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (p.bio.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  p.bio,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                _ProfileStat(
                  value: '${p.followers}',
                  label: 'متابعون',
                ),
                _ProfileStat(
                  value: '${p.following}',
                  label: 'يتابع',
                ),
                _ProfileStat(
                  value: '${posts.length}',
                  label: 'منشورات',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (p.username != data.currentUsername)
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: toggleFollow,
                  child: Text(
                    following ? 'إلغاء المتابعة' : 'متابعة',
                  ),
                ),
              ),
            const SizedBox(height: 22),
            if (posts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    'لا توجد منشورات',
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                  childAspectRatio: .68,
                ),
                itemCount: posts.length,
                itemBuilder: (_, index) {
                  return _ProfileVideoTile(
                    post: posts[index],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
  }
}      }
      
      String? coverUrl;

      if (selectedCover != null) {
        final bytes = await selectedCover!.readAsBytes();
        final path =
            '${data.currentUserId}/covers/${DateTime.now().millisecondsSinceEpoch}.jpg';

        await data.uploadBytes(
          bucket: 'media',
          path: path,
          bytes: bytes,
          contentType: 'image/jpeg',
        );

        coverUrl = data.publicStorageUrl(
          bucket: 'media',
          path: path,
        );
      }

      final videoBytes = await selectedVideo!.readAsBytes();
      final videoPath =
          '${data.currentUserId}/videos/${DateTime.now().millisecondsSinceEpoch}.mp4';

      await data.uploadBytes(
        bucket: 'media',
        path: videoPath,
        bytes: videoBytes,
        contentType: 'video/mp4',
      );

      final videoUrl = data.publicStorageUrl(
        bucket: 'media',
        path: videoPath,
      );

      await data.createPostRecord(
        videoUrl: videoUrl,
        coverUrl: coverUrl,
        caption: caption,
        tags: tags,
        isAdult: isAdult,
      );

      if (!mounted) return;

      captionController.clear();
      tagsController.clear();

      setState(() {
        selectedVideo = null;
        selectedCover = null;
        isAdult = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر الفيديو بنجاح'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر نشر الفيديو: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _UploadPreview(
            video: selectedVideo,
            cover: selectedCover,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : pickVideo,
                  icon: const Icon(
                    Icons.video_library_outlined,
                  ),
                  label: const Text('اختيار فيديو'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : pickCover,
                  icon: const Icon(
                    Icons.image_outlined,
                  ),
                  label: const Text('الغلاف'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: captionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'الوصف',
              hintText: 'اكتب وصف الفيديو...',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: tagsController,
            decoration: const InputDecoration(
              labelText: 'الوسوم',
              hintText: '#رياضة #ترفيه',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isAdult,
            onChanged: uploading
                ? null
                : (value) {
                    setState(() {
                      isAdult = value;
                    });
                  },
            title: const Text(
              'محتوى +21',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'ضع علامة +21 إذا كان المحتوى للبالغين',
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: uploading ? null : publish,
              child: uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'نشر الفيديو',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadPreview extends StatelessWidget {
  const _UploadPreview({
    required this.video,
    required this.cover,
  });

  final XFile? video;
  final XFile? cover;

  @override
  Widget build(BuildContext context) {
    if (video == null && cover == null) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: NColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_collection_outlined,
                size: 56,
              ),
              SizedBox(height: 10),
              Text('اختر فيديو للبدء'),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: NColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: cover != null
          ? Image.file(
              File(cover!.path),
              fit: BoxFit.cover,
            )
          : const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 64,
              ),
            ),
    );
  }
}

class _ExplorePage extends StatefulWidget {
  const _ExplorePage();

  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePage> {
  final searchController = TextEditingController();

  bool searching = false;
  List<NProfile> profiles = [];
  List<NPost> posts = [];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final query = searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        searching = false;
        profiles = [];
        posts = [];
      });
      return;
    }

    setState(() {
      searching = true;
    });

    try {
      profiles = await data.searchProfiles(query);
      posts = await data.searchPosts(query);
    } finally {
      if (mounted) {
        setState(() {
          searching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استكشاف'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              8,
              14,
              10,
            ),
            child: TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => search(),
              decoration: InputDecoration(
                hintText: 'ابحث عن مستخدم أو فيديو...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                ),
                suffixIcon: IconButton(
                  onPressed: search,
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                  ),
                ),
              ),
            ),
          ),
          if (searching)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: searchController.text.trim().isEmpty
                ? const Center(
                    child: Text(
                      'ابحث عن المستخدمين والمنشورات',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: search,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        if (profiles.isNotEmpty) ...[
                          const Text(
                            'المستخدمون',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...profiles.map(
                            (profile) => ListTile(
                              contentPadding:
                                  EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundImage: profile
                                        .avatarUrl
                                        .trim()
                                        .isNotEmpty
                                    ? NetworkImage(
                                        profile.avatarUrl,
                                      )
                                    : null,
                                child: profile.avatarUrl
                                        .trim()
                                        .isEmpty
                                    ? const Icon(
                                        Icons.person,
                                      )
                                    : null,
                              ),
                              title: Text(
                                '@${profile.username}',
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${profile.followers} متابع',
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PublicProfilePage(
                                      username:
                                          profile.username,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        const Text(
                          'المنشورات',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (posts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(
                              child: Text(
                                'لا توجد نتائج',
                              ),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 7,
                              mainAxisSpacing: 7,
                              childAspectRatio: .68,
                            ),
                            itemCount: posts.length,
                            itemBuilder: (_, index) {
                              return _ProfileVideoTile(
                                post: posts[index],
                              );
                            },
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

class _LivePage extends StatelessWidget {
  const _LivePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البث المباشر'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: NColors.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.live_tv_rounded,
                    size: 64,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'البث المباشر قريباً',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'واجهة البث جاهزة، وسيتم ربط مزود البث لاحقاً.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.videocam_rounded),
              ),
              title: const Text(
                'ابدأ بثاً مباشراً',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'هذه الميزة غير مفعلة حالياً',
              ),
              trailing: const Icon(
                Icons.lock_outline_rounded,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'البث المباشر غير متاح حالياً',
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

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    super.key,
    required this.username,
  });

  final String username;

  @override
  State<PublicProfilePage> createState() =>
      _PublicProfilePageState();
}

class _PublicProfilePageState
    extends State<PublicProfilePage> {
  bool loading = true;
  bool following = false;

  NProfile? profile;
  List<NPost> posts = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
    });

    try {
      profile = await data.publicProfile(
        widget.username,
      );

      posts = await data.postsForUser(
        widget.username,
      );

      following = data.isFollowing(
        widget.username,
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> toggleFollow() async {
    final result = await data.toggleFollow(
      widget.username,
    );

    if (!mounted) return;

    setState(() {
      following = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('المستخدم غير موجود'),
        ),
      );
    }

    final p = profile!;

    return Scaffold(
      appBar: AppBar(
        title: Text('@${p.username}'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundImage:
                    p.avatarUrl.trim().isNotEmpty
                        ? NetworkImage(p.avatarUrl)
                        : null,
                child: p.avatarUrl.trim().isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 42,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '@${p.username}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (p.bio.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  p.bio,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                _ProfileStat(
                  value: '${p.followers}',
                  label: 'متابعون',
                ),
                _ProfileStat(
                  value: '${p.following}',
                  label: 'يتابع',
                ),
                _ProfileStat(
                  value: '${posts.length}',
                  label: 'منشورات',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (p.username != data.currentUsername)
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: toggleFollow,
                  child: Text(
                    following
                        ? 'إلغاء المتابعة'
                        : 'متابعة',
                  ),
                ),
              ),
            const SizedBox(height: 22),
            if (posts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    'لا توجد منشورات',
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                  childAspectRatio: .68,
                ),
                itemCount: posts.length,
                itemBuilder: (_, index) {
                  return _ProfileVideoTile(
                    post: posts[index],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
