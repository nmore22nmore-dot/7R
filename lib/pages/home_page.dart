import 'package:flutter/material.dart';
import '../n_data.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (_, __) {
        return Scaffold(
          backgroundColor: const Color(0xFF07080D),
          body: IndexedStack(
            index: index,
            children: const [
              FeedPage(),
              ExplorePage(),
              CreatePage(),
              MessagesPage(),
              ProfilePage(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            height: 68,
            backgroundColor: const Color(0xFF090A10),
            indicatorColor: const Color(0xFF182A35),
            selectedIndex: index,
            onDestinationSelected: (v) => setState(() => index = v),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'استكشاف',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_box_outlined),
                selectedIcon: Icon(Icons.add_box),
                label: 'إنشاء',
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

/* =========================
   FEED
========================= */

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = data.visiblePosts();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF07080D),
            title: const Text(
              'N',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.live_tv_outlined),
                onPressed: () => _live(context),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(child: Stories()),
          if (posts.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('لا توجد منشورات')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => PostCard(post: posts[i]),
                childCount: posts.length,
              ),
            ),
        ],
      ),
    );
  }

  void _live(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF11131A),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.live_tv, size: 50),
              const SizedBox(height: 12),
              const Text(
                'البث المباشر',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('ميزة البث المباشر جاهزة للربط بالخادم.'),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسنًا'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
   STORIES
========================= */

class Stories extends StatelessWidget {
  Stories({super.key});

  final stories = const [
    'قصتك',
    'N Official',
    'Ahmed',
    'Sara',
    'محمد',
    'علي',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          return SizedBox(
            width: 70,
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF00C8FF),
                        Color(0xFFFF287A),
                      ],
                    ),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF181B25),
                    ),
                    child: Center(
                      child: i == 0
                          ? const Icon(Icons.add)
                          : Text(
                              stories[i].substring(0, 1),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stories[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* =========================
   POST
========================= */

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
  });

  final NPost post;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 12),
      color: const Color(0xFF10121A),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 22,
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
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: Color(0xFF00C8FF),
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
                if (post.username != data.username)
                  TextButton(
                    onPressed: () => data.follow(post.username),
                    child: Text(
                      data.following.contains(post.username)
                          ? 'متابَع'
                          : 'متابعة',
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete') {
                      data.deletePost(post);
                    }
                  },
                  itemBuilder: (_) => [
                    if (post.username == data.username)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف المنشور'),
                      ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Text('إبلاغ'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (post.video)
              Container(
                height: 230,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: const Color(0xFF171A24),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 64,
                  ),
                ),
              ),
            if (post.adult)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '🔒 محتوى للبالغين +21',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              post.text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ActionButton(
                  icon: post.liked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  text: '${post.likes}',
                  active: post.liked,
                  onTap: () => data.like(post),
                ),
                ActionButton(
                  icon: Icons.comment_outlined,
                  text: '${post.comments}',
                  onTap: () => comments(context, post),
                ),
                ActionButton(
                  icon: post.saved
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  text: 'حفظ',
                  active: post.saved,
                  onTap: () => data.save(post),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تجهيز المشاركة'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void comments(BuildContext context, NPost post) {
    final c = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF11131A),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'التعليقات',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: c,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'اكتب تعليقك...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (c.text.trim().isNotEmpty) {
                    data.comment(post);
                  }
                  Navigator.pop(ctx);
                  c.dispose();
                },
                child: const Text('إرسال'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            color: active ? Colors.redAccent : Colors.white,
          ),
        ),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/* =========================
   EXPLORE
========================= */

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final controller = TextEditingController();
  String query = '';

  @override
  Widget build(BuildContext context) {
    final posts = data.visiblePosts().where((p) {
      final q = query.toLowerCase();
      return p.text.toLowerCase().contains(q) ||
          p.author.toLowerCase().contains(q) ||
          p.username.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(
            backgroundColor: Color(0xFF07080D),
            title: Text(
              'استكشاف',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: controller,
                onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(
                  hintText: 'ابحث عن أشخاص أو منشورات...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFF151720),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => PostCard(post: posts[i]),
              childCount: posts.length,
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================
   CREATE
========================= */

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
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'إنشاء',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            minLines: 6,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: 'ماذا تريد أن تنشر؟',
              filled: true,
              fillColor: const Color(0xFF151720),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
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
            title: const Text('محتوى +21'),
            subtitle: const Text('يظهر للمستخدمين بعمر 21 سنة فأكثر'),
            value: adult,
            onChanged: (v) => setState(() => adult = v),
          ),
          DropdownButtonFormField<String>(
            initialValue: visibility,
            decoration: const InputDecoration(
              labelText: 'الخصوصية',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'عام', child: Text('عام')),
              DropdownMenuItem(
                value: 'المتابعون',
                child: Text('المتابعون'),
              ),
              DropdownMenuItem(value: 'خاص', child: Text('خاص')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => visibility = v);
            },
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: publish,
            icon: const Icon(Icons.send),
            label: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'نشر الآن',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void publish() {
    if (controller.text.trim().isEmpty) return;

    if (adult && !data.adultAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('محتوى +21 غير متاح لمن هم دون 21 عاماً'),
        ),
      );
      return;
    }

    data.createPost(
      controller.text,
      adult: adult,
      visibility: visibility,
    );

    controller.clear();
    setState(() {
      adult = false;
      visibility = 'عام';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نشر المنشور')),
    );
  }
}

/* =========================
   MESSAGES
========================= */

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = data.messages.entries.toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(
            backgroundColor: Color(0xFF07080D),
            title: Text('الرسائل'),
          ),
          if (entries.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('لا توجد محادثات')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final e = entries[i];
                  final last =
                      e.value.isEmpty ? null : e.value.last;

                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(e.key),
                    subtitle: Text(
                      last?.text ?? 'ابدأ المحادثة',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            username: e.key,
                          ),
                        ),
                      );
                    },
                  );
                },
                childCount: entries.length,
              ),
            ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.username,
  });

  final String username;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (_, __) {
        final list = data.messages[widget.username] ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.username),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final mine = m.sender == data.username;

                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(0xFF006D8D)
                              : const Color(0xFF1A1D27),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(m.text),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'اكتب رسالة...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        data.sendMessage(
                          widget.username,
                          controller.text,
                        );
                        controller.clear();
                      },
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* =========================
   PROFILE
========================= */

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = data.postsOf(data.username);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('حسابي'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    child: Icon(Icons.person, size: 55),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '@${data.username}',
                    style: const TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                    children: [
                      Stat('${posts.length}', 'منشورات'),
                      Stat(
                        '${data.following.length}',
                        'متابَعون',
                      ),
                      Stat('0', 'متابعون'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('تعديل الملف الشخصي'),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'منشوراتي',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => PostCard(post: posts[i]),
              childCount: posts.length,
            ),
          ),
        ],
      ),
    );
  }
}

class Stat extends StatelessWidget {
  const Stat(this.value, this.label, {super.key});

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
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/* =========================
   SETTINGS
========================= */

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (_, __) {
        return Scaffold(
          appBar: AppBar(title: const Text('الإعدادات')),
          body: ListView(
            children: [
              SwitchListTile(
                title: const Text('حساب خاص'),
                value: data.privateAccount,
                onChanged: data.setPrivateAccount,
              ),
              SwitchListTile(
                title: const Text('حالة النشاط'),
                value: data.activityStatus,
                onChanged: data.setActivityStatus,
              ),
              SwitchListTile(
                title: const Text('السماح بالرسائل'),
                value: data.allowMessages,
                onChanged: data.setAllowMessages,
              ),
              SwitchListTile(
                title: const Text('الإشعارات'),
                value: data.notifications,
                onChanged: data.setNotifications,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.military_tech),
                title: const Text('مستوى الداعم'),
                trailing: Text('${data.supporterLevel}'),
              ),
              ListTile(
                leading: const Icon(Icons.stars),
                title: const Text('الشارات والجوائز'),
                subtitle: Text(
                  data.badges.join(' • '),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.monetization_on),
                title: const Text('الرصيد'),
                trailing: Text('${data.coins}'),
              ),
            ],
          ),
        );
      },
    );
  }
}
