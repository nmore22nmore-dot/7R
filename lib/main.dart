import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NApp());
}

/* =========================================================
   APP
========================================================= */

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
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF11141C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF11141C),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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

/* =========================================================
   DATA MODELS
========================================================= */

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

class NStory {
  NStory({
    required this.name,
    required this.username,
    this.viewed = false,
  });

  final String name;
  final String username;
  bool viewed;
}

/* =========================================================
   APP DATA
========================================================= */

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

  final List<NStory> stories = [
    NStory(name: 'N Official', username: 'n'),
    NStory(name: 'Ahmed', username: 'ahmed'),
    NStory(name: 'Sara', username: 'sara'),
    NStory(name: 'Mohamed', username: 'mohamed'),
    NStory(name: 'Noor', username: 'noor'),
  ];

  final Set<String> following = <String>{};

  final Map<String, List<NMessage>> messages = {
    'ahmed': [
      NMessage(
        sender: 'Ahmed',
        text: 'مرحباً 👋',
        time: '10:20',
      ),
    ],
    'sara': [
      NMessage(
        sender: 'Sara',
        text: 'أهلاً بك في N',
        time: '11:05',
      ),
    ],
  };

  bool get adultAllowed => age >= 21;

  int get myPosts =>
      posts.where((post) => post.username == username).length;

  void login({
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
    return posts.where((post) => post.username == user).toList();
  }

  List<NPost> visiblePosts() {
    return posts.where((post) {
      if (!post.adult) {
        return true;
      }

      return adultAllowed;
    }).toList();
  }

  void sendMessage(String user, String text) {
    final list = messages.putIfAbsent(user, () => []);

    final now = DateTime.now();

    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    list.add(
      NMessage(
        sender: username,
        text: text,
        time: '$hour:$minute',
      ),
    );

    notifyListeners();
  }

  void logout() {
    loggedIn = false;
    notifyListeners();
  }
}

final NData data = NData();

/* =========================================================
   LOGIN
========================================================= */

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool register = true;
  bool hidden = true;

  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  DateTime? birthDate;

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  int ageFromBirth(DateTime date) {
    final now = DateTime.now();

    int age = now.year - date.year;

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
      setState(() {
        birthDate = result;
      });
    }
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void submit() {
    final u = usernameController.text
        .trim()
        .replaceFirst('@', '')
        .replaceAll(' ', '')
        .toLowerCase();

    if (register && nameController.text.trim().isEmpty) {
      showMessage('اكتب اسمك');
      return;
    }

    if (u.length < 4) {
      showMessage('اسم المستخدم يجب أن يحتوي على 4 أحرف على الأقل');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(u)) {
      showMessage(
        'استخدم الأحرف الإنجليزية والأرقام و _ و . فقط',
      );
      return;
    }

    if (!emailController.text.contains('@')) {
      showMessage('أدخل بريدًا إلكترونيًا صحيحًا');
      return;
    }

    if (passwordController.text.length < 6) {
      showMessage('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    if (register && birthDate == null) {
      showMessage('اختر تاريخ الميلاد');
      return;
    }

    final age = register ? ageFromBirth(birthDate!) : 25;

    if (register && age < 13) {
      showMessage('يجب أن يكون العمر 13 سنة أو أكثر');
      return;
    }

    data.login(
      newName: register
          ? nameController.text.trim()
          : 'N User',
      newUsername: u,
      newEmail: emailController.text.trim(),
      newAge: age,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const NHome(),
      ),
    );
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
                maxWidth: 460,
              ),
              child: Column(
                children: [
                  Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF00C8FF),
                          Color(0xFFFF287A),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'N',
                        style: TextStyle(
                          fontSize: 68,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    register ? 'انضم إلى N' : 'مرحباً بعودتك',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    register
                        ? 'شبكة اجتماعية جديدة تجمعك بالعالم'
                        : 'سجل الدخول إلى حسابك',
                    style: const TextStyle(
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (register)
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم',
                        prefixIcon: Icon(
                          Icons.person_outline,
                        ),
                      ),
                    ),
                  if (register) const SizedBox(height: 12),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      hintText: '@username',
                      prefixIcon: Icon(
                        Icons.alternate_email,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: hidden,
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
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  if (register) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: chooseBirthDate,
                      icon: const Icon(
                        Icons.calendar_month,
                      ),
                      label: Text(
                        birthDate == null
                            ? 'تاريخ الميلاد'
                            : '${birthDate!.day}/${birthDate!.month}/${birthDate!.year}',
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: submit,
                      child: Padding(
                        padding: const EdgeInsets.all(15),
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
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        register = !register;
                      });
                    },
                    child: Text(
                      register
                          ? 'لدي حساب بالفعل'
                          : 'إنشاء حساب جديد',
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'N • محتوى +21 محمي حسب عمر الحساب',
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
    );
  }
}

/* =========================================================
   HOME SHELL
========================================================= */

class NHome extends StatefulWidget {
  const NHome({super.key});

  @override
  State<NHome> createState() => _NHomeState();
}

class _NHomeState extends State<NHome> {
  int index = 0;

  final List<Widget> pages = const [
    HomePage(),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const NotificationsPage(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.notifications_none,
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const MessagesPage(),
                    ),
                  );
                },
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
            onDestinationSelected: (value) {
              setState(() {
                index = value;
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
                label: 'نشر',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_outlined),
                selectedIcon: Icon(Icons.chat),
                label: 'الرسائل',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'حسابي',
              ),
            ],
          ),
        );
      },
    );
  }
}

/* =========================================================
   HOME
========================================================= */

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'الأصدقاء والقصص',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 105,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              const Story(
                label: 'قصتك',
                own: true,
              ),
              ...data.stories.map(
                (story) => Story(
                  label: story.name,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LivePage(),
              ),
            );
          },
          child: Container(
            height: 210,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF40105F),
                  Color(0xFF0D4770),
                ],
              ),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 72,
                    color: Colors.white,
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
                    child: const Text(
                      '● مباشر',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  right: 16,
                  bottom: 15,
                  child: Text(
                    'البث المباشر',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'لك',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: data,
          builder: (_, __) {
            final posts = data.visiblePosts();

            return Column(
              children: posts
                  .map(
                    (post) => PostCard(post: post),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

/* =========================================================
   STORY
========================================================= */

class Story extends StatelessWidget {
  const Story({
    super.key,
    required this.label,
    this.own = false,
  });

  final String label;
  final bool own;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryViewerPage(
              title: label,
            ),
          ),
        );
      },
      child: Container(
        width: 84,
        margin: const EdgeInsetsDirectional.only(
          end: 12,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF00C8FF),
                    Color(0xFFFF287A),
                  ],
                ),
              ),
              child: CircleAvatar(
                radius: 31,
                child: Icon(
                  own
                      ? Icons.add
                      : Icons.person,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================================================
   STORY VIEWER
========================================================= */

class StoryViewerPage extends StatelessWidget {
  const StoryViewerPage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(title),
      ),
      body: Stack(
        children: [
          const Center(
            child: Icon(
              Icons.image,
              size: 100,
              color: Colors.white24,
            ),
          ),
          Positioned(
            bottom: 30,
            right: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'قصة N',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================================================
   POST CARD
========================================================= */

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
  });

  final NPost post;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(15),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.author,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (post.verified) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified,
                              size: 17,
                              color: Colors.lightBlue,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '@${post.username}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _postMenu(context);
                  },
                  icon: const Icon(
                    Icons.more_horiz,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              post.text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF171B28),
                    Color(0xFF10131B),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 55,
                  color: Colors.white70,
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => data.like(post),
                  icon: Icon(
                    post.liked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color:
                        post.liked ? Colors.red : null,
                  ),
                ),
                Text('${post.likes}'),
                IconButton(
                  onPressed: () {
                    _comments(context);
                  },
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                  ),
                ),
                Text('${post.comments}'),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'تم تجهيز المشاركة',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.share_outlined,
                  ),
                ),
                const Spacer(),
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
    );
  }

  void _comments(BuildContext context) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context)
                    .viewInsets
                    .bottom +
                16,
            top: 15,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'التعليقات',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'اكتب تعليقك...',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    data.comment(post);
                  }

                  controller.dispose();
                  Navigator.pop(context);
                },
                child: const Text('إرسال'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _postMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              const ListTile(
                title: Text(
                  'خيارات المنشور',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark),
                title: Text(
                  post.saved
                      ? 'إزالة من المحفوظات'
                      : 'حفظ المنشور',
                ),
                onTap: () {
                  data.save(post);
                  Navigator.pop(context);
                },
              ),
              const ListTile(
                leading: Icon(Icons.flag_outlined),
                title: Text('الإبلاغ'),
              ),
              const ListTile(
                leading: Icon(Icons.block),
                title: Text('إخفاء المنشور'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* =========================================================
   EXPLORE
========================================================= */

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final search = TextEditingController();

  final users = const [
    ['N Official', 'n'],
    ['N News', 'nnews'],
    ['Ahmed', 'ahmed'],
    ['Sara', 'sara'],
    ['Mohamed', 'mohamed'],
    ['Noor', 'noor'],
  ];

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = search.text.toLowerCase();

    final filtered = users.where((user) {
      return q.isEmpty ||
          user[0].toLowerCase().contains(q) ||
          user[1].toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'استكشاف',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'ابحث عن أشخاص أو محتوى',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'حسابات مقترحة',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...filtered.map(
          (user) {
            final followed =
                data.following.contains(user[1]);

            return Card(
              margin: const EdgeInsets.only(
                bottom: 9,
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(user[0]),
                subtitle: Text('@${user[1]}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfilePage(
                        name: user[0],
                        username: user[1],
                      ),
                    ),
                  );
                },
                trailing: FilledButton(
                  onPressed: () {
                    data.follow(user[1]);
                  },
                  child: Text(
                    followed ? 'متابَع' : 'متابعة',
                  ),
                ),
              ),
            );
          },
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
            title: Text(
              '#موضوع_رائج_${i + 1}',
            ),
            subtitle: Text(
              '${2500 + i * 731} منشور',
            ),
            trailing: const Icon(
              Icons.trending_up,
            ),
          ),
        ),
      ],
    );
  }
}

/* =========================================================
   CREATE
========================================================= */

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
      visibility = 'عام';
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
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
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
              textAlignVertical:
                  TextAlignVertical.top,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'ماذا تريد أن تشارك؟',
                contentPadding:
                    EdgeInsets.all(17),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'اختيار الصورة جاهز للربط مع التخزين',
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
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'اختيار الفيديو جاهز للربط مع التخزين',
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('+21'),
            subtitle: const Text(
              'محتوى للبالغين بعمر 21 سنة فأكثر',
            ),
            value: adult,
            onChanged: (value) {
              if (value && !data.adultAllowed) {
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
                adult = value;
              });
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
                setState(() {
                  visibility = value;
                });
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

/* =========================================================
   LIVE
========================================================= */

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
              child: const Text(
                '● LIVE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            left: 15,
            bottom: 20,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'N Official',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'مرحباً بالجميع في البث المباشر',
                ),
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
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'تم إرسال هدية 🎁',
                        ),
                      ),
                    );
                  },
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

/* =========================================================
   MESSAGES
========================================================= */

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final users = const [
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
        children: users.map((user) {
          final messages =
              data.messages[user[1]] ?? [];

          final last = messages.isNotEmpty
              ? messages.last.text
              : 'ابدأ المحادثة';

          return Card(
            margin: const EdgeInsets.only(
              bottom: 10,
            ),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(user[0]),
              subtitle: Text(last),
              trailing: const Icon(
                Icons.chevron_left,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      name: user[0],
                      username: user[1],
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

/* =========================================================
   CHAT
========================================================= */

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

    if (text.isEmpty) {
      return;
    }

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
                    data.messages[widget.username] ??
                        [];

                if (current.isEmpty) {
                  return const Center(
                    child: Text(
                      'ابدأ المحادثة الآن',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: current.length,
                  itemBuilder: (_, i) {
                    final message = current[i];

                    final mine =
                        message.sender ==
                            data.username;

                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                            const EdgeInsets.only(
                          bottom: 8,
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(
                                  0xFF006D91,
                                )
                              : const Color(
                                  0xFF1B1E27,
                                ),
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
                      decoration:
                          const InputDecoration(
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

/* =========================================================
   NOTIFICATIONS
========================================================= */

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التنبيهات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          NotificationItem(
            icon: Icons.favorite,
            title: 'الإعجابات',
            subtitle:
                'لديك تفاعلات جديدة على منشوراتك',
          ),
          NotificationItem(
            icon: Icons.person_add,
            title: 'متابعون جدد',
            subtitle:
                'هناك أشخاص جدد يتابعونك',
          ),
          NotificationItem(
            icon: Icons.mode_comment,
            title: 'التعليقات',
            subtitle:
                'لديك تعليقات جديدة',
          ),
          NotificationItem(
            icon: Icons.live_tv,
            title: 'البث المباشر',
            subtitle:
                'بدأ بث مباشر جديد',
          ),
          NotificationItem(
            icon: Icons.message,
            title: 'رسالة جديدة',
            subtitle:
                'لديك رسالة جديدة',
          ),
        ],
      ),
    );
  }
}

class NotificationItem extends StatelessWidget {
  const NotificationItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_left,
        ),
      ),
    );
  }
}

/* =========================================================
   PROFILE
========================================================= */

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (_, __) {
        final myPosts =
            data.postsOf(data.username);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 10),
            const Center(
              child: CircleAvatar(
                radius: 55,
                child: Icon(
                  Icons.person,
                  size: 52,
                ),
              ),
            ),
            const SizedBox(height: 13),
            Center(
              child: Text(
                data.name,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Center(
              child: Text(
                '@${data.username}',
                style: const TextStyle(
                  color: Colors.white54,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
              children: [
                ProfileStat(
                  number: '${myPosts.length}',
                  label: 'المنشورات',
                ),
                const ProfileStat(
                  number: '0',
                  label: 'المتابعون',
                ),
                ProfileStat(
                  number:
                      '${data.following.length}',
                  label: 'المتابَعون',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.person_outline,
                    ),
                    title: const Text('الحساب'),
                    subtitle: Text(
                      'العمر المسجل: ${data.age} سنة',
                    ),
                    trailing: const Icon(
                      Icons.chevron_left,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AccountSettingsPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.security,
                    ),
                    title: const Text(
                      'الأمان والخصوصية',
                    ),
                    trailing: const Icon(
                      Icons.chevron_left,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const PrivacyPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(
                      Icons.shield_outlined,
                    ),
                    title: Text(
                      'الحماية العمرية',
                    ),
                    subtitle: Text(
                      'محتوى +21 محمي بحسب عمر الحساب',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                    ),
                    title: const Text('الإعدادات'),
                    trailing: const Icon(
                      Icons.chevron_left,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const SettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // منشورات صاحب الحساب تظهر داخل ملفه الشخصي
            const Text(
              'منشوراتي',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            if (myPosts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Center(
                    child: Text(
                      'لم تنشر أي منشور بعد',
                    ),
                  ),
                ),
              ),
            ...myPosts.map(
              (post) => PostCard(post: post),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                data.logout();

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const LoginPage(),
                  ),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text(
                'تسجيل الخروج
