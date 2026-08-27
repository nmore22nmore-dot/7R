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
        scaffoldBackgroundColor: const Color(0xFF07080D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C8FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: LoginPage(),
      ),
    );
  }
}

class NData extends ChangeNotifier {
  String name = 'مستخدم N';
  String username = 'n_user';
  int age = 25;

  final List<Post> posts = [
    Post(
      author: 'N Official',
      username: 'n',
      text: 'مرحبًا بك في N 👋',
      likes: 1240,
      comments: 86,
      verified: true,
    ),
    Post(
      author: 'N Official',
      username: 'n',
      text: 'شارك أفكارك، صورك، فيديوهاتك ولحظاتك مع مجتمع N.',
      likes: 842,
      comments: 41,
      verified: true,
    ),
    Post(
      author: 'N News',
      username: 'nnews',
      text: 'اكتشف أحدث المحتوى الرائج في N الآن.',
      likes: 521,
      comments: 28,
    ),
  ];

  final Set<String> following = {};

  bool get adultAllowed => age >= 21;

  void login(String n, String u, int a) {
    name = n;
    username = u;
    age = a;
    notifyListeners();
  }

  void createPost(String text, {bool adult = false}) {
    posts.insert(
      0,
      Post(
        author: name,
        username: username,
        text: text,
        adult: adult,
      ),
    );
    notifyListeners();
  }

  void like(Post post) {
    post.liked = !post.liked;
    post.likes += post.liked ? 1 : -1;
    notifyListeners();
  }

  void comment(Post post) {
    post.comments++;
    notifyListeners();
  }

  void save(Post post) {
    post.saved = !post.saved;
    notifyListeners();
  }

  void follow(String username) {
    if (following.contains(username)) {
      following.remove(username);
    } else {
      following.add(username);
    }
    notifyListeners();
  }
}

final data = NData();

class Post {
  Post({
    required this.author,
    required this.username,
    required this.text,
    this.likes = 0,
    this.comments = 0,
    this.adult = false,
    this.verified = false,
  });

  final String author;
  final String username;
  final String text;
  final bool adult;
  final bool verified;

  int likes;
  int comments;
  bool liked = false;
  bool saved = false;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool create = true;
  bool passwordHidden = true;

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

    if (DateTime(now.year, date.month, date.day).isAfter(now)) {
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

  void submit() {
    final u = username.text
        .trim()
        .replaceFirst('@', '')
        .replaceAll(' ', '')
        .toLowerCase();

    if (create && name.text.trim().isEmpty) {
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

    if (!email.text.contains('@')) {
      message('أدخل بريدًا إلكترونيًا صحيحًا');
      return;
    }

    if (password.text.length < 6) {
      message('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    if (create && birthDate == null) {
      message('اختر تاريخ الميلاد');
      return;
    }

    final age = create ? ageFromBirth(birthDate!) : 21;

    if (create && age < 13) {
      message('يجب أن يكون العمر 13 سنة أو أكثر');
      return;
    }

    data.login(
      create ? name.text.trim() : 'N User',
      u,
      age,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const NHome()),
    );
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
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
              constraints: const BoxConstraints(maxWidth: 460),
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
                    create ? 'انضم إلى N' : 'مرحبًا بعودتك',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    create
                        ? 'شبكة اجتماعية جديدة تجمعك بالعالم'
                        : 'سجل الدخول إلى حسابك',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 30),

                  if (create)
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'الاسم',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),

                  if (create) const SizedBox(height: 12),

                  TextField(
                    controller: username,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      hintText: '@username',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: password,
                    obscureText: passwordHidden,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            passwordHidden = !passwordHidden;
                          });
                        },
                        icon: Icon(
                          passwordHidden
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),

                  if (create) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: chooseBirthDate,
                      icon: const Icon(Icons.calendar_month),
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
                          create ? 'إنشاء الحساب' : 'تسجيل الدخول',
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
                      setState(() => create = !create);
                    },
                    child: Text(
                      create
                          ? 'لدي حساب بالفعل'
                          : 'إنشاء حساب جديد',
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'N • محتوى +21 محمي حسب عمر الحساب',
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

class NHome extends StatefulWidget {
  const NHome({super.key});

  @override
  State<NHome> createState() => _NHomeState();
}

class _NHomeState extends State<NHome> {
  int index = 0;

  final pages = const [
    HomePage(),
    ExplorePage(),
    CreatePage(),
    NotificationsPage(),
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
                onPressed: () {},
                icon: const Icon(Icons.search),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.chat_bubble_outline),
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
                label: 'حسابي',
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'القصص',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 105,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              Story(label: 'قصتك', own: true),
              Story(label: 'N Official'),
              Story(label: 'أحمد'),
              Story(label: 'محمد'),
              Story(label: 'سارة'),
              Story(label: 'نور'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'لك',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('الأحدث'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: data,
          builder: (_, __) {
            final posts = data.posts.where(
              (post) => !post.adult || data.adultAllowed,
            );

            return Column(
              children: posts
                  .map((post) => PostCard(post: post))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

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
    return Container(
      width: 82,
      margin: const EdgeInsetsDirectional.only(end: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: own
                    ? const [
                        Color(0xFF00C8FF),
                        Color(0xFFFF287A),
                      ]
                    : const [
                        Color(0xFF8C52FF),
                        Color(0xFFFF287A),
                      ],
              ),
            ),
            child: const CircleAvatar(
              radius: 31,
              child: Icon(Icons.person),
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
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
  });

  final Post post;

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.author,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (post.verified) ...[
                            const SizedBox(width: 4),
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
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
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
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF171B28),
                    Color(0xFF10131B),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 54,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  onPressed: () => data.like(post),
                  icon: Icon(
                    post.liked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: post.liked ? Colors.red : null,
                  ),
                ),
                Text('${post.likes}'),
                IconButton(
                  onPressed: () => data.comment(post),
                  icon: const Icon(Icons.mode_comment_outlined),
                ),
                Text('${post.comments}'),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined),
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
}

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    const users = [
      ['N Official', '@n'],
      ['N News', '@nnews'],
      ['Ahmed', '@ahmed'],
      ['Sara', '@sara'],
      ['Noor', '@noor'],
    ];

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
        const TextField(
          decoration: InputDecoration(
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
        ...users.map(
          (user) {
            final followed = data.following.contains(user[1]);

            return Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(user[0]),
                subtitle: Text(user[1]),
                trailing: FilledButton(
                  onPressed: () => data.follow(user[1]),
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
        const SizedBox(height: 8),
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
            trailing: const Icon(Icons.trending_up),
          ),
        ),
      ],
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

    data.createPost(
      text,
      adult: adult,
    );

    controller.clear();

    setState(() => adult = false);

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
            'إنشاء',
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
                hintText: 'ماذا تريد أن تشارك مع N؟',
                contentPadding: EdgeInsets.all(17),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('صورة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.videocam_outlined),
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
            fontSize: 29,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        const NotificationItem(
          icon: Icons.favorite,
          title: 'الإعجابات',
          subtitle: 'لديك تفاعلات جديدة على منشوراتك',
        ),
        const NotificationItem(
          icon: Icons.person_add,
          title: 'متابعون جدد',
          subtitle: 'هناك أشخاص جدد يتابعونك',
        ),
        const NotificationItem(
          icon: Icons.mode_comment,
          title: 'التعليقات',
          subtitle: 'لديك تعليقات جديدة',
        ),
        const NotificationItem(
          icon: Icons.celebration,
          title: 'أخبار N',
          subtitle: 'اكتشف الميزات الجديدة في N',
        ),
      ],
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
        trailing: const Icon(Icons.chevron_left),
      ),
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
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ProfileStat(
              number: '0',
              label: 'المنشورات',
            ),
            ProfileStat(
              number: '0',
              label: 'المتابعون',
            ),
            ProfileStat(
              number: '0',
              label: 'المتابَعون',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('الحساب'),
                subtitle: Text(
                  'العمر المسجل: ${data.age} سنة',
                ),
                trailing: const Icon(Icons.chevron_left),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.security),
                title: Text('الأمان والخصوصية'),
                trailing: Icon(Icons.chevron_left),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.shield_outlined),
                title: Text('الحماية العمرية'),
                subtitle: Text(
                  'محتوى +21 محمي بحسب عمر الحساب',
                ),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('الإعدادات'),
                trailing: Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginPage(),
              ),
              (_) => false,
            );
          },
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
        ),
      ],
    );
  }
}

class ProfileStat extends StatelessWidget {
  const ProfileStat({
    super.key,
    required this.number,
    required this.label,
  });

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(label),
      ],
    );
  }
}