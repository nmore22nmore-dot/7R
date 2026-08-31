import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    runApp(const NConfigurationErrorApp());
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabasePublishableKey,
  );

  runApp(const NApp());
}

class NConfigurationErrorApp extends StatelessWidget {
  const NConfigurationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'إعدادات Supabase غير موجودة. أعد بناء التطبيق من Codemagic.',
              textAlign: TextAlign.center,
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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07080D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C8FF),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF11141C),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF11141C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: LoginPage(),
      ),
    );
  }
}

class NPost {
  NPost({
    required this.author,
    required this.username,
    required this.text,
    this.likes = 0,
    this.comments = 0,
    this.verified = false,
    this.adult = false,
    this.visibility = 'عام',
  });

  final String author;
  final String username;
  final String text;
  final bool verified;
  final bool adult;
  final String visibility;
  int likes;
  int comments;
  bool liked = false;
  bool saved = false;
}

class NMessage {
  NMessage({
    required this.sender,
    required this.text,
    required this.time,
  });

  final String sender;
  final String text;
  final String time;
}

class NData extends ChangeNotifier {
  String name = 'مستخدم N';
  String username = 'n_user';
  String email = '';
  int age = 25;
  bool loggedIn = false;

  final List<NPost> posts = [
    NPost(
      author: 'N Official',
      username: 'n',
      text: 'مرحباً بك في N 👋',
      likes: 1240,
      comments: 86,
      verified: true,
    ),
    NPost(
      author: 'N Official',
      username: 'n',
      text: 'شارك أفكارك وصورك وفيديوهاتك ولحظاتك مع مجتمع N.',
      likes: 842,
      comments: 41,
      verified: true,
    ),
    NPost(
      author: 'N News',
      username: 'nnews',
      text: 'اكتشف أحدث المحتوى الرائج في N الآن.',
      likes: 521,
      comments: 28,
    ),
  ];

  final Set<String> following = <String>{};

  final Map<String, List<NMessage>> messages = {
    'ahmed': [
      NMessage(sender: 'Ahmed', text: 'مرحباً 👋', time: '10:20'),
    ],
    'sara': [
      NMessage(sender: 'Sara', text: 'أهلاً بك في N', time: '11:05'),
    ],
  };

  bool get adultAllowed => age >= 21;

  void setAuthenticatedUser({
    required String newName,
    required String newUsername,
    required String newEmail,
    required int newAge,
  }) {
    name = newName;
    username = newUsername;
    email = newEmail;
    age = newAge;
    loggedIn = true;
    notifyListeners();
  }

  void createPost(
    String text, {
    bool adult = false,
    String visibility = 'عام',
  }) {
    posts.insert(
      0,
      NPost(
        author: name,
        username: username,
        text: text,
        adult: adult,
        visibility: visibility,
      ),
    );
    notifyListeners();
  }

  void like(NPost post) {
    post.liked = !post.liked;

    if (post.liked) {
      post.likes++;
    } else if (post.likes > 0) {
      post.likes--;
    }

    notifyListeners();
  }

  void comment(NPost post) {
    post.comments++;
    notifyListeners();
  }

  void save(NPost post) {
    post.saved = !post.saved;
    notifyListeners();
  }

  void follow(String user) {
    if (following.contains(user)) {
      following.remove(user);
    } else {
      following.add(user);
    }

    notifyListeners();
  }

  List<NPost> postsOf(String user) {
    return posts.where((p) => p.username == user).toList();
  }

  List<NPost> visiblePosts() {
    return posts.where((p) => !p.adult || adultAllowed).toList();
  }

  void sendMessage(String user, String text) {
    final list = messages.putIfAbsent(user, () => []);

    final now = TimeOfDay.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');

    list.add(
      NMessage(
        sender: username,
        text: text,
        time: '$hh:$mm',
      ),
    );

    notifyListeners();
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    loggedIn = false;
    notifyListeners();
  }
}

final NData data = NData();

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool register = true;
  bool hidden = true;

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

    if (result != null) {
      setState(() => birthDate = result);
    }
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  Future<void> submit() async {
    final u = username.text
        .trim()
        .replaceFirst('@', '')
        .replaceAll(' ', '')
        .toLowerCase();

    final emailValue = email.text.trim();
    final passwordValue = password.text;

    if (register && name.text.trim().isEmpty) {
      message('اكتب اسمك');
      return;
    }

    if (u.length < 4) {
      message('اسم المستخدم يجب أن يحتوي على 4 أحرف على الأقل');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(u)) {
      message('استخدم الأحرف الإنجليزية والأرقام و _ و . فقط');
      return;
    }

    if (!emailValue.contains('@')) {
      message('أدخل بريدًا إلكترونيًا صحيحًا');
      return;
    }

    if (passwordValue.length < 6) {
      message('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    if (register && birthDate == null) {
      message('اختر تاريخ الميلاد');
      return;
    }

    final age = register ? ageFromBirth(birthDate!) : 25;

    if (register && age < 13) {
      message('يجب أن يكون العمر 13 سنة أو أكثر');
      return;
    }

    setState(() {});

    try {
      final client = Supabase.instance.client;

      if (register) {
        final response = await client.auth.signUp(
          email: emailValue,
          password: passwordValue,
        );

        final user = response.user;

        if (user == null) {
          message('تعذر إنشاء الحساب. حاول مرة أخرى.');
          return;
        }

        if (response.session != null) {
          await client.from('profiles').insert({
            'id': user.id,
            'username': u,
            'display_name': name.text.trim(),
            'birth_date': birthDate!.toIso8601String().split('T').first,
          });

          data.setAuthenticatedUser(
            newName: name.text.trim(),
            newUsername: u,
            newEmail: emailValue,
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

        message(
          'تم إنشاء الحساب. تحقق من بريدك الإلكتروني لتأكيد الحساب ثم سجّل الدخول.',
        );

        setState(() => register = false);
        return;
      }

      final response = await client.auth.signInWithPassword(
        email: emailValue,
        password: passwordValue,
      );

      final user = response.user;

      if (user == null || response.session == null) {
        message('تعذر تسجيل الدخول. تحقق من البريد وكلمة المرور.');
        return;
      }

      final profile = await client
          .from('profiles')
          .select('username, display_name, birth_date')
          .eq('id', user.id)
          .maybeSingle();

      final profileMap = profile as Map<String, dynamic>?;

      final profileUsername =
          (profileMap?['username'] as String?) ?? u;

      final profileName =
          (profileMap?['display_name'] as String?) ?? 'N User';

      final birthDateValue =
          profileMap?['birth_date'] as String?;

      final profileAge = birthDateValue == null
          ? 25
          : ageFromBirth(
              DateTime.parse(birthDateValue),
            );

      data.setAuthenticatedUser(
        newName: profileName,
        newUsername: profileUsername,
        newEmail: user.email ?? emailValue,
        newAge: profileAge,
      );

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
      message('خطأ في ملف الحساب: ${e.message}');
    } catch (e) {
      message(
        'حدث خطأ أثناء ${register ? 'إنشاء الحساب' : 'تسجيل الدخول'}: $e',
      );
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
                      prefixIcon: Icon(
                        Icons.alternate_email,
                      ),
                      hintText: 'username',
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
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => hidden = !hidden);
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
                    if (birthDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'العمر: ${ageFromBirth(birthDate!)} سنة',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 22),

                  FilledButton(
                    onPressed: submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      child: Text(
                        register
                            ? 'إنشاء الحساب'
                            : 'تسجيل الدخول',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () {
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

                  const SizedBox(height: 20),

                  const Text(
                    'باستخدام N أنت توافق على شروط الاستخدام '
                    'وسياسة الخصوصية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
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

  final pages = const [
    NVideoFeedPage(),
    ExplorePage(),
    CreatePage(),
    MessagesPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (_, __) {
        return Scaffold(
          body: IndexedStack(
            index: index,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) {
              setState(() => index = value);
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
                label: 'نشر',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'الرسائل',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'الملف',
              ),
            ],
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
  @override
  Widget build(BuildContext context) {
    final posts = data.visiblePosts();

    if (posts.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد منشورات حالياً',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return PostCard(
          post: posts[index],
          fullScreen: true,
        );
      },
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.fullScreen = false,
  });

  final NPost post;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: fullScreen
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: fullScreen
            ? const BoxConstraints.expand()
            : const BoxConstraints(minHeight: 230),
        padding: const EdgeInsets.all(18),
        child: Stack(
          children: [
            if (fullScreen)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0C0E14),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 80,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 16,
              left: 16,
              bottom: fullScreen ? 30 : 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 23,
                        child: Icon(Icons.person),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        post.author,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (post.verified) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified,
                          size: 19,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post.text,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => data.like(post),
                        icon: Icon(
                          post.liked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: post.liked
                              ? Colors.red
                              : null,
                        ),
                      ),
                      Text('${post.likes}'),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => data.comment(post),
                        icon: const Icon(
                          Icons.mode_comment_outlined,
                        ),
                      ),
                      Text('${post.comments}'),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => data.save(post),
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
          ],
        ),
      ),
    );
  }
}

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    const users = [
      ['Ahmed', 'ahmed'],
      ['Sara', 'sara'],
      ['N Official', 'n'],
      ['N News', 'nnews'],
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'استكشاف',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'بحث في N',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.tune),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'حسابات مقترحة',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...users.map(
            (user) => Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(user[0]),
                subtitle: Text('@${user[1]}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfilePage(
                      name: user[0],
                      username: user[1],
                    ),
                  ),
                ),
                trailing: FilledButton(
                  onPressed: () => data.follow(user[1]),
                  child: Text(
                    data.following.contains(user[1])
                        ? 'متابَع'
                        : 'متابعة',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'الرائج الآن',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          ...List.generate(
            7,
            (i) => ListTile(
              leading: Text(
                '${i + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: Text('#موضوع_رائج_${i + 1}'),
              subtitle: Text('${2500 + i * 731} منشور'),
              trailing: const Icon(
                Icons.trending_up,
              ),
            ),
          ),
        ],
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
  final controller = TextEditingController();

  bool adult = false;
  String visibility = 'عام';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void publish() {
    final text = controller.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتب شيئًا قبل النشر'),
        ),
      );
      return;
    }

    if (adult && !data.adultAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'محتوى +21 متاح للحسابات بعمر 21 سنة فأكثر',
          ),
        ),
      );
      return;
    }

    data.createPost(
      text,
      adult: adult,
      visibility: visibility,
    );

    controller.clear();

    setState(() {
      adult = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نشر المنشور بنجاح'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'إنشاء منشور',
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                child: Icon(Icons.person),
              ),
              const SizedBox(width: 10),
              Text(
                data.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'ماذا تريد أن تشارك؟',
                contentPadding: EdgeInsets.all(17),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'اختيار الصورة جاهز للربط مع التخزين',
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.image_outlined,
                  ),
                  label: const Text('صورة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'اختيار الفيديو جاهز للربط مع التخزين',
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.videocam_outlined,
                  ),
                  label: const Text('فيديو'),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('+21'),
            subtitle: const Text(
              'محتوى للبالغين بعمر 21 سنة فأكثر',
            ),
            value: adult,
            onChanged: (value) {
              if (value && !data.adultAllowed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'هذا الخيار متاح للحسابات بعمر 21 سنة فأكثر',
                    ),
                  ),
                );
                return;
              }

              setState(() => adult = value);
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: visibility,
            decoration: const InputDecoration(
              labelText: 'الخصوصية',
            ),
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
            onChanged: (value) {
              if (value != null) {
                setState(() => visibility = value);
              }
            },
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: publish,
            icon: const Icon(Icons.send),
            label: const Padding(
              padding: EdgeInsets.all(13),
              child: Text('نشر'),
            ),
          ),
        ],
      ),
    );
  }
}

class LivePage extends StatelessWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البث المباشر'),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF171A2A),
                  Color(0xFF05060A),
                ],
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 90,
              ),
            ),
          ),
          Positioned(
            right: 15,
            top: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('● LIVE'),
            ),
          ),
          const Positioned(
            right: 15,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'N Official',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('مرحباً بالجميع في البث المباشر'),
              ],
            ),
          ),
          Positioned(
            left: 15,
            bottom: 110,
            child: Column(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 35,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.card_giftcard,
                    size: 35,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.share,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    const users = [
      ['Ahmed', 'ahmed'],
      ['Sara', 'sara'],
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الرسائل',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: users
            .map(
              (user) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(user[0]),
                  subtitle: const Text(
                    'اضغط لفتح المحادثة',
                  ),
                  trailing: const Icon(
                    Icons.chevron_left,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        name: user[0],
                        username: user[1],
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
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

  void send() {
    final text = controller.text.trim();

    if (text.isEmpty) return;

    data.sendMessage(
      widget.username,
      text,
    );

    controller.clear();
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
                    final message = current[i];
                    final mine =
                        message.sender == data.username;

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
                            Text(message.text),
                            const SizedBox(height: 3),
                            Text(
                              message.time,
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

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الإشعارات',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.favorite),
            ),
            title: Text('إعجاب جديد'),
            subtitle: Text('أعجب شخص بمنشورك'),
          ),
          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.person_add),
            ),
            title: Text('متابع جديد'),
            subtitle: Text('بدأ شخص بمتابعتك'),
          ),
          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.comment),
            ),
            title: Text('تعليق جديد'),
            subtitle: Text('تمت إضافة تعليق على منشورك'),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final myPosts = data.postsOf(data.username);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '@${data.username}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_outlined,
            ),
          ),
          IconButton(
            onPressed: () async {
              await data.logout();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginPage(),
                ),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: data,
        builder: (_, __) {
          return ListView(
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
                data.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@${data.username}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  _ProfileStat(
                    value: '${myPosts.length}',
                    label: 'منشورات',
                  ),
                  const _ProfileStat(
                    value: '0',
                    label: 'المتابعون',
                  ),
                  _ProfileStat(
                    value: '${data.following.length}',
                    label: 'يتابع',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'منشوراتي',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (myPosts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 40,
                  ),
                  child: Center(
                    child: Text(
                      'لم تنشر أي منشورات بعد',
                      style: TextStyle(
                        color: Colors.white60,
                      ),
                    ),
                  ),
                )
              else
                ...myPosts.map(
                  (post) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: PostCard(post: post),
                  ),
                ),
            ],
          );
        },
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
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
          ),
        ),
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
    final userPosts = data.postsOf(username);
    final isFollowing =
        data.following.contains(username);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '@$username',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: data,
        builder: (_, __) {
          return ListView(
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
              const SizedBox(height: 4),
              Text(
                '@$username',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => data.follow(username),
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
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 40,
                  ),
                  child: Center(
                    child: Text(
                      'لا توجد منشورات',
                      style: TextStyle(
                        color: Colors.white60,
                      ),
                    ),
                  ),
                )
              else
                ...userPosts.map(
                  (post) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: PostCard(post: post),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
