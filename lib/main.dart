import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NApp());
}

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
        scaffoldBackgroundColor: const Color(0xFF08090C),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C2FF),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF15171D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111319),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const AuthPage(),
    );
  }
}

class NPost {
  NPost({
    required this.text,
    required this.author,
    required this.handle,
    this.adult = false,
  });

  final String text;
  final String author;
  final String handle;
  final bool adult;

  int likes = 0;
  int comments = 0;
  bool liked = false;
  bool saved = false;
}

class AppStore extends ChangeNotifier {
  String name = '';
  String username = '';
  int age = 0;
  bool loggedIn = false;
  int unread = 3;

  final List<NPost> posts = [
    NPost(
      text: 'مرحباً بك في N 👋',
      author: 'N Official',
      handle: '@n',
    ),
    NPost(
      text: 'شارك أفكارك، لحظاتك، وصوتك مع مجتمع N.',
      author: 'N Official',
      handle: '@n',
    ),
    NPost(
      text: 'اكتشف المحتوى الجديد والرائج اليوم.',
      author: 'N Official',
      handle: '@n',
    ),
  ];

  final Set<String> following = <String>{};

  bool get adultEligible => age >= 21;

  void login(
    String newName,
    String newUsername,
    int newAge,
  ) {
    name = newName;
    username = newUsername;
    age = newAge;
    loggedIn = true;
    notifyListeners();
  }

  void addPost(
    String text, {
    bool adult = false,
  }) {
    posts.insert(
      0,
      NPost(
        text: text,
        author: name,
        handle: '@$username',
        adult: adult,
      ),
    );

    notifyListeners();
  }

  void toggleLike(NPost post) {
    post.liked = !post.liked;

    if (post.liked) {
      post.likes++;
    } else if (post.likes > 0) {
      post.likes--;
    }

    notifyListeners();
  }

  void toggleSaved(NPost post) {
    post.saved = !post.saved;
    notifyListeners();
  }

  void addComment(NPost post) {
    post.comments++;
    notifyListeners();
  }

  void toggleFollow(String handle) {
    if (following.contains(handle)) {
      following.remove(handle);
    } else {
      following.add(handle);
    }

    notifyListeners();
  }

  void logout() {
    loggedIn = false;
    notifyListeners();
  }
}

final AppStore store = AppStore();

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool signup = true;
  bool obscure = true;

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

  int calculateAge(DateTime date) {
    final now = DateTime.now();

    int result = now.year - date.year;

    final birthday = DateTime(
      now.year,
      date.month,
      date.day,
    );

    if (birthday.isAfter(now)) {
      result--;
    }

    return result;
  }

  void submit() {
    final u = username.text
        .trim()
        .replaceFirst('@', '')
        .replaceAll(' ', '')
        .toLowerCase();

    if (signup && name.text.trim().isEmpty) {
      _message('اكتب اسمك الكامل');
      return;
    }

    if (u.length < 4) {
      _message('اسم المستخدم يجب أن يكون 4 أحرف على الأقل');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(u)) {
      _message(
        'اسم المستخدم: أحرف إنجليزية وأرقام و _ . فقط',
      );
      return;
    }

    if (!email.text.contains('@')) {
      _message('أدخل بريداً إلكترونياً صحيحاً');
      return;
    }

    if (password.text.length < 6) {
      _message('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    if (signup && birthDate == null) {
      _message('اختر تاريخ الميلاد');
      return;
    }

    final age = signup
        ? calculateAge(birthDate!)
        : 21;

    if (signup && age < 13) {
      _message('يجب أن يكون العمر 13 سنة أو أكثر');
      return;
    }

    store.login(
      signup ? name.text.trim() : 'N User',
      u,
      age,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const HomeShell(),
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  Future<void> pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'اختر تاريخ الميلاد',
    );

    if (picked != null) {
      setState(() {
        birthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 460,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF00C2FF),
                            Color(0xFFFF2E78),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'N',
                          style: TextStyle(
                            fontSize: 65,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      signup
                          ? 'أنشئ حسابك في N'
                          : 'مرحباً بعودتك',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      signup
                          ? 'ابدأ رحلتك الاجتماعية'
                          : 'سجّل الدخول للمتابعة',
                      style: const TextStyle(
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 26),

                    if (signup) ...[
                      TextField(
                        controller: name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          prefixIcon:
                              Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: username,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم',
                        hintText: '@username',
                        prefixIcon:
                            Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: email,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon:
                            Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: password,
                      obscureText: obscure,
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon:
                            const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscure = !obscure;
                            });
                          },
                          icon: Icon(
                            obscure
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),

                    if (signup) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: pickBirthDate,
                        icon: const Icon(
                          Icons.calendar_month,
                        ),
                        label: Text(
                          birthDate == null
                              ? 'تاريخ الميلاد'
                              : '${birthDate!.year}/${birthDate!.month}/${birthDate!.day}',
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          child: Text(
                            signup
                                ? 'إنشاء الحساب'
                                : 'تسجيل الدخول',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        setState(() {
                          signup = !signup;
                        });
                      },
                      child: Text(
                        signup
                            ? 'لدي حساب؟ تسجيل الدخول'
                            : 'ليس لدي حساب؟ إنشاء حساب',
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'اسم المستخدم: 4 أحرف فأكثر • المحتوى +21 مقيد بالعمر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  late final List<Widget> pages = [
    const FeedPage(),
    const ExplorePage(),
    const CreatePage(),
    const NotificationsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'N',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  index = 3;
                });
              },
              icon: Badge(
                isLabelVisible: store.unread > 0,
                label: Text('${store.unread}'),
                child: const Icon(
                  Icons.notifications_none,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _messages(context),
              icon: const Icon(
                Icons.chat_bubble_outline,
              ),
            ),
          ],
        ),
        body: IndexedStack(
          index: index,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            setState(() {
              index = i;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'استكشاف',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'إنشاء',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_none),
              selectedIcon: Icon(Icons.notifications),
              label: 'التنبيهات',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'الملف',
            ),
          ],
        ),
      ),
    );
  }

  void _messages(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.chat),
                  title: Text('الرسائل'),
                ),
                ListTile(
                  leading: CircleAvatar(
                    child: Text('1'),
                  ),
                  title: Text('User 1'),
                  subtitle: Text('لا توجد رسائل جديدة'),
                ),
                ListTile(
                  leading: CircleAvatar(
                    child: Text('2'),
                  ),
                  title: Text('User 2'),
                  subtitle: Text('لا توجد رسائل جديدة'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'القصص',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 8,
            itemBuilder: (_, i) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: 12,
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 31,
                      child: Text(
                        i == 0 ? 'N' : '$i',
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      i == 0 ? 'قصتك' : 'User $i',
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          'لك',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 10),

        AnimatedBuilder(
          animation: store,
          builder: (_, __) {
            final visiblePosts = store.posts
                .where(
                  (p) =>
                      !p.adult ||
                      store.adultEligible,
                )
                .toList();

            return Column(
              children: visiblePosts
                  .map(
                    (p) => PostCard(post: p),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
  });

  final NPost post;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    post.author.isEmpty
                        ? 'N'
                        : post.author[0],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        post.handle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.more_horiz,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              post.text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(16),
                color: const Color(0xFF1A1D25),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: Colors.white30,
                ),
              ),
            ),

            Row(
              children: [
                IconButton(
                  onPressed: () {
                    store.toggleLike(post);
                  },
                  icon: Icon(
                    post.liked
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                ),
                Text('${post.likes}'),

                IconButton(
                  onPressed: () {
                    _comment(context);
                  },
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                  ),
                ),
                Text('${post.comments}'),

                IconButton(
                  onPressed: () {
                    _share(context);
                  },
                  icon: const Icon(
                    Icons.share_outlined,
                  ),
                ),

                const Spacer(),

                IconButton(
                  onPressed: () {
                    store.toggleSaved(post);
                  },
                  icon: Icon(
                    post.saved
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _comment(BuildContext context) {
    final c = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('التعليقات'),
          content: TextField(
            controller: c,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'اكتب تعليقك...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (c.text.trim().isNotEmpty) {
                  store.addComment(post);
                }

                Navigator.pop(context);
              },
              child: const Text('إرسال'),
            ),
          ],
        );
      },
    ).whenComplete(c.dispose);
  }

  void _share(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              const ListTile(
                title: Text('مشاركة المنشور'),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('نسخ الرابط'),
                onTap: () {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تم تجهيز الرابط',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('إرسال إلى صديق'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() =>
      _ExplorePageState();
}

class _ExplorePageState
    extends State<ExplorePage> {
  final q = TextEditingController();

  final users = const [
    'User 1',
    'User 2',
    'User 3',
    'User 4',
    'User 5',
  ];

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = users
        .where(
          (u) =>
              q.text.isEmpty ||
              u.toLowerCase().contains(
                    q.text.toLowerCase(),
                  ),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'استكشاف',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: q,
          onChanged: (_) {
            setState(() {});
          },
          decoration: const InputDecoration(
            hintText: 'ابحث عن أشخاص أو محتوى',
            prefixIcon: Icon(Icons.search),
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          'حسابات مقترحة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        ...filtered.map(
          (u) {
            final handle =
                '@${u.toLowerCase().replaceAll(' ', '')}';

            final following =
                store.following.contains(handle);

            return Card(
              margin: const EdgeInsets.only(
                bottom: 8,
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(u),
                subtitle: Text(handle),
                trailing: FilledButton(
                  onPressed: () {
                    setState(() {
                      store.toggleFollow(handle);
                    });
                  },
                  child: Text(
                    following
                        ? 'متابَع'
                        : 'متابعة',
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 18),

        const Text(
          'المحتوى الرائج',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        ...List.generate(
          5,
          (i) {
            return ListTile(
              leading: const Icon(
                Icons.trending_up,
              ),
              title: Text(
                '#موضوع_رائج_${i + 1}',
              ),
              subtitle: Text(
                '${1200 + i * 500} منشور',
              ),
            );
          },
        ),
      ],
    );
  }
}

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() =>
      _CreatePageState();
}

class _CreatePageState
    extends State<CreatePage> {
  final c = TextEditingController();

  bool adult = false;
  String visibility = 'عام';

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          const Text(
            'إنشاء منشور',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: TextField(
              controller: c,
              maxLines: null,
              expands: true,
              textAlignVertical:
                  TextAlignVertical.top,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText:
                    'ماذا تريد أن تشارك؟',
                contentPadding:
                    EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Text('الخصوصية'),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: visibility,
                items: const [
                  DropdownMenuItem(
                    value: 'عام',
                    child: Text('عام'),
                  ),
                  DropdownMenuItem(
                    value: 'المتابعون',
                    child: Text('المتابعون'),
                  ),
                  DropdownMenuItem(
                    value: 'خاص',
                    child: Text('خاص'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;

                  setState(() {
                    visibility = v;
                  });
                },
              ),
            ],
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'محتوى للبالغين +21',
            ),
            subtitle: const Text(
              'لا يظهر إلا للحسابات بعمر 21 سنة فأكثر',
            ),
            value: adult,
            onChanged: (v) {
              if (v && !store.adultEligible) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'هذا الخيار متاح للحسابات بعمر 21 سنة فأكثر',
                    ),
                  ),
                );
                return;
              }

              setState(() {
                adult = v;
              });
            },
          ),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'منتقي الصور يحتاج إضافة مكتبة الوسائط في نسخة الإنتاج',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.image_outlined,
                  ),
                  label: const Text('صورة'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'منتقي الفيديو يحتاج إضافة مكتبة الوسائط في نسخة الإنتاج',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.videocam_outlined,
                  ),
                  label: const Text('فيديو'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          FilledButton.icon(
            onPressed: () {
              final text = c.text.trim();

              if (text.isEmpty) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'اكتب شيئاً قبل النشر',
                    ),
                  ),
                );
                return;
              }

              store.addPost(
                text,
                adult: adult,
              );

              c.clear();

              setState(() {
                adult = false;
              });

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'تم نشر المنشور',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.send),
            label: const Padding(
              padding: EdgeInsets.all(13),
              child: Text('نشر المنشور'),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'التنبيهات',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),

        const ListTile(
          leading: CircleAvatar(
            child: Icon(Icons.favorite),
          ),
          title: Text('الإعجابات'),
          subtitle: Text(
            'ستظهر هنا الإعجابات على منشوراتك.',
          ),
        ),

        const ListTile(
          leading: CircleAvatar(
            child: Icon(Icons.person_add),
          ),
          title: Text('المتابعات'),
          subtitle: Text(
            'ستظهر هنا المتابعات الجديدة.',
          ),
        ),

        const ListTile(
          leading: CircleAvatar(
            child: Icon(Icons.comment),
          ),
          title: Text('التعليقات'),
          subtitle: Text(
            'ستظهر هنا التعليقات الجديدة.',
          ),
        ),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),

        const Center(
          child: CircleAvatar(
            radius: 54,
            child: Text(
              'N',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Center(
          child: Text(
            store.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Center(
          child: Text(
            '@${store.username}',
            style: const TextStyle(
              color: Colors.white54,
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
          children: [
            Stat(
              n: '0',
              t: 'المنشورات',
            ),
            Stat(
              n: '0',
              t: 'المتابعون',
            ),
            Stat(
              n: '0',
              t: 'المتابَعون',
            ),
          ],
        ),

        const SizedBox(height: 22),

        Card(
          child: ListTile(
            leading: const Icon(
              Icons.verified_user_outlined,
            ),
            title: const Text(
              'حالة الحساب',
            ),
            subtitle: Text(
              'العمر المسجل: ${store.age} سنة',
            ),
          ),
        ),

        const Card(
          child: ListTile(
            leading: Icon(
              Icons.shield_outlined,
            ),
            title: Text(
              'الحماية العمرية',
            ),
            subtitle: Text(
              'المحتوى المصنف +21 محمي بحسب العمر',
            ),
          ),
        ),

        const Card(
          child: ListTile(
            leading: Icon(
              Icons.lock_outline,
            ),
            title: Text(
              'الخصوصية والأمان',
            ),
            subtitle: Text(
              'إعدادات الحساب والخصوصية',
            ),
          ),
        ),

        const SizedBox(height: 10),

        OutlinedButton.icon(
          onPressed: () {
            store.logout();

            Navigator.of(context)
                .pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const AuthPage(),
              ),
              (_) => false,
            );
          },
          icon: const Icon(Icons.logout),
          label: const Text(
            'تسجيل الخروج',
          ),
        ),
      ],
    );
  }
}

class Stat extends StatelessWidget {
  const Stat({
    super.key,
    required this.n,
    required this.t,
  });

  final String n;
  final String t;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          n,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(t),
      ],
    );
  }
}