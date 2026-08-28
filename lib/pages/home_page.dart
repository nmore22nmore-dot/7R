import 'package:flutter/material.dart';
import '../n_data.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selected = 0;

  final pages = const [
    _FeedPage(),
    _ExplorePlaceholder(),
    _CreatePlaceholder(),
    _MessagesPlaceholder(),
    _ProfilePlaceholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: data,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: pages[selected],
          bottomNavigationBar: NavigationBar(
            backgroundColor: Colors.black,
            indicatorColor: const Color(0xFF18202A),
            selectedIndex: selected,
            onDestinationSelected: (index) {
              setState(() {
                selected = index;
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
                icon: Icon(Icons.add_box_outlined),
                selectedIcon: Icon(Icons.add_box),
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

class _FeedPage extends StatelessWidget {
  const _FeedPage();

  @override
  Widget build(BuildContext context) {
    final posts = data.visiblePosts();

    return Stack(
      children: [
        PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return _VideoPost(post: posts[index]);
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: Row(
              children: [
                const Text(
                  'N',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.live_tv_outlined,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoPost extends StatelessWidget {
  const _VideoPost({
    required this.post,
  });

  final NPost post;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF181B27),
                Color(0xFF050509),
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.play_circle_outline,
              size: 85,
              color: Colors.white54,
            ),
          ),
        ),

        Positioned(
          right: 16,
          left: 85,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${post.username}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                post.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(
                    Icons.music_note,
                    size: 16,
                  ),
                  SizedBox(width: 5),
                  Text('الصوت الأصلي'),
                ],
              ),
            ],
          ),
        ),

        Positioned(
          left: 8,
          bottom: 25,
          child: Column(
            children: [
              _SideAction(
                icon: post.liked
                    ? Icons.favorite
                    : Icons.favorite_border,
                label: '${post.likes}',
                active: post.liked,
                onTap: () => data.like(post),
              ),
              _SideAction(
                icon: Icons.comment_outlined,
                label: '${post.comments}',
                onTap: () => _showComment(context, post),
              ),
              _SideAction(
                icon: post.saved
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                label: 'حفظ',
                active: post.saved,
                onTap: () => data.save(post),
              ),
              _SideAction(
                icon: Icons.share_outlined,
                label: 'مشاركة',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تجهيز المشاركة'),
                    ),
                  );
                },
              ),
              if (post.username == data.username)
                _SideAction(
                  icon: Icons.delete_outline,
                  label: 'حذف',
                  onTap: () => _deletePost(context, post),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _deletePost(BuildContext context, NPost post) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('حذف المنشور؟'),
          content: const Text(
            'سيتم حذف هذا المنشور من حسابك.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                data.deletePost(post);
                Navigator.pop(context);
              },
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
  }

  void _showComment(
    BuildContext context,
    NPost post,
  ) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
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
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'اكتب تعليقك...',
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

                    Navigator.pop(context);
                    controller.dispose();
                  },
                  child: const Text('إرسال'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          IconButton(
            onPressed: onTap,
            icon: Icon(
              icon,
              size: 31,
              color: active ? Colors.red : Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplorePlaceholder extends StatelessWidget {
  const _ExplorePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('استكشاف'),
    );
  }
}

class _CreatePlaceholder extends StatelessWidget {
  const _CreatePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('إنشاء منشور'),
    );
  }
}

class _MessagesPlaceholder extends StatelessWidget {
  const _MessagesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('الرسائل'),
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('حسابي'),
    );
  }
}
