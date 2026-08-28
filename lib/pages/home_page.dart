import 'package:flutter/material.dart';

import '../n_data.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF07080D),
          body: IndexedStack(
            index: selectedIndex,
            children: [
              const _HomeFeedPage(),
              const _ExplorePage(),
              const _CreatePage(),
              const _MessagesPage(),
              const _ProfilePage(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            height: 72,
            backgroundColor: const Color(0xFF090A10),
            indicatorColor: const Color(0xFF182A35),
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
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
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: 'إنشاء',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
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

class _HomeFeedPage extends StatelessWidget {
  const _HomeFeedPage();

  @override
  Widget build(BuildContext context) {
    final posts = data.visiblePosts();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF07080D),
            surfaceTintColor: Colors.transparent,
            floating: true,
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
                icon: const Icon(Icons.live_tv_outlined),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: _StoriesSection(),
          ),

          if (posts.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'لا توجد منشورات بعد',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _PostCard(post: posts[index]);
                },
                childCount: posts.length,
              ),
            ),
        ],
      ),
    );
  }
}

/* =========================================================
   STORIES
========================================================= */

class _StoriesSection extends StatelessWidget {
  _StoriesSection();

  final List<Map<String, String>> stories = const [
    {'name': 'قصتك', 'username': 'your_story'},
    {'name': 'N Official', 'username': 'n'},
    {'name': 'Ahmed', 'username': 'ahmed'},
    {'name': 'Sara', 'username': 'sara'},
    {'name': 'محمد', 'username': 'mohammed'},
    {'name': 'علي', 'username': 'ali'},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final story = stories[index];

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
                      color: Color(0xFF151720),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: index == 0
                          ? const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 28,
                            )
                          : Text(
                              story['name']!.substring(0, 1),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  story['name']!,
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

/* =========================================================
   POST CARD
========================================================= */

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
  });

  final NPost post;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      color: const Color(0xFF10121A),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
                  backgroundColor: Color(0xFF202633),
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                  onSelected: (value) {
                    if (value == 'delete' &&
                        post.username == data.username) {
                      data.deletePost(post);
                    }
                  },
                  itemBuilder: (_) {
                    return [
                      if (post.username == data.username)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('حذف المنشور'),
                        ),
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('إبلاغ'),
                      ),
                    ];
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (post.adult)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'محتوى للبالغين',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Text(
              post.text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                _PostAction(
                  icon: post.liked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: '${post.likes}',
                  active: post.liked,
                  onPressed: () => data.like(post),
                ),
                _PostAction(
                  icon: Icons.comment_outlined,
                  label: '${post.comments}',
                  onPressed: () => _showComments(context, post),
                ),
                _PostAction(
                  icon: post.saved
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  label: 'حفظ',
                  active: post.saved,
                  onPressed: () => data.save(post),
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

  void _showComments(
    BuildContext context,
    NPost post,
  ) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF11131A),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 16,
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
              const SizedBox(height: 16),
              TextField(
                controller: controller,
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
                    if (controller.text.trim().isNotEmpty) {
                      data.comment(post);
                    }

                    controller.dispose();
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('إرسال التعليق'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: active ? Colors.redAccent : Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/* =========================================================
   EXPLORE
========================================================= */

class _ExplorePage extends StatefulWidget {
  const _ExplorePage();

  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePage> {
  final controller = TextEditingController();
  String query = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = data
        .visiblePosts()
        .where(
          (post) =>
              post.text.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
              post.author.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
              post.username.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
        )
        .toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(
            backgroundColor: Color(0xFF07080D),
            title: Text(
              'استكشاف',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: controller,
                onChanged: (value) {
                  setState(() {
                    query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ابحث عن أشخاص أو منشورات...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            controller.clear();
                            setState(() {
                              query = '';
                            });
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,
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
          if (results.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'لا توجد نتائج',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 17,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _PostCard(post: results[index]);
                },
                childCount: results.length,
              ),
            ),
        ],
      ),
    );
  }
}

/* =========================================================
   CREATE
========================================================= */

class _CreatePage extends StatefulWidget {
  const _CreatePage();

  @override
  State<_CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<_CreatePage> {
  final controller = TextEditingController();

  bool adult = false;
  String visibility = 'عام';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void create() {
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتب شيئاً أولاً'),
        ),
      );
      return;
    }

    if (adult && !data.adultAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكنك نشر محتوى للبالغين قبل سن 21 عاماً',
          ),
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
      const SnackBar(
        content: Text('تم نشر المنشور بنجاح'),
      ),
    );
  }

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
          const SizedBox(height: 6),
          const Text(
            'شارك لحظتك مع مجتمع N',
            style: TextStyle(
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF11131A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      child: Icon(Icons.person),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  minLines: 6,
                  maxLines: 12,
                  decoration: InputDecoration(
                    hintText: 'ماذا تريد أن تنشر؟',
                    filled: true,
                    fillColor: const Color(0xFF191B24),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.photo_library_outlined),
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
                const Divider(height: 30),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('محتوى للبالغين +21'),
                  subtitle: const Text(
                    'سيظهر فقط للمستخدمين بعمر 21 سنة أو أكثر',
                  ),
                  value: adult,
                  onChanged: (value) {
                    setState(() {
                      adult = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: visibility,
                  decoration: const InputDecoration(
                    labelText: 'الخصوصية',
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: create,
                    icon: const Icon(Icons.send),
                    label: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'نشر الآن',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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

class _MessagesPage extends StatelessWidget {
  const _MessagesPage();

  @override
  Widget build(BuildContext context) {
    final conversations = data.sortedConversations();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(
            backgroundColor: Color(0xFF07080D),
            title: Text(
              'الرسائل',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (conversations.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('لا توجد محادثات'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = conversations[index];
                  final username = entry.key;
                  final messages = entry.value;
                  final last = messages.isEmpty
                      ? null
                      : messages.last;

                  final displayName = _displayName(username);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 5,
                    ),
                    leading: const CircleAvatar(
                      radius: 27,
                      child: Icon(Icons.person),
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      last?.text ?? 'ابدأ المحادثة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: last == null
                        ? null
                        : Text(
                            last.time,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ChatPage(
                            username: username,
                            name: displayName,
                          ),
                        ),
                      );
                    },
                  );
                },
                childCount: conversations.length,
              ),
            ),
        ],
      ),
    );
  }

  String _displayName(String username) {
    switch (username) {
      case 'ahmed':
        return 'Ahmed';
      case 'sara':
        return 'Sara';
      default:
        return username;
    }
  }
}

/* =========================================================
   CHAT
========================================================= */

class _ChatPage extends StatefulWidget {
  const _ChatPage({
    required this.username,
    required this.name,
  });

  final String username;
  final String name;

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void send() {
    final text = controller.text.trim();

    if (text.isEmpty) return;

    data.sendMessage(widget.username, text);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
final currentMessages = data.messages[widget.username] ?? [];
    return AnimatedBuilder(
      animation: data,
      builder: (context, _) {
        final currentMessages = data.messages[widget.username] ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFF07080D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF07080D),
            title: Row(
              children: [
                const CircleAvatar(
                  radius: 19,
                  child: Icon(Icons.person, size: 20),
                ),
                const SizedBox(width: 10),
                Text(widget.name),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: currentMessages.length,
                  itemBuilder: (context, index) {
                    final message = currentMessages[index];
                    final mine = message.sender == data.username;

                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.78,
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(0xFF006D8D)
                              : const Color(0xFF1A1D27),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(message.text),
                            const SizedBox(height: 4),
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
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    10,
                    6,
                    10,
                    10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالة...',
                            filled: true,
                            fillColor: const Color(0xFF151720),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FloatingActionButton.small(
                        onPressed: send,
                        child: const Icon(Icons.send),
                      ),
                    ],
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

/* =========================================================
   PROFILE
========================================================= */

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    final myPosts = data.postsOf(data.username);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF07080D),
            title: const Text(
              'حسابي',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  _openSettings(context);
                },
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                10,
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 48,
                    backgroundColor: Color(0xFF1C2630),
                    child: Icon(
                      Icons.person,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.name,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${data.username}',
                    style: const TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                  if (data.email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      data.email,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ProfileStat(
                        value: '${myPosts.length}',
                        label: 'منشورات',
                      ),
                      _ProfileStat(
                        value: '${data.following.length}',
                        label: 'متابَعون',
                      ),
                      const _ProfileStat(
                        value: '0',
                        label: 'متابعون',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تعديل الملف الشخصي',
                            ),
                          ),
                        );
                      },
                      child: const Text('تعديل الملف الشخصي'),
                    ),
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

          if (myPosts.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'لم تنشر شيئاً بعد',
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _PostCard(
                    post: myPosts[index],
                  );
                },
                childCount: myPosts.length,
              ),
            ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const _SettingsPage(),
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
        const SizedBox(height: 4),
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

/* =========================================================
   SETTINGS
========================================================= */

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF07080D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF07080D),
            title: const Text('الإعدادات'),
          ),
          body: ListView(
            children: [
              const _SettingsHeader(
                title: 'الحساب والخصوصية',
              ),

              SwitchListTile(
                title: const Text('حساب خاص'),
                subtitle: const Text(
                  'تحكم بمن يستطيع متابعة حسابك',
                ),
                value: data.privateAccount,
                onChanged: data.setPrivateAccount,
              ),

              SwitchListTile(
                title: const Text('حالة النشاط'),
                subtitle: const Text(
                  'السماح للآخرين برؤية نشاطك',
                ),
                value: data.activityStatus,
                onChanged: data.setActivityStatus,
              ),

              SwitchListTile(
                title: const Text('السماح بالرسائل'),
                value: data.allowMessages,
                onChanged: data.setAllowMessages,
              ),

              const _SettingsHeader(
                title: 'الإشعارات',
              ),

              SwitchListTile(
                title: const Text('الإشعارات'),
                value: data.notifications,
                onChanged: data.setNotifications,
              ),

              SwitchListTile(
                title: const Text('الأصوات'),
                value: data.sounds,
                onChanged: data.setSounds,
              ),

              const _SettingsHeader(
                title: 'الحساب',
              ),

              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('اسم المستخدم'),
                subtitle: Text('@${data.username}'),
              ),

              ListTile(
                leading: const Icon(Icons.cake_outlined),
                title: const Text('العمر'),
                subtitle: Text('${data.age} سنة'),
              ),

              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('تسجيل الخروج'),
                textColor: Colors.redAccent,
                iconColor: Colors.redAccent,
                onTap: () {
                  data.logout();

                  Navigator.popUntil(
                    context,
                    (route) => route.isFirst,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF00C8FF),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
